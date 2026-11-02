--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side building service. Grid placement, ownership, cost validation,
-- overlap prevention, half-refund removal, and rebuild-on-join from saved
-- data. All placements are validated on the server; clients send intent only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local BuildingService = {}
local started = false

local BuildRemote: RemoteEvent

-- Template definitions: cost, size, appearance. Only templates listed here
-- can ever be placed.
type Template = {
	id: string,
	name: string,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	cost: {{ id: string, count: number }},
	registerCraftingStation: string?, -- StationType to register as, if any
}

local Templates: {[string]: Template} = {
	WoodWall = {
		id = "WoodWall", name = "Wood Wall",
		size = Vector3.new(8, 10, 1), material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(101, 76, 54),
		cost = { { id = "Wood", count = 5 } },
	},
	WoodFloor = {
		id = "WoodFloor", name = "Wood Floor",
		size = Vector3.new(8, 1, 8), material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(113, 88, 62),
		cost = { { id = "Wood", count = 4 } },
	},
	ScrapGate = {
		id = "ScrapGate", name = "Scrap Gate",
		size = Vector3.new(10, 8, 1), material = Enum.Material.CorrodedMetal,
		color = Color3.fromRGB(82, 87, 86),
		cost = { { id = "ScrapMetal", count = 4 }, { id = "Nails", count = 6 } },
	},
	FieldWorkbench = {
		id = "FieldWorkbench", name = "Field Workbench",
		size = Vector3.new(4, 3, 2.5), material = Enum.Material.Metal,
		color = Color3.fromRGB(88, 94, 92),
		cost = { { id = "ScrapMetal", count = 4 }, { id = "Wood", count = 4 } },
		registerCraftingStation = "Workbench",
	},
}

local PlacementRange = 24
local GridSize = 2 -- structures snap to a 2-stud grid
local MinStructureSpacing = 5 -- min distance between distinct structures
local MaxStructuresPerPlayer = 40
local RegionBounds = 400 -- keep builds inside the Greywood playfield

-- Live structure records: model -> record. Records also persist in player data.
local liveStructures: {[Model]: any} = {}
local structureById: {[string]: Model} = {}

