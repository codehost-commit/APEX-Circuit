# Materials and lighting

The shipped prototype uses compact procedural `StandardMaterial3D` colours so the scene works before art arrives. `WorldEnvironment` uses a 1K CC0 Poly Haven HDRI, ACES tonemapping, modest glow and SSAO.

Performance defaults intentionally leave SSR and SDFGI off. Toggle the exported `RaceConfig.enable_ssr` and `RaceConfig.enable_sdfgi` only after profiling the target Quadro T2000; generated barriers/trees already use `MultiMeshInstance3D` and visibility-range LOD.

When replacing placeholders, create `.tres` PBR materials here rather than assigning textures directly inside unrelated scenes. Keep asphalt, kerb, grass, gravel and carbon surfaces separate.
