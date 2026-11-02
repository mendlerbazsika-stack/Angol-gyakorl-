--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side dialogue and NPC service. Resolves conditional dialogue nodes
-- from server quest state, drives quest accept/turn-in, and spawns NPC
-- rigs in the settlement with interaction prompts. The client can only pick
-- among server-approved options.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DialogueDefinitions = require(Shared:WaitForChild("DialogueDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local QuestService = require(Services:WaitForChild("QuestService"))

local DialogueService = {}
local started = false

local DialogueRemote: RemoteEvent

-- npcId -> current dialogue session per player, for remote validation.
local activeSessions: {[Player]: { npcId: string, node: string, options: {any} }} = {}

local NPC_SPAWNS = {
	{
		npcId = "MaraVoss",
		position = Vector3.new(80, 0, -35),
		interactionText = "Talk",
		displayName = "Mara Voss",
	},
	{
		npcId = "EliasWard",
		position = Vector3.new(70, 0, -20),
		interactionText = "Talk",
		displayName = "Elias Ward",
	},
	{
		npcId = "Rook",
		position = Vector3.new(-55, 0, -100),
		interactionText = "Talk",
		displayName = "Rook",
	},
}

local function questState(player: Player, questId: string): string
	local Services = ServerScriptService:WaitForChild("Services")
	local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
	local data = PlayerDataService.GetData(player)
	if not data then
		return "unknown"
	end
	local progression = data.progression
	if progression.activeQuests[questId] then
		return "active"
	end
	if progression.completedQuests[questId] then
		return "completed"
	end
	return "notStarted"
end

local function entryMatches(player: Player, condition: any): boolean
	if condition.completed and questState(player, condition.completed) ~= "completed" then
		return false
	end
	if condition.active and questState(player, condition.active) ~= "active" then
		return false
	end
	if condition.notStarted and questState(player, condition.notStarted) ~= "notStarted" then
		return false
	end
	return true
end

local function resolveEntryNode(player: Player, npcId: string): string
	local npc = DialogueDefinitions.Get(npcId)
	if not npc then
		return ""
	end
	for _, entry in ipairs(npc.entries) do
		if entryMatches(player, entry.condition) then
			return entry.node
		end
	end
	return npc.defaultNode
end

local function sendNode(player: Player, npcId: string, nodeId: string, npcName: string, npcTitle: string)
	local npc = DialogueDefinitions.Get(npcId)
	if not npc then
		return
	end
	local node = npc.nodes[nodeId]
	if not node then
		return
	end

	-- Only server-approved options are transmitted.
	local options = {}
	for _, option in ipairs(node.options) do
		table.insert(options, {
			text = option.text,
			actionKind = option.actionKind or "None",
			questId = option.questId,
		})
	end

	activeSessions[player] = {
		npcId = npcId,
		node = nodeId,
		options = options,
	}

	DialogueRemote:FireClient(player, "NodeShown", {
		npcId = npcId,
		npcName = npcName,
		npcTitle = npcTitle,
		text = node.text,
		options = options,
	})
end

function DialogueService.BeginDialogue(player: Player, npcId: string): (boolean, string?)
	local npc = DialogueDefinitions.Get(npcId)
	if not npc then
		return false, "UnknownNpc"
	end
	if activeSessions[player] then
		return false, "DialogueInProgress"
	end

	local entryNode = resolveEntryNode(player, npcId)
	sendNode(player, npcId, entryNode, npc.name, npc.title)
	return true, nil
end

local function endDialogue(player: Player)
	activeSessions[player] = nil
	DialogueRemote:FireClient(player, "DialogueEnded", {})
end

function DialogueService.SelectOption(player: Player, optionIndex: number): (boolean, string?)
	local session = activeSessions[player]
	if not session then
		return false, "NoDialogueSession"
	end

	local option = session.options[optionIndex]
	if not option then
		return false, "InvalidOption"
	end

	local npc = DialogueDefinitions.Get(session.npcId)
	if not npc then
		endDialogue(player)
		return false, "UnknownNpc"
	end

	-- Look up the full node again; the session only stores the safe copy.
	local node = npc.nodes[session.node]
	if not node then
		endDialogue(player)
		return false, "StaleSession"
	end

	if option.actionKind == "AcceptQuest" and option.questId then
		local ok, err = QuestService.AcceptQuest(player, option.questId)
		if not ok then
			return false, tostring(err)
		end
		QuestService.NotifyTalkedTo(player, session.npcId)
		sendNode(player, session.npcId, option.next :: string, npc.name, npc.title)
		return true, nil
	elseif option.actionKind == "TurnInQuest" and option.questId then
		local ok, err = QuestService.TurnInQuest(player, option.questId)
		if not ok then
			return false, tostring(err)
		end
		sendNode(player, session.npcId, option.next :: string, npc.name, npc.title)
		return true, nil
	elseif option.actionKind == "End" then
		endDialogue(player)
		return true, nil
	end

	-- Plain navigation node.
	if option.next then
		sendNode(player, session.npcId, option.next, npc.name, npc.title)
		return true, nil
	end

	endDialogue(player)
	return true, nil
end

local function spawnNpcs()
	local world = Workspace:FindFirstChild("World")
	local regions = world and world:FindFirstChild("Regions")
	local greywood = regions and regions:FindFirstChild("GreywoodCounty")
	local npcFolder
	if greywood then
		npcFolder = greywood:FindFirstChild("Npcs")
		if not npcFolder then
			npcFolder = Instance.new("Folder")
			npcFolder.Name = "Npcs"
			npcFolder.Parent = greywood
		end
	end
	if not npcFolder then
		-- Settlement not generated (WorldService may be disabled); skip spawning.
		warn("AFTERZERO DialogueService: Greywood region not found; NPCs not spawned")
		return
	end

	for _, spawnInfo in ipairs(NPC_SPAWNS) do
		local existing = npcFolder:FindFirstChild(spawnInfo.npcId)
		if existing then
			continue
		end

		local npc = DialogueDefinitions.Get(spawnInfo.npcId)
		if not npc then
			continue
		end

		local model = Instance.new("Model")
		model.Name = spawnInfo.npcId

		-- Simple block rig placeholder; replace with authored avatar assets.
		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(2, 5, 1)
		torso.CFrame = CFrame.new(spawnInfo.position.X, 3, spawnInfo.position.Z)
		torso.Color = Color3.fromRGB(84, 88, 84)
		torso.Material = Enum.Material.Fabric
		torso.Anchored = true
		torso.Parent = model

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.6, 1.6, 1.6)
		head.CFrame = CFrame.new(spawnInfo.position.X, 6.4, spawnInfo.position.Z)
		head.Color = Color3.fromRGB(160, 134, 105)
		head.Material = Enum.Material.SmoothPlastic
		head.Anchored = true
		head.Parent = model

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = spawnInfo.interactionText
		prompt.ObjectText = npc.name
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = torso

		prompt.Triggered:Connect(function(player)
			DialogueService.BeginDialogue(player, spawnInfo.npcId)
		end)

		model.Parent = npcFolder
	end
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "SelectOption" then
		local index = if typeof(payload) == "table" then payload.optionIndex else nil
		if typeof(index) ~= "number" then
			return
		end
		DialogueService.SelectOption(player, math.floor(index))
	elseif action == "End" then
		activeSessions[player] = nil
	end
end

function DialogueService.Start()
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
	DialogueRemote = remotes:FindFirstChild("DialogueRemote")
	if not DialogueRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "DialogueRemote"
		remote.Parent = remotes
		DialogueRemote = remote
	end

	DialogueRemote.OnServerEvent:Connect(handleRemote)

	Players.PlayerRemoving:Connect(function(player)
		activeSessions[player] = nil
	end)

	spawnNpcs()
	print("AFTERZERO DialogueService initialized.")
end

return DialogueService
