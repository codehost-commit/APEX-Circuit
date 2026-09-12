# APEX Circuit

An original open-wheel racing vertical slice for Godot 4.6 (GDScript, Forward+, Jolt). It ships as a fully text-authored, playable gray-box game: one original circuit, custom four-raycast vehicle physics, an AI field, race control, HUD/cockpit, and a live cinematic menu.

## Run

Open `project.godot` in the Godot **standard** editor with Forward+ and Jolt Physics selected, then run the main scene. The game begins at the live menu.

- **Qualifying** lets the player set real laps before the grid.
- **Race** starts the five-light race sequence immediately.
- **WASD / arrows** drive; **Q/E** shift; **F** opens DRS where available; **C** changes camera; **Esc** pauses.

## Contents

- `cars/` — custom raycast formula-car and tunable resource.
- `tracks/` — original Apex Loop geometry, collision, surfaces, checkpoints, and racing line.
- `ai/` — curvature/braking speed profile and tactical pure-pursuit drivers.
- `scripts/` — session state, race rules, timing, penalties, DRS and classification.
- `ui/` — HUD, cockpit instrument, minimap, menu and cinematic camera.
- `assets/` — free-source assets and attribution record.

## Art status

The included 1K **Hochsal Field** HDRI is CC0 from Poly Haven. Cars, track surfaces and props are generated placeholders until final CC0/CC-BY assets are dropped into `assets/`; see [HUMAN_TODO.md](HUMAN_TODO.md) and [assets/ATTRIBUTIONS.md](assets/ATTRIBUTIONS.md).

All binary art is configured for Git LFS through `.gitattributes`.
