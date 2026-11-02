--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized faction definitions. FactionService validates against this
-- table only; no other script may define faction data.

export type Faction = {
	id: string,
	name: string,
	description: string,
	friendlyAbove: number, -- reputation at or above which the faction is friendly
	alliedAbove: number, -- reputation at or above which the faction is allied
	hostileBelow: number, -- reputation below which the faction is hostile
}

local factions: {[string]: Faction} = {
	GreywoodSettlers = {
		id = "GreywoodSettlers",
		name = "Greywood Settlers",
		description = "Survivors who rebuilt around the county's water pump. They trade shelter for honest work.",
		friendlyAbove = 25,
		alliedAbove = 75,
		hostileBelow = -25,
	},
	OrderOfTheLamp = {
		id = "OrderOfTheLamp",
		name = "Order of the Lamp",
		description = "A secretive group that claims to know why the lights went out. They keep records nobody else has.",
		friendlyAbove = 30,
		alliedAbove = 80,
		hostileBelow = -30,
	},
	IronPact = {
		id = "IronPact",
		name = "Iron Pact",
		description = "Scrap-hoarders and road toll collectors out of the Ironworks. Respected, never trusted.",
		friendlyAbove = 20,
		alliedAbove = 70,
		hostileBelow = -40,
	},
	DawnCaravan = {
		id = "DawnCaravan",
		name = "Dawn Caravan",
		description = "Nomad traders who cross the Frostline between regions. Their routes are the region's lifelines.",
		friendlyAbove = 25,
		alliedAbove = 75,
		hostileBelow = -25,
	},
}

-- Reward multipliers by tier, applied to trade and quest payouts.
-- Tier is computed by FactionService; these numbers are data only.
local FactionDefinitions = {}

function FactionDefinitions.Get(id: string): Faction?
	return factions[id]
end

function FactionDefinitions.All(): {[string]: Faction}
	return factions
end

-- Computes the standing tier for a faction at a given reputation.
-- Tiers: "Hostile", "Neutral", "Friendly", "Allied".
function FactionDefinitions.GetTier(factionId: string, reputation: number): string
	local faction = factions[factionId]
	if not faction then
		return "Neutral"
	end
	if reputation >= faction.alliedAbove then
		return "Allied"
	elseif reputation >= faction.friendlyAbove then
		return "Friendly"
	elseif reputation <= faction.hostileBelow then
		return "Hostile"
	end
	return "Neutral"
end

return table.freeze(FactionDefinitions)
