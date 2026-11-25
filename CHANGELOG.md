# Changelog

## 2.15.0

- Every Lens panel carries the Lens Badge on its tab in Trainer Desk (0.8.0 or newer; older versions just show the title).
- The mod is now part of the **Trainer Badges**: a badge, a banner and the family case in the README.

## 2.14.3

- Moves panel: the effectiveness mark against the opponent was wrong on the current game version. A neutral move showed a red **x0.01**, and super effective moves showed as weak. It now shows x2, x0.5 and so on, and nothing for a neutral move.

## 2.14.2

- Trainer panel: the badges are now the mod's own medals (a disc in the colour of the gym's type, with the number of the badge) instead of the pictures from the game's trainer card. The mod no longer reads any picture imported from your ROM, and passes the modkit's `validate --strict` and `lint`.
- New `DIFFERENCES.md`: what the mod changes from the unmodded game.

## 2.14.1

- Trainer panel: the badge pictures show again (2.10.0 had dropped the second place the game keeps them).

## 2.14.0

- New **Dashboard** panel: while exploring, the area's Pokémon, Repel steps, VS Seeker charge, a waiting egg, encounters since the last shiny and the items left; in a battle, the opponent, and in a wild battle the exact Gen 3 chance of catching it with each ball you carry.
- Party panel: give, take and switch held items from the bag, through the game's own functions (field only; Mail is left to the game).

## 2.13.0

- PC panel: move Pokémon between box slots, by dragging inside a box or with **Move** to any slot of any box; a taken slot swaps. Never to or from the party. Same rules as sorting (field only, no menu or battle) and one step of **Undo**.

## 2.12.0

- PC panel: the living dex orders leave an empty slot for each missing species (up to the highest Pokédex number you have); if the unlocked boxes are too small for that, nothing moves.
- PC panel: new order **Remove gaps**, which keeps the order and closes up empty slots.
- PC panel: each slot and sheet shows the National Pokédex number.

## 2.11.0

- PC panel: **Lock box** keeps a box out of sorting (kept per save; the game itself can still change it).
- PC panel: **Sort** the unlocked boxes by living dex (repeats side by side, or at the end), species then level, or level up or down. Eggs go last; a question comes first; one step of **Undo**. Only in the field, with no menu open and no battle.

## 2.10.0

- Panels in English, Spanish, Portuguese and Japanese (Language option; English by default). Type names and labels follow the language; game names stay in the game's language.
- Japanese text drawn with a bundled Noto Sans JP subset.
- The Pokédex sheet's "Evolves into", "Where to find it", "Pokédex entry" and "Base stats" headings no longer show as raw keys.
- Level labels follow the language.
- Drops the unused `network` permission; lists FireRed and LeafGreen as its games, with an up-to-date description.
- Badge pictures are read only through the game's cache layer.
- MIT license, release workflow and a ready mod index entry (docs/PUBLISHING.md).

## 2.9.0

- Renamed from PokePanels to Trainer Lens; mod id `poke_panels` becomes `trainer_lens`. Panel ids become `trainer_lens.<kind>`.
- English documentation; the "Panel placement" option now names Trainer Desk.

## 2.8.0

- PC panel: the boxes as a grid and the full sheet of the Pokémon clicked. View only.

## 2.7.x

- Page buttons (`<  n/m  >`) on every paged list; in the bag they sit under the list.
- Auto Repel in the Tools panel.
- Tools shows only what can be used right now.
- Auto Repel no longer looks at other mods.

## 2.6.x

- An Online panel was added and then removed: the game does not allow online play with mods on.

## 2.5.x

- Pokédex panel with a sheet per species.
- Notices panel.
- Party members can be swapped by clicking one and then another.
- Area Pokémon can be clicked for a species sheet; the wheel turns its pages.

## 2.4.0

- Bag, Moves, Day-Care and Counter panels.

## 2.3.x

- Area map and Region map, drawn with the game's own tiles and Town Map.

## 2.2.x

- Trainer and Progress panels; icons on the tools; a Poké Ball for caught species; badge pictures.

## 2.1.0

- Tools panel; one radar chart for stats, IVs and EVs; drawn gender signs.

## 2.0.0

- New look: flat cards and a vector font instead of the game-themed frames; every panel redraws itself for the room it has (needs Trainer Desk 0.4.0).

## 1.x

- Area Pokémon, Party, Opponent, Item radar and My Pokémon panels; desktop windows and Trainer Desk docking.
