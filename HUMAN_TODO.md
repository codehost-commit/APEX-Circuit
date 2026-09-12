# ⚠ HUMAN TODO — asset/editor handoff

The playable slice has deliberately generated gray-box visuals so it runs with no external art.

1. Install/open with the Godot 4.6 standard build and confirm **Project Settings → Physics → 3D → Physics Engine = Jolt Physics**. The project is already configured for it.
2. For final art, place only appropriately licensed CC0/CC-BY files below `assets/`, including their source URL, author, license, and attribution in `assets/ATTRIBUTIONS.md`.
3. Import one open-wheel model with separately addressable body and four wheels. In the car scene, assign it to the exported `art_root` / `wheel_visual_paths` properties of `RaycastFormulaCar`; retain the collision/physics root.
4. The project now includes a compact 1K CC0 Poly Haven HDRI. Add CC0 asphalt, kerb, grass, gravel and carbon-fibre textures from ambientCG/Poly Haven, then replace the procedural material colours with `.tres` PBR materials. See `assets/README.md` for exact targets.
5. When art is ready, select the Forward+ rendering method, then profile SSR/SDFGI versus baked lighting on the Quadro T2000 and keep whichever holds 30 FPS.
