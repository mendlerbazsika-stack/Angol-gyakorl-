--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Inventory controller: grid of slots bound to server InventoryUpdated
-- snapshots, with consume, equip, and repair actions sent through the
-- validated remotes. The client renders server state; it never edits it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local InventoryController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryRemote = remotes:WaitForChild("InventoryRemote")
local equipmentRemote = remotes:WaitForChild("EquipmentRemote")

local gui: ScreenGui
local window: Frame
local slotsContainer: Frame
local detailPanel: Frame
local slotsLayout: UIGridLayout
local currentSlots: {any} = {}
local maxSlots: number = 24

local GRID_CELL = 64
local GRID_GAP = 6

local function slotClicked(slot: any)
	-- Detail panel shows the item and its available actions.
	local detailName = detailPanel:FindFirstChild("ItemName")
	local detailDesc = detailPanel:FindFirstChild("ItemDescription")
	local detailActions = detailPanel:FindFirstChild("Actions")

	if detailName then
		detailName.Text = ("%s  ×%d"):format(slot.name, slot.count)
	end
	if detailDesc then
		detailDesc.Text = slot.description
	end
	if detailActions then
		detailActions:ClearAllChildren()
		local yOffset = 0

		if slot.effect then
			local consumeButton = UIFactory.Button("ConsumeButton", detailActions, "Use", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, yOffset), function()
				inventoryRemote:FireServer("Consume", { itemId = slot.id })
			end)
			consumeButton.BackgroundColor3 = Theme.Colors.AccentDark
			yOffset += 34
		end

		if slot.category == "Tool" or slot.category == "Weapon" then
			local equipButton = UIFactory.Button("EquipButton", detailActions, "Equip (Main Hand)", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, yOffset), function()
				equipmentRemote:FireServer("Equip", { itemId = slot.id, slot = "MainHand" })
			end)
			equipButton.BackgroundColor3 = Theme.Colors.AccentDark
			yOffset += 34
		elseif slot.category == "Clothing" or slot.category == "Armor" then
			local equipButton = UIFactory.Button("EquipButton", detailActions, "Equip (Body)", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, yOffset), function()
				equipmentRemote:FireServer("Equip", { itemId = slot.id, slot = "Body" })
			end)
			equipButton.BackgroundColor3 = Theme.Colors.AccentDark
			yOffset += 34
		end

		if slot.durability then
			local repairButton = UIFactory.Button("RepairButton", detailActions, "Repair (1 Scrap Metal)", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, yOffset), function()
				equipmentRemote:FireServer("Repair", { itemId = slot.id })
			end)
			yOffset += 34
		end
	end
end

local function buildWindow()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Inventory"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	window = UIFactory.Window("InventoryWindow", gui, "INVENTORY", UDim2.new(0, 520, 0, 360), UDim2.new(0.5, -260, 0.5, -180))
	window.Visible = false

	slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "SlotsContainer"
	slotsContainer.Size = UDim2.new(1, -220, 1, -56)
	slotsContainer.Position = UDim2.new(0, 12, 0, 44)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = window

	slotsLayout = Instance.new("UIGridLayout")
	slotsLayout.CellSize = UDim2.new(0, GRID_CELL, 0, GRID_CELL)
	slotsLayout.CellPadding = UDim2.new(0, GRID_GAP, 0, GRID_GAP)
	slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotsLayout.Parent = slotsContainer

	detailPanel = Instance.new("Frame")
	detailPanel.Name = "DetailPanel"
	detailPanel.Size = UDim2.new(0, 196, 1, -56)
	detailPanel.Position = UDim2.new(1, -208, 0, 44)
	detailPanel.BackgroundColor3 = Theme.Colors.Background
	detailPanel.BorderSizePixel = 0
	detailPanel.Parent = window
	detailPanel:AddChild(Theme.UICorner())

	UIFactory.Label("ItemName", detailPanel, "Select an item", UDim2.new(1, -12, 0, 32), UDim2.new(0, 8, 0, 8), Theme.Colors.Accent, Theme.Fonts.Header, 14)
	UIFactory.Label("ItemDescription", detailPanel, "", UDim2.new(1, -12, 0, 96), UDim2.new(0, 8, 0, 44), Theme.Colors.TextSecondary, Theme.Fonts.Body, 12)

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.Size = UDim2.new(1, -16, 1, -170)
	actions.Position = UDim2.new(0, 8, 0, 150)
	actions.BackgroundTransparency = 1
	actions.Parent = detailPanel

	-- Toggle key: I / Y (keyboard), plus a mobile button.
	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.Y then
			window.Visible = not window.Visible
			if window.Visible then
				inventoryRemote:FireServer("RequestState", {})
			end
		end
	end)

	local toggleButton = UIFactory.Button("InventoryToggle", gui, "PACK", UDim2.new(0, 64, 0, 28), UDim2.new(0, 12, 1, -40), function()
		window.Visible = not window.Visible
		if window.Visible then
			inventoryRemote:FireServer("RequestState", {})
		end
	end)
end

local function renderSlots(snapshot: {any})
	currentSlots = snapshot
	slotsContainer:ClearAllChildren()
	slotsLayout = Instance.new("UIGridLayout")
	slotsLayout.CellSize = UDim2.new(0, GRID_CELL, 0, GRID_CELL)
	slotsLayout.CellPadding = UDim2.new(0, GRID_GAP, 0, GRID_GAP)
	slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotsLayout.Parent = slotsContainer

	for index, slot in ipairs(snapshot) do
		local cell = UIFactory.Button("Slot_" .. index, slotsContainer, ("%d"):format(slot.count), UDim2.new(0, GRID_CELL, 0, GRID_CELL), UDim2.new(0, 0, 0, 0))
		cell.BackgroundColor3 = Theme.Colors.BackgroundPanel
		cell.LayoutOrder = index

		UIFactory.Label("ItemName", cell, slot.name, UDim2.new(1, -6, 0, 40), UDim2.new(0, 4, 0, 4), Theme.Colors.TextPrimary, Theme.Fonts.Body, 10).TextScaled = true

		cell.Activated:Connect(function()
			slotClicked(slot)
		end)
	end

	-- Empty slots render as dimmed placeholders up to maxSlots.
	local occupied = #snapshot
	for index = occupied + 1, maxSlots do
		local cell = Instance.new("Frame")
		cell.Name = "Empty_" .. index
		cell.Size = UDim2.new(0, GRID_CELL, 0, GRID_CELL)
		cell.BackgroundColor3 = Theme.Colors.Background
		cell.BorderSizePixel = 0
		cell.LayoutOrder = index
		cell.Parent = slotsContainer
		cell:AddChild(Theme.UICorner())
	end
end

function InventoryController.Start()
	buildWindow()

	inventoryRemote.OnClientEvent:Connect(function(action, payload)
		if action == "InventoryUpdated" and type(payload) == "table" then
			maxSlots = payload.maxSlots or 24
			renderSlots(payload.slots or {})
		end
	end)

	inventoryRemote:FireServer("RequestState", {})
end

return InventoryController
