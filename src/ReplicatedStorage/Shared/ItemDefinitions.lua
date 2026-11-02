--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized item definitions. Every item in the game is registered here with
-- stable ids; no other script may invent item properties.

export type ItemEffect = {
	hunger: number?,
	thirst: number?,
	health: number?,
	cureBleeding: boolean?,
	infectionCure: boolean?,
}

export type EquipmentStats = {
	damage: number?,
	armor: number?,
	coldProtection: number?,
	radiationProtection: number?,
	toolLevel: number?,
	ranged: boolean?,
	fireRateSeconds: number?,
	rangeStuds: number?,
	ammoId: string?,
}

export type ItemDefinition = {
	id: string,
	name: string,
	description: string,
	category: string, -- Food, Water, Medical, Tool, CraftingMaterial, Weapon, Ammo, Armor, Clothing, Collectible
	stackLimit: number,
	weight: number,
	rarity: string,
	durability: number?, -- max durability if the item is a tool, weapon, or gear
	effect: ItemEffect?,
	equipment: EquipmentStats?,
}

local items: {[string]: ItemDefinition} = {
	-- Food
	CannedBeans = { id = "CannedBeans", name = "Canned Beans", description = "Sealed before the Blackout. Still edible.", category = "Food", stackLimit = 10, weight = 0.6, rarity = "Common", effect = { hunger = 25 } },
	PreservedRation = { id = "PreservedRation", name = "Preserved Ration", description = "Dense military ration block. Bland but reliable.", category = "Food", stackLimit = 10, weight = 0.4, rarity = "Uncommon", effect = { hunger = 40 } },
	ForagedBerries = { id = "ForagedBerries", name = "Foraged Berries", description = "Wild berries picked near Greywood. Probably safe.", category = "Food", stackLimit = 20, weight = 0.1, rarity = "Common", effect = { hunger = 10, thirst = 5 } },
	TrailSnack = { id = "TrailSnack", name = "Trail Snack", description = "Crushed crackers and dried fruit.", category = "Food", stackLimit = 15, weight = 0.2, rarity = "Common", effect = { hunger = 15 } },
	RawMeat = { id = "RawMeat", name = "Raw Meat", description = "Fresh from a feral dog. Cook it before eating... if you can.", category = "Food", stackLimit = 10, weight = 0.5, rarity = "Common", effect = { hunger = 12, health = -4 } },

	-- Water
	WaterBottleClean = { id = "WaterBottleClean", name = "Sealed Water Bottle", description = "Factory-sealed water. Increasingly rare.", category = "Water", stackLimit = 10, weight = 0.7, rarity = "Uncommon", effect = { thirst = 35 } },
	WaterFlaskMurky = { id = "WaterFlaskMurky", name = "Murky Water Flask", description = "Boil it first... if you had a fire.", category = "Water", stackLimit = 10, weight = 0.6, rarity = "Common", effect = { thirst = 25, health = -5 } },
	RainwaterJar = { id = "RainwaterJar", name = "Rainwater Jar", description = "Collected during the last storm.", category = "Water", stackLimit = 10, weight = 0.8, rarity = "Common", effect = { thirst = 20 } },

	-- Medical
	Bandage = { id = "Bandage", name = "Bandage", description = "Stops bleeding and patches minor wounds.", category = "Medical", stackLimit = 15, weight = 0.1, rarity = "Common", effect = { health = 5, cureBleeding = true } },
	FirstAidKit = { id = "FirstAidKit", name = "First Aid Kit", description = "A proper medical kit from a hospital.", category = "Medical", stackLimit = 5, weight = 1.2, rarity = "Rare", effect = { health = 40, cureBleeding = true } },
	Antibiotics = { id = "Antibiotics", name = "Antibiotics", description = "Fights off infection from bad water.", category = "Medical", stackLimit = 10, weight = 0.1, rarity = "Rare", effect = { health = 10, infectionCure = true } },
	Painkillers = { id = "Painkillers", name = "Painkillers", description = "Blunts the pain, restores a little function.", category = "Medical", stackLimit = 10, weight = 0.1, rarity = "Common", effect = { health = 8 } },

	-- Crafting materials
	Wood = { id = "Wood", name = "Wood", description = "Salvaged timber and branches.", category = "CraftingMaterial", stackLimit = 50, weight = 0.2, rarity = "Common" },
	ScrapMetal = { id = "ScrapMetal", name = "Scrap Metal", description = "Torn from cars, fences, and machines.", category = "CraftingMaterial", stackLimit = 50, weight = 0.4, rarity = "Common" },
	Cloth = { id = "Cloth", name = "Cloth", description = "Torn fabric and old clothing.", category = "CraftingMaterial", stackLimit = 50, weight = 0.15, rarity = "Common" },
	Chemicals = { id = "Chemicals", name = "Chemical Bottle", description = "Unlabeled. Handle with gloves.", category = "CraftingMaterial", stackLimit = 20, weight = 0.3, rarity = "Uncommon" },
	Electronics = { id = "Electronics", name = "Electronic Parts", description = "Wires, boards, and dead batteries.", category = "CraftingMaterial", stackLimit = 30, weight = 0.1, rarity = "Uncommon" },
	PlasticScrap = { id = "PlasticScrap", name = "Plastic Scrap", description = "Moldable debris from packaging.", category = "CraftingMaterial", stackLimit = 50, weight = 0.1, rarity = "Common" },
	Rope = { id = "Rope", name = "Rope", description = "Fiber rope, still strong.", category = "CraftingMaterial", stackLimit = 20, weight = 0.3, rarity = "Common" },
	Nails = { id = "Nails", name = "Nails", description = "A fistful of rusty nails.", category = "CraftingMaterial", stackLimit = 100, weight = 0.05, rarity = "Common" },

	-- Tools and weapons
	Crowbar = { id = "Crowbar", name = "Crowbar", description = "Opens doors, crates, and arguments.", category = "Tool", stackLimit = 3, weight = 2.0, rarity = "Uncommon", durability = 100, equipment = { toolLevel = 2 } },
	Flashlight = { id = "Flashlight", name = "Flashlight", description = "Half a charge left. Better than nothing.", category = "Tool", stackLimit = 2, weight = 0.5, rarity = "Common" },
	Torch = { id = "Torch", name = "Torch", description = "Wrapped rag on a stick. Keeps the dark honest.", category = "Tool", stackLimit = 5, weight = 0.4, rarity = "Common", durability = 40 },
	SalvagedKnife = { id = "SalvagedKnife", name = "Salvaged Knife", description = "Ground-down steel with a wrapped grip. It cuts.", category = "Weapon", stackLimit = 3, weight = 0.6, rarity = "Common", durability = 60, equipment = { damage = 12 } },
	RebarClub = { id = "RebarClub", name = "Rebar Club", description = "A length of rebar with a cloth grip. Heavy, honest, final.", category = "Weapon", stackLimit = 1, weight = 2.5, rarity = "Uncommon", durability = 70, equipment = { damage = 18 } },
	ScrapPistol = { id = "ScrapPistol", name = "Scrap Pistol", description = "A workshop-built single-shot pistol. Loud, crude, effective.", category = "Weapon", stackLimit = 1, weight = 1.2, rarity = "Rare", durability = 90, equipment = { damage = 14, ranged = true, fireRateSeconds = 1.2, rangeStuds = 90, ammoId = "PistolRounds" } },

	-- Ammunition
	PistolRounds = { id = "PistolRounds", name = "Pistol Rounds", description = "Hand-loaded rounds in a worn pouch.", category = "Ammo", stackLimit = 60, weight = 0.03, rarity = "Common" },

	-- Clothing and armor
	RaggedCoat = { id = "RaggedCoat", name = "Ragged Coat", description = "Layered rags. Ugly, but the wind slows down.", category = "Clothing", stackLimit = 1, weight = 1.5, rarity = "Common", durability = 50, equipment = { coldProtection = 0.25 } },
	ScrapVest = { id = "ScrapVest", name = "Scrap Vest", description = "Plates of scrap bolted to a vest frame.", category = "Armor", stackLimit = 1, weight = 4.0, rarity = "Uncommon", durability = 80, equipment = { armor = 10 } },

	-- Collectibles
	BlackoutRecording = { id = "BlackoutRecording", name = "Recovered Recording", description = "A data chip holding a voice from the day of the Blackout.", category = "Collectible", stackLimit = 5, weight = 0.05, rarity = "Rare" },
	SurvivorPhoto = { id = "SurvivorPhoto", name = "Survivor Photograph", description = "A family, before.", category = "Collectible", stackLimit = 10, weight = 0.02, rarity = "Common" },
}

local ItemDefinitions = {}

function ItemDefinitions.Get(id: string): ItemDefinition?
	return items[id]
end

function ItemDefinitions.All(): {[string]: ItemDefinition}
	return items
end

return table.freeze(ItemDefinitions)
