--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Region definitions for the four campaign regions. RegionService builds
-- compact blockouts and travel gates from this data; EnemyService and
-- LootService spawn from these tables via their public APIs.

export type Poi = {
	name: string,
	position: Vector3,
	dimensions: Vector3,
	lootTable: string?,
}

export type RegionConfig = {
	id: string,
	displayName: string,
	description: string,
	-- Blockout is generated far from Greywood (X offset), reached by gate teleport.
	spawnOffset: Vector3,
	buildings: {Poi},
	enemySpawns: {{ enemyId: string, position: Vector3 }}, -- positions relative to spawnOffset
	entryGate: { name: string, position: Vector3 }, -- position relative to spawnOffset
	gatesTo: string, -- region id this region's entry gate returns to
}

local regions: {[string]: RegionConfig} = {
	AshfordCity = {
		id = "AshfordCity",
		displayName = "Ashford City",
		description = "A dead city of leaning towers. The archive under the bank still holds pre-Blackout records.",
		spawnOffset = Vector3.new(2000, 0, 0),
		buildings = {
			{ name = "ArchiveRuins", position = Vector3.new(0, 0, -30), dimensions = Vector3.new(40, 12, 30), lootTable = "ResidentialCabinet" },
			{ name = "CollapsedBank", position = Vector3.new(-60, 0, 20), dimensions = Vector3.new(36, 14, 28), lootTable = "GasStationCache" },
			{ name = "SubwayEntrance", position = Vector3.new(50, 0, 50), dimensions = Vector3.new(20, 6, 16), lootTable = "HiddenCache" },
			{ name = "TenementRow", position = Vector3.new(-20, 0, -80), dimensions = Vector3.new(60, 16, 20), lootTable = "ResidentialCabinet" },
		},
		enemySpawns = {
			{ enemyId = "Scavenger", position = Vector3.new(20, 0, 20) },
			{ enemyId = "Scavenger", position = Vector3.new(-40, 0, -60) },
			{ enemyId = "FeralDog", position = Vector3.new(60, 0, -20) },
		},
		entryGate = { name = "GateToGreywood", position = Vector3.new(0, 0, 80) },
		gatesTo = "GreywoodCounty",
	},
	Ironworks = {
		id = "Ironworks",
		displayName = "Ironworks",
		description = "A scrapyard empire of furnaces and toll roads. The Iron Pact counts every bolt twice.",
		spawnOffset = Vector3.new(-2000, 0, 0),
		buildings = {
			{ name = "PactHall", position = Vector3.new(0, 0, 0), dimensions = Vector3.new(48, 12, 36), lootTable = "IndustrialCrate" },
			{ name = "FurnaceStack", position = Vector3.new(60, 0, 30), dimensions = Vector3.new(20, 30, 20), lootTable = "IndustrialCrate" },
			{ name = "TollShed", position = Vector3.new(-50, 0, -40), dimensions = Vector3.new(16, 8, 14), lootTable = "RareMedicalLocker" },
			{ name = "ScrapyardWall", position = Vector3.new(0, 0, -90), dimensions = Vector3.new(120, 10, 2), lootTable = nil },
		},
		enemySpawns = {
			{ enemyId = "Raider", position = Vector3.new(30, 0, 40) },
			{ enemyId = "Raider", position = Vector3.new(-30, 0, -20) },
			{ enemyId = "Scavenger", position = Vector3.new(70, 0, -60) },
		},
		entryGate = { name = "GateToAshford", position = Vector3.new(0, 0, 100) },
		gatesTo = "AshfordCity",
	},
	Frostline = {
		id = "Frostline",
		displayName = "Frostline",
		description = "A frozen pass where the wind files teeth. The Dawn Caravan's fires are the only warmth.",
		spawnOffset = Vector3.new(0, 0, 2000),
		buildings = {
			{ name = "CaravanFire", position = Vector3.new(0, 0, 0), dimensions = Vector3.new(24, 8, 20), lootTable = "GasStationCache" },
			{ name = "FrozenStation", position = Vector3.new(-70, 0, 40), dimensions = Vector3.new(30, 10, 24), lootTable = "RareMedicalLocker" },
			{ name = "WindbreakShelter", position = Vector3.new(60, 0, -50), dimensions = Vector3.new(18, 6, 14), lootTable = "HiddenCache" },
		},
		enemySpawns = {
			{ enemyId = "FeralDog", position = Vector3.new(20, 0, 60) },
			{ enemyId = "FeralDog", position = Vector3.new(-40, 0, -70) },
		},
		entryGate = { name = "GateToIronworks", position = Vector3.new(0, 0, 90) },
		gatesTo = "Ironworks",
	},
	ExclusionZone = {
		id = "ExclusionZone",
		displayName = "The Exclusion Zone",
		description = "Fenced, irradiated, and officially empty. The Meridian facility breathes under the concrete.",
		spawnOffset = Vector3.new(0, 0, -2000),
		buildings = {
			{ name = "PerimeterPost", position = Vector3.new(0, 0, 40), dimensions = Vector3.new(16, 8, 14), lootTable = "RareMedicalLocker" },
			{ name = "ConcreteCap", position = Vector3.new(0, 0, -40), dimensions = Vector3.new(50, 4, 50), lootTable = "HiddenCache" },
			{ name = "MeridianEntrance", position = Vector3.new(0, 0, -80), dimensions = Vector3.new(24, 10, 18), lootTable = "HiddenCache" },
		},
		enemySpawns = {
			{ enemyId = "Raider", position = Vector3.new(30, 0, 0) },
			{ enemyId = "Raider", position = Vector3.new(-30, 0, 10) },
		},
		entryGate = { name = "GateToFrostline", position = Vector3.new(0, 0, 80) },
		gatesTo = "Frostline",
	},
}

local RegionDefinitions = {}

function RegionDefinitions.Get(id: string): RegionConfig?
	return regions[id]
end

function RegionDefinitions.All(): {[string]: RegionConfig}
	return regions
end

return table.freeze(RegionDefinitions)
