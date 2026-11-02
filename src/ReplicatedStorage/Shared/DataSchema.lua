--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Versioned, allowlisted player data schema. Normalizes raw DataStore data into
-- a known-safe structure before any game system reads or writes it.

local GameConfig = require(script.Parent.GameConfig)

local DataSchema = {}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function boundedInteger(value: any, defaultValue: number, minimum: number, maximum: number): number
	if not isFiniteNumber(value) then
		return defaultValue
	end

	return math.clamp(math.floor(value), minimum, maximum)
end

local function boundedNumber(value: any, defaultValue: number, minimum: number, maximum: number): number
	if not isFiniteNumber(value) then
		return defaultValue
	end

	return math.clamp(value, minimum, maximum)
end

local function copyNumberMap(source: any, minimum: number, maximum: number): {[string]: number}
	local result: {[string]: number} = {}

	if typeof(source) ~= "table" then
		return result
	end

	local copied = 0
	for key, value in pairs(source) do
		if copied >= GameConfig.MaxSavedMapEntries then
			break
		end

		if typeof(key) == "string" and #key <= 100 and isFiniteNumber(value) then
			result[key] = math.clamp(math.floor(value), minimum, maximum)
			copied += 1
		end
	end

	return result
end

local function copyBooleanMap(source: any): {[string]: boolean}
	local result: {[string]: boolean} = {}

	if typeof(source) ~= "table" then
		return result
	end

	local copied = 0
	for key, value in pairs(source) do
		if copied >= GameConfig.MaxSavedMapEntries then
			break
		end

		if typeof(key) == "string" and #key <= 100 and typeof(value) == "boolean" then
			result[key] = value
			copied += 1
		end
	end

	return result
end

local function copyStringMap(source: any, maximumEntries: number): {[string]: string}
	local result: {[string]: string} = {}

	if typeof(source) ~= "table" then
		return result
	end

	local copied = 0
	for key, value in pairs(source) do
		if copied >= maximumEntries then
			break
		end

		if typeof(key) == "string" and #key <= 100
			and typeof(value) == "string" and #value <= 100 then
			result[key] = value
			copied += 1
		end
	end

	return result
end

