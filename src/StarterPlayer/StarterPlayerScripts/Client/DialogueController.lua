--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Dialogue controller: renders the exact node the server sends, with only
-- the options the server approved. Option clicks send back the index; the
-- server re-validates everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local DialogueController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dialogueRemote = remotes:WaitForChild("DialogueRemote")

local gui: ScreenGui
local window: Frame
local npcNameLabel: TextLabel
local npcTitleLabel: TextLabel
local bodyLabel: TextLabel
local optionsContainer: Frame
local optionsLayout: UIListLayout

local function clearOptions()
	if optionsContainer then
		optionsContainer:ClearAllChildren()
		optionsLayout = Instance.new("UIListLayout")
		optionsLayout.Padding = UDim.new(0, 6)
		optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optionsLayout.Parent = optionsContainer
	end
end

local function renderOptions(options: {any})
	clearOptions()

	for index, option in ipairs(options) do
		local button = UIFactory.Button("Option_" .. index, optionsContainer, option.text, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), function()
			dialogueRemote:FireServer("SelectOption", { optionIndex = index })
		end)
		button.LayoutOrder = index
		button.TextWrapped = false
		button.TextTruncate = Enum.TextTruncate.AtEnd

		if option.actionKind == "AcceptQuest" or option.actionKind == "TurnInQuest" then
			button.BackgroundColor3 = Theme.Colors.AccentDark
		elseif option.actionKind == "EndgameDecision" then
			button.BackgroundColor3 = Theme.Colors.Danger
		end
	end
end

function DialogueController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Dialogue"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	window = UIFactory.Frame("DialogueWindow", gui, UDim2.new(0, 560, 0, 320), UDim2.new(0.5, -280, 1, -360), Theme.Colors.BackgroundRaised)
	window.Visible = false

	npcNameLabel = UIFactory.Label("NpcName", window, "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 16, 0, 12), Theme.Colors.Accent, Theme.Fonts.Header, 18)
	npcTitleLabel = UIFactory.Label("NpcTitle", window, "", UDim2.new(1, -24, 0, 18), UDim2.new(0, 16, 0, 40), Theme.Colors.TextMuted, Theme.Fonts.Body, 12)
	bodyLabel = UIFactory.Label("Body", window, "", UDim2.new(1, -32, 0, 120), UDim2.new(0, 16, 0, 66), Theme.Colors.TextPrimary, Theme.Fonts.Body, 15)

	optionsContainer = Instance.new("Frame")
	optionsContainer.Name = "Options"
	optionsContainer.Size = UDim2.new(1, -32, 0, 110)
	optionsContainer.Position = UDim2.new(0, 16, 1, -128)
	optionsContainer.BackgroundTransparency = 1
	optionsContainer.Parent = window

	optionsLayout = Instance.new("UIListLayout")
	optionsLayout.Padding = UDim.new(0, 6)
	optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionsContainer:AddChild(optionsLayout)

	dialogueRemote.OnClientEvent:Connect(function(action, payload)
		if action == "NodeShown" and type(payload) == "table" then
			window.Visible = true
			npcNameLabel.Text = payload.npcName or ""
			npcTitleLabel.Text = payload.npcTitle or ""
			bodyLabel.Text = payload.text or ""
			renderOptions(payload.options or {})
		elseif action == "DialogueEnded" then
			window.Visible = false
			clearOptions()
		end
	end)
end

return DialogueController
