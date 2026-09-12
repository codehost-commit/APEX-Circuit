# Validation — rebuilt development version

Windows; installed Godot 4.7.2 standard; Forward+/D3D12; NVIDIA Quadro T2000 Max-Q; Jolt; 120 Hz physics. Godot 4.6 has not been independently run.

| Check | Measured result |
|---|---|
| Track continuity | 4,239.5985 m; 1,500 full-loop collision/projection probes, zero gaps or spline jumps |
| Structure clearance | 4,500 chassis-volume sweeps across three driving lanes, zero obstructions |
| 0-100 km/h | 2.292 s |
| Speed at five seconds | 217.94 km/h, gear 5, four suspension contacts |
| Brake from 198 km/h | 34.83 km/h after two seconds, 62.40 m travelled |
| Steering | Right +5.355 m; left -5.357 m |
| Two physical solo laps | 97.948 s / 96.918 s, both valid without reset; maximum offset 4.009 m |
| Twelve-car menu, 100 simulated seconds | Zero recovery teleports; maximum offset 4.026 m; longest slow interval one second |
| Final five-lap race | All twelve finishers, results at 516.183 s; 6 s total penalties |
| Rules | 21 checks pass, including ordered timing gates, DRS detector timestamps, penalties, limits and PB/ghost persistence |
| Session/input flow | 15 checks pass, including actual UI signals, mode changes, camera modes, restart, qualifying and gamepad bindings |
| Presentation | 23 checks pass: upward terrain normals, units, mouse/controller look, twelve sponsor combinations, complete ghost wheels, mirror culling, DRS paint, absent sector boards, clear driving lanes, stable spawns, measured braking G/dot direction, actual marker collision/debris momentum, restart cleanup, debris timer isolation/lifetime and HUD bounds |

The final handling/lap/field/race runs include the integrator-pose suspension fix and collision-surface lookup optimization. The final presentation/flow runs additionally cover the supplied logo, reference-based HUD layout and wider/lower brake boards. Rule logic is unchanged since its passing run. Tests run headless at 120 fixed physics FPS; automated tests do not certify human driving feel or photorealism.

## Rendering evidence

Actual Forward+/D3D12 captures on the Quadro T2000 Max-Q, 1280 x 720 window:

| Capture | Preset | Result |
|---|---|---|
| Stationary car inspection | High, 90% scale, 2x MSAA | 60 FPS; p95 16.67 ms; about 1,619 MiB reported GPU memory |
| Stationary car inspection | Ultra, native scale, 4x MSAA, SDFGI | 60 FPS; p95 16.67 ms; about 2,171 MiB reported GPU memory |
| T-cam with both live rearview cameras | High | 57 FPS; p95 19.44 ms; about 1,658 MiB reported GPU memory |
| Twelve-car flying menu | High | 36-40 FPS across final views; p95 31.25-31.64 ms; about 1,546-1,615 MiB reported GPU memory |
| Moving T-cam, supplied logo and reference HUD | High | 49 FPS; p95 22.42 ms; about 1,665 MiB reported GPU memory |

These are short, view-dependent captures, not sustained benchmarks or a promise of 60 FPS in a full race. Some ran alongside headless checks and the open editor. Initial detailed-world menu captures were 6-16 FPS; moving visual animation out of the physics loop, avoiding idle particle-material updates, and using collision surface metadata instead of four redundant spline searches per car improved the measured menu result. Earlier revision claims of 60 FPS in every captured camera are superseded by this table. Hardware path tracing, full dynamic weather and photorealistic character art remain outside the implemented result; see [OVERHAUL.md](OVERHAUL.md).

## Reproduce

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_checks.ps1 -Godot 'C:/path/to/Godot_console.exe'
```

`Bypass` applies only to this test process, not the system execution policy. Append `-Cases race_full` to run the full five-lap soak instead of the default suite.

Individual case (absolute log paths on Windows):

```text
godot --headless --path . --fixed-fps 120 --log-file C:/absolute/path/apex-check.log tests/drive_checks.tscn -- --case=basics
```

Cases: `basics`, `rules`, `flow`, `lap`, `field`, `race`, `race_full`, `presentation`; `fieldquick` is a 30-second diagnostic. `all` runs basics/lap/field/rules/flow; the PowerShell runner additionally runs the two-lap race. Physical lap/race cases take longer than rule checks. PB files and captures stay in ignored `tests/artifacts/`, not player saves. Unknown case names fail rather than reporting an empty success.

Normal-scene screenshot arguments: `--session=time_trial --autodrive --camera=0 --capture=C:/absolute/path/frame.png --capture-after=10`. Cameras 0/1/2 are chase/T-cam/cockpit; 3 is stationary car inspection. Omit session to capture the menu. Add `--quality=0`, `1` or `2` for Performance/High/Ultra, or `--ui=settings` / `--ui=credits` for those menu panels. Run `tests/presentation_checks.tscn` directly for presentation checks; the runner selects that scene automatically.

The rules deliberately move controlled poses to isolate timing. Their artificial 70.66-second traversal is **not a driven lap** and not evidence of 75-second human pace. The separate lap test uses physical inputs only.

Restricted headless runs emitted a Windows root-certificate-store warning; script checks completed. GUI/editor imports also ran outside that restriction. See FEATURE_PARITY.md and HUMAN_TODO.md for remaining work.

The flow harness initially hit a native shutdown crash when destroying the world immediately after many synchronous body resets. It now advances three physics frames before shutdown; repeated runs exit successfully. The engine-level cause has not been independently isolated. Normal UI transitions are frame-separated, but this is another reason to test the exact target Godot version before release.
