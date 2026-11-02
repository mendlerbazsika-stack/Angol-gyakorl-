--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Central game configuration shared by all server services.

local GameConfig = {
	DataStoreName = "Afterzero_PlayerData_v1",
	SchemaVersion = 1,

	AutosaveIntervalSeconds = 90,
	SessionLeaseSeconds = 240,

	RetryCount = 3,
	RetryBaseDelaySeconds = 1,

	MaxCurrency = 2_000_000_000,
	MaxExperience = 2_000_000_000,
	MaxLevel = 1000,
	MaxSavedMapEntries = 300,
}

return table.freeze(GameConfig)
