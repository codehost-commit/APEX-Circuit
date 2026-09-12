# APEX Circuit

An original open-wheel racer rebuilt around the supplied Python prototype's circuit and handling. GDScript, Forward+, Jolt, 120 Hz physics. Target: Godot 4.6 or later; this revision was actually validated on the installed **Godot 4.7.2** standard build.

This is a tested development build, not a claim of photorealistic or launch-ready quality. See [VALIDATION.md](VALIDATION.md) for measured results and remaining limitations.

## Run

Open `project.godot` in the Godot **standard** editor with Forward+ and Jolt Physics selected, then run the main scene. The game begins at the live menu.

- **Time Trial**: unlimited timed laps, three sectors, saved clean PB, ghost and live delta.
- **Race Weekend**: five-minute physical qualifying, then a best-lap-ordered grid. Skip is available without setting a lap.
- **Quick Race**: twelve-car, five-lap race. Hold the brake until all five red lights go out; moving early earns a penalty.
- **WASD / arrows** drive; **Q/E** shift; hold **F** for eligible DRS; **C** cycles chase/T-cam/cockpit; **Space** handbrake; **R** checkpoint recovery; **G** ghost; **Esc** pause/settings/results flow.
- Gamepad: left stick steer, RT/LT throttle/brake, LB/RB shifts, X DRS, Y camera, A handbrake, Start pause, Back recover.
- **K** opens section-coach capture; **T** runs the experimental physical AI pace tuner. These are development tools, not a complete port of the Python vector trainer.

## Contents

- `cars/` — custom raycast formula-car and tunable resource.
- `tracks/` — the copied 4,239.6 m Python circuit, 21 m road, 7.84 m kerbs, continuous collision, sand traps, five checkpoints and three DRS zones.
- `ai/` — curvature/braking speed profile and tactical pure-pursuit drivers.
- `scripts/` — session state, race rules, timing, penalties, DRS and classification.
- `ui/` — HUD, cockpit instrument, minimap, menu and cinematic camera.
- `assets/` — free-source assets and attribution record.

## Art status

Road, grass and gravel now use downloaded CC0 Poly Haven albedo/normal/roughness maps. The horizon uses actual terrain and a sky, not a finite backdrop wall. The working car is an original procedural body with separate steering/roll pivots and an actuated rear flap. A free CC0 source car and its creator-supplied unbranded texture are also downloaded in `assets/cars/` for art replacement; they are not silently substituted without pivot/camera validation. Exact next steps: [HUMAN_TODO.md](HUMAN_TODO.md). Licensing: [assets/ATTRIBUTIONS.md](assets/ATTRIBUTIONS.md).

Large model/HDR binaries use Git LFS. Install Git LFS and run `git lfs pull` after cloning. Small texture maps are ordinary Git files.

## Automated checks

Run `tests/run_checks.ps1 -Godot <path-to-godot-console.exe>` from PowerShell. The suite checks geometry, physical handling, rules, clean laps, menu-field recovery and a two-lap twelve-car grid-to-results race. It writes only ignored test artifacts, not the player's PB. Full details and direct commands are in [VALIDATION.md](VALIDATION.md).
