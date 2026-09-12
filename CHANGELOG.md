# Changelog

## Unreleased

### Prototype-based revamp

- Replaced DRS distance/speed estimates with interpolated physical detection-line timestamps, including same-tick ordering and recovery reset tests.
- Validated a complete twelve-car five-lap race; added session/button/camera/input regression checks and a Windows-compatible test-runner command.
- Rebuilt vehicle around ZIP SI-unit handling, correct A/D, seven gears, RPM, suspension, slippery surfaces, DRS, braking/reverse and damage.
- Copied original 60-point 4.24 km circuit, wide kerbs and sand; rebuilt collision, physical gantry, paddock, stands, barriers and terrain.
- Added real Time Trial/PB/ghost, ordered checkpoint/sector timing, physical qualifying/grid, deferred penalties, live passage-time gaps and results.
- Rebuilt HUD/cockpit/menu/cameras, input/controller mapping, section-coach capture and experimental pace trainer.
- Imported CC0 PBR maps; downloaded free CC0 car plus unbranded texture for art replacement. Fixed procedural body visibility and batched static detail.
- Added physical handling/lap/field/race tests and GPU captures. VALIDATION.md records numbers; FEATURE_PARITY.md records remaining gaps.

### Historical baseline scaffold (superseded)

The old phase list below records scaffold additions, not verified acceptance of the full prompt or release readiness. The revamp and actual validation supersede those claims.

- Phase 7: CC0 HDRI world lighting, ACES/glow/SSAO rendering defaults, optional SSR/SDFGI switches, surface drag, and MultiMesh/visibility-range trackside LOD pass for the 30 FPS target.
- Phase 6: cinematic menu over the live AI field, alternating kerb/aerial drone shots with fade cuts, and Qualifying/Race/Quit flow into the real session.
- Phase 5: live HUD, timing/leaderboard/minimap, penalty and incident messages, start lights, results panel, plus cockpit-only steering-wheel/shift-LED display.
- Phase 4: qualifying/grid flow, five-light launch, valid lap/sector timing, DRS detection/zones, live classification, collision attribution, deferred penalties, track limits, recovery, and finish state.
- Phase 3: curvature-aware racing-line speed envelope, pure-pursuit AI field, lane-smoothing, passing/defending and side-by-side anti-encroachment corridor.
- Phase 2: original drivable Apex Loop with generated road collision, surface grip/drag zones, legal kerbs, Path3D line, checkpoints, progress, and lap-distance helpers.
- Phase 1: custom four-raycast formula car, load-sensitive friction-circle tyres, independent suspension, RWD powertrain, DRS, keyboard/gamepad-ready inputs, and chase/cockpit cameras.
- Phase 0: Godot skeleton, Jolt project configuration, input map, game singletons, and a boot scene.
