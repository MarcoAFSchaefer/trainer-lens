# Changelog

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
