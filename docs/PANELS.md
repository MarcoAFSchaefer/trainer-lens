# Panels

Every panel has an id of the form `trainer_lens.<kind>` in Trainer Desk. This page lists, for each one, the model function in `main.lua`, the view in `ui.lua`, and the engine data it reads. Module names are the game's own (`src.core.game3.*` unless written in full).

| Kind | Title | Model | View |
| --- | --- | --- | --- |
| `dash` | Dashboard | `dashModel` (`dashField`, `dashBattle`) | `UI.dash` |
| `wild` | Area Pokémon | `wildModel`, `wildDetail` | `UI.wild`, `UI.dex` |
| `party` | Party | `partyModel` | `UI.party` |
| `enemy` | Opponent | `enemyModel` | `UI.sheet` |
| `ally` | My Pokémon | `allyModel` | `UI.sheet` |
| `moves` | Moves | `movesModel` | `UI.moves` |
| `radar` | Item radar | `radarModel` | `UI.radar` |
| `tools` | Tools | `toolsModel` | `UI.tools` |
| `trainer` | Trainer | `trainerModel` | `UI.trainer` |
| `progress` | Progress | `progressModel` | `UI.progress` |
| `map` | Area map | `localMapModel` | `UI.map` |
| `region` | Region map | `regionModel`, `townMapModel` | `UI.region` |
| `dex` | Pokédex | `dexModel`, `dexDetail` | `UI.dex` |
| `bag` | Bag | `bagModel` | `UI.bag` |
| `daycare` | Day-Care | `daycareModel` | `UI.daycare` |
| `counter` | Counter | `counterModel` | `UI.counter` |
| `notices` | Notices | `notices` (filled by `noticeWatch`) | `UI.notices` |
| `box` | PC | `boxModel` | `UI.box` |

## Dashboard

- **Exploring** (`dashField`): the area list of `wildModel`, `repelLeft()`, `vs_seeker.getBattery`, `daycare.isEggPending`, the encounter counter, and the Item radar's counts and nearest item.
- **Battle** (`dashBattle`): the opponent as the Opponent panel picks it. In a wild battle, each ball in the `POKE_BALLS` pocket (or the Safari Ball, `safari.balls`) gets `battle.catching.catchOdds(ball, battler, state, session)`, the game's own odds `a` (catch rate, HP, status, ball bonus). The chance shown is the Gen 3 one: four shake checks, each passing with probability `b / 65536`, where `b = floor(1048560 / sqrt(sqrt(16711680 / a)))`; `a >= 255` is certain.

## Party: held items

`partyItemModel` lists what the member holds and the bag's `ITEMS`, `POKE_BALLS` and `BERRY_POUCH` rows, without Mail (`mail.isMailItem`). Giving calls `item_use.giveToMon(session, bag, id, slot, item_use.partyGiveSource(bag))`, which also switches when something is held; taking calls `item_use.takeFromMon`. Both only when the field is idle (`fieldIdle`), and never for Mail.

## Pokémon sheets (Opponent, My Pokémon, PC)

`sheetModel(mon, basics)` builds the sheet: types (`pokemon.types`), nature and gender (`summary_data`), ability (`pokemon.abilityId`, `abilityName`), held item (`items_data.displayName`), stats from the Pokémon table, IVs from `mon.ivs`, EVs from `mon.evs`, moves (`battle.moves.get`, `displayName`), and the front sprite (`pokemon.frontPic`). The view draws one radar chart with three shapes: stats (purple, scaled to the highest), IVs (green, out of 31) and EVs (blue, out of 252), with the numbers at each corner. When there is no room for a readable chart, the same numbers are drawn as a table.

- **Opponent** reads `battle.getState()`; in battle it follows the HP bar the game is animating (`battle.anim`).
- **My Pokémon** picks, in order: the summary screen's Pokémon (`src.ui.game3.summary_menu`), the PC cursor's (`src.ui.game3.box_storage_ui`), the party menu's cursor, the active battler, then the party lead.
- **PC** reads `session.storage.boxes[b].mons[1..30]` directly, without `storage.ensure`. A boxed Pokémon without computed stats is shown through a copy with `pokemon.calcStats` filled in.

## PC: moving, locks and sorting

- **Move** (`moveMon`) swaps two box slots, in the same box or in two boxes, under the same rule as Sort (`pcFree`). Dragging is handled by `boxPointer`: a press on a Pokémon waits; letting go in place selects it, letting go over another slot of the box moves it. The party is never read or written.