local function getStructuresTable(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	if typeof(data.structures) ~= "table" then
		data.structures = {}
	end
	if typeof(data.structures.built) ~= "table" then
		data.structures.built = {}
	end
	return data.structures
end

local function snapToGrid(value: number): number
	return math.floor(value / GridSize + 0.5) * GridSize
end

local function canAfford(player: Player, template: Template): boolean
	for _, costEntry in ipairs(template.cost) do
		if InventoryService.CountItem(player, costEntry.id) < costEntry.count then
			return false
		end
	end
	return true
end

local function consumeCost(player: Player, template: Template): (boolean, string?)
	for _, costEntry in ipairs(template.cost) do
		local ok, err = InventoryService.RemoveItem(player, costEntry.id, costEntry.count)
		if not ok then
			return false, tostring(err)
		end
	end
	return true, nil
end

local function refundHalf(player: Player, template: Template)
	for _, costEntry in ipairs(template.cost) do
		InventoryService.AddItem(player, costEntry.id, math.max(1, math.floor(costEntry.count / 2)))
	end
end

local function overlapsExisting(position: Vector3): boolean
	for _, record in pairs(liveStructures) do
		local part = record.model:FindFirstChild("Structure")
		if part and part:IsA("BasePart") then
			if (part.Position - position).Magnitude < MinStructureSpacing then
				return true
			end
		end
	end
	return false
end

local function buildStructureModel(record: any): Model
	local template = Templates[record.templateId]
	local model = Instance.new("Model")
	model.Name = "Structure_" .. record.id

	local part = Instance.new("Part")
	part.Name = "Structure"
	part.Size = template.size
	part.CFrame = CFrame.new(record.x, record.y, record.z) * CFrame.Angles(0, record.ry, 0)
	part.Color = template.color
	part.Material = template.material
	part.Anchored = true
	part.Parent = model

	model:SetAttribute("StructureId", record.id)
	model:SetAttribute("OwnerId", record.ownerUserId)
	model:SetAttribute("TemplateId", template.id)

	if template.registerCraftingStation then
		local CollectionService = game:GetService("CollectionService")
		CollectionService:AddTag(part, "CraftingStation")
		part:SetAttribute("StationType", template.registerCraftingStation)
	end

	return model
end

local function registerLive(record: any): Model
	local model = buildStructureModel(record)
	model.Parent = Workspace
	liveStructures[model] = record
	structureById[record.id] = model
	return model
end

function BuildingService.PlaceStructure(player: Player, templateId: string, position: Vector3, rotationDegrees: number): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local template = Templates[templateId]
	if not template then
		return false, "UnknownTemplate"
	end

	local structures = getStructuresTable(player)
	if not structures then
		return false, "DataNotReady"
	end

	if #structures.built >= MaxStructuresPerPlayer then
		return false, "StructureLimitReached"
	end

	-- Placement range: the position must be near the player.
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false, "NoCharacter"
	end
	if (root.Position - position).Magnitude > PlacementRange then
		return false, "TooFar"
	end

	-- Keep builds inside the playfield.
	if math.abs(position.X) > RegionBounds or math.abs(position.Z) > RegionBounds then
		return false, "OutsideBuildArea"
	end
	if position.Y < 0 or position.Y > 60 then
		return false, "InvalidHeight"
	end

	-- No floating builds: snap Y to a ground band.
	local snapped = Vector3.new(snapToGrid(position.X), math.clamp(position.Y, 0.5, 60), snapToGrid(position.Z))

	if overlapsExisting(snapped) then
		return false, "OverlapsStructure"
	end

	if not canAfford(player, template) then
		return false, "MissingMaterials"
	end

	-- Consume cost before creating anything.
	local consumed, err = consumeCost(player, template)
	if not consumed then
		return false, err
	end

	local record = {
		id = "s_" .. HttpService:GenerateGUID(false),
		templateId = templateId,
		ownerUserId = player.UserId,
		x = snapped.X,
		y = snapped.Y,
		z = snapped.Z,
		ry = math.rad(math.floor(rotationDegrees)),
	}

	table.insert(structures.built, record)
	registerLive(record)

	if BuildRemote then
		BuildRemote:FireClient(player, "Placed", { templateId = templateId, position = snapped })
	end

	return true, nil
end

function BuildingService.RemoveStructure(player: Player, structureId: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local model = structureById[structureId]
	if not model then
		return false, "UnknownStructure"
	end

	local record = liveStructures[model]
	if not record then
		return false, "UnknownStructure"
	end

	-- Ownership check: only the owner can remove their structure.
	if record.ownerUserId ~= player.UserId then
		return false, "NotOwner"
	end

	local template = Templates[record.templateId]
	local structures = getStructuresTable(player)
	if not structures then
		return false, "DataNotReady"
	end

	-- Remove from persisted list.
	local removed = false
	for index, saved in ipairs(structures.built) do
		if saved.id == structureId then
			table.remove(structures.built, index)
			removed = true
			break
		end
	end
	if not removed then
		return false, "RecordNotFound"
	end

	liveStructures[model] = nil
	structureById[structureId] = nil
	model:Destroy()

	-- Half-material refund.
	if template then
		refundHalf(player, template)
	end

	if BuildRemote then
		BuildRemote:FireClient(player, "Removed", { structureId = structureId })
	end

	return true, nil
end

-- Rebuild a joining player's saved structures server-side.
local function rebuildForPlayer(player: Player)
	local structures = getStructuresTable(player)
	if not structures then
		return
	end
	for _, record in ipairs(structures.built) do
		if not structureById[record.id] then
			registerLive(record)
		end
	end
end

local function handleRemote(player: Player, action: string, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if action == "Place" then
		if typeof(payload.templateId) == "string"
			and typeof(payload.position) == "Vector3"
			and typeof(payload.rotationDegrees) == "number" then
			BuildingService.PlaceStructure(player, payload.templateId, payload.position, payload.rotationDegrees)
		end
	elseif action == "Remove" then
		if typeof(payload.structureId) == "string" then
			BuildingService.RemoveStructure(player, payload.structureId)
		end
	end
end

function BuildingService.Start()
	if started then
		return
	end
	started = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	BuildRemote = remotes:FindFirstChild("BuildRemote")
	if not BuildRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "BuildRemote"
		remote.Parent = remotes
		BuildRemote = remote
	end

	BuildRemote.OnServerEvent:Connect(handleRemote)

	local function onPlayerReady(player: Player)
		task.spawn(function()
			repeat task.wait(0.5) until player.Parent == nil or player:GetAttribute("DataReady") == true
			if player.Parent then rebuildForPlayer(player) end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerReady)
	for _, player in Players:GetPlayers() do
		onPlayerReady(player)
	end

	-- Structures persist in the world for the server lifetime; they are
	-- removed only by their owner or when the server shuts down.

	print("AFTERZERO BuildingService initialized.")
end

return BuildingService
