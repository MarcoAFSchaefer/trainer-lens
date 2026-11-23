# Tests

`main.lua` is a LÖVE program that loads Trainer Desk and Trainer Lens against a stand-in for the game and checks how they behave: every panel at several sizes, clicks on the clickable panels (party swap, Pokédex, bag, area list, PC), Auto Repel, the encounter counter, and the docking behaviour of Trainer Desk.

It runs on Linux with LÖVE 11.5 and a virtual X server:

```
DOCK_MOD=/path/to/trainer-desk/trainer_desk \
PP_MOD=/path/to/trainer-lens/trainer_lens \
TEST_OUT=/tmp/trainer_out \
xvfb-run -a -s "-screen 0 1280x800x24" love tests
```

| Variable | Meaning |
| --- | --- |
| `DOCK_MOD` | Path to the `trainer_desk` mod folder. |
| `PP_MOD` | Path to the `trainer_lens` mod folder. |
| `TEST_OUT` | Where screenshots of the panels are written (default `/tmp/kg_out`). |

Set `TEST_LANG` to `en`, `es`, `pt` or `ja` to run the checks with that language and get the screenshots in it (default `en`).

The run ends with `ALL DOCK CHECKS PASSED`; a failing check prints `CHECK FAILED` with the reason and stops. `panels-2.0.png` in `TEST_OUT` is a contact sheet of every panel, useful to look at after a visual change.

The stand-in has no real game art: sprites, tiles, the Town Map and badges are replaced by simple test pictures.

The same file is kept in the Trainer Desk repository.
