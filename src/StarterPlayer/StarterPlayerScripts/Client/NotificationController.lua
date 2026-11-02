--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Notification controller: collects event feeds from every service remote
-- (loot, crafting, gathering, quests, campaign, factions, vehicles, survival,
-- parties) into a single stacking toast column.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local NotificationController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui: ScreenGui
local container: Frame
local layout: UIListLayout

local TOAST_LIFETIME = 4

local function pushToast(text: string, color: Color3?)
	local toast = UIFactory.Frame("Toast", container, UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 0), Theme.Colors.BackgroundRaised)
	toast.AutomaticSize = Enum.AutomaticSize.Y

	local label = UIFactory.Label("Text", toast, text, UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 5), color or Theme.Colors.TextPrimary, Theme.Fonts.Body, 12)
	label.AutomaticSize = Enum.AutomaticSize.Y

	task.delay(TOAST_LIFETIME, function()
		local TweenService = game:GetService("TweenService")
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tween:Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

local function wireRemote(remoteName: string, handlers: {[string]: (payload: any) -> ()})
	local remote = remotes:FindFirstChild(remoteName)
	if not remote then
		return
	end

	remote.OnClientEvent:Connect(function(action, payload)
		local handler = handlers[action]
		if handler then
			handler(payload)
		end
	end)
end

function NotificationController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Notifications"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	container = Instance.new("Frame")
	container.Name = "Toasts"
	container.Size = UDim2.new(0, 300, 1, -100)
	container.Position = UDim2.new(1, -312, 0, 40)
	container.BackgroundTransparency = 1
	container.Parent = gui

	layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = container

	wireRemote("LootRemote", {
		LootFound = function(payload)
			if type(payload) == "table" then
				for _, entry in ipairs(payload) do
					pushToast(("Found: %s ×%d"):format(entry.id, entry.count), Theme.Colors.Success)
				end
			end
		end,
	})

	wireRemote("CraftingRemote", {
		CraftCompleted = function(payload)
			if type(payload) == "table" then
				pushToast(("Crafted: %s"):format(payload.outputId or "item"), Theme.Colors.Success)
			end
		end,
		CraftCancelled = function(payload)
			pushToast("Craft cancelled — materials refunded.")
		end,
	})

	wireRemote("GatheringRemote", {
		HarvestCompleted = function(payload)
			if type(payload) == "table" then
				if payload.inventoryFull then
					pushToast("Pack is full — resources lost.", Theme.Colors.Danger)
				else
					pushToast(("Gathered: %s ×%d (+%d xp)"):format(payload.outputId, payload.count, payload.experience), Theme.Colors.Success)
				end
			end
		end,
	})

	wireRemote("QuestRemote", {})

	wireRemote("CampaignRemote", {
		ChapterCompleted = function(payload)
			if type(payload) == "table" then
				local regionLine = if payload.unlockedRegion then (" — new region unlocked!"):format("") else ""
				pushToast(("CHAPTER COMPLETE: %s%s"):format(payload.title or "", if payload.unlockedRegion then " — new region unlocked!" else ""), Theme.Colors.Accent)
			end
		end,
		EndgameDecided = function(payload)
			if type(payload) == "table" then
				pushToast(("THE LAST LIGHT: %s"):format(payload.decisionId or ""), Theme.Colors.Accent)
			end
		end,
		RegionLocked = function(payload)
			if type(payload) == "table" then
				pushToast(("This road is closed — %s"):format(payload.message or "advance the story to open it."), Theme.Colors.Danger)
			end
		end,
	})

	wireRemote("FactionRemote", {
		ReputationChanged = function(payload)
			if type(payload) == "table" then
				local sign = if payload.amount >= 0 then "+" else ""
				pushToast(("%s reputation %s%d (%s)"):format(payload.factionId, sign, payload.amount, payload.tier), Theme.Colors.TextSecondary)
			end
		end,
		TierChanged = function(payload)
			if type(payload) == "table" then
				pushToast(("%s now considers you %s"):format(payload.factionId, payload.toTier), Theme.Colors.Accent)
			end
		end,
	})

	wireRemote("VehicleRemote", {
		OutOfFuel = function()
			pushToast("The engine sputters out — no fuel.", Theme.Colors.Danger)
		end,
		NoFuel = function()
			pushToast("The tank is bone dry.", Theme.Colors.Danger)
		end,
		FuelChanged = function(payload)
			if type(payload) == "table" then
				pushToast(("Fuel: %d"):format(payload.fuel), Theme.Colors.TextSecondary)
			end
		end,
		HealthChanged = function(payload)
			if type(payload) == "table" then
				pushToast(("Vehicle repaired: %d%%"):format(payload.health), Theme.Colors.Success)
			end
		end,
	})

	wireRemote("SurvivalRemote", {
		Downed = function()
			pushToast("You are downed — a teammate can revive you.", Theme.Colors.Danger)
		end,
		Revived = function()
			pushToast("Back on your feet. Stay closer.", Theme.Colors.Success)
		end,
		Died = function(payload)
			if type(payload) == "table" and payload.respawnSeconds then
				pushToast(("You died. Respawning in %d seconds..."):format(payload.respawnSeconds), Theme.Colors.Danger)
			else
				pushToast("You died.", Theme.Colors.Danger)
			end
		end,
	})

	wireRemote("PartyRemote", {
		Notification = function(payload)
			if type(payload) == "table" then
				pushToast(payload.text or "")
			end
		end,
		SharedExperience = function(payload)
			if type(payload) == "table" then
				pushToast(("%s shared +%d xp"):format(payload.from or "Teammate", payload.experience or 0), Theme.Colors.Success)
			end
		end,
	})
end

return NotificationController
