# Project art

- `textures/`: imported 1K CC0 asphalt, grass and gravel albedo/normal/roughness maps, approximately 8 MB.
- `hdris/`: retained Hochsal Field CC0 reference. The active scene uses procedural sky and real terrain.
- `cars/cc0_f2002.glb` and `unbranded.png`: free CC0 source car and creator-supplied replacement texture. Not the active car. Embedded original material is branded; see `../HUMAN_TODO.md` before integration.
- Default car/scenery are original generated meshes; engine/tyre audio is synthesized.

Optional art wrapper: `cars/formula_car.tscn`, with centred nodes `Wheels/FL`, `Wheels/FR`, `Wheels/RL`, `Wheels/RR`. Exported `art_root`, `visual_scene` and `wheel_visual_paths` also support manual wiring.

Record external sources in `ATTRIBUTIONS.md`. CC-BY assets also need in-game credit.
