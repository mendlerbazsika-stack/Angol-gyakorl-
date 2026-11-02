--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server bootstrap. Starts services in dependency order.

local Services = script.Parent:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local SurvivalService = require(Services:WaitForChild("SurvivalService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local LootService = require(Services:WaitForChild("LootService"))
local EquipmentService = require(Services:WaitForChild("EquipmentService"))
local GatheringService = require(Services:WaitForChild("GatheringService"))
local CraftingService = require(Services:WaitForChild("CraftingService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local QuestService = require(Services:WaitForChild("QuestService"))
local DialogueService = require(Services:WaitForChild("DialogueService"))

PlayerDataService.Start()
SurvivalService.Start()
InventoryService.Start()
LootService.Start()
EquipmentService.Start()
GatheringService.Start()
CraftingService.Start()
WorldService.Start()
QuestService.Start()
DialogueService.Start()

print("AFTERZERO Stage 5 server services initialized.")
