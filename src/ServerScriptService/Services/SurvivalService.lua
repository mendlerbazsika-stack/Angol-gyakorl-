--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side survival system. Owns health, hunger, thirst, stamina, body
-- temperature, radiation, bleeding, and infection. All values live on the
-- server; clients only receive read-only attribute updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SurvivalConfig = require(Shared:WaitForChild("SurvivalConfig"))
local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local SurvivalService = {}
local started = false
local tracked: {[Player]: boolean} = {}
local SurvivalRemote: RemoteEvent

local DownedHealth = 30 -- health restored when revived by a party member

local function clamp(value: number, minimum: number, maximum: number): number
	return math.clamp(value, minimum, maximum)
end

function SurvivalService.GetStats(player: Player)
	local data = PlayerDataService.GetData(player)
	return if data then data.survival else nil
end

local function setStats(player: Player, stats)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and math.abs(humanoid.Health - stats.health) > 0.5 then
		humanoid.Health = clamp(stats.health, 0, SurvivalConfig.MaxHealth)
	end
	player:SetAttribute("Hunger", math.floor(stats.hunger))
	player:SetAttribute("Thirst", math.floor(stats.thirst))
	player:SetAttribute("Stamina", math.floor(stats.stamina))
	player:SetAttribute("BodyTemperature", math.floor(stats.bodyTemperature))
	player:SetAttribute("Radiation", math.floor(stats.radiation))
	player:SetAttribute("IsBleeding", stats.bleeding)
	player:SetAttribute("IsInfected", stats.infected)
end

