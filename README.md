# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong. Survivors scrape by in settlements and fortified zones while the truth waits underground.

**Status: Stage 1 of 10 — foundation only. This is not a playable game yet, and nothing here has been tested in Roblox Studio.**

## Progress

| Stage | Scope | Status |
|---|---|---|
| 1 | Core framework, player initialization, persistence | Scripts provided, untested in Studio |
| 2 | Survival, inventory, items, loot, consumables | Not started |
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
4. Create a `Services` folder inside `ServerScriptService`, and add:
   - `ServerScriptService/Services/PlayerDataService` (ModuleScript) ← `src/ServerScriptService/Services/PlayerDataService.lua`
5. Add this Script directly under `ServerScriptService`:
   - `ServerScriptService/ServerBootstrap` ← `src/ServerScriptService/ServerBootstrap.lua`
6. Open each `.lua` file in this repository and paste its contents into the matching Studio object. Set script types correctly: `PlayerDataService`, `GameConfig`, and `DataSchema` are **ModuleScripts**; `ServerBootstrap` is a **Script**.

## Stage 1 test checklist

Complete these in Studio before moving on to Stage 2:

- [ ] Two or more test players join; the server prints the Stage 1 initialization message.
- [ ] Each player shows `DataReady = true` and `PersistenceMode = "Persistent"` attributes.
- [ ] Stop the server and rejoin; data loads as Persistent again.
- [ ] Joining the same account from a second server is blocked while the first session lease is active.
- [ ] With API access disabled, joining produces a `SessionOnly` player and a server warning; temporary data is never written to the DataStore.

## Architecture notes

- All player data mutations happen on the server; clients never write profiles directly.
- `PlayerDataService.GetData(player)` returns the live profile table for server systems; future services (survival, inventory, quests) read and write through this service.
- Data is normalized against `DataSchema` before every save and load, with a session lease preventing concurrent servers from overwriting the same profile.
- Studio API access is required for real persistence testing; the Studio volatile fallback (`SessionOnly`) never persists.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.