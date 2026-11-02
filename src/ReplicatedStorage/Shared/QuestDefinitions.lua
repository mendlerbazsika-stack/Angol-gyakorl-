--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized quest definitions. QuestService validates against this table
-- only; no other script may define quest data.

export type QuestObjective = {
	id: string,
	type: string, -- "CollectItem", "TalkTo", or "KillEnemies"
	description: string,
	itemId: string?,
	count: number?,
	consume: boolean?,
	npcId: string?,
	enemyId: string?, -- for KillEnemies: which enemy counts
}

export type QuestReward = {
	experience: number,
	currency: number,
	items: {{ id: string, count: number }},
	factionReputation: {{ factionId: string, amount: number }},
}

export type Quest = {
	id: string,
	title: string,
	description: string,
	giverNpcId: string,
	turnInNpcId: string,
	prerequisites: {string},
	objectives: {QuestObjective},
	rewards: QuestReward,
	repeatable: boolean,
}

local quests: {[string]: Quest} = {
	-- Greywood starter quests (unchanged behavior, now with faction rewards)
	Q_FreshWater = {
		id = "Q_FreshWater",
		title = "Clear Water",
		description = "Mara needs sealed drinking water for the settlement's reserves. Find two untouched bottles.",
		giverNpcId = "MaraVoss",
		turnInNpcId = "MaraVoss",
		prerequisites = {},
		objectives = {
			{ id = "obj_water", type = "CollectItem", description = "Collect 2 sealed water bottles", itemId = "WaterBottleClean", count = 2, consume = true },
		},
		rewards = {
			experience = 30, currency = 10,
			items = { { id = "Bandage", count = 2 } },
			factionReputation = { { factionId = "GreywoodSettlers", amount = 10 } },
		},
		repeatable = false,
	},
	Q_SupplyRun = {
		id = "Q_SupplyRun",
		title = "Scrap for the Settlement",
		description = "The settlement needs building material. Bring Mara five pieces of scrap metal from the eastern warehouse.",
		giverNpcId = "MaraVoss",
		turnInNpcId = "MaraVoss",
		prerequisites = { "Q_FreshWater" },
		objectives = {
			{ id = "obj_scrap", type = "CollectItem", description = "Collect 5 scrap metal", itemId = "ScrapMetal", count = 5, consume = true },
		},
		rewards = {
			experience = 50, currency = 25,
			items = { { id = "Nails", count = 10 } },
			factionReputation = { { factionId = "GreywoodSettlers", amount = 15 } },
		},
		repeatable = false,
	},
	Q_WardCheckup = {
		id = "Q_WardCheckup",
		title = "Ward's Request",
		description = "Elias needs painkillers for his patients. Talk Mara into releasing the settlement's medical crate.",
		giverNpcId = "EliasWard",
		turnInNpcId = "EliasWard",
		prerequisites = { "Q_FreshWater" },
		objectives = {
			{ id = "obj_talk_mara", type = "TalkTo", description = "Speak with Mara Voss about the medical supplies", npcId = "MaraVoss" },
		},
		rewards = {
			experience = 25, currency = 0,
			items = { { id = "Painkillers", count = 2 } },
			factionReputation = { { factionId = "GreywoodSettlers", amount = 8 } },
		},
		repeatable = false,
	},

	-- Campaign quests (one per chapter that requires a quest)
	Q_RecordingDrop = {
		id = "Q_RecordingDrop",
		title = "A Voice from the Blackout",
		description = "Rook wants the recovered recording delivered to the Order of the Lamp's courier — himself, as it turns out.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_SupplyRun" },
		objectives = {
			{ id = "obj_recording", type = "CollectItem", description = "Recover a Blackout recording and bring it to Rook", itemId = "BlackoutRecording", count = 1, consume = true },
		},
		rewards = {
			experience = 60, currency = 20,
			items = { { id = "Chemicals", count = 2 } },
			factionReputation = { { factionId = "OrderOfTheLamp", amount = 20 } },
		},
		repeatable = false,
	},
	Q_AshfordManifest = {
		id = "Q_AshfordManifest",
		title = "What Ashford Kept",
		description = "The Order's courier says the city archive kept a Meridian shipping manifest. Search the ruins and clear the scavengers watching them.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_RecordingDrop" },
		objectives = {
			{ id = "obj_hidden_cache", type = "CollectItem", description = "Search Ashford's ruins for the manifest", itemId = "BlackoutRecording", count = 1, consume = true },
			{ id = "obj_clear_scavengers", type = "KillEnemies", description = "Kill 3 scavengers in Ashford City", enemyId = "Scavenger", count = 3 },
		},
		rewards = {
			experience = 80, currency = 30,
			items = { { id = "FirstAidKit", count = 1 } },
			factionReputation = { { factionId = "OrderOfTheLamp", amount = 25 } },
		},
		repeatable = false,
	},
	Q_IronToll = {
		id = "Q_IronToll",
		title = "The Iron Toll",
		description = "The Pact wants six pieces of scrap and one dead raider who skipped the toll. Pay both.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_AshfordManifest" },
		objectives = {
			{ id = "obj_toll_scrap", type = "CollectItem", description = "Gather 6 scrap metal for the toll", itemId = "ScrapMetal", count = 6, consume = true },
			{ id = "obj_raider", type = "KillEnemies", description = "Kill 1 Iron Pact raider", enemyId = "Raider", count = 1 },
		},
		rewards = {
			experience = 90, currency = 40,
			items = { { id = "PistolRounds", count = 8 } },
			factionReputation = { { factionId = "IronPact", amount = 30 } },
		},
		repeatable = false,
	},
	Q_CaravanCrossing = {
		id = "Q_CaravanCrossing",
		title = "Caravan of Survivors",
		description = "Cross the Frostline and hear what the fire-side survivors saw the night the lights died.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_IronToll" },
		objectives = {
			{ id = "obj_frost_dogs", type = "KillEnemies", description = "Kill 2 feral dogs on the pass", enemyId = "FeralDog", count = 2 },
		},
		rewards = {
			experience = 100, currency = 30,
			items = { { id = "RaggedCoat", count = 1 } },
			factionReputation = { { factionId = "DawnCaravan", amount = 30 } },
		},
		repeatable = false,
	},
	Q_FacilityMap = {
		id = "Q_FacilityMap",
		title = "The Ledger",
		description = "The Caravan trades a facility map for supplies: four cloth, two sealed water, and proof the pass is safe.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_CaravanCrossing" },
		objectives = {
			{ id = "obj_cloth", type = "CollectItem", description = "Gather 4 cloth", itemId = "Cloth", count = 4, consume = true },
			{ id = "obj_water", type = "CollectItem", description = "Bring 2 sealed water bottles", itemId = "WaterBottleClean", count = 2, consume = true },
		},
		rewards = {
			experience = 110, currency = 35,
			items = { { id = "FirstAidKit", count = 1 } },
			factionReputation = { { factionId = "DawnCaravan", amount = 25 }, { factionId = "OrderOfTheLamp", amount = 10 } },
		},
		repeatable = false,
	},
	Q_ZoneEntry = {
		id = "Q_ZoneEntry",
		title = "Crossing the Line",
		description = "The Zone's perimeter is watched by Pact deserters. Clear two raiders and reach the Meridian entrance.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_FacilityMap" },
		objectives = {
			{ id = "obj_zone_raiders", type = "KillEnemies", description = "Kill 2 raiders at the perimeter", enemyId = "Raider", count = 2 },
		},
		rewards = {
			experience = 120, currency = 40,
			items = { { id = "ScrapVest", count = 1 } },
			factionReputation = { { factionId = "OrderOfTheLamp", amount = 20 } },
		},
		repeatable = false,
	},
	Q_MeridianCore = {
		id = "Q_MeridianCore",
		title = "Project Meridian",
		description = "Reach the core chamber. What you find there ends the argument about what the Blackout was.",
		giverNpcId = "Rook",
		turnInNpcId = "Rook",
		prerequisites = { "Q_ZoneEntry" },
		objectives = {
			{ id = "obj_recording_final", type = "CollectItem", description = "Recover the final Meridian log from the entrance cache", itemId = "BlackoutRecording", count = 1, consume = true },
		},
		rewards = {
			experience = 150, currency = 60,
			items = { { id = "PreservedRation", count = 2 } },
			factionReputation = { { factionId = "OrderOfTheLamp", amount = 40 } },
		},
		repeatable = false,
	},
}

local QuestDefinitions = {}

function QuestDefinitions.Get(id: string): Quest?
	return quests[id]
end

function QuestDefinitions.All(): {[string]: Quest}
	return quests
end

return table.freeze(QuestDefinitions)