local function initStats(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then return end
	if not data.survival then
		data.survival = {
			health = SurvivalConfig.MaxHealth, hunger = SurvivalConfig.MaxHunger,
			thirst = SurvivalConfig.MaxThirst, stamina = SurvivalConfig.MaxStamina,
			bodyTemperature = 60, radiation = 0, bleeding = false,
			infected = false, dead = false,
		}
	end
	tracked[player] = true
	player:SetAttribute("IsDowned", false)
	setStats(player, data.survival)
end

local function getRegion(player: Player)
	local name = player:GetAttribute("CurrentRegion")
	if typeof(name) == "string" then
		local region = SurvivalConfig.Regions[name]
		if region then return region end
	end
	-- Wilderness and unknown area names use Greywood's neutral environment.
	return SurvivalConfig.Regions.GreywoodCounty
end

local function handleDeath(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data or not data.survival or data.survival.dead then return end
	data.survival.dead = true
	player:SetAttribute("IsDowned", false)
	if SurvivalRemote then
		SurvivalRemote:FireClient(player, "Died", { respawnSeconds = SurvivalConfig.RespawnSeconds })
	end
	task.delay(SurvivalConfig.RespawnSeconds, function()
		if player.Parent and data.survival and data.survival.dead then
			data.survival.health = SurvivalConfig.MaxHealth
			data.survival.bleeding = false
			data.survival.dead = false
			player:LoadCharacter()
		end
	end)
end

-- Called when health hits zero: party members enter the downed state so
-- teammates can revive them; solo players go straight to the death flow.
local function handleDowned(player: Player)
	local PartyService = require(Services:WaitForChild("PartyService"))
	local party = PartyService.GetParty(player)

	if not party or #party.members <= 1 then
		handleDeath(player)
		return
	end

	local data = PlayerDataService.GetData(player)
	if not data or not data.survival then
		handleDeath(player)
		return
	end

	data.survival.dead = true
	player:SetAttribute("IsDowned", true)

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		-- Keep the body alive but immobile until revived or the timer expires.
		humanoid.Health = 1
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end

	local reviveWindow = SurvivalConfig.RespawnSeconds * 3
	if SurvivalRemote then
		SurvivalRemote:FireClient(player, "Downed", { reviveWindowSeconds = reviveWindow })
	end

	task.delay(reviveWindow, function()
		if player.Parent and data.survival and data.survival.dead and player:GetAttribute("IsDowned") == true then
			-- Nobody revived in time: normal death flow.
			player:SetAttribute("IsDowned", false)
			if SurvivalRemote then
				SurvivalRemote:FireClient(player, "Died", { respawnSeconds = SurvivalConfig.RespawnSeconds })
			end
			task.delay(SurvivalConfig.RespawnSeconds, function()
				if player.Parent and data.survival and data.survival.dead then
					data.survival.health = SurvivalConfig.MaxHealth
					data.survival.bleeding = false
					data.survival.dead = false
					player:LoadCharacter()
				end
			end)
		end
	end)
end

-- Revive entry point, called by PartyService after full validation.
function SurvivalService.TryRevive(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	if not data or not data.survival or not data.survival.dead then
		return false
	end
	if player:GetAttribute("IsDowned") ~= true then
		return false
	end

	data.survival.dead = false
	data.survival.health = DownedHealth
	player:SetAttribute("IsDowned", false)

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpHeight = 7.2
	end
	setStats(player, data.survival)

	if SurvivalRemote then
		SurvivalRemote:FireClient(player, "Revived", { health = DownedHealth })
	end

	return true
end

-- Public entry for CombatService when player health hits zero.
function SurvivalService.EnterDownedOrDead(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data or not data.survival or data.survival.dead then
		return
	end
	handleDowned(player)
end

local function onTick()
	local deltaTime = SurvivalConfig.TickIntervalSeconds
	local minutes = deltaTime / 60
	for player in pairs(tracked) do
		if not player.Parent then continue end
		local data = PlayerDataService.GetData(player)
		local stats = if data then data.survival else nil
		if not stats or stats.dead then continue end
		local region = getRegion(player)

		stats.hunger = clamp(stats.hunger - SurvivalConfig.HungerDecayPerMinute * minutes, 0, SurvivalConfig.MaxHunger)
		stats.thirst = clamp(stats.thirst - SurvivalConfig.ThirstDecayPerMinute * minutes, 0, SurvivalConfig.MaxThirst)
		stats.bodyTemperature = clamp(stats.bodyTemperature + region.temperatureDeltaPerMinute * minutes, 0, SurvivalConfig.MaxBodyTemperature)
		stats.radiation = clamp(stats.radiation + region.radiationRatePerMinute * minutes, 0, SurvivalConfig.MaxRadiation)
		if stats.radiation > 0 and region.radiationRatePerMinute <= 0 then
			stats.radiation = clamp(stats.radiation - SurvivalConfig.RadiationRecoveryPerMinute * minutes, 0, SurvivalConfig.MaxRadiation)
		end

		local damagePerMinute = 0
		if stats.hunger <= 0 then damagePerMinute += SurvivalConfig.StarvationHealthDamagePerMinute end
		if stats.thirst <= 0 then damagePerMinute += SurvivalConfig.DehydrationHealthDamagePerMinute end
		if stats.bodyTemperature < SurvivalConfig.ColdDamageHealthThreshold then damagePerMinute += SurvivalConfig.ColdHealthDamagePerMinute end
		if stats.radiation >= 50 then damagePerMinute += SurvivalConfig.RadiationDamageHealthPerMinute end
		if stats.bleeding then damagePerMinute += SurvivalConfig.BleedingHealthLossPerMinute end
		if stats.infected then damagePerMinute += SurvivalConfig.InfectionHealthLossPerMinute end
		stats.health = clamp(stats.health - damagePerMinute * minutes, 0, SurvivalConfig.MaxHealth)
		setStats(player, stats)
		if stats.health <= 0 then handleDowned(player) end
	end
end

local function waitForDataThenTrack(player: Player)
	task.spawn(function()
		repeat task.wait(0.5) until player.Parent == nil or player:GetAttribute("DataReady") == true
		if player.Parent and player:GetAttribute("DataReady") == true then initStats(player) end
	end)
end

function SurvivalService.Start()
	if started then return end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage end
	SurvivalRemote = remotes:FindFirstChild("SurvivalRemote") :: RemoteEvent
	if not SurvivalRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "SurvivalRemote"
		remote.Parent = remotes
		SurvivalRemote = remote
	end
	Players.PlayerAdded:Connect(waitForDataThenTrack)
	Players.PlayerRemoving:Connect(function(player) tracked[player] = nil end)
	for _, player in Players:GetPlayers() do waitForDataThenTrack(player) end
	task.spawn(function()
		while started do task.wait(SurvivalConfig.TickIntervalSeconds); onTick() end
	end)
end

return SurvivalService
