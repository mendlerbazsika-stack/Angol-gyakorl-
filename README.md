# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong. Survivors scrape by in settlements and fortified zones while the truth waits underground.

**Status: Stage 2 of 10. This is not a playable game yet, and nothing here has been tested in Roblox Studio.**

## Progress

| Stage | Scope | Status |
|---|---|---|
| 1 | Core framework, player initialization, persistence | Scripts provided, untested in Studio |
| 2 | Survival, inventory, items, loot, consumables | Scripts provided, untested in Studio |
| 3 | Crafting, equipment, gathering | Not started |
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
4. Create a `Services` folder inside `ServerScriptService`, and add these ModuleScripts:
   - `ServerScriptService/Services/PlayerDataService` ← `src/ServerScriptService/Services/PlayerDataService.lua`
   - `ServerScriptService/Services/SurvivalService` ← `src/ServerScriptService/Services/SurvivalService.lua`
   - `ServerScriptService/Services/InventoryService` ← `src/ServerScriptService/Services/InventoryService.lua`
   - `ServerScriptService/Services/LootService` ← `src/ServerScriptService/Services/LootService.lua`
5. Add this Script directly under `ServerScriptService`:
   - `ServerScriptService/ServerBootstrap` ← `src/ServerScriptService/ServerBootstrap.lua`
6. Open each `.lua` file in this repository and paste its contents into the matching Studio object. `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `GameConfig`, `DataSchema`, `ItemDefinitions`, and `SurvivalConfig` are **ModuleScripts**; `ServerBootstrap` is a **Script**.
7. Create a folder named `LootContainers` inside `Workspace`. Place Parts inside it and, via the command bar or a test script, call `LootService.RegisterContainer(part, "GasStationCache", "cache_gas_1")` to mark lootable parts. (A world-setup script arrives in Stage 4.)

## What Stage 2 implements

- **Survival:** health, hunger, thirst, stamina, body temperature, radiation, bleeding, and infection, all server-authoritative, persisted in the schema, ticking at a fixed rate. Deaths trigger a timed respawn with health restoration.
- **Items:** 25 items across food, water, medical, materials, tools, and collectibles, defined centrally in `ItemDefinitions` with stable ids, weights, stack limits, rarity, and consumption effects.
- **Inventory:** 24 slots / 60 weight capacity, stack filling, server-validated add/remove/consume, and snapshot broadcasts to the owning client over `InventoryRemote`.
- **Loot:** five weighted loot tables, distance-validated searching, per-player per-container cooldowns, and grant messages over `LootRemote`.
- **Persistence:** survival stats and inventory slots are normalized and saved with the profile.

## Stage 2 test checklist

Complete these in Studio before moving to Stage 3. Previous Stage 1 checks must also pass.

- [ ] Server prints `AFTERZERO Stage 2 server services initialized.`
- [ ] A joining player's attributes show Hunger/Thirst/Stamina/BodyTemperature/Radiation values.
- [ ] Hunger and thirst decay over several minutes; no errors in server Output.
- [ ] Command-bar test: `require(game.ServerScriptService.Services.InventoryService):AddItem(player, "CannedBeans", 5)` adds five items and the client receives an `InventoryUpdated` event.
- [ ] Consume a canned beans item server-side; hunger increases and the item count decreases by one.
- [ ] Consume murky water repeatedly; infection can occur; antibiotics cure it (server-side calls).
- [ ] Set a part as a loot container, search it via remote with two players; second search within 60 seconds is rejected with `ContainerOnCooldown`.
- [ ] Fill the inventory past 24 slots; `AddItem` returns `InventoryFull` instead of creating ghost slots.
- [ ] Save, leave, and rejoin: inventory slots and survival stats persist exactly.
- [ ] Starve/dehydrate a test player; health drains and the death → respawn flow works.

## Architecture notes

- All player data mutations happen on the server; clients never write profiles directly.
- `PlayerDataService.GetData(player)` returns the live profile table for server systems.
- Data is normalized against `DataSchema` before every save and load, with a session lease preventing concurrent servers from overwriting the same profile.
- Survival, inventory, and loot all read from the same live profile, so a save snapshot always contains a consistent world state for those systems.
- Known limitation: UI is server-driven data only for now; client HUD controllers arrive in later stages. Remote payload shapes are already final.
- Known limitation: the survival tick runs at a fixed 4-second interval for all tracked players in one pass (cheap, but attribute updates land in visible steps; acceptable and intended).

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
