--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server bootstrap. Starts all Stage 1 services in a reliable order.

local Services = script.Parent:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

PlayerDataService.Start()
print("AFTERZERO Stage 1 server services initialized.")
