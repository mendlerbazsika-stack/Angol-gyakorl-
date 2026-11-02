# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. The truth, buried in the Meridian facility under the Exclusion Zone, is that the lights were switched off — on purpose.

**Status: Stage 10 of 10 — ALL SYSTEMS DELIVERED. This is a full-featured prototype: every system is scripted, but nothing has been tested in Roblox Studio, and art/audio assets are placeholder. It is NOT release-ready until the Studio test checklists pass.**

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
| 10 | Client UI, audio, input, release readiness | Scripts provided, untested in Studio |

## Install in Roblox Studio

1. Open the `stage1/game-foundation` branch on GitHub and choose **Code → Download ZIP**.
2. Create a new Baseplate experience in Roblox Studio. For DataStore tests, publish it privately and enable **Game Settings → Security → Enable Studio Access to API Services**.
3. Create `ReplicatedStorage/Shared` and add ModuleScripts `GameConfig`, `DataSchema`, `ItemDefinitions`, `SurvivalConfig`, `RecipeDefinitions`, `QuestDefinitions`, `DialogueDefinitions`, `EnemyDefinitions`, `FactionDefinitions`, `CampaignDefinitions`, and `RegionDefinitions`, using the matching `.lua` files in `src/ReplicatedStorage/Shared/`.
4. Create `ServerScriptService/Services` and add ModuleScripts `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `EquipmentService`, `GatheringService`, `CraftingService`, `WorldService`, `FactionService`, `CampaignService`, `RegionService`, `QuestService`, `DialogueService`, `EnemyService`, `CombatService`, `PartyService`, `TradingService`, `BuildingService`, and `VehicleService`, using the matching files in `src/ServerScriptService/Services/`.
5. Add a Script named `ServerBootstrap` under `ServerScriptService`, using `src/ServerScriptService/ServerBootstrap.lua`.
6. Create `StarterPlayer/StarterPlayerScripts`. Add a **LocalScript** named `ClientBootstrap` using `src/StarterPlayer/StarterPlayerScripts/ClientBootstrap.lua`.
7. Inside `StarterPlayerScripts`, create a **Folder** named `Client`. Add these **ModuleScripts** (from `src/StarterPlayer/StarterPlayerScripts/Client/`):
   - `Theme`, `UIFactory`, `HUDController`, `InventoryController`, `DialogueController`, `QuestController`, `PartyController`, `TradeController`, `CombatController`, `NotificationController`, `AmbienceController`.
8. Set `Workspace.StreamingEnabled = true` in Studio properties.
9. Boot order matters on the server: RegionService starts before EnemyService so region spawn registrations exist when enemies first spawn. `ServerBootstrap` handles this — do not reorder it.

## Stage 10 scope

- **HUD:** six animated survival bars (health, hunger, thirst, stamina, temperature, radiation), status effect line (bleeding/infected/downed), world clock and weather line, and a region-entry banner.
- **Inventory:** slot grid bound to server snapshots with use/equip/repair actions routed through validated remotes. Toggle with `I` or the PACK button (mobile).
- **Dialogue:** renders only server-approved nodes and options; quest/endgame options are visually distinguished. No client-side dialogue logic exists.
- **Quest journal:** active quests with objective checkboxes and live kill progress. Toggle with `J` or the LOG button (mobile).
- **Party:** member list, invite-by-UserId flow with timed prompt, leave, and a "revive nearest teammate" scan that only sends intent — the server re-validates party, distance, and downed state. Toggle with `P`.
- **Trading:** offer draft, send, ready/cancel, lock-state rendering, and incoming request prompts with expiry.
- **Combat input:** mouse click (PC) and an ATTACK button (mobile/tablet) raycast for a target part and report intent only. The server re-validates range, weapon, cooldown, ammo, and that the target is a tracked live enemy. `F` forces a melee swing.
- **Notifications:** a single toast feed aggregating loot, crafting, gathering, campaign chapters, faction tiers, vehicle state, and survival events.
- **Ambience:** procedural looping wind/rain/storm audio that crossfades with the server's weather and day/night state. Uses Roblox stock sounds — replace with original recordings in an art pass.

## Controls

| Action | PC | Mobile/Tablet |
|---|---|---|
| Move / jump | WASD / Space | On-screen controls |
| Attack | Left click (auto melee/ranged) / `F` melee | ATTACK button |
| Inventory | `I` or `Y` | PACK button |
| Quest journal | `J` or `L` | LOG button |
| Party | `P` | Window always toggleable |
| Interact / talk / search / gather / travel / drive | ProximityPrompts (hold `E`) | ProximityPrompts (hold) |

## The full game loop

Wake in Greywood County → survive hunger, thirst, cold, and radiation → gather, craft, and equip → earn the settlement's trust (quests, chapters 1–2) → follow Rook's chain: the recording → **Ashford City unlocked** → archive manifest + scavenger kills → **Ironworks unlocked** → iron toll + raider kill → **Frostline unlocked** → caravan crossing → facility map → **Exclusion Zone unlocked** → clear the perimeter → the Meridian log → **the final choice:** restart the core, bury the facility, or seal it for the Order. Party up for shared XP and revives, trade with other players, build structures, and drive the field trucks along the way. Everything persists: profile, structures, chapters, reputation, and your one final decision.

## Master test checklist (not run)

Run these in Studio across a local server with 2+ players. Stages build on each other; earlier stage checklists are in the commit history and remain prerequisites.

- [ ] Server: `AFTERZERO Stage 9 server services initialized.` and all service initialization lines appear with **zero red errors**.
- [ ] Client: `AFTERZERO Stage 10 client initialized (11 controllers).` appears for each player.
- [ ] HUD bars render and animate as survival stats change; bleeding/infected/downed text appears; clock/weather line updates.
- [ ] Inventory opens (`I`), shows server slots, and Use/Equip/Repair send actions that the server accepts or rejects with reasons.
- [ ] Dialogue with Mara renders; accepting "Clear Water" shows in the journal (`J`) immediately.
- [ ] Turning in the quest via dialogue grants rewards; a toast appears; the journal clears the quest.
- [ ] Full campaign walk: chapters 1–10 complete in order; each region gate refuses before its chapter and teleports after; the endgame choice is stored permanently and cannot be re-made.
- [ ] Combat: equip SalvagedKnife, click an enemy; damage applies with server-side cooldown; kill grants XP + loot + quest kill progress; mobile ATTACK button works in the emulator.
- [ ] Party + downed: form a party, have an enemy down a member, revive within range; solo death skips downed state.
- [ ] Trading: full happy-path trade between two players; cancel during the lock window exchanges nothing.
- [ ] Building: place/remove structures; leave and rejoin; they persist.
- [ ] Vehicles: enter, drive, drain fuel, refuel with a GasolineCan, repair with scrap.
- [ ] Ambience: audio crossfades when the weather changes (force it by waiting or adjusting the interval in WorldService).
- [ ] DataStore: with API access enabled, leave/rejoin and verify profile persistence end-to-end.

## Release readiness — the honest assessment

**What exists:** every major system from the original vision is scripted — persistence, survival, crafting, equipment, gathering, a five-region world with travel, NPCs and a full conditional dialogue system, quests with three objective types, server-authoritative combat and AI, parties with revives, escrowed trading, base building, vehicles, a 10-chapter campaign with factions and a final decision, and a complete client UI layer. The security model is consistent: clients send intent, servers validate everything.

**What stands between this and release:**

1. **Zero testing.** No script here has run in Studio. Expect compile errors, typos, and integration bugs on first boot. Budget a real debugging pass guided by the checklists.
2. **Placeholder art.** All geometry is colored blockout parts; all rigs are 2-3 part placeholder models; NPCs have no animation states. The game needs modeled environments, rigged characters, and animation.
3. **Placeholder audio.** Ambience uses stock loop ids that may or may not be valid/pleasant; the game needs original wind/rain/music recordings and interaction sounds.
4. **Straight-line AI.** Enemies walk directly toward players with no pathfinding, no obstacles handling, and no attack animations.
5. **Performance unmeasured.** Streaming settings, structure counts, enemy update loops, and UI performance have never been profiled on mobile.
6. **Content thinness.** One broker NPC carries the whole campaign; regions are compact plates; there is one vehicle type, 3 enemy types, ~33 items, ~10 recipes. A shipped game needs 5-10x more content density.
7. **No monetization, no analytics, no moderation tooling** — none were specified, none exist.
8. **Security unreviewed.** The design is defensively written, but it has never faced an actual exploit attempt or a formal audit.

This is a complete, honest skeleton with muscle on it — not a shipped game. The fastest path from here: run the master checklist in Studio, fix what breaks, then replace placeholders with real assets.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
