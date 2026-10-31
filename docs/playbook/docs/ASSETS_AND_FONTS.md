# ASSETS_AND_FONTS: asset pipeline, texture budgets, fonts

Purpose: where our assets come from, how to import them, and the font setup measured on the phone.
Last verified: 2026-10-28
Read this when: you add models, textures or fonts to a game, or write its licence table.

Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz, Godot 4.7.2, Compat build (godot_lab).

## Sources and licences we use (src: godot_lab/LICENSES.md)
| Source | Use | Licence | How we fetch |
| --- | --- | --- | --- |
| Poly Haven (https://polyhaven.com) | 3D models and textures | CC0 1.0 | API manifest `https://api.polyhaven.com/files/<id>` via `godot_lab/tools/fetch_polyhaven.py` (sends a descriptive User-Agent) |
| Kenney (https://kenney.nl/assets) | low-poly packs | CC0 | download in a browser, place the zip in `third_party/manual/` |
| Quaternius (https://quaternius.com) | low-poly and animated packs | CC0 | download in a browser, place the zip in `third_party/manual/` |
| Google Fonts / Noto (https://github.com/google/fonts, `ofl/`) | fonts | SIL OFL 1.1 (each folder holds `OFL.txt`) | `curl` of the raw file |
| Poing Studios godot-admob-plugin | ads plugin | MIT | GitHub release asset (see `ADS.md`) |

## The LICENSES.md habit
- One row per download: name, source URL, licence, download date, SHA-256 (`shasum -a 256`).
- For multi-file downloads keep a per-file log next to the files (`third_party/polyhaven/<id>/DOWNLOAD_LOG_*.txt`).
- Use an asset only when its licence is confirmed on the source page; copy each OFL.txt next to its font.
- Put downloads in `third_party/<source>/`; add a `.gdignore` to folders Godot should not scan (archives, extracted plugin copies).

## Import settings that worked
- Textures: select the format per file in `<file>.import`: `compress/mode=2` (VRAM Compressed), `compress/high_quality=false` for ETC2 or `true` for ASTC, `mipmaps/generate=true`; `compress/mode=0` is Lossless (src: godot_lab/tools/set_import_modes.py).
- Project setting `textures/vram_compression/import_etc2_astc=true` enables both mobile formats.
- glTF models: keep `.gltf`, `.bin` and `textures/` together under `res://third_party/<source>/<asset>/<res>/`; in code `load(path) as PackedScene`, instantiate, read bounds from `MeshInstance3D.get_aabb()`.
- Run `godot --headless --path . --import` after adding or changing files; changing a `.import` file re-imports the texture.
- Presets pick content with `exclude_filter` (for example one preset per texture size) so each APK holds only what a test needs.

## Texture budgets from the ladder (src: godot_lab/results/phone2_20261028-143502/bench_s5_*_a1_meta.txt)
Scene texture memory with one texture of that size (Godot counter, MB) and load time (ms):
| Size | Lossless | ETC2 | ASTC |
| --- | --- | --- | --- |
| 2048 | `35.8` MB, `91.8` ms | `22.4` MB, `14.0` ms | `25.1` MB, `25.2` ms |
| 4096 | `83.8` MB, `321.8` ms | `30.4` MB, `46.5` ms | `41.1` MB, `99.1` ms |
| 8192 | `275.8` MB, `1248.3` ms | `62.4` MB, `195.8` ms | `105.1` MB, `377.3` ms |
- Every size and format rendered correctly on the phone (`render_ok=true` in each meta file).
- Practice: 2K as the default texture size; ETC2 for the smallest memory, ASTC when quality matters; reserve 4K for hero assets.

## Heavy-model scene (S4) in numbers (src: godot_lab/results/phone3_20261028-150837_b_c/summary_s4_2k_a1.txt)
- A Poly Haven ship at 2K textures renders `148960` primitives in `7` draw calls per frame, p99 `18.46` ms.

## Fonts
- Text server on the phone: advanced (`ICU / HarfBuzz / Graphite (Built-in)`), shaping, bidi and variable fonts reported `true` (src: godot_lab/results/phone3_20261028-150837_b_c/bench_fonts_view_16_a1_meta.txt).
- Fonts used (OFL): Bungee Regular (Latin display), Noto Sans Devanagari (variable), Noto Sans Arabic (variable).
- Setup in `godot_lab/scripts/fonts_scene.gd`: load each font with `load()`, `duplicate()` it, then set properties; build one chain `Bungee -> Devanagari -> Arabic` through `FontFile.fallbacks`.
- Settings: gray antialiasing, light hinting, automatic subpixel positioning, no MSDF, no mipmaps, `allow_system_fallback=false`, whole files (no subsetting).
- Rationale: hinting suits fixed on-screen sizes; an own fallback chain keeps every script in files we ship and license.
- File sizes (bytes): Bungee `118996`, Devanagari `641944`, Arabic `844676`; compressed in the APK `1000767` bytes for the three together (src: godot_playbook/data/font_apk_cost.txt; godot_lab/third_party/fonts/).
- Test strings (src: godot_lab/scripts/fonts_scene.gd): Hindi words with conjuncts and matras, a mixed line `Score: १२३ / Best: 123`, an Arabic RTL line, and one Label mixing Latin, Devanagari and Arabic.
- Text cost on the phone: 200 Labels use `601` draw calls and render CPU `5.28` ms; a Label changing every frame stays at `3` draw calls (src: godot_playbook/docs/FINDINGS.md).
- Screenshots for human review of the shaping: `godot_lab/results/phone3_20261028-150837_b_c/screen_font_*.png`. The developer judges how Devanagari and Arabic look.

## Run the lab scenes for a new asset
1. Textures: `godot --headless --path . --script tools/gen_textures.gd`, `python3 -I tools/set_import_modes.py`, `godot --headless --path . --import`.
2. New model: add it under `third_party/`, add a scene id to `_spec_for` in `scripts/main.gd` and to `markers.txt` and the list in `PLAN.md`, add a preset with an `exclude_filter`, export, then follow `docs/PHONE_TEST_PROTOCOL.md`.
3. Read results with `python3 -I tools/summarize_bench.py <bench csv>`.
