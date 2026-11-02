--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized NPC dialogue definitions. DialogueService resolves which node
-- a player sees using server-side quest state; clients never choose branches
-- the server did not offer.

export type DialogueCondition = {
	completed: string?,
	active: string?,
	notStarted: string?,
}

export type DialogueOption = {
	text: string,
	next: string?,
	actionKind: string?, -- "AcceptQuest" | "TurnInQuest" | "End"
	questId: string?,
}

export type DialogueNode = {
	text: string,
	options: {DialogueOption},
}

export type NpcDialogue = {
	name: string,
	title: string,
	entries: {{ condition: DialogueCondition, node: string }},
	defaultNode: string,
	nodes: {[string]: DialogueNode},
}

local npcs: {[string]: NpcDialogue} = {
	MaraVoss = {
		name = "Mara Voss",
		title = "Settlement Leader",
		defaultNode = "idle",
		entries = {
			{ condition = { notStarted = "Q_FreshWater" }, node = "offer_water" },
			{ condition = { active = "Q_FreshWater" }, node = "water_progress" },
			{ condition = { completed = "Q_FreshWater", notStarted = "Q_SupplyRun" }, node = "offer_supply" },
			{ condition = { active = "Q_SupplyRun" }, node = "supply_progress" },
		},
		nodes = {
			offer_water = {
				text = "You're the one from the gas station. We keep the pumps dry and the gate shut for a reason. If you want a place here, earn it. Our water reserve is nearly gone — sealed bottles, untouched. Bring me two.",
				options = {
					{ text = "I'll bring the water.", next = "water_accepted", actionKind = "AcceptQuest", questId = "Q_FreshWater" },
					{ text = "I'll think about it.", actionKind = "End" },
				},
			},
			water_accepted = {
				text = "Good. Check the station shelves and the old houses. And don't drink what you find open — that's how we lost Henrick for a week.",
				options = {
					{ text = "Understood.", actionKind = "End" },
				},
			},
			water_progress = {
				text = "Any luck with the water? Two sealed bottles, that's all I need.",
				options = {
					{ text = "Here are the bottles.", next = "water_done", actionKind = "TurnInQuest", questId = "Q_FreshWater" },
					{ text = "Still searching.", actionKind = "End" },
				},
			},
			water_done = {
				text = "Sealed tight. Good hands. Elias always needs bandages — take these, and welcome to Greywood.",
				options = {
					{ text = "Thank you.", actionKind = "End" },
				},
			},
			offer_supply = {
				text = "You proved you can walk a road. Now prove you can build one. The warehouse east of here is full of scrap the settlement needs. Bring me five pieces of scrap metal.",
				options = {
					{ text = "I'll get the scrap.", next = "supply_accepted", actionKind = "AcceptQuest", questId = "Q_SupplyRun" },
					{ text = "Another time.", actionKind = "End" },
				},
			},
			supply_accepted = {
				text = "Watch the yard. Scavengers marked it weeks ago, and they don't share.",
				options = {
					{ text = "Noted.", actionKind = "End" },
				},
			},
			supply_progress = {
				text = "Five pieces of scrap, that's the ask. The warehouse sits east, before the bridge road.",
				options = {
					{ text = "Here's the scrap.", next = "supply_done", actionKind = "TurnInQuest", questId = "Q_SupplyRun" },
					{ text = "On my way.", actionKind = "End" },
				},
			},
			supply_done = {
				text = "This patches the fence and the water rig both. You're becoming useful, wanderer. Keep it up and people here will start trusting you.",
				options = {
					{ text = "Glad to help.", actionKind = "End" },
				},
			},
			idle = {
				text = "Keep your head down and your pack light. The county takes both from people who forget.",
				options = {
					{ text = "Goodbye.", actionKind = "End" },
				},
			},
		},
	},
	EliasWard = {
		name = "Elias Ward",
		title = "Field Medic",
		defaultNode = "greet",
		entries = {
			{ condition = { completed = "Q_FreshWater", notStarted = "Q_WardCheckup" }, node = "offer_checkup" },
			{ condition = { active = "Q_WardCheckup" }, node = "checkup_progress" },
		},
		nodes = {
			greet = {
				text = "Elias Ward. I pulled people out of burning buildings before the Blackout. Now I pull splinters out of scavengers. Need something?",
				options = {
					{ text = "Just passing through.", actionKind = "End" },
				},
			},
			offer_checkup = {
				text = "Mara says you can move. Half the settlement is running low on painkillers, and she guards the last crate like it's gold. Talk to her — convince her to release medical supplies for my patients.",
				options = {
					{ text = "I'll speak with her.", next = "checkup_accepted", actionKind = "AcceptQuest", questId = "Q_WardCheckup" },
					{ text = "Not my problem.", actionKind = "End" },
				},
			},
			checkup_accepted = {
				text = "Careful with your words. She respects proof, not speeches.",
				options = {
					{ text = "Understood.", actionKind = "End" },
				},
			},
			checkup_progress = {
				text = "Did you speak to Mara about the medical supplies?",
				options = {
					{ text = "I did.", next = "checkup_done", actionKind = "TurnInQuest", questId = "Q_WardCheckup" },
					{ text = "Not yet.", actionKind = "End" },
				},
			},
			checkup_done = {
				text = "She released the crate. Stubborn, but her heart's in the right place. Take these painkillers — you'll need them more than my shelves will.",
				options = {
					{ text = "Thank you, Elias.", actionKind = "End" },
				},
			},
		},
	},
	Rook = {
		name = "Rook",
		title = "Information Broker",
		defaultNode = "greet",
		entries = {},
		nodes = {
			greet = {
				text = "Rook. I trade in what people whisper when the generators die. The solar storm story? Government comfort food. The lights didn't fail, friend — they were switched off.",
				options = {
					{ text = "Switched off? By whom?", next = "detail" },
					{ text = "I have to go.", actionKind = "End" },
				},
			},
			detail = {
				text = "Check the recordings people left behind. Half are static. The other half mention Project Meridian — dated before the Blackout, not after. Curious, that a solar storm already had a name in paperwork written months earlier.",
				options = {
					{ text = "I'll look into it.", actionKind = "End" },
				},
			},
		},
	},
}

local DialogueDefinitions = {}

function DialogueDefinitions.Get(npcId: string): NpcDialogue?
	return npcs[npcId]
end

function DialogueDefinitions.All(): {[string]: NpcDialogue}
	return npcs
end

return table.freeze(DialogueDefinitions)
