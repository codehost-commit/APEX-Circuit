# Asset provenance

No paid assets were purchased. The downloaded art assets in this table are offered under CC0 by their creators; fonts use the separate OFL licenses listed below.

| Asset | Creator | Source | Use |
|---|---|---|---|
| Asphalt Track, 1K | Dimitrios Savva | https://polyhaven.com/a/asphalt_track | Road albedo, OpenGL normal, roughness |
| Grass Ground, 1K | Charlotte Baglioni | https://polyhaven.com/a/grass_ground | Terrain albedo, OpenGL normal, roughness |
| Gravel Floor, 1K | Jenelle van Heerden / Matterfield | https://polyhaven.com/a/gravel_floor | Gravel albedo, OpenGL normal, roughness |
| Hochsal Field, 1K | Adrian Kubasa | https://polyhaven.com/a/hochsal_field | Retained HDRI reference, not active sky |
| Island Tree 02, 2K | Rico Cilliers / Rob Tuytel | https://polyhaven.com/a/island_tree_02 | Optimized active 3D broadleaf tree and PBR maps |
| Pine Sapling Small, 2K | Rico Cilliers / Rob Tuytel | https://polyhaven.com/a/pine_sapling_small | Three active conifer variants and PBR maps |
| Kloofendal 48d Partly Cloudy (Pure Sky), 2K | Greg Zaal / Jarod Guest | https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky | Active HDR sky, ambient illumination and reflections |
| Free f2002 demo | som_natalino | https://som-natalino.itch.io/iconic-open-wheelers-low-poly-car-pack | Optional source car and unbranded texture, not active visual |

Poly Haven license: https://polyhaven.com/license

The f2002 page marks the asset CC0 1.0 and offers the model as a free demo separately from the paid pack. Only that demo was downloaded. The GLB retains its original embedded material; use the included unbranded texture before integrating it. The default game renders no real-world branding.

All nine Poly Haven maps were checked against MD5 values from the provider's file API. Default car, track/props, shaders, UI and synthesized audio are original project code.

## Tree conversion

The 2K glTF sources and dependencies were downloaded through the Poly Haven file API with source MD5 verification. Runtime GLBs were simplified with [gltfpack](https://meshoptimizer.org/gltf/), version 1.2: island `-si 0.12`, pine `-si 0.15`, both with `-sp -se 0.02 -kn -noq`. Original maps are retained. Godot generates further mesh LODs; regional MultiMeshes provide culling and instancing. Original downloads remain in ignored `assets/reference/`; optimized GLBs and their Godot-extracted image dependencies are committed in `assets/nature/`.

## Fonts and original artwork

Barlow Condensed (Jeremy Tribby), Rajdhani (Indian Type Foundry), and IBM Plex Mono (IBM) came from the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl). Each font's SIL Open Font License is included beside its TTF in `assets/fonts/`. Barlow Condensed SemiBold Italic is used for display text, Rajdhani SemiBold for UI text, and IBM Plex Mono Medium for instruments.

Fictional sponsor atlases were generated with the built-in image generation tool and applied as image panels on car bodywork, gantries and circuit furniture. Generation briefs and output paths are recorded in [sponsors/README.md](sponsors/README.md). These are original fictional identities, with no intended real team or sponsor affiliation. Brake-board numerals were rasterized with the installed Arial Black font using `tests/bake_brake_markers.gd`; no system font binary is distributed. The script uses DejaVu Sans as a fallback on other systems. The supplied APEX logo replaces the generated APEX atlas tile at runtime; see [branding/README.md](branding/README.md).
