--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized enemy definitions. EnemyService validates against this table
-- only; no other script may define enemy stats or loot.

export type EnemyLootEntry = {
	id: string,
	weight: number,
	min: number,
	max: number,
}

export type EnemyConfig = {
	id: string,
	name: string,
	health: number,
	damage: number,
	walkSpeed: number,
	aggroRange: number,
	attackRange: number,
	attackCooldown: number,
	bleedChance: number,
	experience: number,
	loot: {EnemyLootEntry},
}

local enemies: {[string]: EnemyConfig} = {
	Scavenger = {
		id = "Scavenger",
		name = "Greywood Scavenger",
		health = 40,
		damage = 8,
		walkSpeed = 12,
		aggroRange = 26,
		attackRange = 4.5,
		attackCooldown = 1.6,
		bleedChance = 0.15,
		experience = 20,
		loot = {
			{ id = "Cloth", weight = 30, min = 1, max = 2 },
			{ id = "ScrapMetal", weight = 25, min = 1, max = 2 },
			{ id = "TrailSnack", weight = 15, min = 1, max = 1 },
			{ id = "Painkillers", weight = 10, min = 1, max = 1 },
			{ id = "PistolRounds", weight = 10, min = 2, max = 4 },
			{ id = "WaterFlaskMurky", weight = 10, min = 1, max = 1 },
		},
	},
	FeralDog = {
		id = "FeralDog",
		name = "Feral Dog",
		health = 25,
		damage = 6,
		walkSpeed = 17,
		aggroRange = 20,
		attackRange = 4,
		attackCooldown = 1.2,
		bleedChance = 0.25,
		experience = 12,
		loot = {
			{ id = "RawMeat", weight = 60, min = 1, max = 2 },
			{ id = "Cloth", weight = 25, min = 1, max = 1 },
			{ id = "ForagedBerries", weight = 15, min = 1, max = 2 },
		},
	},
	Raider = {
		-- Defined for later regions; not spawned in Greywood County.
		id = "Raider",
		name = "Iron Pact Raider",
		health = 60,
		damage = 12,
		walkSpeed = 13,
		aggroRange = 30,
		attackRange = 4.5,
		attackCooldown = 1.4,
		bleedChance = 0.2,
		experience = 35,
		loot = {
			{ id = "ScrapMetal", weight = 30, min = 1, max = 3 },
			{ id = "PistolRounds", weight = 25, min = 3, max = 6 },
			{ id = "Painkillers", weight = 15, min = 1, max = 2 },
			{ id = "FirstAidKit", weight = 8, min = 1, max = 1 },
			{ id = "PreservedRation", weight = 22, min = 1, max = 1 },
		},
	},
}

local EnemyDefinitions = {}

function EnemyDefinitions.Get(id: string): EnemyConfig?
	return enemies[id]
end

function EnemyDefinitions.All(): {[string]: EnemyConfig}
	return enemies
end

-- Weighted loot roll: 1-2 entries per kill. Called only by EnemyService.
function EnemyDefinitions.RollLoot(config: EnemyConfig): {any}
	local results = {}

	local totalWeight = 0
	for _, entry in ipairs(config.loot) do
		totalWeight += entry.weight
	end
	if totalWeight <= 0 then
		return results
	end

	local rolls = math.random(1, 2)
	for _ = 1, rolls do
		local roll = math.random() * totalWeight
		local chosen = config.loot[#config.loot]
		for _, entry in ipairs(config.loot) do
			roll -= entry.weight
			if roll <= 0 then
				chosen = entry
				break
			end
		end
		table.insert(results, { id = chosen.id, count = math.random(chosen.min, chosen.max) })
	end

	return results
end

return table.freeze(EnemyDefinitions)
