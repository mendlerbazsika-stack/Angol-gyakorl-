--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side inventory service. Stacks, slots, weight capacity, item
-- consumption, and drops. Every mutation is validated on the server; clients
-- can request actions but never dictate quantities or outcomes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local InventoryService = {}
local started = false

local MaxSlots = 24
local MaxWeight = 60

local InventoryRemote: RemoteEvent

local function ensureInventory(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end

	if typeof(data.inventory) ~= "table" then
		data.inventory = {}
	end
	if typeof(data.inventory.slots) ~= "table" then
		data.inventory.slots = {}
	end

	return data
end

local function getSlots(player: Player): {any}?
	local data = ensureInventory(player)
	return if data then data.inventory.slots else nil
end

local function totalWeight(slots: {any}): number
	local weight = 0
	for _, slot in ipairs(slots) do
		local def = ItemDefinitions.Get(slot.id)
		if def then
			weight += def.weight * slot.count
		end
	end
	return weight
end

local function broadcastInventory(player: Player)
	local slots = getSlots(player)
	if not slots or not InventoryRemote then
		return
	end

	local snapshot = {}
	for index, slot in ipairs(slots) do
		local def = ItemDefinitions.Get(slot.id)
		if def then
			table.insert(snapshot, {
				slot = index,
				id = def.id,
				name = def.name,
				description = def.description,
				category = def.category,
				stackLimit = def.stackLimit,
				weight = def.weight,
				rarity = def.rarity,
				count = slot.count,
			})
		end
	end

	InventoryRemote:FireClient(player, "InventoryUpdated", {
		slots = snapshot,
		maxSlots = MaxSlots,
		maxWeight = MaxWeight,
		currentWeight = math.floor(totalWeight(slots) * 10) / 10,
	})
end

function InventoryService.AddItem(player: Player, itemId: string, count: number): (boolean, string?)
	local definition = ItemDefinitions.Get(itemId)
	if not definition then
		return false, "UnknownItem"
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local slots = getSlots(player)
	if not slots then
		return false, "DataNotReady"
	end

	local toAdd = math.floor(count)
	if toAdd <= 0 then
		return false, "InvalidCount"
	end

	-- Fill existing stacks first
	local remaining = toAdd
	for _, slot in ipairs(slots) do
		if remaining <= 0 then
			break
		end
		if slot.id == itemId and slot.count < definition.stackLimit then
			local space = definition.stackLimit - slot.count
			local moved = math.min(space, remaining)
			slot.count += moved
			remaining -= moved
		end
	end

	-- Open new slots as needed
	while remaining > 0 do
		if #slots >= MaxSlots then
			broadcastInventory(player)
			return false, "InventoryFull"
		end
		local moved = math.min(definition.stackLimit, remaining)
		table.insert(slots, { id = itemId, count = moved })
		remaining -= moved
	end

	broadcastInventory(player)
	return true, nil
end

function InventoryService.RemoveItem(player: Player, itemId: string, count: number): (boolean, string?)
	local slots = getSlots(player)
	if not slots then
		return false, "DataNotReady"
	end

	local available = 0
	for _, slot in ipairs(slots) do
		if slot.id == itemId then
			available += slot.count
		end
	end

	local toRemove = math.floor(count)
	if toRemove <= 0 then
		return false, "InvalidCount"
	end
	if available < toRemove then
		return false, "NotEnoughItems"
	end

	local remaining = toRemove
	for index = #slots, 1, -1 do
		if remaining <= 0 then
			break
		end
		local slot = slots[index]
		if slot.id == itemId then
			local taken = math.min(slot.count, remaining)
			slot.count -= taken
			remaining -= taken
			if slot.count <= 0 then
				table.remove(slots, index)
			end
		end
	end

	broadcastInventory(player)
	return true, nil
end

function InventoryService.CountItem(player: Player, itemId: string): number
	local slots = getSlots(player)
	if not slots then
		return 0
	end

	local total = 0
	for _, slot in ipairs(slots) do
		if slot.id == itemId then
			total += slot.count
		end
	end
	return total
end

local function applyConsumableEffect(player: Player, itemId: string): (boolean, string?)
	local definition = ItemDefinitions.Get(itemId)
	if not definition or not definition.effect then
		return false, "NotConsumable"
	end

	local Services = ServerScriptService:WaitForChild("Services")
	local SurvivalService = require(Services:WaitForChild("SurvivalService"))
	local stats = SurvivalService.GetStats(player)
	if not stats then
		return false, "DataNotReady"
	end

	local effect = definition.effect
	if effect.hunger then
		stats.hunger = math.clamp(stats.hunger + effect.hunger, 0, 100)
	end
	if effect.thirst then
		stats.thirst = math.clamp(stats.thirst + effect.thirst, 0, 100)
	end
	if effect.health then
		stats.health = math.clamp(stats.health + effect.health, 0, 100)
	end
	if effect.cureBleeding then
		stats.bleeding = false
	end
	if effect.infectionCure then
		stats.infected = false
	end

	return true, nil
end

function InventoryService.ConsumeItem(player: Player, itemId: string): (boolean, string?)
	local definition = ItemDefinitions.Get(itemId)
	if not definition then
		return false, "UnknownItem"
	end
	if not definition.effect then
		return false, "NotConsumable"
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local consumed = InventoryService.RemoveItem(player, itemId, 1)
	if not consumed then
		return consumed
	end

	-- Murky water may cause infection (roll once, server-side).
	if itemId == "WaterFlaskMurky" then
		local SurvivalConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SurvivalConfig"))
		if math.random() < SurvivalConfig.InfectionChanceFromMurkyWater then
			local Services = ServerScriptService:WaitForChild("Services")
			local SurvivalService = require(Services:WaitForChild("SurvivalService"))
			local stats = SurvivalService.GetStats(player)
			if stats then
				stats.infected = true
			end
		end
	end

	local applied = applyConsumableEffect(player, itemId)
	if not applied then
		-- Refund the item if the effect could not be applied.
		InventoryService.AddItem(player, itemId, 1)
		return applied
	end

	return true, nil
end

local function handleRemote(player: Player, action: string, payload: any)
	-- Server is authoritative: payload is validated, never trusted for outcomes.
	if action == "Consume" then
		local itemId = if typeof(payload) == "table" then payload.itemId else nil
		if typeof(itemId) ~= "string" then
			return
		end
		InventoryService.ConsumeItem(player, itemId)
	elseif action == "RequestState" then
		broadcastInventory(player)
	end
end

function InventoryService.Start()
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
	InventoryRemote = remotesFolder:FindFirstChild("InventoryRemote")
	if InventoryRemote == nil then
		InventoryRemote = Instance.new("RemoteEvent")
		InventoryRemote.Name = "InventoryRemote"
		InventoryRemote.Parent = remotesFolder
	end

	InventoryRemote.OnServerEvent:Connect(function(player, action, payload)
		handleRemote(player, action, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		-- Ensure inventory exists once data is ready.
		task.spawn(function()
			repeat
				task.wait(0.5)
			until player.Parent == nil or player:GetAttribute("DataReady") == true
			if player.Parent then
				ensureInventory(player)
				broadcastInventory(player)
			end
		end)
	end)

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("DataReady") == true then
			ensureInventory(player)
			broadcastInventory(player)
		else
			task.spawn(function()
				repeat
					task.wait(0.5)
				until player.Parent == nil or player:GetAttribute("DataReady") == true
				if player.Parent then
					ensureInventory(player)
					broadcastInventory(player)
				end
			end)
		end
	end
end

return InventoryService
