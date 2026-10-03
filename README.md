# Heroes Duel

A 1v1 real-time, top-down hero duel for phones, built with Godot 4.7.2 (GDScript).
See [docs/PLAN.md](docs/PLAN.md) for the design, milestones and iOS shipping plan.

## Run

1. Install Godot 4.7.2 (standard build). This repo expects it at
   `..\tools\godot\4.7.2\`, or set the `GODOT` environment variable.
2. Open `project.godot` in Godot and press F5. The game boots straight into
   Knight (you) vs Ranger (AI).

Controls on desktop: WASD/arrows to move (or drag with the mouse in the left part of the
screen), J/Space to attack, K/L/; to quick-cast skills, Q/E/R to cast at the mouse
cursor, Esc/P to pause, F3 to restart (debug builds).

To preview an iPhone-shaped screen, set *Display > Window > Size > Window Width/Height
Override* to about 1300x600.

## Validate

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate.ps1
```

It runs a headless import, the smoke test (`tools/smoke_test.gd`: hero data validation,
a full AI-vs-AI match and a determinism check), the unit tests, and a 300-frame boot
whose log is scanned for errors. The same steps run in CI on every push
([.github/workflows/ci.yml](.github/workflows/ci.yml)).

## Tests

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

[GUT](https://github.com/bitwes/Gut) 9.7.1 lives in `addons/gut`. The suite in
`tests/unit` covers the cooldown tracker, arena geometry, hero data, and the combat
rules that are easy to break silently: simultaneous resolution, cast lock, the global
cooldown, input buffering, crowd control and determinism.

## Layout

| Path | Contents |
|---|---|
| `scripts/sim/` | Fixed-tick simulation: no nodes, input or textures |
| `scripts/data/` | Resource classes for heroes, skills, effects and the arena |
| `scripts/controllers/` | Local player (touch and keyboard) and AI command producers |
| `scripts/match/` | Match configuration and the runner that ticks the simulation |
| `scenes/` | Boot, arena, hero view and HUD (read-only presentation) |
| `data/` | `.tres` hero, skill, arena and roster data |
| `tools/` | Smoke test and validation script |

## Balance batch

```bash
godot --headless --path . -s res://tools/ai_batch.gd -- --matches=20
```

Plays AI-vs-AI matches and reports win rates, round lengths and damage. See
"Measured balance" in [docs/PLAN.md](docs/PLAN.md) for the current readings.

## Changing the pictures

Drop an image into `art/heroes/`, `art/skills/` or `art/arena/`, named after the thing
it belongs to — `art/heroes/knight.png` becomes the Knight. Then let Godot import it,
either by opening the editor or by running:

```bash
godot --headless --path . --import
```

No code or resource files to edit, and anything missing falls back to the placeholder
shape. Hero art is auto-scaled to fit. See [art/README.md](art/README.md) for the ids,
the supported formats, and how to assign a picture explicitly or animate a hero instead.

## Try it on a phone (no Apple account needed)

Export for the web and serve it on your Wi-Fi:

```bash
godot --headless --path . --export-release Web build/web/index.html
```

```bash
python tools/serve_web.py
```

Open the `http://<your-pc-ip>:8060/` address it prints on the phone, with the phone on
the same network. Windows will ask to allow Python through the firewall; allow it on
Private networks only.

Good for checking layout, thumb reach and multitouch early. Not a substitute for a real
iOS build: the browser's own bars change the safe area, the web vibration API is not
iOS haptics, and the single-threaded WebGL build does not represent native speed.

## Screenshots

`tools/screenshot.gd` captures PNGs of the running game, so a change can be checked
rather than assumed. It can also drive a drag, to capture the aim indicator:

```bash
godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- --frames=300 --drag=0
```

## Status

Milestone M0 (scaffold) and nearly all of M1 (greybox combat) are done: movement,
normal attacks, all five v1 effect primitives, cooldowns, cast lock, the input buffer,
drag-aim with a cancel disc, rounds with overtime and draws, the AI, and the result and
pause screens. A full best-of-3 plays out, and 37 unit tests plus CI guard it.

Still open in M1: testing on a real iPhone. Area-over-time effects are data-only until
the v1.1 heroes arrive. [.github/workflows/ios.yml](.github/workflows/ios.yml) is
written but has never been run, and needs an iOS export preset first.
