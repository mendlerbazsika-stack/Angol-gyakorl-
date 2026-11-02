--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Centralized crafting recipe definitions. Every recipe is registered here with
-- stable ids; CraftingService validates against this table only.

export type Ingredient = {
	id: string,
	count: number,
}

export type Recipe = {
	id: string,
	outputId: string,
	outputCount: number,
	ingredients: {Ingredient},
	station: string, -- "Hand", "Workbench", "MedicStation"
	craftSeconds: number,
	level: number,
	requiresUnlock: boolean, -- if true, recipe must be unlocked via progression
}

local recipes: {[string]: Recipe} = {
	Bandage = {
		id = "Bandage", outputId = "Bandage", outputCount = 1,
		ingredients = { { id = "Cloth", count = 2 } },
		station = "Hand", craftSeconds = 3, level = 1, requiresUnlock = false,
	},
	Rope = {
		id = "Rope", outputId = "Rope", outputCount = 1,
		ingredients = { { id = "Cloth", count = 3 } },
		station = "Hand", craftSeconds = 4, level = 1, requiresUnlock = false,
	},
	Torch = {
		id = "Torch", outputId = "Torch", outputCount = 1,
		ingredients = { { id = "Wood", count = 1 }, { id = "Cloth", count = 1 } },
		station = "Hand", craftSeconds = 2, level = 1, requiresUnlock = false,
	},
	Nails = {
		id = "Nails", outputId = "Nails", outputCount = 5,
		ingredients = { { id = "ScrapMetal", count = 1 } },
		station = "Workbench", craftSeconds = 3, level = 2, requiresUnlock = false,
	},
	PurifiedWater = {
		id = "PurifiedWater", outputId = "WaterBottleClean", outputCount = 1,
		ingredients = { { id = "RainwaterJar", count = 1 }, { id = "Chemicals", count = 1 } },
		station = "Workbench", craftSeconds = 6, level = 2, requiresUnlock = false,
	},
	SalvagedKnife = {
		id = "SalvagedKnife", outputId = "SalvagedKnife", outputCount = 1,
		ingredients = { { id = "ScrapMetal", count = 2 }, { id = "Wood", count = 1 } },
		station = "Workbench", craftSeconds = 5, level = 3, requiresUnlock = false,
	},
	RaggedCoat = {
		id = "RaggedCoat", outputId = "RaggedCoat", outputCount = 1,
		ingredients = { { id = "Cloth", count = 4 }, { id = "Rope", count = 1 } },
		station = "Workbench", craftSeconds = 10, level = 2, requiresUnlock = false,
	},
	ScrapVest = {
		id = "ScrapVest", outputId = "ScrapVest", outputCount = 1,
		ingredients = { { id = "ScrapMetal", count = 4 }, { id = "Cloth", count = 2 } },
		station = "Workbench", craftSeconds = 12, level = 5, requiresUnlock = false,
	},
	FirstAidKit = {
		id = "FirstAidKit", outputId = "FirstAidKit", outputCount = 1,
		ingredients = {
			{ id = "Bandage", count = 2 },
			{ id = "Cloth", count = 2 },
			{ id = "Chemicals", count = 1 },
		},
		station = "MedicStation", craftSeconds = 8, level = 4, requiresUnlock = false,
	},
}

local RecipeDefinitions = {}

function RecipeDefinitions.Get(id: string): Recipe?
	return recipes[id]
end

function RecipeDefinitions.All(): {[string]: Recipe}
	return recipes
end

return table.freeze(RecipeDefinitions)
