--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side crafting service. Validates recipes, verifies ingredients,
-- consumes resources atomically, and tracks in-progress crafts to prevent
-- duplicate rewards or double-crafting exploits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))
local RecipeDefinitions = require(Shared:WaitForChild("RecipeDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local CraftingService = {}
local started = false

local CraftingRemote: RemoteEvent

-- Active crafts: player -> { recipeId, completesAt, station }
local activeCrafts: {[Player]: any} = {}

-- Stations present in the world, tagged via CollectionService.
local CollectionService = game:GetService("CollectionService")
local StationTag = "CraftingStation"

local function getStationName(player: Player, stationPart: BasePart?): string
	-- Validate the claimed station exists, is near the player, and has an
	-- accepted station type. Clients may suggest a station; the server
	-- verifies position and type.
	if not stationPart or not stationPart:IsA("BasePart") then
		return "Hand"
	end

	local character = player.Character
	if not character or not character.PrimaryPart then
		return "Hand"
	end
	if (character.PrimaryPart.Position - stationPart.Position).Magnitude > 16 then
		return "Hand"
	end

	local stationType = stationPart:GetAttribute("StationType")
	if typeof(stationType) ~= "string" then
		return "Hand"
	end
	if stationType ~= "Hand" and stationType ~= "Workbench" and stationType ~= "MedicStation" then
		return "Hand"
	end

	return stationType
end

local function hasIngredients(player: Player, recipe: any): boolean
	for _, ingredient in ipairs(recipe.ingredients) do
		if InventoryService.CountItem(player, ingredient.id) < ingredient.count then
			return false
		end
	end
	return true
end

local function consumeIngredients(player: Player, recipe: any): (boolean, string?)
	-- Remove all ingredients; removal is validated count-wise first so this
	-- pass cannot partially complete.
	for _, ingredient in ipairs(recipe.ingredients) do
		local ok, err = InventoryService.RemoveItem(player, ingredient.id, ingredient.count)
		if not ok then
			return false, tostring(err)
		end
	end
	return true, nil
end

local function refundIngredients(player: Player, recipe: any): boolean
	-- Returns false if any ingredient could not be fully returned (for
	-- example, inventory full); the caller logs a warning in that case.
	local allRefunded = true
	for _, ingredient in ipairs(recipe.ingredients) do
		local ok = InventoryService.AddItem(player, ingredient.id, ingredient.count)
		if not ok then
			allRefunded = false
		end
	end
	return allRefunded
end

function CraftingService.Craft(player: Player, recipeId: string, stationPart: BasePart?): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	if activeCrafts[player] then
		return false, "AlreadyCrafting"
	end

	local recipe = RecipeDefinitions.Get(recipeId)
	if not recipe then
		return false, "UnknownRecipe"
	end

	local output = ItemDefinitions.Get(recipe.outputId)
	if not output then
		return false, "UnknownOutput"
	end

	-- Level requirement
	local level = if typeof(data.character.level) == "number" then data.character.level else 1
	if level < recipe.level then
		return false, "LevelTooLow"
	end

	-- Station requirement
	local station = getStationName(player, stationPart)
	if recipe.station ~= "Hand" and recipe.station ~= station then
		return false, "WrongStation"
	end

	-- Unlock requirement
	if recipe.requiresUnlock then
		local unlocked = data.progression.craftedRecipes
		if typeof(unlocked) ~= "table" or not unlocked[recipeId] then
			return false, "RecipeLocked"
		end
	end

	-- Ingredients
	if not hasIngredients(player, recipe) then
		return false, "MissingIngredients"
	end

	local consumed, err = consumeIngredients(player, recipe)
	if not consumed then
		return false, err
	end

	-- Instant crafts complete immediately; timed crafts finish later.
	if recipe.craftSeconds <= 0 then
		local added = InventoryService.AddItem(player, recipe.outputId, recipe.outputCount)
		if not added then
			refundIngredients(player, recipe)
			return false, "InventoryFull"
		end
		return true, nil
	end

	activeCrafts[player] = {
		recipeId = recipeId,
		completesAt = os.clock() + recipe.craftSeconds,
	}

	if CraftingRemote then
		CraftingRemote:FireClient(player, "CraftStarted", {
			recipeId = recipeId,
			craftSeconds = recipe.craftSeconds,
		})
	end

	return true, nil
end

function CraftingService.Cancel(player: Player): (boolean, string?)
	local active = activeCrafts[player]
	if not active then
		return false, "NoActiveCraft"
	end

	local recipe = RecipeDefinitions.Get(active.recipeId)
	if not recipe then
		activeCrafts[player] = nil
		return false, "UnknownRecipe"
	end

	activeCrafts[player] = nil
	local allRefunded = refundIngredients(player, recipe)
	if not allRefunded then
		warn(("AFTERZERO: partial refund after cancel for %s (inventory likely full)"):format(player.Name))
	end

	if CraftingRemote then
		CraftingRemote:FireClient(player, "CraftCancelled", {})
	end

	return true, nil
end

local function completeCraft(player: Player, recipe: any)
	activeCrafts[player] = nil

	local added, err = InventoryService.AddItem(player, recipe.outputId, recipe.outputCount)
	if not added then
		-- Refund ingredients if the output does not fit.
		refundIngredients(player, recipe)
		warn(("AFTERZERO: craft output rejected for %s (%s)"):format(player.Name, tostring(err)))
		return
	end

	if CraftingRemote then
		CraftingRemote:FireClient(player, "CraftCompleted", {
			recipeId = recipe.id,
			outputId = recipe.outputId,
			outputCount = recipe.outputCount,
		})
	end
end

local function handleRemote(player: Player, action: string, payload: any)
	-- The server never trusts payload-provided station instances directly;
	-- it re-validates type, position, and attribute.
	local stationPart = nil
	if typeof(payload) == "table" and typeof(payload.stationPart) == "Instance" then
		local instance = payload.stationPart
		if instance:IsA("BasePart") and CollectionService:HasTag(instance, StationTag) then
			stationPart = instance
		end
	end

	if action == "Craft" then
		local recipeId = if typeof(payload) == "table" then payload.recipeId else nil
		if typeof(recipeId) ~= "string" then
			return
		end
		CraftingService.Craft(player, recipeId, stationPart)
	elseif action == "Cancel" then
		CraftingService.Cancel(player)
	end
end

function CraftingService.Start()
	if started then
		return
	end
	started = true

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesFolder == nil then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	CraftingRemote = remotesFolder:FindFirstChild("CraftingRemote")
	if CraftingRemote == nil then
		CraftingRemote = Instance.new("RemoteEvent")
		CraftingRemote.Name = "CraftingRemote"
		CraftingRemote.Parent = remotesFolder
	end

	CraftingRemote.OnServerEvent:Connect(handleRemote)

	-- Completion watcher: finishes timed crafts when their time elapses.
	task.spawn(function()
		while started do
			task.wait(0.25)
			local now = os.clock()
			for player, active in pairs(activeCrafts) do
				if not player.Parent then
					activeCrafts[player] = nil
					continue
				end
				if now >= active.completesAt then
					local recipe = RecipeDefinitions.Get(active.recipeId)
					if recipe then
						completeCraft(player, recipe)
					else
						activeCrafts[player] = nil
					end
				end
			end
		end
	end)

	-- Player leaves: any in-progress craft is simply lost (ingredients were
	-- consumed at start). Refund on leave would enable crafting-and-leave
	-- dupes against future timed outputs.
	Players.PlayerRemoving:Connect(function(player)
		activeCrafts[player] = nil
	end)
end

return CraftingService
