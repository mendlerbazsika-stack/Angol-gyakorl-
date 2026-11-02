--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side faction service. Owns reputation values and tier computation.
-- All reputation changes come through this service from validated sources
-- (quest turn-ins, campaign events); clients never set reputation directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionDefinitions = require(Shared:WaitForChild("FactionDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local FactionService = {}
local started = false

local FactionRemote: RemoteEvent

local MinReputation = -1000
local MaxReputation = 1000

local function getReputationTable(player: Player): {[string]: number}?
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	if typeof(data.progression.factionReputation) ~= "table" then
		data.progression.factionReputation = {}
	end
	return data.progression.factionReputation
end

function FactionService.GetReputation(player: Player, factionId: string): number
	local reputation = getReputationTable(player)
	if not reputation or not FactionDefinitions.Get(factionId) then
		return 0
	end
	return reputation[factionId] or 0
end

function FactionService.GetTier(player: Player, factionId: string): string
	return FactionDefinitions.GetTier(factionId, FactionService.GetReputation(player, factionId))
end

function FactionService.AddReputation(player: Player, factionId: string, amount: number): (boolean, string?)
	if not FactionDefinitions.Get(factionId) then
		return false, "UnknownFaction"
	end
	if typeof(amount) ~= "number" then
		return false, "InvalidAmount"
	end

	local reputation = getReputationTable(player)
	if not reputation then
		return false, "DataNotReady"
	end

	local before = reputation[factionId] or 0
	local after = math.clamp(before + math.floor(amount), MinReputation, MaxReputation)
	reputation[factionId] = after

	local beforeTier = FactionDefinitions.GetTier(factionId, before)
	local afterTier = FactionDefinitions.GetTier(factionId, after)

	if FactionRemote then
		FactionRemote:FireClient(player, "ReputationChanged", {
			factionId = factionId,
			reputation = after,
			tier = afterTier,
			amount = after - before,
		})
		if beforeTier ~= afterTier then
			FactionRemote:FireClient(player, "TierChanged", {
				factionId = factionId,
				fromTier = beforeTier,
				toTier = afterTier,
			})
		end
	end

	return true, nil
end

function FactionService.GetStandingSnapshot(player: Player)
	local result = {}
	for factionId in pairs(FactionDefinitions.All()) do
		local reputation = FactionService.GetReputation(player, factionId)
		result[factionId] = {
			reputation = reputation,
			tier = FactionDefinitions.GetTier(factionId, reputation),
		}
	end
	return result
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "RequestState" then
		if FactionRemote then
			FactionRemote:FireClient(player, "FactionsUpdated", {
				standings = FactionService.GetStandingSnapshot(player),
			})
		end
	end
	-- Reputation is never writable through remotes.
end

function FactionService.Start()
	if started then
		return
	end
	started = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	FactionRemote = remotes:FindFirstChild("FactionRemote")
	if not FactionRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "FactionRemote"
		remote.Parent = remotes
		FactionRemote = remote
	end

	FactionRemote.OnServerEvent:Connect(handleRemote)

	print("AFTERZERO FactionService initialized.")
end

return FactionService