- **Locks** are kept in the `box_locks/v1` cache key, one line per save (`<trainer id>:<name>=1,4,7`). They only tell Sort which boxes to skip.
- **Sort** (`runSort`) runs only when `WorldAPI:availableFieldActions()` gives no reason to refuse and no battle is active, which keeps it away from the PC screen, menus and scripts. It gathers the Pokémon of the unlocked boxes, orders them (`sortEntries`: eggs last, Pokédex number from `pokemon.national`, level, then the old order), lays them out (`placement`: the living dex orders keep an empty slot for every missing number up to the highest one; if that does not fit, nothing moves), and writes them back slot by slot. Only table references move between `mons` slots; no Pokémon is created, copied, healed or changed.
- **Undo** keeps the layout from before and after the sort. It puts the old one back only if the boxes still hold exactly the sorted layout; any other change since drops it.

## Area Pokémon

`wildRows` reads `game.data.gen3Encounters[map]` (`land`, `water`, `rocks`, `fishing`) and weighs each slot as the native picker does (FireRed: weights scaled to the slots that exist; fishing split into Old, Good and Super Rod). Caught species come from `dex.isCaught`. A click opens the species sheet (`dexDetail` with the "In this area" line). The list pages turn by themselves every 6 seconds; a page chosen with the buttons or the wheel stays for 30 seconds.

## Item radar

Item balls are objects with graphics id 92 on the current map; hidden items are the map's hidden-item events. Both are filtered by the save's flags, so collected items do not show.

## Tools

`world.game3.WorldAPI:availableFieldActions()` says which field actions can be used right now; a click calls `useFieldAction(id)`. Rods, VS Seeker, Repels and Escape Rope go through `item_use.useField(session, bag, id)`. Icons come from `src.ui.game3.bag_chrome.iconImage` (items) and `pokemon.monIcon` (the party member that knows the move). The repel counter is read with `field_semantics.getVar(session, "repelSteps")`, as the encounter check does.

**Auto Repel** (saved in `autorepel`): when the counter reaches 0 on a map with wild encounters (land, or water while surfing), it uses the weakest Repel in the bag (Repel, then Super Repel, then Max Repel), never during a battle, a dialogue or a menu, and writes a notice.

## Trainer

Badges come from `src.ui.game3.trainer_card.isBadgeUnlocked`, which knows every way a save may record them (its `_session` is set for the call and restored); their pictures are the mod's own medals, drawn in `main.lua` (a disc in the colour of the gym's type with the badge's number); the game's badge art is not read. Pokédex counts use `dex.countSeen` and `countCaught` (Kanto, then National when caught). Counters come from `session.gameStats` (steps, battles, captures, fishing, eggs, evolutions, Center heals), shown only when non-zero.

## Progress

Every map with wild encounters is grouped by area name (`src.import.gba.map_sections_extract`); an area's species are all those in its encounter tables. Sorted: the current area, then the closest to complete, finished ones last.

## Area map and Region map

- **Area map:** the map's layout (`def.midLayout:midAt`) drawn with the game's tileset atlas (`tileset_native.get`, `slotFor`, `quad`, `overQuad`) into the panel's own canvas, rebuilt when the map, its tiles or its overrides change (at most once a second). A map too big to read whole follows the player. Markers: the player, trainers, other characters, and the radar's items. If the tiles are not available, the map is drawn from collision data instead.
- **Region map:** the game's Town Map image (`src.ui.game3.region_map_gpu.image`, `src.import.gba.region_map_extract`) with the player's cell from `src.ui.game3.region_map_position.playerCell`. If it is not available, the panel lays out the maps reached through their connections instead.

## Pokédex

`dexModel` lists Kanto (or National, once a species from outside Kanto is caught) with `dex.isSeen` and `isCaught`. `dexDetail` adds types, abilities, evolutions (`pokemon.evolutions`), base stats (`pokemon.stats`), the areas where the species appears (from the Progress list), and, for caught species, category, height, weight and the Pokédex text (`pokemon.dexEntry`).

## Bag, Moves, Day-Care

- **Bag:** `bag.listPocket(bag, pocket)` for `ITEMS`, `KEY_ITEMS`, `POKE_BALLS`, `TM_CASE`, `BERRY_POUCH`.
- **Moves:** `battle.moves.get` and `summary_data.moveDescription`; effectiveness from `battle.types.effectiveness` against the opponent's types.
- **Day-Care:** `daycare.stateOf`, `route5Of`, `mon`, `levelsGained`, `cost`, `isEggPending`.

## Counter and Notices

`counterWatch` runs every frame: a wild battle that has just begun is one more encounter, by species; a shiny resets "since the last shiny". Saved in `counter/v1`.

`noticeWatch` runs twice a second and compares with what it saw last: Trainer Pilot stopping by itself (read from `mod.find("trainer_pilot").exports.bot`, optional), the VS Seeker reaching full charge, the Repel counter reaching 0, a party member fainting, a Day-Care level-up, a waiting egg. Notices are kept for the session only (30 at most).
