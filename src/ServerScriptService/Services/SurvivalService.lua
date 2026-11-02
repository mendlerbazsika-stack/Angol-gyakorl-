--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side survival system. Owns health, hunger, thirst, stamina, body
-- temperature, radiation, bleeding, and infection. All values live on the
-- server; clients only receive read-only attribute updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SurvivalConfig = require(Shared:WaitForChild("SurvivalConfig"))

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local SurvivalService = {}
local started = false
local tracked: {[Player]: boolean} = {}
local sprinting: {[Player]: boolean} = {}

local SurvivalRemote: RemoteEvent

local function clamp(value: number, minimum: number, maximum: number): number
	return math.clamp(value, minimum, maximum)
end

function SurvivalService.GetStats(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	return data.survival
end

local function setStats(player: Player, stats)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end

	humanoid.Health = clamp(stats.health, 0, SurvivalConfig.MaxHealth)

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
	if not data then
		return
	end

	if not data.survival then
		data.survival = {
			health = SurvivalConfig.MaxHealth,
			hunger = SurvivalConfig.MaxHunger,
			thirst = SurvivalConfig.MaxThirst,
			stamina = SurvivalConfig.MaxStamina,
			bodyTemperature = 60, -- comfortable
			radiation = 0,
			bleeding = false,
			infected = false,
			dead = false,
		}
	end

	tracked[player] = true
	sprinting[player] = false

	local character = player.Character or player.CharacterAdded:Wait()
	setStats(player, data.survival)
end

local function getRegionName(player: Player): string
	-- Stage 4 will replace this with real region zone detection.
	local attribute = player:GetAttribute("CurrentRegion")
	if typeof(attribute) == "string" and SurvivalConfig.Regions[attribute] then
		return attribute
	end
	return "GreywoodCounty"
end

local function onCharacterAdded(player: Player, character: Model)
	local data = PlayerDataService.GetData(player)
	if not data or not data.survival then
		return
	end

	-- Respawn restores health but keeps hunger/thirst pressure; death is
	-- designed to be a setback, not a full reset.
	data.survival.health = SurvivalConfig.MaxHealth
	data.survival.dead = false
	setStats(player, data.survival)

	character:PivotTo(spawnPosition or CFrame.new(0, 5, 0))
end

local function handleDeath(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data or not data.survival then
		return
	end

	data.survival.dead = true
	if SurvivalRemote then
		SurvivalRemote:FireClient(player, "Died", {
			respawnSeconds = SurvivalConfig.RespawnSeconds,
		})
	end

	task.delay(SurvivalConfig.RespawnSeconds, function()
		if player.Parent and data.survival and data.survival.dead then
			local character = player.Character
			if character then
				character:BreakJoints()
			else
				player:LoadCharacter()
			end
		end
	end)
end

local function onHeartbeat(deltaTime: number)
	for player, isTracked in pairs(tracked) do
		if not isTracked or not player.Parent then
			continue
		end

		local data = PlayerDataService.GetData(player)
		local stats = if data then data.survival else nil
		if not stats then
			continue
		end

		local minutes = deltaTime / 60
		local region = SurvivalConfig.Regions[getRegionName(player)]

		-- Hunger and thirst decay
		stats.hunger = clamp(stats.hunger - SurvivalConfig.HungerDecayPerMinute * minutes, 0, SurvivalConfig.MaxHunger)
		stats.thirst = clamp(stats.thirst - SurvivalConfig.ThirstDecayPerMinute * minutes, 0, SurvivalConfig.MaxThirst)

		-- Stamina
		if sprinting[player] then
			stats.stamina = clamp(stats.stamina - SurvivalConfig.SprintStaminaDrainPerSecond * deltaTime, 0, SurvivalConfig.MaxStamina)
		else
			stats.stamina = clamp(stats.stamina + SurvivalConfig.StaminaRegenPerSecond * deltaTime, 0, SurvivalConfig.MaxStamina)
		end

		-- Body temperature by region
		stats.bodyTemperature = clamp(
			stats.bodyTemperature + region.temperatureDeltaPerMinute * minutes,
			0,
			SurvivalConfig.MaxBodyTemperature
		)

		-- Radiation
		stats.radiation = clamp(
			stats.radiation + region.radiationRatePerMinute * minutes,
			0,
			SurvivalConfig.MaxRadiation
		)
		if stats.radiation > 0 and region.radiationRatePerMinute == 0 then
			stats.radiation = clamp(stats.radiation - SurvivalConfig.RadiationRecoveryPerMinute * minutes, 0, SurvivalConfig.MaxRadiation)
		end

		-- Health damage from starvation, dehydration, cold, radiation, bleeding
		local damagePerMinute = 0
		if stats.hunger <= 0 then
			damagePerMinute += SurvivalConfig.StarvationHealthDamagePerMinute
		end
		if stats.thirst <= 0 then
			damagePerMinute += SurvivalConfig.DehydrationHealthDamagePerMinute
		end
		if stats.bodyTemperature < SurvivalConfig.ColdDamageHealthThreshold then
			damagePerMinute += SurvivalConfig.ColdHealthDamagePerMinute
		end
		if stats.radiation >= 50 then
			damagePerMinute += SurvivalConfig.RadiationDamageHealthPerMinute
		end
		if stats.bleeding then
			damagePerMinute += SurvivalConfig.BleedingHealthLossPerMinute
		end
		if stats.infected then
			damagePerMinute += SurvivalConfig.InfectionHealthLossPerMinute
		end

		if damagePerMinute > 0 then
			stats.health = clamp(stats.health - damagePerMinute * minutes, 0, SurvivalConfig.MaxHealth)
		end

		setStats(player, stats)

		if stats.health <= 0 and not stats.dead then
			handleDeath(player)
		end
	end
end

function SurvivalService.Start()
	if started then
		return
	end
	started = true

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesFolder == nil then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	SurvivalRemote = remotesFolder:FindFirstChild("SurvivalRemote")
	if SurvivalRemote == nil then
		SurvivalRemote = Instance.new("RemoteEvent")
		SurvivalRemote.Name = "SurvivalRemote"
		SurvivalRemote.Parent = respFolder
	end

	Players.PlayerAdded:Connect(function(player)
		-- Wait until profile data is ready before initializing survival stats.
		repeat
			task.wait(0.5)
		until player.Parent == nil or player:GetAttribute("DataReady") == true
		if player.Parent then
			initStats(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		tracked[player] = nil
		sprinting[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("DataReady") == true then
			initStats(player)
		else
			task.spawn(function()
				repeat
					task.wait(0.5)
				until player.Parent == nil or player:GetAttribute("DataReady") == true
				if player.Parent then
					initStats(player)
				end
			end)
		end
	end

	game:GetService("RunService").Heartbeat:Connect(function(deltaTime: number)
		onHeartbeat(deltaTime)
	end)
end

return SurvivalService
