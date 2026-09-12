# Python → native 3D status

The full prompt outranks the artifact plan. The later request to copy ZIP handling/circuit outranks conflicting starting-tune suggestions in the earlier prompt.

| Area | This revision |
|---|---|
| Circuit | All 60 authored points; rounded 4,239.6 m route; 21 m road; 7.84 m kerbs; original five gravel regions |
| Surfaces | Contact sampling: asphalt 1.0, kerbs 0.58, grass 0.38, gravel 0.52; off-road rolling resistance and dust |
| Handling | Prototype combined-slip axle/bicycle tyre forces in Jolt, four suspension rays, load transfer, split-grip yaw, lock/spin indicators, handbrake, reverse and damage |
| Powertrain | 798 kg, 735 kW, 14.5 kN drive limit, prototype seven-speed spacing, wheel/gear RPM, automatic/manual shifting, limiter, physical aero and DRS |
| Time Trial | Unlimited attempts, ordered gates, invalid laps, three interpolated sectors, session/PB times, saved ghost and live delta |
| Weekend | Physical five-minute qualifying, best valid laps determine grid, skip, twelve cars, five-light launch, jump starts, five-lap default race, results |
| Race control | Checkpoints, all-four-off limits, deferred fault penalties for any driver, retirement, checkpoint recovery, penalty-adjusted classification |
| Gaps | Interpolated passage-time history. DRS detection still estimates its one-second gap from distance/reference speed |
| AI | Same physical car, curvature/braking profile, pure pursuit, smoothed tactics, final-target alongside corridor, track-space following around corners, pace variation |
| UI | Live RPM/gear/speed/input/tyre telemetry, sectors, standings, minimap, DRS, messages, pause/settings/results; cockpit-only wheel readout |
| Cameras/menu | Collision-swept chase, T-cam, driver-eye cutaway; floating overlay, physical flying field, low/aerial shots, fades and proximity shake |
| Art/audio | Original procedural body, independent wheels, active flap, physical gantry/stands/paddock/fences/trees/pebbles/terrain; CC0 PBR textures; synthesized RPM audio |
| K coach | Native 24-section clean-run bank and persistence, not the full Python coach replay/blending system |
| T training | Experimental same-physics pace search with valid-lap selection/persistence, not the NumPy/vector evolutionary trainer |

## Deliberate differences and remaining gaps

- Seven-speed/20,000 RPM prototype tune replaces the older suggested eight-speed/15,000 RPM tune.
- Tyres retain the prototype tanh combined-slip axle model. Wheel lock/spin/rotation use an implicit rolling approximation, **not** a full independent per-wheel Pacejka/angular-inertia simulation. Some advanced tuning fields remain reserved.
- No 75-second human lap has been demonstrated. The ZIP's physical AI envelope itself is about 93.49 s; measured Godot clean AI laps are about 97 s. The track was copied, not redrawn to force a time.
- AI finishes races but occasional contact remains. No guarantee of perfectly clean racing against arbitrary player inputs.
- No dedicated proximity-only forced-off adjudication beyond contact attribution and victim limits protection.
- No fuel/pit strategy, tyre temperature/wear, component-level failures, weather or multiplayer was added.
- Final photorealistic art, real recordings, baked GI, motion blur, exhaustive performance/release QA and packaging remain. The downloaded external car awaits pivot/camera integration and is not the tested default.

This records implemented code; it does not claim every full-spec acceptance criterion is met.
