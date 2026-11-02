--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side quest service. Owns quest state, prerequisites, objective
-- tracking, and reward grants. All state changes are validated on the server;
-- turn-ins re-verify inventory at grant time so clients cannot claim rewards
-- they did not earn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestDefinitions = require(Shared:WaitForChild("QuestDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local FactionService = require(Services:WaitForChild("FactionService"))
local CampaignService = require(Services:WaitForChild("CampaignService"))

local QuestService = {}
local started = false

local QuestRemote: RemoteEvent

local function getStateTable(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	local progression = data.progression
	if typeof(progression.activeQuests) ~= "table" then
		progression.activeQuests = {}
	end
	if typeof(progression.completedQuests) ~= "table" then
		progression.completedQuests = {}
	end
	if typeof(progression.questObjectives) ~= "table" then
		progression.questObjectives = {}
	end
	if typeof(progression.killProgress) ~= "table" then
		progression.killProgress = {}
	end
	return progression
end

local function objectiveKey(questId: string, objectiveId: string): string
	return questId .. ":" .. objectiveId
end

local function broadcastState(player: Player)
	local progression = getStateTable(player)
	if not progression or not QuestRemote then
		return
	end

	local active = {}
	for questId in pairs(progression.activeQuests) do
		local quest = QuestDefinitions.Get(questId)
		if quest then
			local objectiveStatus = {}
			for _, objective in ipairs(quest.objectives) do
				local key = objectiveKey(questId, objective.id)
				local completed = progression.questObjectives[key] == true

				-- Kill objectives report live progress.
				local progress: any = nil
				if objective.type == "KillEnemies" then
					local progressKey = questId .. ":" .. objective.enemyId
					local killed = progression.killProgress[progressKey] or 0
					progress = { killed = killed, required = objective.count or 1 }
					completed = killed >= (objective.count or 1)
				end

				table.insert(objectiveStatus, {
					id = objective.id,
					description = objective.description,
					completed = completed,
					progress = progress,
				})
			end
			table.insert(active, {
				id = quest.id,
				title = quest.title,
				description = quest.description,
				objectives = objectiveStatus,
			})
		end
	end

	QuestRemote:FireClient(player, "QuestsUpdated", { activeQuests = active })
end

local function prerequisitesMet(progression: any, questId: string): boolean
	local quest = QuestDefinitions.Get(questId)
	if not quest then
		return false
	end
	for _, prerequisite in ipairs(quest.prerequisites) do
		if not progression.completedQuests[prerequisite] then
			return false
		end
	end
	return true
end

local function objectiveComplete(player: Player, questId: string, objective: any): boolean
	local key = objectiveKey(questId, objective.id)
	local progression = getStateTable(player)
	if not progression then
		return false
	end

	if objective.type == "KillEnemies" then
		local progressKey = questId .. ":" .. objective.enemyId
		local killed = progression.killProgress[progressKey] or 0
		return killed >= (objective.count or 1)
	end

	if progression.questObjectives[key] then
		return true
	end

	if objective.type == "TalkTo" then
		return false -- only the NPC interaction itself completes this
	elseif objective.type == "CollectItem" then
		return InventoryService.CountItem(player, objective.itemId) >= (objective.count or 1)
	end
	return false
end

function QuestService.AcceptQuest(player: Player, questId: string): (boolean, string?)
	local progression = getStateTable(player)
	if not progression then
		return false, "DataNotReady"
	end

	local quest = QuestDefinitions.Get(questId)
	if not quest then
		return false, "UnknownQuest"
	end
	if progression.activeQuests[questId] then
		return false, "AlreadyActive"
	end
	if progression.completedQuests[questId] and not quest.repeatable then
		return false, "AlreadyCompleted"
	end
	if not prerequisitesMet(progression, questId) then
		return false, "PrerequisitesNotMet"
	end

	progression.activeQuests[questId] = true
	broadcastState(player)
	return true, nil
end

local function grantRewards(player: Player, quest: any)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	data.character.experience += quest.rewards.experience
	data.currency += quest.rewards.currency
	for _, rewardItem in ipairs(quest.rewards.items) do
		InventoryService.AddItem(player, rewardItem.id, rewardItem.count)
	end

	-- Faction reputation is applied through the validated FactionService.
	if quest.rewards.factionReputation then
		for _, reputationReward in ipairs(quest.rewards.factionReputation) do
			FactionService.AddReputation(player, reputationReward.factionId, reputationReward.amount)
		end
	end
end

function QuestService.TurnInQuest(player: Player, questId: string): (boolean, string?)
	local progression = getStateTable(player)
	if not progression then
		return false, "DataNotReady"
	end

	local quest = QuestDefinitions.Get(questId)
	if not quest then
		return false, "UnknownQuest"
	end
	if not progression.activeQuests[questId] then
		return false, "NotActive"
	end

	-- Verify every objective against live server state before completing.
	for _, objective in ipairs(quest.objectives) do
		if not objectiveComplete(player, questId, objective) then
			return false, "ObjectivesIncomplete"
		end
	end

	-- Consume marked items AFTER validation, before rewards, atomically.
	for _, objective in ipairs(quest.objectives) do
		if objective.type == "CollectItem" and objective.consume then
			local ok, err = InventoryService.RemoveItem(player, objective.itemId :: string, objective.count :: number)
			if not ok then
				-- State changed mid-turn-in; abort without granting anything.
				return false, tostring(err)
			end
		end
	end

	for _, objective in ipairs(quest.objectives) do
		progression.questObjectives[objectiveKey(questId, objective.id)] = nil
		if objective.enemyId then
			progression.killProgress[questId .. ":" .. objective.enemyId] = nil
		end
	end
	progression.activeQuests[questId] = nil
	progression.completedQuests[questId] = true

	grantRewards(player, quest)

	-- Share a fraction of the quest's experience with nearby party members
	-- who still have the same quest active. Items and currency stay personal.
	PartyService.ShareQuestCompletion(player, quest)

	-- Campaign hooks: chapters check their requirements after every turn-in.
	CampaignService.OnQuestCompleted(player, questId)

	broadcastState(player)
	return true, nil
end

function QuestService.NotifyTalkedTo(player: Player, npcId: string)
	-- Completes any active TalkTo objective matching this NPC, then notifies.
	-- Called by DialogueService when a dialogue session BEGINS with an NPC,
	-- which is the actual moment the player "talks" to them.
	local progression = getStateTable(player)
	if not progression then
		return
	end

	local changed = false
	for questId in pairs(progression.activeQuests) do
		local quest = QuestDefinitions.Get(questId)
		if quest then
			for _, objective in ipairs(quest.objectives) do
				if objective.type == "TalkTo" and objective.npcId == npcId then
					progression.questObjectives[objectiveKey(questId, objective.id)] = true
					changed = true
				end
			end
		end
	end
	if changed then
		broadcastState(player)
	end
end

-- Kill notification: called by EnemyService's hook after a validated kill.
function QuestService.NotifyEnemyKilled(player: Player, enemyId: string)
	local progression = getStateTable(player)
	if not progression then
		return
	end

	local changed = false
	for questId in pairs(progression.activeQuests) do
		local quest = QuestDefinitions.Get(questId)
		if quest then
			for _, objective in ipairs(quest.objectives) do
				if objective.type == "KillEnemies" and objective.enemyId == enemyId then
					local progressKey = questId .. ":" .. enemyId
					local killed = progression.killProgress[progressKey] or 0
					if killed < (objective.count or 1) then
						progression.killProgress[progressKey] = killed + 1
						changed = true
					end
				end
			end
		end
	end
	if changed then
		broadcastState(player)
	end
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "RequestState" then
		broadcastState(player)
	end
	-- Quest accept/turn-in is driven through dialogue, not direct remote
	-- calls; DialogueService re-validates everything server-side.
end

function QuestService.Start()
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
	QuestRemote = remotes:FindFirstChild("QuestRemote")
	if not QuestRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "QuestRemote"
		remote.Parent = remotes
		QuestRemote = remote
	end

	QuestRemote.OnServerEvent:Connect(handleRemote)

	-- Subscribe to validated enemy kills for KillEnemies objectives.
	local EnemyService = require(Services:WaitForChild("EnemyService"))
	EnemyService.SetOnKilledCallback(function(player, enemyId, _regionId)
		QuestService.NotifyEnemyKilled(player, enemyId)
	end)

	local function onPlayerReady(player: Player)
		task.spawn(function()
			repeat task.wait(0.5) until player.Parent == nil or player:GetAttribute("DataReady") == true
			if player.Parent then broadcastState(player) end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerReady)
	for _, player in Players:GetPlayers() do
		onPlayerReady(player)
	end
end

return QuestService
