# Human TODO — release/art review

Nothing must be imported to run this revision. The game boots with its own car, CC0 PBR surfaces, generated scenery and synthesized audio.

1. Play the rebuilt handling before launch: Time Trial → A/D, full braking, kerb entry, countersteering and all three cameras. Keyboard/controller feel needs a human driver; automated laps cannot certify that it feels right.
2. Review the downloaded CC0 source model in `assets/cars/cc0_f2002.glb` and creator-supplied `unbranded.png`. It is the **free f2002 demo** by som_natalino, not the paid pack. Its embedded material is branded: replace it with the unbranded texture before use. It is a low-poly candidate, not photorealistic final art. The original procedural car remains the tested default.
3. To integrate it or another CC0/CC-BY car, create a Node3D wrapper at `assets/cars/formula_car.tscn`. Use +X right, -Z forward, +Y up, metres. Create centred wheel nodes `Wheels/FL`, `Wheels/FR`, `Wheels/RL`, `Wheels/RR` at (-0.95,0.34,-1.62), (0.95,0.34,-1.62), (-0.95,0.34,1.83), (0.95,0.34,1.83). Axle roll is local X; steering is Y. The main scene loads this wrapper automatically and binds its wheels. Do not add another physics body/controller to it.
4. The downloaded mesh has generic component names and different axes/scale. Run `godot --headless --path . --script tests/inspect_model.gd` for component bounds, then reparent/align wheel assemblies and the active rear flap in Godot or Blender. The wrapper may implement `update_controls(steer, drs, brake, time)` and `set_camera_view(mode)`; the car calls those hooks. Preserve original liveries and remove real sponsor/team marks. Add any CC-BY author/source/license to credits.
5. Replace generated trees, paddock and driver art with licensed production assets for final visual quality. Select suitable engine recordings. Asphalt, grass and gravel PBR maps are already imported; no photographic backdrop wall is needed.
6. Before release, validate in Godot 4.6 if that exact version is mandatory (checks used installed 4.7.2), run sustained five-lap/controller tests on target machines, and export/sign/package. Short 720p captures do not certify every resolution or race situation.

See `VALIDATION.md` and `FEATURE_PARITY.md` for actual evidence and remaining gaps. Not every full-spec acceptance criterion is complete.
