--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- CLIENT bootstrap. This is a LocalScript placed at
-- StarterPlayer/StarterPlayerScripts/ClientBootstrap.
-- It requires the Client module folder under StarterPlayerScripts and
-- starts every UI controller in a fixed order.

local Client = script:WaitForChild("Client")

local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

-- Order matters: HUD first (always visible), then interactive windows.
local controllers = {
	"Theme",
	"UIFactory",
	"HUDController",
	"InventoryController",
	"DialogueController",
	"QuestController",
	"PartyController",
	"TradeController",
	"CombatController",
	"NotificationController",
	"AmbienceController",
}

local started = {}

for _, name in ipairs(controllers) do
	local module = Client:WaitForChild(name .. "Controller", 10) or Client:WaitForChild(name, 10)
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and result.Start then
			result.Start()
			table.insert(started, name)
		else
			warn(("AFTERZERO client: controller %s failed to start (%s)"):format(name, tostring(result)))
		end
	else
		warn(("AFTERZERO client: controller module %s missing"):format(name))
	end
end

print(("AFTERZERO Stage 10 client initialized (%d controllers)."):format(#started))
