--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Quest controller: journal window bound to server QuestsUpdated snapshots,
-- including kill-objective progress. Read-only; acceptance happens in dialogue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local QuestController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local questRemote = remotes:WaitForChild("QuestRemote")

local gui: ScreenGui
local window: Frame
local questsContainer: Frame
local questsLayout: UIListLayout

local function renderQuest(quest: any)
	local questFrame = UIFactory.Frame("Quest_" .. quest.id, questsContainer, UDim2.new(1, 0, 0, 90), UDim2.new(0, 0, 0, 0), Theme.Colors.Background)
	questFrame.LayoutOrder = 0
	questFrame.AutomaticSize = Enum.AutomaticSize.Y

	local header = UIFactory.Label("Title", questFrame, quest.title, UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 6), Theme.Colors.Accent, Theme.Fonts.Header, 14)
	header.AutomaticSize = Enum.AutomaticSize.Y

	local body = UIFactory.Label("Description", questFrame, quest.description, UDim2.new(1, -16, 0, 30), UDim2.new(0, 10, 0, 28), Theme.Colors.TextSecondary, Theme.Fonts.Body, 12)
	body.AutomaticSize = Enum.AutomaticSize.Y

	local objectiveContainer = Instance.new("Frame")
	objectiveContainer.Name = "Objectives"
	objectiveContainer.Size = UDim2.new(1, -16, 0, 0)
	objectiveContainer.Position = UDim2.new(0, 10, 0, 60)
	objectiveContainer.BackgroundTransparency = 1
	objectiveContainer.AutomaticSize = Enum.AutomaticSize.Y
	objectiveContainer.Parent = questFrame

	local objectiveLayout = Instance.new("UIListLayout")
	objectiveLayout.Padding = UDim.new(0, 2)
	objectiveLayout.SortOrder = Enum.SortOrder.LayoutOrder
	objectiveLayout.Parent = objectiveContainer

	for index, objective in ipairs(quest.objectives) do
		local prefix = if objective.completed then "[X]" else "[ ]"
		local text = objective.description
		if objective.progress then
			text = ("%s  (%d/%d)"):format(text, objective.progress.killed, objective.progress.required)
		end

		local label = UIFactory.Label("Objective_" .. index, objectiveContainer, ("%s %s"):format(prefix, text), UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 0), if objective.completed then Theme.Colors.Success else Theme.Colors.TextPrimary, Theme.Fonts.Mono, 11)
		label.LayoutOrder = index
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
end

local function renderQuests(activeQuests: {any})
	questsContainer:ClearAllChildren()
	questsLayout = Instance.new("UIListLayout")
	questsLayout.Padding = UDim.new(0, 8)
	questsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	questsLayout.Parent = questsContainer

	if #activeQuests == 0 then
		local empty = UIFactory.Label("Empty", questsContainer, "No active quests. Talk to the settlement's people.", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), Theme.Colors.TextMuted, Theme.Fonts.Body, 12)
		empty.LayoutOrder = 0
		return
	end

	for index, quest in ipairs(activeQuests) do
		renderQuest(quest)
		-- Layout order is index-based so list order matches the server snapshot.
		local frame = questsContainer:FindFirstChild("Quest_" .. quest.id)
		if frame then
			frame.LayoutOrder = index
		end
	end
end

function QuestController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Quests"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	window = UIFactory.Window("QuestWindow", gui, "JOURNAL", UDim2.new(0, 420, 0, 480), UDim2.new(1, -440, 0.5, -240))
	window.Visible = false

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "QuestScroll"
	scroll.Size = UDim2.new(1, -24, 1, -56)
	scroll.Position = UDim2.new(0, 12, 0, 44)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = window

	questsContainer = Instance.new("Frame")
	questsContainer.Name = "Quests"
	questsContainer.Size = UDim2.new(1, 0, 0, 0)
	questsContainer.BackgroundTransparency = 1
	questsContainer.AutomaticSize = Enum.AutomaticSize.Y
	questsContainer.Parent = scroll

	questsLayout = Instance.new("UIListLayout")
	questsLayout.Padding = UDim.new(0, 8)
	questsLayout.Parent = questsContainer

	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.J or input.KeyCode == Enum.KeyCode.L then
			window.Visible = not window.Visible
			if window.Visible then
				questRemote:FireServer("RequestState", {})
			end
		end
	end)

	local toggleButton = UIFactory.Button("QuestToggle", gui, "LOG", UDim2.new(0, 64, 0, 28), UDim2.new(0, 12, 1, -40), function()
		window.Visible = not window.Visible
		if window.Visible then
			questRemote:FireServer("RequestState", {})
		end
	end)
	toggleButton.Position = UDim2.new(0, 84, 1, -40)

	questRemote.OnClientEvent:Connect(function(action, payload)
		if action == "QuestsUpdated" and type(payload) == "table" then
			renderQuests(payload.activeQuests or {})
		end
	end)

	questRemote:FireServer("RequestState", {})
end

return QuestController