-- Inventory slots: ordered array of { id = string, count = number }.
local function normalizeSlots(source: any, maximumSlots: number): {any}
	local result = {}

	if typeof(source) ~= "table" then
		return result
	end

	for index = 1, math.min(#source, maximumSlots) do
		local slot = source[index]
		if typeof(slot) == "table" and typeof(slot.id) == "string"
			and #slot.id <= 100 and isFiniteNumber(slot.count) then
			local count = math.clamp(math.floor(slot.count), 0, 9999)
			if count > 0 then
				table.insert(result, { id = slot.id, count = count })
			end
		end
	end

	return result
end

-- Built structures: ordered array of { id, templateId, x, y, z, ry }.
-- Owner userId is implied by the profile the record is saved in.
local function normalizeStructures(source: any, maximumStructures: number): {any}
	local result = {}

	if typeof(source) ~= "table" then
		return result
	end

	for index = 1, math.min(#source, maximumStructures) do
		local record = source[index]
		if typeof(record) == "table"
			and typeof(record.id) == "string" and #record.id <= 100
			and typeof(record.templateId) == "string" and #record.templateId <= 100
			and isFiniteNumber(record.x) and isFiniteNumber(record.y) and isFiniteNumber(record.z) then
			table.insert(result, {
				id = record.id,
				templateId = record.templateId,
				x = boundedNumber(record.x, 0, -5000, 5000),
				y = boundedNumber(record.y, 1, 0.5, 200),
				z = boundedNumber(record.z, 0, -5000, 5000),
				ry = boundedNumber(record.ry, 0, -math.pi, math.pi),
			})
		end
	end

	return result
end

local function normalizeSurvival(source: any): any
	local defaults = {
		health = 100,
		hunger = 100,
		thirst = 100,
		stamina = 100,
		bodyTemperature = 60,
		radiation = 0,
		bleeding = false,
		infected = false,
		dead = false,
	}

	if typeof(source) ~= "table" then
		return defaults
	end

	return {
		health = boundedInteger(source.health, 100, 0, 100),
		hunger = boundedInteger(source.hunger, 100, 0, 100),
		thirst = boundedInteger(source.thirst, 100, 0, 100),
		stamina = boundedInteger(source.stamina, 100, 0, 100),
		bodyTemperature = boundedInteger(source.bodyTemperature, 60, 0, 100),
		radiation = boundedInteger(source.radiation, 0, 0, 100),
		bleeding = if typeof(source.bleeding) == "boolean" then source.bleeding else false,
		infected = if typeof(source.infected) == "boolean" then source.infected else false,
		dead = false, -- never persist dead state; a fresh session always spawns alive
	}
end

-- Valid endgame decisions only; anything else drops to nil on load.
local ValidEndgameDecisions = {
	RestartTheCore = true,
	BuryTheFacility = true,
	HandToTheOrder = true,
}

function DataSchema.CreateDefault()
	return {
		schemaVersion = GameConfig.SchemaVersion,

		currency = 0,

		character = {
			level = 1,
			experience = 0,
			skills = {},
		},

		inventory = {
			slots = {},
			equipment = {},
			durability = {},
			hotbar = {},
		},

		survival = normalizeSurvival(nil),

		structures = {
			built = {},
		},

		progression = {
			unlockedRegions = {
				GreywoodCounty = true,
			},
			activeQuests = {},
			completedQuests = {},
			questObjectives = {},
			killProgress = {},
			completedChapters = {},
			endgameDecision = nil,
			craftedRecipes = {},
			storyDecisions = {},
			factionReputation = {},
		},

		settings = {
			subtitles = true,
			reducedCameraShake = false,
		},
	}
end

-- Migration policy for this first schema:
-- version 0 (missing) is normalized into version 1; records from a future
-- schema version are rejected by PlayerDataService rather than overwritten.
function DataSchema.Normalize(raw: any)
	local data = DataSchema.CreateDefault()

	if typeof(raw) ~= "table" then
		return data
	end

	data.currency = boundedInteger(raw.currency, 0, 0, GameConfig.MaxCurrency)

	local character = if typeof(raw.character) == "table" then raw.character else {}
	data.character.level = boundedInteger(character.level, 1, 1, GameConfig.MaxLevel)
	data.character.experience = boundedInteger(
		character.experience,
		0,
		0,
		GameConfig.MaxExperience
	)
	data.character.skills = copyNumberMap(character.skills, 0, 100)

	local inventory = if typeof(raw.inventory) == "table" then raw.inventory else {}
	data.inventory.slots = normalizeSlots(inventory.slots, 24)
	data.inventory.equipment = copyStringMap(inventory.equipment, 30)
	data.inventory.durability = copyNumberMap(inventory.durability, 0, 100)
	data.inventory.hotbar = copyStringMap(inventory.hotbar, 10)

	if raw.survival ~= nil then
		data.survival = normalizeSurvival(raw.survival)
	end

	local structures = if typeof(raw.structures) == "table" then raw.structures else {}
	data.structures.built = normalizeStructures(structures.built, 40)

	local progression = if typeof(raw.progression) == "table" then raw.progression else {}
	data.progression.unlockedRegions = copyBooleanMap(progression.unlockedRegions)
	data.progression.activeQuests = copyBooleanMap(progression.activeQuests)
	data.progression.completedQuests = copyBooleanMap(progression.completedQuests)
	data.progression.questObjectives = copyBooleanMap(progression.questObjectives)
	data.progression.killProgress = copyNumberMap(progression.killProgress, 0, 999)
	data.progression.completedChapters = copyBooleanMap(progression.completedChapters)

	local endgameDecision = progression.endgameDecision
	if typeof(endgameDecision) == "string" and ValidEndgameDecisions[endgameDecision] then
		data.progression.endgameDecision = endgameDecision
	end

	data.progression.craftedRecipes = copyBooleanMap(progression.craftedRecipes)
	data.progression.storyDecisions = copyStringMap(progression.storyDecisions, 100)
	data.progression.factionReputation = copyNumberMap(
		progression.factionReputation,
		-1000,
		1000
	)

	-- Keep the starting region unlocked even if older or malformed data omitted it.
	data.progression.unlockedRegions.GreywoodCounty = true

	local settings = if typeof(raw.settings) == "table" then raw.settings else {}
	if typeof(settings.subtitles) == "boolean" then
		data.settings.subtitles = settings.subtitles
	end
	if typeof(settings.reducedCameraShake) == "boolean" then
		data.settings.reducedCameraShake = settings.reducedCameraShake
	end

	return data
end

return DataSchema
