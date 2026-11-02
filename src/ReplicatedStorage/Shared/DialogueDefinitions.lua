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
	actionKind: string?, -- "AcceptQuest" | "TurnInQuest" | "EndgameDecision" | "End"
	questId: string?,
	decisionId: string?,
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
				text = "This patches the fence and the water rig both. You're becoming useful, wanderer.",
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
		title = "Information Broker — Order of the Lamp",
		defaultNode = "greet",
		entries = {
			-- Campaign chain: each quest gates the next offer.
			{ condition = { completed = "Q_SupplyRun", notStarted = "Q_RecordingDrop" }, node = "offer_recording" },
			{ condition = { active = "Q_RecordingDrop" }, node = "recording_progress" },
			{ condition = { completed = "Q_RecordingDrop", notStarted = "Q_AshfordManifest" }, node = "offer_ashford" },
			{ condition = { active = "Q_AshfordManifest" }, node = "ashford_progress" },
			{ condition = { completed = "Q_AshfordManifest", notStarted = "Q_IronToll" }, node = "offer_toll" },
			{ condition = { active = "Q_IronToll" }, node = "toll_progress" },
			{ condition = { completed = "Q_IronToll", notStarted = "Q_CaravanCrossing" }, node = "offer_caravan" },
			{ condition = { active = "Q_CaravanCrossing" }, node = "caravan_progress" },
			{ condition = { completed = "Q_CaravanCrossing", notStarted = "Q_FacilityMap" }, node = "offer_map" },
			{ condition = { active = "Q_FacilityMap" }, node = "map_progress" },
			{ condition = { completed = "Q_FacilityMap", notStarted = "Q_ZoneEntry" }, node = "offer_zone" },
			{ condition = { active = "Q_ZoneEntry" }, node = "zone_progress" },
			{ condition = { completed = "Q_ZoneEntry", notStarted = "Q_MeridianCore" }, node = "offer_meridian" },
			{ condition = { active = "Q_MeridianCore" }, node = "meridian_progress" },
		},
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
			offer_recording = {
				text = "You've made the settlement's list, and mine. I run messages for the Order of the Lamp. Bring me one recovered recording — a data chip from the caches — and I'll put your name in our ledger as someone who listens.",
				options = {
					{ text = "I'll bring a recording.", next = "recording_accepted", actionKind = "AcceptQuest", questId = "Q_RecordingDrop" },
					{ text = "Not interested.", actionKind = "End" },
				},
			},
			recording_accepted = {
				text = "The old houses and hidden caches keep them. Chips with voices from the day itself. Handle them gently — those voices are the only witnesses left.",
				options = {
					{ text = "Understood.", actionKind = "End" },
				},
			},
			recording_progress = {
				text = "You have the chip? The Order doesn't loan trust twice.",
				options = {
					{ text = "Here it is.", next = "recording_done", actionKind = "TurnInQuest", questId = "Q_RecordingDrop" },
					{ text = "Still looking.", actionKind = "End" },
				},
			},
			recording_done = {
				text = "Intact. The voice on it says 'we pulled the switch ourselves.' The Order will want the rest of this story — and the road to Ashford is yours now.",
				options = {
					{ text = "Ashford City. What's there?", actionKind = "End" },
				},
			},
			offer_ashford = {
				text = "The city's archive kept Meridian's shipping manifest. It's under rubble and scavenger nests now. Find the manifest and clear three of the scavengers who roost in the stacks.",
				options = {
					{ text = "I'll search the archive.", next = "ashford_accepted", actionKind = "AcceptQuest", questId = "Q_AshfordManifest" },
					{ text = "Another time.", actionKind = "End" },
				},
			},
			ashford_accepted = {
				text = "Take the east road through the gate. The city doesn't forgive carelessness — go fed, armed, and dry.",
				options = {
					{ text = "Understood.", actionKind = "End" },
				},
			},
			ashford_progress = {
				text = "Manifest first, bodies second — or the other way, if that's how you count.",
				options = {
					{ text = "Both are done.", next = "ashford_done", actionKind = "TurnInQuest", questId = "Q_AshfordManifest" },
					{ text = "Working on it.", actionKind = "End" },
				},
			},
			ashford_done = {
				text = "The manifest names a facility nobody admits existed — shipped to the Ironworks district, signed six months before the storm supposedly hit. The Pact knows where it went. Ironworks is open to you.",
				options = {
					{ text = "Then I'll pay their toll.", actionKind = "End" },
				},
			},
			offer_toll = {
				text = "The Iron Pact charges two things: six scrap, and one dead raider who's been skipping their own toll booth. Pay both and they'll open the Frostline pass.",
				options = {
					{ text = "Consider it paid.", next = "toll_accepted", actionKind = "AcceptQuest", questId = "Q_IronToll" },
					{ text = "I don't kill on request.", actionKind = "End" },
				},
			},
			toll_accepted = {
				text = "You kill on survival, same as everyone out here. The raider's name is in nobody's ledger — that's the point.",
				options = {
					{ text = "Fine.", actionKind = "End" },
				},
			},
			toll_progress = {
				text = "The Pact doesn't repeat offers. Scrap and the raider.",
				options = {
					{ text = "Paid in full.", next = "toll_done", actionKind = "TurnInQuest", questId = "Q_IronToll" },
					{ text = "Soon.", actionKind = "End" },
				},
			},
			toll_done = {
				text = "The ledger's balanced. The Frostline pass is yours — the Caravan keeps fires along it. Listen at their fires; the old ones talk when the wind is loud enough to hide them.",
				options = {
					{ text = "I'll cross.", actionKind = "End" },
				},
			},
			offer_caravan = {
				text = "Cross the pass with the Dawn Caravan. Two feral packs run the ridge — clear them and the Caravan will speak freely about what they saw the night of the Blackout.",
				options = {
					{ text = "I'll clear the ridge.", next = "caravan_accepted", actionKind = "AcceptQuest", questId = "Q_CaravanCrossing" },
					{ text = "Later.", actionKind = "End" },
				},
			},
			caravan_accepted = {
				text = "The dogs are fast but stupid. You're slow and clever. Use that.",
				options = {
					{ text = "On it.", actionKind = "End" },
				},
			},
			caravan_progress = {
				text = "Dogs first, fires after. That's the order of the pass.",
				options = {
					{ text = "The ridge is clear.", next = "caravan_done", actionKind = "TurnInQuest", questId = "Q_CaravanCrossing" },
					{ text = "Still hunting.", actionKind = "End" },
				},
			},
			caravan_done = {
				text = "An old caravaner told me what she saw: the lights went out in a pattern. Grid by grid, exactly forty seconds apart, like someone walking down a list. Storms don't read lists, friend.",
				options = {
					{ text = "Someone walked the country switching it off.", actionKind = "End" },
				},
			},
			offer_map = {
				text = "The Caravan will trade their facility map for supplies: four cloth, two sealed water. They winter hard. Pay it, and the Zone's geometry is yours to read.",
				options = {
					{ text = "I'll gather the supplies.", next = "map_accepted", actionKind = "AcceptQuest", questId = "Q_FacilityMap" },
					{ text = "Too rich for me.", actionKind = "End" },
				},
			},
			map_accepted = {
				text = "Cloth and water keep children alive through a Frostline winter. It's a fair price for a map to a place that officially doesn't exist.",
				options = {
					{ text = "Fair enough.", actionKind = "End" },
				},
			},
			map_progress = {
				text = "Cloth and water, then the map. The Caravan doesn't extend credit.",
				options = {
					{ text = "Here — cloth and water.", next = "map_done", actionKind = "TurnInQuest", questId = "Q_FacilityMap" },
					{ text = "Gathering.", actionKind = "End" },
				},
			},
			map_done = {
				text = "Look at the map's margin: the Meridian site was scheduled for decommission — six months AFTER the storm they blamed. You can't decommission what never existed. The Zone is open to you now.",
				options = {
					{ text = "Then I'm going in.", actionKind = "End" },
				},
			},
			offer_zone = {
				text = "Two raiders deserted the Pact and squat the Zone's perimeter, charging their own toll to a fence nobody owns. Clear them, and the entrance is yours to read.",
				options = {
					{ text = "I'll clear the perimeter.", next = "zone_accepted", actionKind = "AcceptQuest", questId = "Q_ZoneEntry" },
					{ text = "Not yet.", actionKind = "End" },
				},
			},
			zone_accepted = {
				text = "The Zone reads hot on the detectors. Keep your exposure short and your water sealed.",
				options = {
					{ text = "Understood.", actionKind = "End" },
				},
			},
			zone_progress = {
				text = "Perimeter first. The core keeps.",
				options = {
					{ text = "Perimeter's clear.", next = "zone_done", actionKind = "TurnInQuest", questId = "Q_ZoneEntry" },
					{ text = "Working on it.", actionKind = "End" },
				},
			},
			zone_done = {
				text = "The final log is in the entrance cache. Bring it, and you'll know what we've all been guessing at.",
				options = {
					{ text = "Getting it now.", actionKind = "End" },
				},
			},
			offer_meridian = {
				text = "The last log sits in the entrance cache by the concrete cap. Bring it back and stop pretending any of us ever had a choice about knowing.",
				options = {
					{ text = "I'll bring the log.", next = "meridian_accepted", actionKind = "AcceptQuest", questId = "Q_MeridianCore" },
					{ text = "I need to prepare.", actionKind = "End" },
				},
			},
			meridian_accepted = {
				text = "Meridian was built to move energy like water — anywhere, instantly. The night of the Blackout they aimed it at the whole grid at once. It worked. That's the horror of it.",
				options = {
					{ text = "It worked.", actionKind = "End" },
				},
			},
			meridian_progress = {
				text = "The log. Then the choice.",
				options = {
					{ text = "Here's the log.", next = "meridian_done", actionKind = "TurnInQuest", questId = "Q_MeridianCore" },
					{ text = "Still out there.", actionKind = "End" },
				},
			},
			meridian_done = {
				text = "The core is live — dormant, but live. It can be restarted, buried, or sealed and handed to the Order. Whatever civilization becomes next starts with what you decide. Choose carefully; the ledger only takes one entry.",
				options = {
					{ text = "Restart the core.", next = "endgame_restart", actionKind = "EndgameDecision", decisionId = "RestartTheCore" },
					{ text = "Bury the facility.", next = "endgame_bury", actionKind = "EndgameDecision", decisionId = "BuryTheFacility" },
					{ text = "Seal it for the Order.", next = "endgame_order", actionKind = "EndgameDecision", decisionId = "HandToTheOrder" },
				},
			},
			endgame_restart = {
				text = "Then the lights come back on your shoulders. Pray they stay kind to what they illuminate.",
				options = {
					{ text = "Done.", actionKind = "End" },
				},
			},
			endgame_bury = {
				text = "Bury it deep enough that curiosity needs a better reason than a shovel. The world rebuilds on wood and patience.",
				options = {
					{ text = "Done.", actionKind = "End" },
				},
			},
			endgame_order = {
				text = "The Order will keep it locked and keep it quiet. Whether that's mercy or cowardice is a question for the next century.",
				options = {
					{ text = "Done.", actionKind = "End" },
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
