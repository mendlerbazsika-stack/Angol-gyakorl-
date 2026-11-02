# AFTERZERO: THE LAST CIVILIZATION

Original post-apocalyptic multiplayer survival experience for Roblox, built with Luau.

Year 2039. A global event called **The Blackout** collapsed electrical grids, communications, and transportation worldwide. The official story blames solar storms. Evidence scattered across five regions suggests a secret research organization was experimenting with technology that manipulates energy and matter — and something went wrong.

**Status: Stage 7 of 10. This is an in-progress Roblox Studio blockout, not a finished game. No Studio tests have been run.**

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
| 8 | Building, settlements, vehicles | Not started |
| 9 | Campaign, factions, endgame | Not started |
| 10 | UI polish, audio, optimization, release testing | Not started |

## Install in Roblox Studio

1. Open the `stage1/game-foundation` branch on GitHub and choose **Code → Download ZIP**.
2. Create a new Baseplate experience in Roblox Studio. For DataStore tests, publish it privately and enable **Game Settings → Security → Enable Studio Access to API Services**.
3. Create `ReplicatedStorage/Shared` and add ModuleScripts `GameConfig`, `DataSchema`, `ItemDefinitions`, `SurvivalConfig`, `RecipeDefinitions`, `QuestDefinitions`, `DialogueDefinitions`, and `EnemyDefinitions`, using the matching `.lua` files in `src/ReplicatedStorage/Shared/`.
4. Create `ServerScriptService/Services` and add ModuleScripts `PlayerDataService`, `SurvivalService`, `InventoryService`, `LootService`, `EquipmentService`, `GatheringService`, `CraftingService`, `WorldService`, `QuestService`, `DialogueService`, `EnemyService`, `CombatService`, `PartyService`, and `TradingService`, using the matching files in `src/ServerScriptService/Services/`.
5. Add a Script named `ServerBootstrap` under `ServerScriptService`, using `src/ServerScriptService/ServerBootstrap.lua`.
6. Set `Workspace.StreamingEnabled = true` in Studio properties to test streaming; the script does not set this Studio property.

## Stage 7 scope

- **Parties:** `PartyService` provides creation, leader-only invitations with 60-second expiry, a 4-member cap, leader promotion on leader departure, and disconnect-safe leave handling. Party membership is purely session state — it is not persisted.
- **Reviving:** players in a party who lose all health enter a **downed** state (immobile, revive window = 3x respawn time) instead of dying. A party member within 8 studs can revive them to 30 health. Solo players go straight to the normal death flow. All revive requests are validated server-side (same party, distance, actually downed).
- **Shared objectives:** when a party member turns in a quest, nearby members (within 80 studs) who still have the same quest active receive half the quest's experience. Items and currency are never shared, so there is no reward duplication path.
- **Trading:** `TradingService` implements two-player trades with expiring requests (30s), validated offers (max 6 item slots plus currency, re-checked against live inventory), ready flags that reset on any offer change, a 2-second lock window before execution, and atomic execution — both sides are removed before delivery, and undeliverable goods return to the giver. Range limits apply at request, acceptance, and execution.

## Stage 7 test checklist (not run)

- [ ] Start a local server with 2+ test players; confirm the Stage 7 startup line, `AFTERZERO PartyService initialized.`, and `AFTERZERO TradingService initialized.` appear.
- [ ] Player A creates a party, invites B; B receives the invite, accepts, and both see the correct member list.
- [ ] A non-leader invites a third player: rejected with `NotLeader`. A fifth player cannot join a full party.
- [ ] B leaves; with a 2-member party the party disbands. Leader leaving promotes the next member.
- [ ] Have an enemy down player B (in party): B is downed, not dead. A stands within 8 studs and revives; B returns at 30 health. Reviving from beyond 8 studs is rejected with `TooFar`.
- [ ] A solo player killed by an enemy skips downed state and takes the normal death flow.
- [ ] A downed player whose teammates do not revive in time dies normally.
- [ ] Trade: A requests within 30 studs of B; B accepts. Both set offers (items and/or currency); offer changes reset both ready flags. Both ready → 2-second lock → trade executes. Walk apart during the lock: trade cancels with `TooFar` and nothing is exchanged.
- [ ] Offer more items than held: rejected with `NotEnoughItems`; forged offers with unknown item ids are rejected with `UnknownItem`.
- [ ] Disconnect a player mid-trade: session ends with `PlayerLeft`, nothing is exchanged, and the partner keeps their items.
- [ ] Quest turn-in by a party member grants half experience to a nearby member who still has the quest active; a member without the quest active receives nothing; items and currency are never duplicated.
- [ ] Run all previous milestone checks; Stage 7 depends on Stages 1–6.

## Known limitations

This game is not complete or tested. Only Greywood blockout exists; other regions, the full 10-chapter campaign, factions, PvP zones, base building, vehicles, HUD, party/trade UI, downed-state visuals, audio, and monetization remain outstanding. All Stage 7 interactions are server-driven; the client UI for parties, trading, downed prompts, and revive buttons arrives with Stage 10. PvP remains disabled everywhere. No claim is made that scripts compiled or passed Studio tests.

## License

All original code and writing in this repository by the project author. Do not reuse the AFTERZERO name, story, characters, or world content without permission.
