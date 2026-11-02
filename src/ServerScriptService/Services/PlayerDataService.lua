--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-authoritative player profile service. Owns loading, saving, and
-- session leases so two servers can never overwrite the same profile.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DataSchema = require(Shared:WaitForChild("DataSchema"))

type Profile = {
	data: any,
	token: string,
	persistent: boolean,
	released: boolean,
}

local PlayerDataService = {}
local Profiles: {[Player]: Profile} = {}

local Store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local started = false

local function dataKey(player: Player): string
	return "u_" .. tostring(player.UserId)
end

local function retryUpdate(key: string, transform: (any) -> any): (boolean, any)
	local lastError: any = nil

	for attempt = 1, GameConfig.RetryCount do
		local success, result = pcall(function()
			return Store:UpdateAsync(key, transform)
		end)

		if success then
			return true, result
		end

		lastError = result
		if attempt < GameConfig.RetryCount then
			local delaySeconds = GameConfig.RetryBaseDelaySeconds * (2 ^ (attempt - 1))
			task.wait(delaySeconds)
		end
	end

	return false, lastError
end

local function setPlayerPersistenceState(player: Player, mode: string)
	player:SetAttribute("PersistenceMode", mode)
end

local function acquireProfile(player: Player): (Profile?, string?)
	local token = HttpService:GenerateGUID(false)
	local lockRejected = false
	local futureSchema = false
	local now = os.time()

	local success, result = retryUpdate(dataKey(player), function(oldRecord)
		lockRejected = false
		futureSchema = false

		if typeof(oldRecord) ~= "table" then
			oldRecord = nil
		end

		local oldVersion = 0
		if oldRecord and typeof(oldRecord.schemaVersion) == "number" then
			oldVersion = oldRecord.schemaVersion
		end

		if oldVersion > GameConfig.SchemaVersion then
			futureSchema = true
			return nil
		end

		local oldSession = if oldRecord then oldRecord.session else nil
		if typeof(oldSession) == "table" then
			local active = typeof(oldSession.expiresAt) == "number"
				and oldSession.expiresAt > now
			local otherToken = oldSession.token ~= token

			if active and otherToken then
				lockRejected = true
				return nil
			end
		end

		local rawData = if oldRecord then oldRecord.data else nil
		local normalized = DataSchema.Normalize(rawData)

		return {
			schemaVersion = GameConfig.SchemaVersion,
			data = normalized,
			session = {
				token = token,
				expiresAt = now + GameConfig.SessionLeaseSeconds,
			},
		}
	end)

	if not success then
		warn(("AFTERZERO: Data load failed for %s: %s"):format(player.Name, tostring(result)))
		return nil, "DataStoreUnavailable"
	end

	if result == nil then
		if futureSchema then
			return nil, "FutureSchema"
		end
		if lockRejected then
			return nil, "ProfileInUse"
		end
		return nil, "ProfileUnavailable"
	end

	return {
		data = DataSchema.Normalize(result.data),
		token = token,
		persistent = true,
		released = false,
	}, nil
end

local function saveProfile(player: Player, releaseLock: boolean): (boolean, string?)
	local profile = Profiles[player]
	if not profile or not profile.persistent or profile.released then
		return false, "NoPersistentProfile"
	end

	local snapshot = DataSchema.Normalize(profile.data)
	local now = os.time()
	local ownershipLost = false

	local success, result = retryUpdate(dataKey(player), function(oldRecord)
		ownershipLost = false

		if typeof(oldRecord) ~= "table" then
			ownershipLost = true
			return nil
		end

		local session = oldRecord.session
		if typeof(session) ~= "table" or session.token ~= profile.token then
			ownershipLost = true
			return nil
		end

		return {
			schemaVersion = GameConfig.SchemaVersion,
			data = snapshot,
			session = if releaseLock
				then nil
				else {
					token = profile.token,
					expiresAt = now + GameConfig.SessionLeaseSeconds,
				},
		}
	end)

	if not success then
		warn(("AFTERZERO: Data save failed for %s: %s"):format(player.Name, tostring(result)))
		return false, "DataStoreUnavailable"
	end

	if result == nil then
		if ownershipLost then
			profile.persistent = false
			setPlayerPersistenceState(player, "SessionOnly")
		end
		return false, "ProfileOwnershipLost"
	end

	profile.data = snapshot
	return true, nil
end

local function loadPlayer(player: Player)
	player:SetAttribute("DataReady", false)
	setPlayerPersistenceState(player, "Loading")

	local profile, reason = acquireProfile(player)

	if not player.Parent then
		if profile then
			Profiles[player] = profile
			saveProfile(player, true)
			Profiles[player] = nil
		end
		return
	end

	if not profile then
		if reason == "ProfileInUse" then
			player:Kick("Your AFTERZERO profile is active in another server. Please rejoin shortly.")
			return
		elseif reason == "FutureSchema" then
			player:Kick("Your saved data uses a newer game version. Please join an updated server.")
			return
		end

		-- Allow a temporary session when DataStore is unavailable, but never
		-- write this fallback profile back to persistent storage.
		profile = {
			data = DataSchema.CreateDefault(),
			token = "",
			persistent = false,
			released = false,
		}
		setPlayerPersistenceState(player, "SessionOnly")
		warn(("AFTERZERO: %s is playing with temporary, unsaved data."):format(player.Name))
	else
		setPlayerPersistenceState(player, "Persistent")
	end

	Profiles[player] = profile

	player:SetAttribute("CharacterLevel", profile.data.character.level)
	player:SetAttribute("DataReady", true)
end

function PlayerDataService.GetData(player: Player): any?
	local profile = Profiles[player]
	if not profile or not player:GetAttribute("DataReady") then
		return nil
	end

	return profile.data
end

function PlayerDataService.MarkDirty(player: Player)
	-- Explicit API reserved for future systems. Stage 1 saves the full
	-- normalized profile on the autosave interval and on player exit.
	if not Profiles[player] then
		warn(("AFTERZERO: MarkDirty called without a loaded profile for %s"):format(player.Name))
	end
end

function PlayerDataService.SavePlayer(player: Player): (boolean, string?)
	return saveProfile(player, false)
end

local function releasePlayer(player: Player)
	local profile = Profiles[player]
	if not profile then
		return
	end

	profile.released = true
	if profile.persistent then
		-- saveProfile checks the released flag, so clear it for the final save.
		profile.released = false
		saveProfile(player, true)
		profile.released = true
	end

	Profiles[player] = nil
end

function PlayerDataService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)

	Players.PlayerRemoving:Connect(releasePlayer)

	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	task.spawn(function()
		while started do
			task.wait(GameConfig.AutosaveIntervalSeconds)

			for player, profile in pairs(Profiles) do
				if player.Parent and profile.persistent and not profile.released then
					saveProfile(player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0

		for player, profile in pairs(Profiles) do
			if profile.persistent and not profile.released then
				pending += 1
				task.spawn(function()
					saveProfile(player, true)
					pending -= 1
				end)
			end
		end

		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
