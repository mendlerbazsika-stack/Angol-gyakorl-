# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong. Survivors scrape by in settlements and fortified zones while the truth waits underground.

**Status: Stage 3 of 10. This is not a playable game yet, and nothing here has been tested in Roblox Studio.**

## Progress

| Stage | Scope | Status |
|---|---|---|
| 1 | Core framework, player initialization, persistence | Scripts provided, untested in Studio |
| 2 | Survival, inventory, items, loot, consumables | Scripts provided, untested in Studio |
| 3 | Crafting, equipment, gathering | Scripts provided, untested in Studio |
| 4 | World regions, environment, exploration | Not started |
| 5 | NPCs, dialogue, quest framework | Not started |
| 6 | Combat, weapons, enemies, AI | Not started |
| 7 | Parties, trading, shared objectives | Not started |
| 8 | Building, settlements, vehicles | Not started |
| 9 | Campaign, factions, endgame | Not started |
| 10 | UI polish, audio, optimization, release testing | Not started |

## Installing the scripts in Roblox Studio

1. Open Roblox Studio and create a new Baseplate experience.
2. Enable `Game Settings → Security → Enable Studio Access to API Services` on a **published private test experience** so DataStores can be tested.
3. Create a `Shared` folder inside `ReplicatedStorage`, and add these ModuleScripts:
   - `ReplicatedStorage/Shared/GameConfig` ← `src/ReplicatedStorage/Shared/GameConfig.lua`
   - `ReplicatedStorage/Shared/DataSchema` ← `src/ReplicatedStorage/Shared/DataSchema.lua`
   - `ReplicatedStorage/Shared/ItemDefinitions` ← `src/ReplicatedStorage/Shared/ItemDefinitions.lua`
   - `ReplicatedStorage/Shared/SurvivalConfig` ← `src/ReplicatedStorage/Shared/SurvivalConfig.lua`
   - `ReplicatedStorage/Shared/RecipeDefinitions` ← `src/ReplicatedStorage/Shared/RecipeDefinitions.lua`
4. Create a `Services` folder inside `ServerScriptService`, and add these ModuleScripts:
   - `ServerScriptService/Services/PlayerDataService` ← `src/ServerScriptService/Services/PlayerDataService.lua`
   - `ServerScriptService/Services/SurvivalService` ← `src/ServerScriptService/Services/SurvivalService.lua`
   - `ServerScriptService/Services/InventoryService` ← `src/ServerScriptService/Services/InventoryService.lua`
   - `ServerScriptService/Services/LootService` ← `src/ServerScriptService/Services/LootService.lua`
   - `ServerScriptService/Services/EquipmentService` ← `src/ServerScriptService/Services/EquipmentService.lua`
   - `ServerScriptService/Services/GatheringService` ← `src/ServerScriptService/Services/GatheringService.lua`
   - `ServerScriptService/Services/CraftingService` ← `src/ServerScriptService/Services/CraftingService.lua`
5. Add this Script directly under `ServerScriptService`:
   - `ServerScriptService/ServerBootstrap` ← `src/ServerScriptService/ServerBootstrap.lua`
6. All service modules and shared modules are **ModuleScripts**; only `ServerBootstrap` is a **Script**. Paste each repository file into its matching Studio object.
7. Create a folder named `LootContainers` inside `Workspace` for lootable parts (see Stage 2 README history in commit log). Resource nodes and crafting stations are tagged via `CollectionService`:
   - Resource node: call `GatheringService.RegisterNode(part, "Tree")` — valid types: `Tree`, `ScrapPile`, `BerryBush`, `ClothPile`, `RuinCar`.
   - Crafting station: `CollectionService:AddTag(part, "CraftingStation")` and `part:SetAttribute("StationType", "Workbench")` — valid types: `Workbench`, `MedicStation`.

## What Stage 3 implements

- **Crafting:** 9 recipes (bandage, rope, torch, nails, purified water, salvaged knife, ragged coat, scrap vest, first aid kit) with station, level, and unlock requirements; atomic ingredient consumption; timed crafts with cancel/refund; output refused and refunded when inventory is full — no duplication paths.
- **Equipment:** Body / MainHand / OffHand slots, category validation, durability wear on use, break-on-zero with client notification, repair using ScrapMetal, and tool-level lookups feeding the gathering system.
- **Gathering:** 5 resource node types tagged via CollectionService, distance-validated harvests, tool-level requirements, per-player per-node cooldowns, timed harvests, and small experience grants.
- **Items:** new Torch, SalvagedKnife, RaggedCoat, ScrapVest items; durability and equipment stats now defined centrally for tools, weapons, armor, and clothing.
- **Persistence:** equipment, durability, and crafted-recipe unlocks persist in the normalized schema.

## Stage 3 test checklist

Complete these in Studio before moving to Stage 4. Stages 1–2 checks must also pass.

- [ ] Server prints `AFTERZERO Stage 3 server services initialized.`
- [ ] Tag a part as a Tree node and harvest it: wood is granted, harvest takes ~2.5 seconds, second harvest within 45 seconds is rejected with `NodeOnCooldown`.
- [ ] Harvest a RuinCar node with empty hands: rejected with `ToolRequired`; equip a Crowbar (tool level 2) and harvest succeeds.
- [ ] Craft a Bandage from 2 Cloth: cloth is consumed, bandage appears after 3 seconds; craft output is refused and refunded when inventory is deliberately full.
- [ ] Attempt a Workbench recipe at hand distance from a station: rejected with `WrongStation`; stand at a tagged Workbench and it succeeds.
- [ ] Cancel a timed craft: ingredients are refunded exactly once.
- [ ] Start two crafts simultaneously: second is rejected with `AlreadyCrafting`.
- [ ] Equip SalvagedKnife to MainHand: inventory loses one knife, equipment slot shows it; unequip returns it.
- [ ] Apply durability wear repeatedly: item breaks at zero and an `ItemBroke` event fires to the client.
- [ ] Repair a worn item with one ScrapMetal: durability restores to max.
- [ ] Save, leave, rejoin: equipment slots, durability values, and crafted-recipe unlocks persist exactly.
- [ ] Level gate: on a fresh level-1 profile, ScrapVest crafting is rejected with `LevelTooLow`.

## Architecture notes

- All player data mutations happen on the server; clients never write profiles directly.
- `PlayerDataService.GetData(player)` returns the live profile table for server systems.
- Data is normalized against `DataSchema` before every save and load, with a session lease preventing concurrent servers from overwriting the same profile.
- Crafting, gathering, and equipment all mutate the same live profile through `InventoryService`, so saves are always consistent across systems.
- Station and node instances sent by clients are re-validated server-side (tag check, distance check, attribute check) before use.
- Known limitation: no client UI yet; remote event payloads are final-shaped for the Stage 10 UI. Interaction prompts arrive with the Stage 4 world scripts.
- Known limitation: gathering does not yet consume stamina or apply durability wear; those hooks land with Stage 6 combat integration to avoid double-wiring.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
