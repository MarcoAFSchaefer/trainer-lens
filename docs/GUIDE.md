# Trainer Lens: player guide

Trainer Lens adds information panels to FireRed and LeafGreen: what lives in the area, the full sheet of any Pokémon, maps, your Pokédex, your bag and PC, and one-click field tools. Panels only read the game, with a few exceptions that act only when you click: **Tools** (and its **Auto Repel**), swapping two **Party** members, and sorting the **PC**.

## Installing

1. Download `trainer_lens-<version>.zip`, or install it from the launcher's **Find mods** tab.
2. If you downloaded the zip, use **Import mod .zip** in the launcher, or unpack it into `%APPDATA%\pokemon-love2d\mods\trainer_lens`.
3. Recommended: install **Trainer Desk** too, so the panels dock around the game.
4. Turn the mods on in the launcher and start the game.

## Two ways to show the panels

- **Docked (with Trainer Desk):** every panel is a tab in the docks around the game, and each redraws itself for the room it has. Move, resize and close them as described in the Trainer Desk guide.
- **Desktop windows (without Trainer Desk, or by choice):** up to five panels open as separate windows. Choose how many and which ones in the settings. In this mode the windows only show; they do not take clicks.

## The panels

### Area Pokémon
The wild Pokémon of the map you are on, grouped by how you meet them: grass, Surf, Old/Good/Super Rod, rocks. Each row shows the level range and the chance. A Poké Ball marks the species you have caught. Click a species to see its sheet. The list turns its pages by itself; use the **<** **>** buttons or the mouse wheel to choose a page.

### Party
HP, level, gender, status and held item of your party. **To change the order**, click one Pokémon and then the one it should swap with.

### Opponent and My Pokémon
The full sheet of a Pokémon: types, nature, ability, item, moves, and one radar chart with three shapes: stats (purple), IVs (green, out of 31) and EVs (blue, out of 252). An arrow next to a stat shows the nature raising or lowering it.

- **Opponent** shows the Pokémon you are fighting.
- **My Pokémon** follows what you are looking at: the summary screen, the PC cursor, the party menu, your Pokémon in battle, or else the first in your party.

### Moves
Your Pokémon's moves with type, category, power, accuracy, PP and description. In battle it also shows how effective each one is against the opponent.

### Item radar
Items still lying on this map, visible and hidden, nearest first, with how many steps away and in which direction.

### Tools
One click to ride the bicycle, use a field move (Cut, Surf, Strength, Flash, Rock Smash, Waterfall, Dig, Teleport, Sweet Scent), fish, use the VS Seeker, a Repel or an Escape Rope. Only what can be used right now is shown; nothing is shown in battle or during a dialogue.

**Auto Repel:** turn it on in this panel. When a Repel wears off on a map with wild Pokémon, it uses the weakest Repel in your bag (Repel, then Super Repel, then Max Repel). It never acts in battle, in a dialogue or in a menu. Each use is written in Notices.

### Trainer
Name, ID, money, play time, your badges, Pokédex counts and a few save counters (steps, battles, captures, fish caught, eggs hatched...).

### Progress
For every area, how many of its wild species you have caught. The area you are in comes first, then the closest to complete.

### Area map and Region map
- **Area map:** the current map drawn with the game's own tiles, with you, trainers, other people and items. A big map follows you.
- **Region map:** the game's Town Map with your position.

### Pokédex
Every species in a grid; switch between **All** and **Only the missing**. Click one for its sheet: types, abilities, base stats, evolutions, where to find it, and, once caught, its Pokédex entry.

### Bag
The five pockets with icons and descriptions. View only.

### Day-Care
The Pokémon left at the Four Island and Route 5 Day-Cares: steps walked, the level they would have if you took them back now, the cost, and whether an egg is waiting.

### Counter
Wild encounters by species, encounters since the last shiny, shinies seen, and the chance you had of seeing one by now. **Reset** clears it.

### Notices
A short feed of things worth knowing: a wild shiny, the VS Seeker fully charged, a Repel wearing off, a party member fainting, Day-Care news, Auto Repel, and Trainer Pilot stopping. Kept for this session only.

### PC
Your PC boxes as a grid. Use **<** **>** or the mouse wheel to change box, and click a Pokémon to see its full sheet, with IVs and EVs.

**Lock box** (or the padlock before the box name) marks a box that sorting must leave alone, such as your legendaries or a box arranged by hand. The lock is only for Trainer Lens: in the game you can still do anything with that box. Locks are kept per save.

**Sort** rearranges every Pokémon in the boxes that are not locked, filling them from the first unlocked box on. Choose an order:

| Order | Result |
| --- | --- |
| Living dex, repeats side by side | National Pokédex order, leaving one empty slot for each species you are missing; several of one species sit together. |
| Living dex, repeats at the end | One of each species in Pokédex order (the highest level one), with an empty slot for each missing species, then all the repeats, also in Pokédex order. |
| Species, then level | Pokédex order; within a species, lowest level first. |
| Level, low to high | By level; same level in Pokédex order. |
| Level, high to low | By level, highest first. |
| Remove gaps | Keeps the order they are in and closes up the empty slots. |

Eggs always go last. The living dex orders need room for their gaps (up to the highest Pokédex number you have); if the unlocked boxes are too few, nothing moves and the panel says how many slots are missing. Each Pokémon shows its National Pokédex number in the corner of its slot and on its sheet. A question shows how many Pokémon and boxes will change before anything moves. Sorting only works in the field, with no menu open and no battle. **Undo** puts the boxes back as they were, as long as nothing else in the PC has changed since. The new order is in your game at once and is kept when you save; nothing is ever deposited, withdrawn or released.

## Settings

| Setting | What it does |
| --- | --- |
| Panel placement | Dock in Trainer Desk, or open desktop windows. |
| Panel windows | How many desktop windows to open (0 to 5). |
| Panel 1 to 5 | Which panel each window shows. |
| Opponent in battle | In window mode, panel 1 switches to the opponent during a battle. |
| Language | English, Spanish, Portuguese or Japanese. Names from the game (Pokémon, moves, items, places) stay in your game's language. |
| Remember windows | Windows only: put the panel windows back where you left them. |
| Remember game window | Windows only: also remember the main game window. |
| Bring windows forward | Windows only: when the game gets focus, bring its other windows forward too. |

## Problems

- **A panel says "Waiting for the game".** Load your save; panels start once you are in the game.
- **A tool is missing from Tools.** It cannot be used here right now (wrong place, no Pokémon that knows the move, item not in the bag, or you are in a battle or a menu).
- **Auto Repel did nothing.** It only acts on maps with wild Pokémon (water only while surfing) and never in a battle, dialogue or menu. Check that you have Repels and that it is turned on.
- **Text is cut with "..".** Give the panel more room by dragging a divider in Trainer Desk.
