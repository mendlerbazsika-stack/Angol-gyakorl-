# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong.

**Status: Stage 8 of 10. This is an in-progress Roblox Studio blockout, not a finished game. No Studio tests have been run.**

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
| 9 | Campaign, factions, endgame | Not started |
| 10 | UI polish, audio, optimization, release testing | Not started |

## Install in Roblox Studio

1. Open the `stage1/game-foundation` branch on GitHub and choose **Code → Download ZIP**.
2. Create a new Baseplate experience in Roblox Studio. For DataStore tests, publish it privately and enable **Game Settings → Security → Enable Studio Access to API Services**.
3. Create `ReplicatedStorage/Shared` and add ModuleScripts `GameConfig`, `DataSchema`, `ItemDefinitions`, `SurvivalConfig`, `RecipeDefinitions`, `QuestDefinitions`, `DialogueDefinitions`, and `EnemyDefinitions`, using the matching `.lua` files in `src/ReplicatedStorage/Shared/`.
4. Create `ServerScriptService/Services` and add ModuleScripts `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `EquipmentService`, `GatheringService`, `CraftingService`, `WorldService`, `QuestService`, `DialogueService`, `EnemyService`, `CombatService`, `PartyService`, `TradingService`, `BuildingService`, and `VehicleService`, using the matching files in `src/ServerScriptService/Services/`.
5. Add a Script named `ServerBootstrap` under `ServerScriptService`, using `src/ServerScriptService/ServerBootstrap.lua`.
6. Set `Workspace.StreamingEnabled = true` in Studio properties to test streaming; the script does not set this Studio property.

## Stage 8 scope

- **Building:** `BuildingService` provides 4 structure templates (Wood Wall, Wood Floor, Scrap Gate, Field Workbench) with server-validated placement: 2-stud grid snapping, 24-stud placement range, playfield bounds, overlap prevention (5-stud minimum spacing), 40-structure cap per player, material cost consumption before creation, owner-only removal with a half-material refund, and rebuild-on-join from persisted data. Field Workbenches register as real crafting stations via CollectionService tags.
- **Vehicles:** `VehicleService` spawns 3 field trucks at fixed points with server-managed seating: the engine only enables when fuel is available, fuel drains by throttle, refueling consumes a GasolineCan (+40 fuel) within 12 studs, repairs consume 2 ScrapMetal (+30 health), and occupancy itself is engine-exclusive so seats cannot be hijacked.
- **Items:** new GasolineCan (Rare, 3.0 weight) — obtainable from loot in future tables.
- **Persistence:** built structures persist in the normalized schema with coordinate clamping and template allowlisting; corrupted records are dropped silently rather than crashing loads.

## Stage 8 test checklist (not run)

- [ ] Start a local server; confirm the Stage 8 startup line, `AFTERZERO BuildingService initialized.`, and `AFTERZERO VehicleService initialized.` appear.
- [ ] Place a Wood Wall via the Build remote near your character; wood is consumed, the wall appears on the grid; a second wall within 5 studs is rejected with `OverlapsStructure`.
- [ ] Place beyond 24 studs: rejected with `TooFar`. Place outside the ±400 bounds: rejected with `OutsideBuildArea`.
- [ ] Place with insufficient wood: rejected with `MissingMaterials`, no partial consumption.
- [ ] Remove your own structure: it disappears and half materials are refunded. Attempt to remove another player's structure: rejected with `NotOwner`.
- [ ] Place a Field Workbench and craft a Workbench recipe standing at it — the station validation accepts it.
- [ ] Save, leave, rejoin: structures rebuild in place from persisted data; remove one, rejoin, it stays removed.
- [ ] Enter a truck: engine enables only while fuel > 0. Drive at full throttle: fuel drains visibly. Reach 0 fuel: engine disables and the client receives `OutOfFuel`.
- [ ] Refuel with a GasolineCan within 12 studs: fuel rises by 40. Refuel beyond 12 studs: rejected with `TooFar`.
- [ ] Repair with 2 ScrapMetal: health rises by 30. Without ScrapMetal: rejected with `MissingMaterials`.
- [ ] Attempt refuel/repair on a forged vehicle id: rejected with `UnknownVehicle`.
- [ ] Run all previous milestone checks; Stage 8 depends on Stages 1–7.

## Known limitations

This game is not complete or tested. Only Greywood blockout exists; other regions, the full 10-chapter campaign, factions, PvP zones, settlement progression levels, vehicle damage from combat, HUD, building/vehicle UI, audio, and monetization remain outstanding. Structures use simple anchored Parts (no physics destruction). Vehicles have server-side fuel but Roblox's built-in VehicleSeat physics movement; collisions and terrain handling are untested. The fuel drain loop runs every 0.05s per vehicle — cheap for 3 vehicles, but a larger fleet would need a slower shared loop. No claim is made that scripts compiled or passed Studio tests.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
