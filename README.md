# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong.

**Status: Stage 6 of 10. This is an in-progress Roblox Studio blockout, not a finished game. No Studio tests have been run.**

## Progress

| Stage | Scope | Status |
|---|---|---|
| 1 | Core framework, player initialization, persistence | Scripts provided, untested in Studio |
| 2 | Survival, inventory, items, loot, consumables | Scripts provided, untested in Studio |
| 3 | Crafting, equipment, gathering | Scripts provided, untested in Studio |
| 4 | Greywood blockout, interactions, region detection, clock/weather | Scripts provided, untested in Studio |
| 5 | NPCs, dialogue, quest framework | Scripts provided, untested in Studio |
| 6 | Combat, weapons, enemies, AI | Scripts provided, untested in Studio |
| 7 | Parties, trading, shared objectives | Not started |
| 8 | Building, settlements, vehicles | Not started |
| 9 | Campaign, factions, endgame | Not started |
| 10 | UI polish, audio, optimization, release testing | Not started |

## Install in Roblox Studio

1. Open the `stage1/game-foundation` branch on GitHub and choose **Code → Download ZIP**.
2. Create a new Baseplate experience in Roblox Studio. For DataStore tests, publish it privately and enable **Game Settings → Security → Enable Studio Access to API Services**.
3. Create `ReplicatedStorage/Shared` and add ModuleScripts `GameConfig`, `DataSchema`, `ItemDefinitions`, `SurvivalConfig`, `RecipeDefinitions`, `QuestDefinitions`, `DialogueDefinitions`, and `EnemyDefinitions`, using the matching `.lua` files in `src/ReplicatedStorage/Shared/`.
4. Create `ServerScriptService/Services` and add ModuleScripts `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `EquipmentService`, `GatheringService`, `CraftingService`, `WorldService`, `QuestService`, `DialogueService`, `EnemyService`, and `CombatService`, using the matching files in `src/ServerScriptService/Services/`.
5. Add a Script named `ServerBootstrap` under `ServerScriptService`, using `src/ServerScriptService/ServerBootstrap.lua`.
6. `WorldService` generates Greywood County at server startup; `EnemyService` spawns 5 enemies (3 scavengers, 2 feral dogs) at fixed points; `DialogueService` spawns Mara Voss, Elias Ward, and Rook.
7. Set `Workspace.StreamingEnabled = true` in Studio properties to test streaming; the script does not set this Studio property.

## Stage 6 scope

- **Combat:** `CombatService` validates melee and ranged attacks fully server-side: equipped-weapon check, fire-rate cooldowns with jitter tolerance, server-measured range, ammo verification and consumption before the shot resolves, durability wear per attack, and armor with diminishing returns. Clients send intent only.
- **Enemies:** `EnemyService` spawns blockout rigs at 5 fixed points and runs a bounded state machine (Patrol → Pursue → Attack → Search → Return) at a fixed 0.5s cadence — never per-frame. Kills grant experience plus weighted loot drops; spawn points respawn after 120 seconds.
- **Enemy types:** Greywood Scavenger, Feral Dog, and an Iron Pact Raider defined for later regions.
- **Items:** new weapons (Rebar Club, Scrap Pistol with ammo), PistolRounds ammo, and Raw Meat from dog kills.
- **PvP:** disabled by default in Greywood County; hits on players are rejected with `PvPDisabled`. Zones arrive in Stage 7.

## Stage 6 test checklist (not run)

- [ ] Start a local server; confirm the Stage 6 startup line and `AFTERZERO EnemyService initialized.` appear without errors.
- [ ] Confirm 5 enemy rigs spawn at the fixed spawn points under `Workspace/World/Enemies`.
- [ ] Walk near a scavenger (within ~26 studs); it switches to Pursue and closes distance. Walk beyond 70 studs; it gives up and returns home.
- [ ] Let an enemy attack; health drops, its cooldown prevents machine-gun hits, and feral dog bites can cause bleeding.
- [ ] Equip SalvagedKnife to MainHand; a melee remote against an enemy part damages it (40 HP scavenger needs ~4 hits with 12 damage). Kill it: XP granted, 1–2 loot items appear in inventory, rig destroyed, respawn after 120s.
- [ ] Equip ScrapPistol with PistolRounds; firing consumes 1 round per shot; firing with 0 rounds is rejected with `OutOfAmmo`.
- [ ] Send forged melee remotes faster than the fire rate; rejected with `AttackTooFast`. Send a target part beyond 8 studs; rejected with `TargetOutOfRange`.
- [ ] Send a target part that belongs to no tracked enemy; no damage occurs.
- [ ] Attack another player; rejected with `PvPDisabled`.
- [ ] Run all previous milestone checks; Stage 6 depends on Stages 1–5.

## Known limitations

This game is not complete or tested. Only Greywood blockout exists; other regions, the full 10-chapter campaign, factions, parties, trading, PvP zones, base building, vehicles, HUD, weapon animations/effects, pathfinding (enemies move in straight lines), audio, and monetization remain outstanding. Enemy rigs are placeholder geometry. Combat has no client-side swing animation or hit feedback yet; the UI and effects come with later stages. No claim is made that scripts compiled or passed Studio tests.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
