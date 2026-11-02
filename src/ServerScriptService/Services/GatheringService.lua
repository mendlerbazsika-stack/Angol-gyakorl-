--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side gathering service. Resource nodes (trees, scrap piles, berry
-- bushes) are tagged via CollectionService and harvested with per-node
-- cooldowns and tool requirements, all validated on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local GatheringService = {}
local started = false

local GatheringRemote: RemoteEvent

local NodeTag = "ResourceNode"
local InteractionRange = 10
local NodeCooldownSeconds = 45
local HarvestSeconds = 2.5

-- Node type -> { outputId, minCount, maxCount, requiredToolLevel, xp }
local NodeTypes = {
	Tree = { outputId = "Wood", minCount = 2, maxCount = 4, requiredToolLevel = 0, xp = 4 },
	ScrapPile = { outputId = "ScrapMetal", minCount = 1, maxCount = 3, requiredToolLevel = 0, xp = 3 },
	BerryBush = { outputId = "ForagedBerries", minCount = 1, maxCount = 3, requiredToolLevel = 0, xp = 2 },
	ClothPile = { outputId = "Cloth", minCount = 1, maxCount = 3, requiredToolLevel = 0, xp = 2 },
	RuinCar = { outputId = "PlasticScrap", minCount = 1, maxCount = 4, requiredToolLevel = 1, xp = 5 },
}

-- In-progress harvests: player -> { node, nodeId, completesAt }
local harvests: {[Player]: any} = {}

-- Per-player per-node cooldowns.
local nodeCooldowns: {[Player]: {[string]: number}} = {}

local function nodeKey(node: BasePart): string
	local key = node:GetAttribute("NodeId")
	if typeof(key) ~= "string" or #key == 0 then
		key = "node_" .. HttpService:GenerateGUID(false)
		node:SetAttribute("NodeId", key)
	end
	return key
end

local function getEquippedToolLevel(player: Player): number
	-- Equipment slots arrive fully in the same stage's EquipmentService;
	-- until then, hands count as tool level 0.
	local EquipmentService = require(Services:WaitForChild("EquipmentService"))
	return EquipmentService.GetEquippedToolLevel(player)
end

function GatheringService.Harvest(player: Player, node: BasePart): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	if not CollectionService:HasTag(node, NodeTag) then
		return false, "NotAResourceNode"
	end

	local nodeType = node:GetAttribute("NodeType")
	if typeof(nodeType) ~= "string" or not NodeTypes[nodeType] then
		return false, "UnknownNodeType"
	end

	-- Distance validation
	local character = player.Character
	if not character or not character.PrimaryPart then
		return false, "NoCharacter"
	end
	if (character.PrimaryPart.Position - node.Position).Magnitude > InteractionRange then
		return false, "TooFar"
	end

	-- One harvest at a time per player
	if harvests[player] then
		return false, "AlreadyHarvesting"
	end

	local key = nodeKey(node)

	-- Cooldown check
	local playerCooldowns = nodeCooldowns[player]
	if playerCooldowns == nil then
		playerCooldowns = {}
		nodeCooldowns[player] = playerCooldowns
	end
	local lastHarvested = playerCooldowns[key] or 0
	if os.clock() - lastHarvested < NodeCooldownSeconds then
		return false, "NodeOnCooldown"
	end

	-- Tool level requirement
	local config = NodeTypes[nodeType]
	local toolLevel = getEquippedToolLevel(player)
	if toolLevel < config.requiredToolLevel then
		return false, "ToolRequired"
	end

	-- Begin the timed harvest
	harvests[player] = {
		node = node,
		nodeId = key,
		nodeType = nodeType,
		completesAt = os.clock() + HarvestSeconds,
	}

	if GatheringRemote then
		GatheringRemote:FireClient(player, "HarvestStarted", {
			nodeType = nodeType,
			harvestSeconds = HarvestSeconds,
		})
	end

	return true, nil
end

local function completeHarvest(player: Player)
	local active = harvests[player]
	if not active then
		return
	end
	harvests[player] = nil

	local config = NodeTypes[active.nodeType]
	if not config then
		return
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	-- Grant resources
	local count = math.random(config.minCount, config.maxCount)
	local ok = InventoryService.AddItem(player, config.outputId, count)

	-- Grant a little experience
	local xp = config.xp
	data.character.experience += xp

	local playerCooldowns = nodeCooldowns[player]
	if playerCooldowns == nil then
		playerCooldowns = {}
		nodeCooldowns[player] = playerCooldowns
	end
	playerCooldowns[active.nodeId] = os.clock()

	if GatheringRemote then
		GatheringRemote:FireClient(player, "HarvestCompleted", {
			outputId = config.outputId,
			count = if ok then count else 0,
			experience = xp,
			inventoryFull = not ok,
		})
	end
end

local function handleRemote(player: Player, action: string, payload: any)
	if action ~= "Harvest" then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end

	local node = payload.node
	if typeof(node) ~= "Instance" or not node:IsA("BasePart") then
		return
	end

	GatheringService.Harvest(player, node)
end

function GatheringService.RegisterNode(node: BasePart, nodeType: string)
	if not NodeTypes[nodeType] then
		warn(("AFTERZERO GatheringService: unknown node type %s"):format(nodeType))
		return
	end
	CollectionService:AddTag(node, NodeTag)
	node:SetAttribute("NodeType", nodeType)
end

function GatheringService.Start()
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
	GatheringRemote = remotesFolder:FindFirstChild("GatheringRemote")
	if GatheringRemote == nil then
		GatheringRemote = Instance.new("RemoteEvent")
		GatheringRemote.Name = "GatheringRemote"
		GatheringRemote.Parent = remotesFolder
	end

	GatheringRemote.OnServerEvent:Connect(handleRemote)

	-- Completion watcher
	task.spawn(function()
		while started do
			task.wait(0.25)
			local now = os.clock()
			for player, active in pairs(harvests) do
				if not player.Parent then
					harvests[player] = nil
					continue
				end
				if now >= active.completesAt then
					completeHarvest(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		harvests[player] = nil
		nodeCooldowns[player] = nil
	end)
end

return GatheringService
