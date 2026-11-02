--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized quest definitions. QuestService validates against this table
-- only; no other script may define quest data.

export type QuestObjective = {
	id: string,
	type: string, -- "CollectItem" or "TalkTo"
	description: string,
	itemId: string?,
	count: number?,
	consume: boolean?,
	npcId: string?,
}

export type QuestReward = {
	experience: number,
	currency: number,
	items: {{ id: string, count: number }},
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
	Q_FreshWater = {
		id = "Q_FreshWater",
		title = "Clear Water",
		description = "Mara needs sealed drinking water for the settlement's reserves. Find two untouched bottles.",
		giverNpcId = "MaraVoss",
		turnInNpcId = "MaraVoss",
		prerequisites = {},
		objectives = {
			{
				id = "obj_water",
				type = "CollectItem",
				description = "Collect 2 sealed water bottles",
				itemId = "WaterBottleClean",
				count = 2,
				consume = true,
			},
		},
		rewards = {
			experience = 30,
			currency = 10,
			items = { { id = "Bandage", count = 2 } },
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
			{
				id = "obj_scrap",
				type = "CollectItem",
				description = "Collect 5 scrap metal",
				itemId = "ScrapMetal",
				count = 5,
				consume = true,
			},
		},
		rewards = {
			experience = 50,
			currency = 25,
			items = { { id = "Nails", count = 10 } },
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
			{
				id = "obj_talk_mara",
				type = "TalkTo",
				description = "Speak with Mara Voss about the medical supplies",
				npcId = "MaraVoss",
			},
		},
		rewards = {
			experience = 25,
			currency = 0,
			items = { { id = "Painkillers", count = 2 } },
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
