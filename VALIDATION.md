# Validation — rebuilt development version

Windows; installed Godot 4.7.2 standard; Forward+/D3D12; NVIDIA Quadro T2000 Max-Q; Jolt; 120 Hz physics. Godot 4.6 has not been independently run.

| Check | Measured result |
|---|---|
| Original track | 4,239.5985 m; five checkpoints, three sectors, three DRS zones |
| Continuity | 1,500 full-loop ray probes; zero missing collisions or spline jumps |
| 0–100 km/h | 2.292 s |
| Speed at five seconds | 217.94 km/h, gear 5, four suspension contacts |
| Brake from 198 km/h | 34.83 km/h after two seconds, 62.40 m travelled |
| Steering | Right command +5.355 m right displacement; left -5.357 m |
| Two physical solo laps | 97.918 s / 96.760 s, both valid without reset; maximum offset 4.01 m |
| Twelve-car menu, 100 simulated seconds | Zero recovery teleports; max offset 3.98 m; brief hairpin slowdowns but no sustained stuck car |
| Twelve-car race | All twelve finished two laps; latest run reached final results at 219.975 s; three adjudicated incidents, 11 s total penalties; no false jump-start penalty with brake held |
| Rules | Ordered gates, sector sum, shortcut rejection, five lights, jump-start deduplication, DRS detection/exit/brake close, deferred aggressor penalty, penalty reorder, passage-time gaps, limits, reset/damage policy, ghost save/load all pass |
| Actual GPU captures | Chase/T-cam/cockpit/menu reached 60 FPS at 1280×720 window, 0.85 3D scale, 2× MSAA; sampled p95 delta 16.67 ms; final chase/menu approximately 527/555 MiB GPU memory |

These are short rendering captures, not a sustained benchmark or evidence of native 1080p performance, launch quality or gamepad feel. Some captures ran alongside headless tests. The first menu capture was 6 FPS; exact-pose projection caching and static-mesh batching addressed its major overhead.

## Reproduce

```powershell
./tests/run_checks.ps1 -Godot 'C:/path/to/Godot_console.exe'
```

Individual case (absolute log paths on Windows):

```text
godot --headless --path . --fixed-fps 120 --log-file C:/absolute/path/apex-check.log tests/drive_checks.tscn -- --case=basics
```

Cases: `basics`, `rules`, `lap`, `field`, `race`; `fieldquick` is a 30-second diagnostic. `all` runs basics/lap/field/rules; the PowerShell runner additionally runs race. Physical lap/race cases take longer than rule checks. PB files and captures stay in ignored `tests/artifacts/`, not player saves.

Normal-scene screenshot arguments: `--session=time_trial --autodrive --camera=0 --capture=C:/absolute/path/frame.png --capture-after=10`. Cameras 0/1/2 are chase/T-cam/cockpit; 3 is stationary car inspection. Omit session to capture the menu.

The rules deliberately move controlled poses to isolate timing. Their artificial 70.66-second traversal is **not a driven lap** and not evidence of 75-second human pace. The separate lap test uses physical inputs only.

Restricted headless runs emitted a Windows root-certificate-store warning; script checks completed. GUI/editor imports also ran outside that restriction. See FEATURE_PARITY.md and HUMAN_TODO.md for remaining work.
