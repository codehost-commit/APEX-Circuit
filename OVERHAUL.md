# September presentation overhaul

This records the implementation against the supplied change list. See [VALIDATION.md](VALIDATION.md) for reproducible checks and measured performance.

| Requested area | Implemented behavior |
|---|---|
| Car, axles and wings | Layered front wing, cascades, slotted endplates, floor vanes, rear aero, calipers, uprights, tie rods, crash structure, exhaust and an attached rear light housing |
| Shared steering wheel | The same 3D grips, paddles, buttons, live OLED, brake-bias display and RPM LEDs appear in cockpit and T-cam |
| Driver and hands | Gloved fingers/palms, seams, articulated forearms, visible driver/helmet in external views; cockpit only hides the head that obstructs the camera |
| Mirrors | Two rear-facing world cameras render to the actual mirror surfaces; player geometry is excluded from reflection cameras |
| Ghost | Complete translucent car body, four tyres, steering and wheel roll; newer recordings include pitch/roll/steering/DRS while older recordings remain readable |
| Acceleration HUD | Reference-matched single annulus with three sectors, curved labels, blue throttle, green brake, yellow G fill, translucent centered car and orange trail dot; measured body-frame acceleration, current/peak G numbers and a 5 G dot range |
| HUD cleanup | Redundant throttle/brake bars and LAT/LONG fields removed from lower instruments; delta and current sector moved into upper-left timing; announcements wrap in a race-control panel |
| AI labels | Depth-tested billboard driver names above competitors |
| Menu/settings/credits | Three included fonts, redesigned heading/tagline, removed original metadata footer, saved metric/imperial and mouse-look settings; Rahul Awasthi, Game Development Head; Pritam Avuthu, Marketing Head |
| Input detection | Keyboard/mouse activity enables cursor-following cockpit look; controller activity recentres the camera |
| Sponsors | User-supplied APEX logo adapted onto a dark background across menus, startup/icon, wheel display, cars and circuit; two generated fictional sponsor atlases; track-specific signs/gantry/garages and twelve unique car sponsor combinations, including car-only identities |
| Text clipping/z-fighting | Logos use padded textured panels with physical separation; UI labels wrap and remain within their panels |
| Fences | Closed offset polygons resolve sharp joins, then continuous resampling builds posts, rails, mesh wires and collisions, including the closing seam |
| Kerbs | Width reduced from 7.84 m to 7.25 m; curvature caps the inner ribbon to prevent folded strips at tight bends |
| DRS and sectors | Six physical painted boundary lines replace the DRS signs; sector boards removed while sector timing stays functional |
| Brake markers | Reference-matched low, wide white blocks (1.65 x 0.88 x 0.26 m) with heavy black 150/100/50 numerals; an actual car impact releases twelve rigid foam pieces with velocity, impact direction, torque, gravity and ground collisions; restart restores boards |
| Buildings/stands | Collidable varied service buildings, garage joints/windows/HVAC, control tower, marshalling posts, tyre stacks, light poles, corrected stand direction and track-clear placement |
| Trees/background | Eighty spaced 3D trees using a broadleaf model and three conifer variants; continuous, smoothly lit 3D hills surround the circuit, with green textured grass below |
| Crowds | Varied seated/standing 3D spectators with separate limbs, faces, hair, glasses and clothing colors, instanced in stands and spectator areas |
| Particles | World-space tyre plumes with surface-dependent dust colors, velocity inheritance, turbulence, drag, growth and fading; individual board fragments use rigid-body physics |
| Lighting/materials | Photographic HDR sky, slowly moving sun, cascaded soft shadows, ACES, reflection probe, differentiated carbon/paint/metal/concrete/asphalt/grass/gravel response; optional SSR, SSIL, SSAO, volumetric haze and SDFGI |
| Floating/reset/AI conflicts | Suspension queries use the integrator's current transform; reset clears stale control/acceleration/tactical state; corner anticipation and deterministic side-by-side separation reduce tactical collisions |

## Practical limits

The original body, driver and spectators have been improved in code, but are still procedural models. They are not photorealistic scanned people, and the car is an original 2018-inspired design rather than a verified replica of a specific constructor's chassis. The landscape has real depth and textured surfaces; its landforms remain generated.

Ultra enables Godot's [signed-distance-field global illumination](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html); High/Ultra use screen-space reflections and illumination. Hardware-accelerated triangle ray tracing/path tracing is not implemented. The HDR cloud image is static, with moving direct sunlight and volumetric haze; a complete dynamic weather or cloud-fluid simulation is not implemented.

Smoke is a GPU particle approximation. Board destruction uses predefined foam fragments and physical impulses, not arbitrary mesh fracture or a soft-body solver. AI completes the tested races but occasional contact/penalties remain possible. Rendering performance varies with view, hardware, resolution and graphics preset; the measured results are reported rather than claiming a locked 60 FPS everywhere.

## Review

Open the game, start Time Trial, and cycle C through chase, T-cam and cockpit. Settings are available from the menu/pause flow. Original generated images and their application are documented in [assets/sponsors/README.md](assets/sponsors/README.md). Downloaded art and font licenses are listed in [assets/ATTRIBUTIONS.md](assets/ATTRIBUTIONS.md).
