# Trainer Lens architecture

## Files

| File | Role |
| --- | --- |
| `manifest.json` | Mod id `trainer_lens`, API 3, Gen 3 games, optional dependency `trainer_desk`. |
| `main.lua` | Options, text in Portuguese and English, the models built from game state, click handling, Trainer Desk registration and window mode. |
| `ui.lua` | Every view: given a model and a size, draws the panel. Knows nothing about the game. |
| `windows.lua` | Window mode: one desktop window per panel. |
| `wm_worker.lua` | Windows only: a thread that remembers and restores the game's window positions. |

## Models and views

`main.lua` turns game state into plain tables (models); `ui.lua` draws them. Every view takes the width and height it is given and arranges itself: columns appear and disappear, charts become tables when they would be too small, and long text is cut on a whole character with "..".

`paint(kind, now, w, h)` picks the model and view for a panel kind. Views that can be clicked return their clickable rectangles (`hits`); the panel's pointer handler looks the click up in the last `hits` it got.

`ui.lua` keeps its own colours and takes the surfaces and text colours from the Trainer Desk theme when there is one (`UI.theme`). Fonts are LÖVE's vector font at the sizes asked for.

## Placement

**With Trainer Desk** (`placement = dock` and the dock active), `syncDock` registers one panel per kind, all `responsive`, side `right` for the party and `bottom` for the rest. Each panel's `draw` receives the room its dock gives it. The pointer handlers are attached to the panels that can be clicked (area, party, tools, Pokédex, bag, counter, progress, PC).

**Without it**, `update` opens up to five desktop windows (`windows.lua`), each showing the kind chosen in the options, drawn at 480x432 and stretched by the window. In battle, panel 1 shows the opponent unless another window already does. Panel windows are frames only: they do not take clicks.

## The window keeper (Windows only)

`wm_worker.lua` runs in its own thread, where LuaJIT's FFI can reach `user32`. It only moves and raises this game's own windows: the main window and the second-display windows (including panel windows). It remembers their place and size, puts them back when they open, and brings the others forward when one of them gains focus from another program. Positions are saved in the `windows/layout2` cache key.

## Hooks

| Hook | Priority | Use |
| --- | --- | --- |
| `core.update` | default | Counter and notices watchers, Trainer Desk registration or window mode, the window keeper. Stops the mod (with one log line) if an error escapes. |
| `core.quit_to_launcher` | default | Closes windows and forgets the game. |
| `game.ready` (event) | | Remembers the game. |

## Saved data

Stored with `mod.cache` under `mod_cache/trainer_lens/`:

| Key | Content |
| --- | --- |
| `counter/v1` | `total=`, `since=`, `shinies=` and `s<species>=<count>` lines. |
| `autorepel` | `1` when Auto Repel is on. |
| `windows/layout2` | Window positions remembered by the window keeper. |

## Errors

Each panel is painted inside `pcall`. A panel that fails shows the error and logs it once; the other panels keep working.
