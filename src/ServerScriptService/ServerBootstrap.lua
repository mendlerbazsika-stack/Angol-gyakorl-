--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server bootstrap. Starts all services in a reliable dependency order.

local Services = script.Parent:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local SurvivalService = require(Services:WaitForChild("SurvivalService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local LootService = require(Services:WaitForChild("LootService"))
local EquipmentService = require(Services:WaitForChild("EquipmentService"))
local GatheringService = require(Services:WaitForChild("GatheringService"))
local CraftingService = require(Services:WaitForChild("CraftingService"))

-- Dependency order: data first, then gameplay systems that read it.
PlayerDataService.Start()
SurvivalService.Start()
InventoryService.Start()
LootService.Start()
EquipmentService.Start()
GatheringService.Start()
CraftingService.Start()

print("AFTERZERO Stage 3 server services initialized.")
