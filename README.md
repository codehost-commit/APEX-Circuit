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
- Settings include **KM/H or MPH**, mouse look, and **Performance / High / Ultra** graphics. Keyboard/mouse activity enables cursor look in cockpit view; controller activity recentres it.
- **K** opens section-coach capture; **T** runs the experimental physical AI pace tuner. These are development tools, not a complete port of the Python vector trainer.

## Contents

- `cars/` — custom raycast formula-car and tunable resource.
- `tracks/` — the copied 4,239.6 m Python circuit, 21 m road, 7.25 m kerbs, continuous collision, sand traps, five checkpoints and three DRS zones.
- `ai/` — curvature/braking speed profile and tactical pure-pursuit drivers.
- `scripts/` — session state, race rules, timing, penalties, DRS and classification.
- `ui/` — HUD, cockpit instrument, minimap, menu and cinematic camera.
- `assets/` — free-source assets and attribution record.

## September presentation overhaul

The car now has layered front/rear wings, detailed suspension and axles, attached rain light, original sponsor liveries, and a shared physical steering wheel with live display, RPM LEDs, articulated gloves and rear-view cameras. The ghost uses the complete body and four rolling wheels.

The HUD includes a measured acceleration circle, a single ring split into blue throttle, green brake and yellow G sectors, curved labels and a moving acceleration dot, top-left delta/sector timing and broadcast-style race-control messages. Driver names sit above competitors. Fonts and credits have been updated. The supplied white/red APEX logo is used throughout on a dark background; a responsive code-drawn version animates at launch and on every return to the menu.

Continuous fences, clipped inner kerbs, painted DRS boundaries, breakable foam brake boards, collidable detailed buildings, corrected stands and varied spectators surround the circuit. Eighty spaced 3D trees use optimized CC0 Poly Haven assets. A continuous 3D mountain landscape, green PBR ground, photographic sky, moving sunlight, reflections and material-specific roughness replace the earlier simple scenery.

**High** enables SSR, SSIL, SSAO, volumetric haze and 90% render scale. **Ultra** adds SDFGI, native scale and 4x MSAA. **Performance** uses 80% scale and disables those costly screen-space/GI/haze passes. All preserve 120 Hz vehicle physics. These are Godot rendering effects, not a hardware path-tracing implementation. The car, driver and crowd remain procedural art; a claim of complete photorealism would be inaccurate.

See [OVERHAUL.md](OVERHAUL.md) for the requirement-by-requirement result, [VALIDATION.md](VALIDATION.md) for measured performance, and [asset attributions](assets/ATTRIBUTIONS.md) for sources. A free CC0 source car remains in `assets/cars/` as an optional art reference; the tested default is the rebuilt original car.

Large model/HDR binaries use Git LFS. Install Git LFS and run `git lfs pull` after cloning. Small texture maps are ordinary Git files.

## Automated checks

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_checks.ps1 -Godot <path-to-godot-console.exe>` from the project directory. This bypass applies to that process only; it does not change the machine's execution policy. The suite checks geometry, physical handling, rules, menu/session transitions, clean laps, menu-field recovery a two-lap twelve-car grid-to-results race, and physical presentation regressions. Add `-Cases race_full` for the longer five-lap soak. Tests write only ignored artifacts, not the player's PB. Full details and direct commands are in [VALIDATION.md](VALIDATION.md).
