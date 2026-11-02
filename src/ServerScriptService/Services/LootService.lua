--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side loot service. Handles loot container spawning and searching
-- with per-container cooldowns so loot cannot be farmed by re-searching.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local LootService = {}
local started = false

local LootRemote: RemoteEvent

-- Loot table format: each entry is { id, weight, min, max }
-- Roll weighted entries; containers roll 1-3 entries per search.
local LootTables = {
	GasStationCache = {
		{ id = "WaterBottleClean", weight = 30, min = 1, max = 2 },
		{ id = "CannedBeans", weight = 30, min = 1, max = 2 },
		{ id = "Bandage", weight = 25, min = 1, max = 2 },
		{ id = "Flashlight", weight = 10, min = 1, max = 1 },
		{ id = "TrailSnack", weight = 15, min = 1, max = 3 },
	},
	ResidentialCabinet = {
		{ id = "TrailSnack", weight = 35, min = 1, max = 2 },
		{ id = "WaterFlaskMurky", weight = 25, min = 1, max = 1 },
		{ id = "Painkillers", weight = 20, min = 1, max = 2 },
		{ id = "Cloth", weight = 30, min = 1, max = 3 },
		{ id = "SurvivorPhoto", weight = 10, min = 1, max = 1 },
	},
	IndustrialCrate = {
		{ id = "ScrapMetal", weight = 35, min = 2, max = 5 },
		{ id = "Nails", weight = 30, min = 5, max = 15 },
		{ id = "Electronics", weight = 20, min = 1, max = 3 },
		{ id = "Rope", weight = 15, min = 1, max = 2 },
	},
	RareMedicalLocker = {
		{ id = "FirstAidKit", weight = 25, min = 1, max = 1 },
		{ id = "Antibiotics", weight = 30, min = 1, max = 2 },
		{ id = "Bandage", weight = 45, min = 2, max = 4 },
	},
	HiddenCache = {
		{ id = "PreservedRation", weight = 30, min = 1, max = 2 },
		{ id = "BlackoutRecording", weight = 15, min = 1, max = 1 },
		{ id = "FirstAidKit", weight = 20, min = 1, max = 1 },
		{ id = "Chemicals", weight = 35, min = 1, max = 3 },
	},
}

-- Search cooldown per player per container instance.
local containerCooldowns: {[Player]: {[string]: number}} = {}
local ContainerCooldownSeconds = 60

function LootService.RegisterContainer(container: BasePart, lootTable: string, id: string)
	if not LootTables[lootTable] then
		warn(("AFTERZERO LootService: unknown loot table %s"):format(lootTable))
		return
	end

	container:SetAttribute("LootTable", lootTable)
	container:SetAttribute("LootContainerId", id)
end

local function rollTable(tableName: string): {string}
	local table = LootTables[tableName]
	local results = {}
	if not table then
		return results
	end

	local rolls = math.random(1, 3)
	for _ = 1, rolls do
		local totalWeight = 0
		for _, entry in ipairs(table) do
			totalWeight += entry.weight
		end
		if totalWeight <= 0 then
			break
		end

		local roll = math.random() * totalWeight
		local chosen = table[#table]
		for _, entry in ipairs(table) do
			roll -= entry.weight
			if roll <= 0 then
				chosen = entry
				break
			end
		end

		local count = math.random(chosen.min, chosen.max)
		table.insert(results, { chosen.id, count })
	end

	return results
end

function LootService.SearchContainer(player: Player, container: BasePart): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local lootTable = container:GetAttribute("LootTable")
	local containerId = container:GetAttribute("LootContainerId")
	if typeof(lootTable) ~= "string" or typeof(containerId) ~= "string" then
		return false, "NotALootContainer"
	end

	-- Distance validation: player must be near the container.
	local character = player.Character
	if not character or not character.PrimaryPart then
		return false, "NoCharacter"
	end
	if (character.PrimaryPart.Position - container.Position).Magnitude > 12 then
		return false, "TooFar"
	end

	-- Per-player cooldown.
	local playerCooldowns = containerCooldowns[player]
	if playerCooldowns == nil then
		playerCooldowns = {}
		containerCooldowns[player] = playerCooldowns
	end
	local lastSearched = playerCooldowns[containerId] or 0
	if os.clock() - lastSearched < ContainerCooldownSeconds then
		return false, "ContainerOnCooldown"
	end

	playerCooldowns[containerId] = os.clock()

	local results = rollTable(lootTable)
	local granted = {}
	for _, entry in ipairs(results) do
		local ok, err = InventoryService.AddItem(player, entry[1], entry[2])
		if ok then
			table.insert(granted, { id = entry[1], count = entry[2] })
		end
	end

	if LootRemote then
		LootRemote:FireClient(player, "LootFound", granted)
	end

	return true, nil
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "Search" then
		if typeof(payload) ~= "table" or typeof(payload.containerId) ~= "string" then
			return
		end

		-- Resolve container by id from workspace folder.
		local workspaceContainers = game:GetService("Workspace"):FindFirstChild("LootContainers")
		local container = if workspaceContainers then workspaceContainers:FindFirstChild(payload.containerId) else nil
		if container and container:IsA("BasePart") then
			LootService.SearchContainer(player, container)
		end
	end
end

function LootService.Start()
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
	LootRemote = remotesFolder:FindFirstChild("LootRemote")
	if LootRemote == nil then
		LootRemote = Instance.new("RemoteEvent")
		LootRemote.Name = "LootRemote"
		Remote.Name = "LootRemote"
		LootRemote.Parent = remotesFolder
	end

	LootRemote.OnServerEvent:Connect(function(player, action, payload)
		handleRemote(player, action, payload)
	end)

	Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player)
		containerCooldowns[player] = nil
	end)
end

return LootService
