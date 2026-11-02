# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong.

**Status: Stage 5 of 10. This is an in-progress Roblox Studio blockout, not a finished game. No Studio tests have been run.**

## Progress

| Stage | Scope | Status |
|---|---|---|
| 1 | Core framework, player initialization, persistence | Scripts provided, untested in Studio |
| 2 | Survival, inventory, items, loot, consumables | Scripts provided, untested in Studio |
| 3 | Crafting, equipment, gathering | Scripts provided, untested in Studio |
| 4 | Greywood blockout, interactions, region detection, clock/weather | Scripts provided, untested in Studio |
| 5 | NPCs, dialogue, quest framework | Scripts provided, untested in Studio |
| 6 | Combat, weapons, enemies, AI | Not started |
| 7 | Parties, trading, shared objectives | Not started |
| 8 | Building, settlements, vehicles | Not started |
| 9 | Campaign, factions, endgame | Not started |
| 10 | UI polish, audio, optimization, release testing | Not started |

## Install in Roblox Studio

1. Open the `stage1/game-foundation` branch on GitHub and choose **Code → Download ZIP**.
2. Create a new Baseplate experience in Roblox Studio. For DataStore tests, publish it privately and enable **Game Settings → Security → Enable Studio Access to API Services**.
3. Create `ReplicatedStorage/Shared` and add ModuleScripts `GameConfig`, `DataSchema`, `ItemDefinitions`, `SurvivalConfig`, `RecipeDefinitions`, `QuestDefinitions`, and `DialogueDefinitions`, using the matching `.lua` files in `src/ReplicatedStorage/Shared/`.
4. Create `ServerScriptService/Services` and add ModuleScripts `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `EquipmentService`, `GatheringService`, `CraftingService`, `WorldService`, `QuestService`, and `DialogueService`, using the matching files in `src/ServerScriptService/Services/`.
5. Add a Script named `ServerBootstrap` under `ServerScriptService`, using `src/ServerScriptService/ServerBootstrap.lua`.
6. `WorldService` generates Greywood County at server startup. `DialogueService` spawns Mara Voss, Elias Ward, and Rook in the settlement and near the gas station.
7. Set `Workspace.StreamingEnabled = true` in Studio properties to test streaming; the script does not set this Studio property.

## Stage 5 scope

- **Quests:** `QuestService` owns quest state with prerequisites, `CollectItem` and `TalkTo` objective types, reward grants (experience, currency, items), and full turn-in validation. Turn-ins re-verify inventory and consume items atomically before rewards are granted, so there is no reward-duplication path.
- **Dialogue:** `DialogueService` resolves conditional dialogue nodes from server quest state. Clients can only pick among options the server explicitly sent, and `AcceptQuest`/`TurnInQuest` actions are re-validated on the server. Three NPCs (Mara Voss, Elias Ward, Rook) spawn with ProximityPrompts; rigs are simple placeholder geometry to be replaced with authored avatars.
- **Content:** Three starter quests — "Clear Water" (Mara), "Scrap for the Settlement" (Mara, gated on Clear Water), and "Ward's Request" (Elias, gated on Clear Water). Rook hints at the Project Meridian mystery for the campaign.
- **Persistence:** Active quests, completed quests, and objective progress persist in the normalized schema.

## Stage 5 test checklist (not run)

- [ ] Start a local server; confirm the Stage 5 startup line and `AFTERZERO DialogueService initialized.` appear without errors.
- [ ] Walk to the settlement; confirm Mara Voss and Elias Ward spawn, and Rook near the gas station.
- [ ] Talk to Mara with a fresh profile; the water quest is offered. Accept it; `QuestsUpdated` fires with the objective.
- [ ] Bring 2 sealed water bottles and choose the turn-in option; bottles are consumed, bandage rewards granted, quest marked complete.
- [ ] Talk to Mara again; the scrap quest is now offered (prerequisite satisfied).
- [ ] Talk to Elias before completing Clear Water; the checkup quest is not offered. After Clear Water, it is.
- [ ] Turn in the checkup quest after only talking to Mara (TalkTo objective); it completes without item loss.
- [ ] Attempt a turn-in without required items in inventory; rejected with `ObjectivesIncomplete`, no rewards.
- [ ] Send a forged `SelectOption` remote with an out-of-range index; the server rejects it.
- [ ] Save, leave, rejoin; active/completed quests and objective progress persist exactly.
- [ ] Run all previous milestone checks; Stage 5 depends on Stages 1–4.

## Known limitations

This game is not complete or tested. Only Greywood blockout exists; other regions, the full 10-chapter campaign, factions, combat, enemies, parties, trading, base building, vehicles, HUD, dialogue UI, audio, and monetization remain outstanding. NPC rigs are placeholder geometry. There is no client dialogue/quest UI yet; remote payload shapes are final for the Stage 10 UI. No claim is made that scripts compiled or passed Studio tests.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
