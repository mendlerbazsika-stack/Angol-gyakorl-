--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized campaign definitions: 10 chapters, rewards, region unlocks,
-- and the endgame decision allowlist. CampaignService validates against this
-- table only.

export type Chapter = {
	id: string,
	title: string,
	summary: string,
	requiredQuests: {string}, -- quest ids that must be completed
	requiredChapters: {string}, -- chapter ids that must be completed first
	unlocksRegion: string?, -- region id unlocked when this chapter completes
	endgameDecision: boolean, -- true only for the final chapter
}

local chapters: {[string]: Chapter} = {
	Chapter1_Echoes = {
		id = "Chapter1_Echoes",
		title = "Chapter 1: Echoes of the Blackout",
		summary = "Prove yourself to the Greywood settlement and hear the first whisper that the Blackout was no accident.",
		requiredQuests = { "Q_FreshWater" },
		requiredChapters = {},
		unlocksRegion = nil,
		endgameDecision = false,
	},
	Chapter2_SupplyLines = {
		id = "Chapter2_SupplyLines",
		title = "Chapter 2: Supply Lines",
		summary = "Secure scrap and medicine for the settlement. Rook hints that the Order of the Lamp knows more than it says.",
		requiredQuests = { "Q_SupplyRun", "Q_WardCheckup" },
		requiredChapters = { "Chapter1_Echoes" },
		unlocksRegion = nil,
		endgameDecision = false,
	},
	Chapter3_TheOrder = {
		id = "Chapter3_TheOrder",
		title = "Chapter 3: The Order of the Lamp",
		summary = "Deliver a recovered recording to the Order's courier at the gas station and earn their first trust.",
		requiredQuests = { "Q_RecordingDrop" },
		requiredChapters = { "Chapter2_SupplyLines" },
		unlocksRegion = "AshfordCity",
		endgameDecision = false,
	},
	Chapter4_Ashford = {
		id = "Chapter4_Ashford",
		title = "Chapter 4: What Ashford Kept",
		summary = "Search the dead city. Its collapsed archive holds the first Meridian shipping manifest.",
		requiredQuests = { "Q_AshfordManifest" },
		requiredChapters = { "Chapter3_TheOrder" },
		unlocksRegion = "Ironworks",
		endgameDecision = false,
	},
	Chapter5_Toll = {
		id = "Chapter5_Toll",
		title = "Chapter 5: The Iron Toll",
		summary = "Buy passage through the Ironworks with scrap and nerve. The Pact keeps a ledger of everyone who paid.",
		requiredQuests = { "Q_IronToll" },
		requiredChapters = { "Chapter4_Ashford" },
		unlocksRegion = "Frostline",
		endgameDecision = false,
	},
	Chapter6_Caravan = {
		id = "Chapter6_Caravan",
		title = "Chapter 6: Caravan of Survivors",
		summary = "Cross the Frostline with the Dawn Caravan. At their fire, a survivor who saw the Blackout speaks its true date.",
		requiredQuests = { "Q_CaravanCrossing" },
		requiredChapters = { "Chapter5_Toll" },
		unlocksRegion = nil,
		endgameDecision = false,
	},
	Chapter7_Records = {
		id = "Chapter7_Records",
		title = "Chapter 7: The Ledger",
		summary = "The Caravan trades a route map for a favor. The map marks a facility that was decommissioned — six months after it was supposedly destroyed.",
		requiredQuests = { "Q_FacilityMap" },
		requiredChapters = { "Chapter6_Caravan" },
		unlocksRegion = nil,
		endgameDecision = false,
	},
	Chapter8_Exclusion = {
		id = "Chapter8_Exclusion",
		title = "Chapter 8: The Exclusion Zone",
		summary = "Cross into the Zone. The radiation readings tell you the reactor story is a cover for something buried deeper.",
		requiredQuests = { "Q_ZoneEntry" },
		requiredChapters = { "Chapter7_Records" },
		unlocksRegion = "ExclusionZone",
		endgameDecision = false,
	},
	Chapter9_Meridian = {
		id = "Chapter9_Meridian",
		title = "Chapter 9: Project Meridian",
		summary = "Inside the Meridian facility, the truth: an experiment meant to redirect energy itself, switched off the world instead.",
		requiredQuests = { "Q_MeridianCore" },
		requiredChapters = { "Chapter8_Exclusion" },
		unlocksRegion = nil,
		endgameDecision = false,
	},
	Chapter10_LastLight = {
		id = "Chapter10_LastLight",
		title = "Chapter 10: The Last Light",
		summary = "The core can be restarted, buried, or handed over. Every answer shapes what civilization becomes next.",
		requiredQuests = {},
		requiredChapters = { "Chapter9_Meridian" },
		unlocksRegion = nil,
		endgameDecision = true,
	},
}

-- The only decisions the final chapter accepts. Anything else is rejected.
local EndgameDecisions = {
	RestartTheCore = "Restart the Meridian core and attempt to restore power for the settlements.",
	BuryTheFacility = "Bury the facility permanently and let the world rebuild without Meridian technology.",
	HandToTheOrder = "Seal the core and hand the keys to the Order of the Lamp.",
}

local CampaignDefinitions = {}

function CampaignDefinitions.GetChapter(id: string): Chapter?
	return chapters[id]
end

function CampaignDefinitions.AllChapters(): {[string]: Chapter}
	return chapters
end

function CampaignDefinitions.GetDecision(id: string): string?
	return EndgameDecisions[id]
end

function CampaignDefinitions.AllDecisions(): {[string]: string}
	return EndgameDecisions
end

return table.freeze(CampaignDefinitions)
