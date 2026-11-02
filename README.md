# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. The truth, buried in the Meridian facility under the Exclusion Zone, is that the lights were switched off — on purpose.

**Status: Stage 9 of 10. This is an in-progress Roblox Studio blockout, not a finished game. No Studio tests have been run.**

## Progress

| Stage | Scope | Status |
|---|---|---|
| 1 | Core framework, player initialization, persistence | Scripts provided, untested in Studio |
| 2 | Survival, inventory, items, loot, consumables | Scripts provided, untested in Studio |
| 3 | Crafting, equipment, gathering | Scripts provided, untested in Studio |
| 4 | Greywood blockout, interactions, region detection, clock/weather | Scripts provided, untested in Studio |
| 5 | NPCs, dialogue, quest framework | Scripts provided, untested in Studio |
| 6 | Combat, weapons, enemies, AI | Scripts provided, untested in Studio |
| 7 | Parties, trading, shared objectives, reviving | Scripts provided, untested in Studio |
| 8 | Building, settlements, vehicles | Scripts provided, untested in Studio |
| 9 | Campaign, regions, factions, endgame | Scripts provided, untested in Studio |
| 10 | UI polish, audio, optimization, release testing | Not started |

## Install in Roblox Studio

1. Open the `stage1/game-foundation` branch on GitHub and choose **Code → Download ZIP**.
2. Create a new Baseplate experience in Roblox Studio. For DataStore tests, publish it privately and enable **Game Settings → Security → Enable Studio Access to API Services**.
3. Create `ReplicatedStorage/Shared` and add ModuleScripts `GameConfig`, `DataSchema`, `ItemDefinitions`, `SurvivalConfig`, `RecipeDefinitions`, `QuestDefinitions`, `DialogueDefinitions`, `EnemyDefinitions`, `FactionDefinitions`, `CampaignDefinitions`, and `RegionDefinitions`, using the matching `.lua` files in `src/ReplicatedStorage/Shared/`.
4. Create `ServerScriptService/Services` and add ModuleScripts `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `EquipmentService`, `GatheringService`, `CraftingService`, `WorldService`, `FactionService`, `CampaignService`, `RegionService`, `QuestService`, `DialogueService`, `EnemyService`, `CombatService`, `PartyService`, `TradingService`, `BuildingService`, and `VehicleService`, using the matching files in `src/ServerScriptService/Services/`.
5. Add a Script named `ServerBootstrap` under `ServerScriptService`, using `src/ServerScriptService/ServerBootstrap.lua`.
6. Set `Workspace.StreamingEnabled = true` in Studio properties to test streaming; the script does not set this Studio property.
7. Boot order matters: RegionService starts before EnemyService so region spawn registrations exist when enemies first spawn. `ServerBootstrap` already handles this order — do not reorder it.

## Stage 9 scope

- **Campaign:** `CampaignService` drives 10 chapters. Chapters complete automatically once their required quests and prerequisite chapters are done, unlocking regions in sequence: Ashford City (Ch. 3), Ironworks (Ch. 4), Frostline (Ch. 5), Exclusion Zone (Ch. 8). The final chapter ends in a permanent, validated endgame decision: restart the Meridian core, bury the facility, or seal it for the Order. The decision is final and only settable through dialogue.
- **Regions:** `RegionService` builds compact blockouts for all four remaining regions far from Greywood (offset 2000 studs) with buildings, loot crates, enemy spawns registered through `EnemyService.RegisterSpawn`, region detection zones, and travel gates. Gate travel teleports only after the server confirms the destination region is unlocked; locked gates notify and refuse.
- **Factions:** `FactionService` tracks reputation for four factions (Greywood Settlers, Order of the Lamp, Iron Pact, Dawn Caravan) with four tiers each (Hostile/Neutral/Friendly/Allied). Quest turn-ins grant reputation through the service; remotes are read-only.
- **Quests:** 7 new campaign quests chained through Rook's dialogue, including `KillEnemies` objectives that track validated enemy kills via a service hook, and faction reputation rewards on turn-in.
- **Bug fix from Stage 5:** `TalkTo` objectives now complete when a dialogue session *begins* with the target NPC — previously they only completed when a quest was accepted from that NPC, which was wrong for Ward's Request and any future TalkTo quest.

## Stage 9 test checklist (not run)

- [ ] Start a local server; confirm the Stage 9 startup line and the Faction/Campaign/Region initialization lines appear without errors.
- [ ] Confirm four new region folders exist under `Workspace/World/Regions`, each with ground, buildings, crates, a detection zone, and a travel gate.
- [ ] Confirm region enemies spawn (Ashford: 3, Ironworks: 3, Frostline: 2, Zone: 2) in addition to Greywood's 5.
- [ ] Fresh profile: walk to a region gate and use its prompt — refused with `RegionLocked` since no region is unlocked.
- [ ] Complete Clear Water: Chapter 1 completes automatically. Complete Supply Run + Ward's Request: Chapter 2 completes. The Order recording quest becomes available from Rook.
- [ ] Turn in Q_RecordingDrop: Chapter 3 completes and Ashford City unlocks; the Ashford gate now teleports you.
- [ ] With Q_AshfordManifest active, kill a scavenger spawned in Ashford: the kill objective progress increments (visible in QuestsUpdated payload); 3 kills complete the objective. Kills of the wrong enemy type do not count.
- [ ] Turn in Q_IronToll after killing an Iron Pact raider in Ironworks; Ironworks unlocks; faction reputation with IronPact rises by 30 and the tier event fires if a threshold is crossed.
- [ ] Continue the chain through Frostline and the Zone; each chapter unlocks its region exactly once; re-checking a gate after unlock always teleports.
- [ ] At the endgame node after Q_MeridianCore, choose "Bury the facility": the decision is stored, `EndgameDecided` fires, and choosing again elsewhere is rejected with `DecisionAlreadyMade`. Forged decision ids are rejected with `InvalidDecision`.
- [ ] Save, leave, rejoin: completed chapters, unlocked regions, faction reputation, kill progress, and the endgame decision persist exactly.
- [ ] Run all previous milestone checks; Stage 9 depends on Stages 1–8.

## Known limitations

This game is not complete or tested. The campaign is fully wired but told through a single broker NPC (Rook) in Greywood — per-region NPCs with their own dialogue arrive with Stage 10 polish. Region blockouts are compact placeholders (a ground plate, road, 3–4 buildings) offset far from Greywood rather than contiguous terrain; travel is a validated gate teleport, not a continuous world. Enemies in new regions reuse the same three enemy types. Faction tiers currently gate dialogue/reputation events only — faction vendors and tier-gated shops are not implemented. Endgame decisions are recorded but produce no world-state changes yet (that is Stage 10 content). No client UI exists for campaigns, factions, or regions; all remote payload shapes are final. No claim is made that scripts compiled or passed Studio tests.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
