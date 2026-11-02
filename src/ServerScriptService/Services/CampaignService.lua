--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side campaign service. Owns chapter progression, region unlocks,
-- and the final endgame decision. Chapters complete automatically when all
-- required quests and chapters are done; decisions come only from validated
-- dialogue, never remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampaignDefinitions = require(Shared:WaitForChild("CampaignDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local QuestService = require(Services:WaitForChild("QuestService"))

local CampaignService = {}
local started = false

local CampaignRemote: RemoteEvent

local function getProgression(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	local progression = data.progression
	if typeof(progression.completedChapters) ~= "table" then
		progression.completedChapters = {}
	end
	if typeof(progression.endgameDecision) ~= "string" then
		progression.endgameDecision = nil
	end
	return progression
end

local function broadcastState(player: Player)
	local progression = getProgression(player)
	if not progression or not CampaignRemote then
		return
	end

	local completed = {}
	for chapterId in pairs(progression.completedChapters) do
		completed[chapterId] = true
	end

	CampaignRemote:FireClient(player, "CampaignUpdated", {
		completedChapters = completed,
		endgameDecision = progression.endgameDecision,
		unlockedRegions = progression.unlockedRegions,
	})
end

local function chapterRequirementsMet(progression: any, chapter: any): boolean
	for _, questId in ipairs(chapter.requiredQuests) do
		if not progression.completedQuests[questId] then
			return false
		end
	end
	for _, prerequisiteId in ipairs(chapter.requiredChapters) do
		if not progression.completedChapters[prerequisiteId] then
			return false
		end
	end
	return true
end

local function completeChapter(player: Player, chapter: any): boolean
	local progression = getProgression(player)
	if not progression or progression.completedChapters[chapter.id] then
		return false
	end

	if not chapterRequirementsMet(progression, chapter) then
		return false
	end

	progression.completedChapters[chapter.id] = true

	if chapter.unlocksRegion then
		progression.unlockedRegions[chapter.unlocksRegion] = true
	end

	if CampaignRemote then
		CampaignRemote:FireClient(player, "ChapterCompleted", {
			chapterId = chapter.id,
			title = chapter.title,
			unlockedRegion = chapter.unlocksRegion,
		})
	end

	broadcastState(player)
	return true
end

-- Public hook called by QuestService after a successful turn-in.
function CampaignService.OnQuestCompleted(player: Player, questId: string)
	local progression = getProgression(player)
	if not progression then
		return
	end

	-- Check every chapter; requirements may include the just-completed quest.
	for _, chapter in pairs(CampaignDefinitions.AllChapters()) do
		if not progression.completedChapters[chapter.id] and chapterRequirementsMet(progression, chapter) then
			completeChapter(player, chapter)
		end
	end
end

-- Endgame decision: only callable internally (DialogueService passes the
-- decision id from a validated final-chapter dialogue option). The decision
-- is final once made and validated against the allowlist.
function CampaignService.SubmitEndgameDecision(player: Player, decisionId: string): (boolean, string?)
	local progression = getProgression(player)
	if not progression then
		return false, "DataNotReady"
	end

	if progression.endgameDecision then
		return false, "DecisionAlreadyMade"
	end

	local description = CampaignDefinitions.GetDecision(decisionId)
	if not description then
		return false, "InvalidDecision"
	end

	local finalChapter = CampaignDefinitions.GetChapter("Chapter10_LastLight")
	if not finalChapter or not progression.completedChapters[finalChapter.id] then
		return false, "FinalChapterNotComplete"
	end

	progression.endgameDecision = decisionId

	if CampaignRemote then
		CampaignRemote:FireClient(player, "EndgameDecided", {
			decisionId = decisionId,
			description = description,
		})
	end

	broadcastState(player)
	return true, nil
end

function CampaignService.GetState(player: Player)
	local progression = getProgression(player)
	if not progression then
		return nil
	end
	return {
		completedChapters = progression.completedChapters,
		endgameDecision = progression.endgameDecision,
		unlockedRegions = progression.unlockedRegions,
	}
end

-- Region travel validation used by RegionService gates.
function CampaignService.IsRegionUnlocked(player: Player, regionId: string): boolean
	local progression = getProgression(player)
	if not progression then
		return false
	end
	return progression.unlockedRegions[regionId] == true
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "RequestState" then
		broadcastState(player)
	end
	-- Decisions and chapter completion are never writable through remotes.
end

function CampaignService.Start()
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
	CampaignRemote = remotes:FindFirstChild("CampaignRemote")
	if not CampaignRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "CampaignRemote"
		remote.Parent = remotes
		CampaignRemote = remote
	end

	CampaignRemote.OnServerEvent:Connect(handleRemote)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			repeat task.wait(0.5) until player.Parent == nil or player:GetAttribute("DataReady") == true
			if player.Parent then broadcastState(player) end
		end)
	end)

	print("AFTERZERO CampaignService initialized.")
end

return CampaignService
