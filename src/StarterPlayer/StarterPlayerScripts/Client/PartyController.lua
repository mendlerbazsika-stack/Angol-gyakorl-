--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Party controller: party panel, invite/accept/leave, and revive requests
-- for downed nearby members. All actions go through the validated remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local PartyController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local partyRemote = remotes:WaitForChild("PartyRemote")

local gui: ScreenGui
local window: Frame
local memberContainer: Frame
local inviteButton: TextButton
local inviteEntry: TextBox

function PartyController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Party"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	window = UIFactory.Window("PartyWindow", gui, "PARTY", UDim2.new(0, 260, 0, 300), UDim2.new(1, -280, 1, -320))
	window.Visible = false

	memberContainer = Instance.new("Frame")
	memberContainer.Name = "Members"
	memberContainer.Size = UDim2.new(1, -24, 0, 140)
	memberContainer.Position = UDim2.new(0, 12, 0, 44)
	memberContainer.BackgroundTransparency = 1
	memberContainer.Parent = window

	local memberLayout = Instance.new("UIListLayout")
	memberLayout.Padding = UDim.new(0, 4)
	memberLayout.Parent = memberContainer

	inviteEntry = Instance.new("TextBox")
	inviteEntry.Name = "InviteEntry"
	inviteEntry.Size = UDim2.new(1, -100, 0, 28)
	inviteEntry.Position = UDim2.new(0, 12, 1, -80)
	inviteEntry.BackgroundColor3 = Theme.Colors.BackgroundPanel
	inviteEntry.TextColor3 = Theme.Colors.TextPrimary
	inviteEntry.PlaceholderText = "User ID"
	inviteEntry.Font = Theme.Fonts.Mono
	inviteEntry.TextSize = 12
	inviteEntry.BorderSizePixel = 0
	inviteEntry.Parent = window
	inviteEntry:AddChild(Theme.UICorner())

	inviteButton = UIFactory.Button("InviteButton", window, "Invite", UDim2.new(0, 80, 0, 28), UDim2.new(1, -92, 1, -80), function()
		local userId = tonumber(inviteEntry.Text)
		if userId then
			partyRemote:FireServer("InvitePlayer", { targetUserId = userId })
			inviteEntry.Text = ""
		end
	end)

	local leaveButton = UIFactory.Button("LeaveButton", window, "Leave Party", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 1, -44), function()
		partyRemote:FireServer("LeaveParty", {})
	end)

	local reviveButton = UIFactory.Button("ReviveButton", window, "Revive Nearest Teammate", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 1, -112), function()
		-- Revive the nearest downed player; the server re-checks party,
		-- distance, and downed state, so this is only a convenience scan.
		local nearest, nearestDistance
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not myRoot then
			return
		end
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other:GetAttribute("IsDowned") == true then
				local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local distance = (root.Position - myRoot.Position).Magnitude
					if not nearestDistance or distance < nearestDistance then
						nearest, nearestDistance = other, distance
					end
				end
			end
		end
		if nearest then
			partyRemote:FireServer("ReviveTarget", { targetUserId = nearest.UserId })
		end
	end)
	reviveButton.BackgroundColor3 = Theme.Colors.Success

	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.P then
			window.Visible = not window.Visible
			if window.Visible then
				partyRemote:FireServer("RequestState", {})
			end
		end
	end)

	partyRemote.OnClientEvent:Connect(function(action, payload)
		if action == "PartyUpdated" and type(payload) == "table" then
			memberContainer:ClearAllChildren()
			for index, name in ipairs(payload.members or {}) do
				local isLeader = name == payload.leader
				local label = UIFactory.Label("Member_" .. index, memberContainer, ("%s %s"):format(if isLeader then "★" else "•", name), UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), if isLeader then Theme.Colors.Accent else Theme.Colors.TextPrimary, Theme.Fonts.Body, 13)
				label.LayoutOrder = index
			end
		elseif action == "InviteReceived" and type(payload) == "table" then
			local invitePrompt = UIFactory.Window("InvitePrompt", gui, "PARTY INVITE", UDim2.new(0, 320, 0, 140), UDim2.new(0.5, -160, 0.5, -70))
			invitePrompt.Visible = true

			UIFactory.Label("InviteText", invitePrompt, ("%s invites you to their party."):format(payload.leaderName or "Someone"), UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 0, 44), Theme.Colors.TextPrimary, Theme.Fonts.Body, 13)

			UIFactory.Button("AcceptButton", invitePrompt, "Accept", UDim2.new(0, 130, 0, 30), UDim2.new(0, 12, 1, -40), function()
				partyRemote:FireServer("AcceptInvite", {})
				invitePrompt:Destroy()
			end).BackgroundColor3 = Theme.Colors.Success

			UIFactory.Button("DeclineButton", invitePrompt, "Decline", UDim2.new(0, 130, 0, 30), UDim2.new(1, -142, 1, -40), function()
				partyRemote:FireServer("DeclineInvite", {})
				invitePrompt:Destroy()
			end).BackgroundColor3 = Theme.Colors.Danger

			task.delay(payload.expirySeconds or 60, function()
				if invitePrompt.Parent then
					invitePrompt:Destroy()
				end
			end)
		end
	end)

	partyRemote:FireServer("RequestState", {})
end

return PartyController
