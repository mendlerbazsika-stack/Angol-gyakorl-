--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side equipment service. Equipment slots, hotbar, durability wear and
-- repair. All equips/unequips are validated on the server against inventory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local EquipmentService = {}
local started = false

local EquipmentRemote: RemoteEvent

-- Equip slots: Body (clothing/armor), MainHand (tool/weapon), OffHand, Back
local ValidSlots = {
	Body = "Body",
	MainHand = "MainHand",
	OffHand = "OffHand",
}
local EquipmentSlotNames = { "Body", "MainHand", "OffHand" }

local function slotMatchesCategory(slot: string, category: string): boolean
	if slot == "Body" then
		return category == "Clothing" or category == "Armor"
	end
	if slot == "MainHand" or slot == "OffHand" then
		return category == "Tool" or category == "Weapon"
	end
	return false
end

local function getEquipmentTable(player: Player): {[string]: string}?
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	if typeof(data.inventory.equipment) ~= "table" then
		data.inventory.equipment = {}
	end
	return data.inventory.equipment
end

local function hasStats(player: Player, itemId: string): boolean
	local definition = ItemDefinitions.Get(itemId)
	if not definition or not definition.equipment then
		return false
	end
	return true
end

function EquipmentService.Equip(player: Player, itemId: string, slot: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local definition = ItemDefinitions.Get(itemId)
	if not definition then
		return false, "UnknownItem"
	end

	if not ValidSlots[slot] then
		return false, "InvalidSlot"
	end

	if not slotMatchesCategory(slot, definition.category) then
		return false, "CategoryMismatch"
	end

	local equipment = getEquipmentTable(player)
	if not equipment then
		return false, "DataNotReady"
	end

	-- Item must be in inventory
	if InventoryService.CountItem(player, itemId) < 1 then
		return false, "ItemNotInInventory"
	end

	-- Remove from inventory, then unequip whatever occupied the slot back into it.
	local current = equipment[slot]
	if current then
		InventoryService.AddItem(player, current, 1)
	end

	local removed = InventoryService.RemoveItem(player, itemId, 1)
	if not removed then
		-- Restore the old equip if something went wrong mid-swap.
		if current then
			InventoryService.RemoveItem(player, current, 1)
		end
		return false, "CouldNotRemoveItem"
	end

	equipment[slot] = itemId

	if EquipmentRemote then
		EquipmentRemote:FireClient(player, "EquipmentUpdated", {
			equipment = { Body = equipment.Body, MainHand = equipment.MainHand, OffHand = equipment.OffHand },
		})
	end

	return true, nil
end

function EquipmentService.Unequip(player: Player, slot: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	if not ValidSlots[slot] then
		return false, "InvalidSlot"
	end

	local equipment = getEquipmentTable(player)
	if not equipment then
		return false, "DataNotReady"
	end

	local current = equipment[slot]
	if not current then
		return false, "NothingEquipped"
	end

	local ok = InventoryService.AddItem(player, current, 1)
	if not ok then
		return false, "InventoryFull"
	end

	equipment[slot] = nil

	if EquipmentRemote then
		EquipmentRemote:FireClient(player, "EquipmentUpdated", {
			equipment = { Body = equipment.Body, MainHand = equipment.MainHand, OffHand = equipment.OffHand },
		)
	end

	return true, nil
end

function EquipmentService.GetEquipped(player: Player): {[string]: string}?
	return getEquipmentTable(player)
end

function EquipmentService.GetEquippedToolLevel(player: Player): number
	local equipment = getEquipmentTable(player)
	if not equipment then
		return 0
	end

	local toolLevel = 0
	for _, slot in ipairs(EquipmentSlotNames) do
		local itemId = equipment[slot]
		if itemId then
			local definition = ItemDefinitions.Get(itemId)
			if definition and definition.equipment and definition.equipment.toolLevel then
				toolLevel = math.max(toolLevel, definition.equipment.toolLevel)
			end
		end
	end
	return toolLevel
end

function EquipmentService.ApplyDurabilityWear(player: Player, slot: string, amount: number): (boolean, string?)
	-- Durability wear is applied on use (harvest, combat). A worn-out item
	-- breaks and is removed from the slot; the player is notified.
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local durabilityTable = data.inventory.durability
	if typeof(durabilityTable) ~= "table" then
		durabilityTable = {}
		data.inventory.durability = durabilityTable
	end

	local equipment = getEquipmentTable(player)
	if not equipment then
		return false, "DataNotReady"
	end

	local itemId = equipment[slot]
	if not itemId then
		return false, "NothingEquipped"
	end

	local current = durabilityTable[itemId]
	if typeof(current) ~= "number" then
		local definition = ItemDefinitions.Get(itemId)
		current = if definition and definition.durability then definition.durability else 100
	end

	current -= amount
	if current <= 0 then
		equipment[slot] = nil
		durabilityTable[itemId] = nil

		if EquipmentRemote then
			EquipmentRemote:FireClient(player, "ItemBroke", { slot = slot, itemId = itemId })
		end
	else
		durabilityTable[itemId] = current
	end

	return true, nil
end

function EquipmentService.Repair(player: Player, itemId: string): (boolean, string?)
	-- Repairs use ScrapMetal; full repair for one unit at a workbench.
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local definition = ItemDefinitions.Get(itemId)
	if not definition or not definition.durability then
		return false, "NotRepairable"
	end

	if InventoryService.CountItem(player, "ScrapMetal") < 1 then
		return false, "MissingScrapMetal"
	end

	local durabilityTable = data.inventory.durability
	if typeof(durabilityTable) ~= "table" then
		durabilityTable = {}
		data.inventory.durability = durabilityTable
	end

	InventoryService.RemoveItem(player, "ScrapMetal", 1)
	durabilityTable[itemId] = definition.durability

	if EquipmentRemote then
		EquipmentRemote:FireClient(player, "ItemRepaired", { itemId = itemId })
	end

	return true, nil
end

local function handleRemote(player: Player, action: string, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if action == "Equip" then
		if typeof(payload.itemId) == "string" and typeof(payload.slot) == "string" then
			EquipmentService.Equip(player, payload.itemId, payload.slot)
		end
	elseif action == "Unequip" then
		if typeof(payload.slot) == "string" then
			EquipmentService.Unequip(player, payload.slot)
		end
	elseif action == "Repair" then
		if typeof(payload.itemId) == "string" then
			EquipmentService.Repair(player, payload.itemId)
		end
	end
end

function EquipmentService.Start()
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
	EquipmentRemote = remotesFolder:FindFirstChild("EquipmentRemote")
	if EquipmentRemote == nil then
		EquipmentRemote = Instance.new("RemoteEvent")
		EquipmentRemote.Name = "EquipmentRemote"
		EquipmentRemote.Parent = remotesFolder
	end

	EquipmentRemote.OnServerEvent:Connect(handleRemote)
end

return EquipmentService
