--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Shared survival configuration: stat ranges, decay rates, penalties, and
-- region environmental data used by SurvivalService.

local SurvivalConfig = {
	-- Stat ranges
	MaxHealth = 100,
	MaxHunger = 100,
	MaxThirst = 100,
	MaxStamina = 100,
	MaxBodyTemperature = 100,
	MaxRadiation = 100,

	-- Tick / update
	TickIntervalSeconds = 4,

	-- Natural decay (per minute, applied proportionally per tick)
	HungerDecayPerMinute = 0.5,
	ThirstDecayPerMinute = 0.8,

	-- Low stat penalties (applied per tick when a stat is below threshold)
	StarvationHealthDamagePerMinute = 1,
	DehydrationHealthDamagePerMinute = 2,
	LowStaminaSprintBlock = 10,

	-- Sprinting
	SprintStaminaDrainPerSecond = 15,
	StaminaRegenPerSecond = 8,

	-- Environment
	BaseTemperaturePerMinute = 0, -- Greywood neutral baseline
	FrostTemperatureLossPerMinute = 0.8,
	ColdDamageHealthThreshold = 30, -- body temperature below which damage applies
	ColdHealthDamagePerMinute = 1,
	ShelterColdProtection = 0.5, -- multiplier inside shelters

	-- Radiation
	RadiationDamageHealthPerMinute = 2,
	RadiationRecoveryPerMinute = 0.5, -- when outside radiation areas
	MaxRadiationExposure = 100,

	-- Bleeding and infection
	BleedingHealthLossPerMinute = 3,
	InfectionHealthLossPerMinute = 1,
	InfectionChanceFromMurkyWater = 0.15,

	-- Death and respawn
	RespawnSeconds = 5,
	DeathPenaltyCurrencyPercent = 10,
	DeathPenaltyItems = false, -- configurable: drop items on death when true

	-- Regions (region name -> environment)
	Regions = {
		GreywoodCounty = {
			temperatureDeltaPerMinute = 0,
			radiationRatePerMinute = 0,
		},
		AshfordCity = {
			temperatureDeltaPerMinute = -0.2,
			radiationRatePerMinute = 0,
		},
		Ironworks = {
			temperatureDeltaPerMinute = 0.1,
			radiationRatePerMinute = 0.05,
		},
		Frostline = {
			temperatureDeltaPerMinute = -0.8,
			radiationRatePerMinute = 0,
		},
		ExclusionZone = {
			temperatureDeltaPerMinute = -0.3,
			radiationRatePerMinute = 0.6,
		},
	},
}

return table.freeze(SurvivalConfig)
