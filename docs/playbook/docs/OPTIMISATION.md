# OPTIMISATION: the menu, ordered by measured gain

Purpose: what to change to make a Godot Android game lighter, with the measured effect and where the evidence is.
Last verified: 2026-10-28
Read this when: you plan an optimisation pass or a size/memory budget.

Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz, Godot 4.7.2, Compat build, unless a line says desktop.
Full tables are in `docs/FINDINGS.md`.

## 1. Merge meshes and use MultiMesh (largest measured gain)
- Do: merge static ground and road boxes into one vertex-coloured mesh; put repeated scenery (trees, bushes, posts, clouds, hills) in MultiMeshes; one merged mesh per vehicle.
- Effect (desktop draw-call count, HIGH tier): total `161` to `42`; props `111` to `9`; road `14` to `3` (src: car/README.md).
- Evidence: `car/tests/draw_breakdown.gd` (hides one category at a time and reads `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`).
- Phone result with this scene: average draw calls `48` on both renderers (src: car/phone_test_results/20261028-123123/summary_gl.txt).
- Per-instance colour in a MultiMesh (`use_colors`) lets differently coloured instances share one draw.

## 2. Import textures as ETC2 or ASTC with mipmaps, at 2K for most assets
- Do: Import Mode = VRAM Compressed; `compress/high_quality=false` gives ETC2, `true` gives ASTC; `mipmaps/generate=true`; keep most assets at 2K.
- Effect at 8192 px: lossless load `1248.3` ms and `275.8` MB; ETC2 `195.8` ms and `62.4` MB; ASTC `377.3` ms and `105.1` MB (src: godot_lab/results/phone2_20261028-143502/bench_s5_8192_raw_a1_meta.txt; godot_lab/results/phone2_20261028-143502/bench_s5_8192_etc2_a1_meta.txt; godot_lab/results/phone2_20261028-143502/bench_s5_8192_astc_a1_meta.txt).
- Effect on a 21-texture model at 4K: ASTC load `1849` ms and `467.8` MB; lossless load `7058` ms and `1363.8` MB (src: godot_lab/results/phone4_20261028-153046_b/bench_s4_4k_a1_meta.txt; godot_lab/results/phone4_20261028-153046_b_c/bench_s4_4k_a2_meta.txt).
- The same model with 2K lossless textures: load `1900` ms, `355.8` MB (src: godot_lab/results/phone3_20261028-150837_b_c/bench_s4_2k_a1_meta.txt).
- Frame time stayed in the same band across all of these (p99 `17.98` to `18.46` ms in S4) (src: godot_lab/results/phone4_20261028-153046_b/summary_s4_4k_a1.txt; godot_lab/results/phone3_20261028-150837_b_c/summary_s4_2k_a1.txt).
- Size budget: ASTC 4x4 with mipmaps stores more bytes in the APK than lossless; use 2K or ETC2 when package size matters (FINDINGS section 7).

## 3. Quality tiers that change real work
- Do: tiers in one table of constants; each tier changes shadows, MSAA, render scale, optional scenery (src: car/README.md).
| Tier | Shadows | MSAA | 3D render scale | Optional scenery |
| --- | --- | --- | --- | --- |
| HIGH | 2048 atlas, 80 m | 2x | 100% | all |
| MEDIUM | 1024 atlas, 55 m | off | 100% | all |
| LOW | off | off | 80% | clouds, bushes, half the trees off |
- Effect (desktop draw calls): `~42` / `~38–40` / `~31` (src: car/README.md).
- Phone: MEDIUM was the default tier on the phone in the Mobile session (src: car/phone_test_results/20261028-125203_session2/summary_mobile.txt).

## 4. Pool and pre-allocate what spawns during play
- Do: build the traffic pool (`MAX_OBSTACLES` cars) before play; reuse scratch arrays in the logic step; replace per-event Tweens with a per-frame timer.
- Evidence: pool and reuse checks in `car/tests/test_integration.gd` (120 checks); the fairness run gives identical results before and after the change (200 seeds).

## 5. Warm-up pass behind a loading cover
- Do: draw every vehicle shape, the particle burst and each overlay once while an opaque cover is shown.
- Phone result with warm-up on: engine start to first playable frame `1477` to `1558` ms on Compat and `2523` to `2682` ms on Mobile (src: car/phone_test_results/20261028-123123/coldstart_gl_on.csv; car/phone_test_results/20261028-123123/coldstart_mobile_on.csv).
- Debug switches to compare: `--no-warmup` or the file `user://no_warmup` (src: car/README.md); the phone comparison is listed in `NEXT_EXPERIMENTS.md`.

## 6. Share materials
- Do: one material for all vehicles, colour in vertex colours (src: car/scripts/vehicle_mesh.gd header comment). This is part of the draw-call result in item 1.

## 7. Export arm64-only and keep native libraries compressed
- Do: `architectures/arm64-v8a=true`, others off; in Gradle presets set `compress_native_libraries=true`.
- Effect: Gradle debug APK `84.05` MB uncompressed libs vs `34.83` MB compressed (src: car/README.md).
- The non-Gradle arm64 debug APK is `28514723` bytes (src: car/build/road_dodge_debug.apk).

## 8. Measure with raw frame times; read p99, share over 20 ms and worst
- Do: `run/delta_smoothing=false`; log `Time.get_ticks_usec` differences; keep vsync on.
- At 60 Hz the share over 16.7 ms reads `36.88`% and `41.21`% on two near-empty scenes, so use the share over 20 ms (`0.72`% and `0.77`% there) (src: godot_lab/results/phone2_20261028-143502/summary_s5_512_raw_a1.txt; godot_lab/results/phone2_20261028-143502/summary_s5_1024_raw_a1.txt).
- The Road Dodge logger reads engine delta, so its p99 sits at `16.67` ms (src: car/phone_test_results/20261028-125203_session2/summary_mobile.txt); use the lab harness (`godot_lab/scripts/bench.gd`) for jitter.
- Memory: read Godot's own counters (`RENDER_TEXTURE_MEM_USED`) next to `dumpsys meminfo`; the lab logs both.

## Order of work for a new game
1. Merge static geometry and use MultiMesh. 2. Set texture import to ETC2/ASTC with mipmaps at 2K. 3. Add quality tiers. 4. Pool spawned objects.
5. Add the warm-up pass. 6. Export arm64-only. 7. Re-measure with the phone protocol after each step.
