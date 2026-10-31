# FINDINGS: measured results

Purpose: every measurement we hold, with its source file and measuring context.
Last verified: 2026-10-28
Read this when: you need a number to plan a budget, choose an import setting, or compare a new game with ours.

Values in backticks are extracted from the cited file by `tools/build_findings.py` and re-checked by `tools/check_playbook.py`.
Paths are relative to the workspace root (the folder that holds `car/`, `godot_lab/`, `godot_playbook/`).

## 1. Road Dodge on the phone: Mobile (Vulkan) vs Compat (OpenGL)
Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz; Road Dodge debug APKs; frame_ms from the engine delta (the Road Dodge logger); hand-played sessions.

| Metric (PLAYING frames only) | Mobile (Vulkan) | Compat (OpenGL) |
| --- | --- | --- |
| Frames logged / seconds | `26570` / `476.5` | `28618` / `540.5` |
| p99 frame_ms | `16.67` | `16.67` |
| Worst frame_ms | `25.77` | `16.67` |
| Share over 16.7 ms (%) | `0.3` | `0.0` |
| Frames over 25 ms / over 50 ms | `4` / `0` | `0` / `0` |
| Average draw calls | `48` | `48` |
| Cold start `am start -W` TotalTime, 5 launches (ms) | `428`, `642`, `600`, `614`, `658` | `469`, `527`, `580`, `546`, `612` |
| First launch after install TotalTime (ms) | `634` | `516` |
| Engine start to first playable frame, warm-up on, 5 launches (ms) | `2536`, `2613`, `2523`, `2605`, `2682` | `1483`, `1491`, `1537`, `1558`, `1477` |
| `dumpsys meminfo` TOTAL PSS / Graphics at session end (KB) | `452347` / `152336` | `318443` / `119768` |
| Battery temperature at session end (tenths of a degree C) | `309` | `305` |
| Quality tier of those frames | MEDIUM `26570` | HIGH `26799`, MEDIUM `1819` |

(src: car/phone_test_results/20261028-125203_session2/summary_mobile.txt; car/phone_test_results/20261028-123123/summary_gl.txt; car/phone_test_results/20261028-123123/cold_start_mobile.txt; car/phone_test_results/20261028-123123/cold_start_gl.txt; car/phone_test_results/20261028-123123/first_launch_mobile.txt; car/phone_test_results/20261028-123123/first_launch_gl.txt; car/phone_test_results/20261028-123123/coldstart_mobile_on.csv; car/phone_test_results/20261028-123123/coldstart_gl_on.csv; car/phone_test_results/20261028-125203_session2/meminfo_mobile_end.txt; car/phone_test_results/20261028-123123/meminfo_gl_end.txt; car/phone_test_results/20261028-125203_session2/system_mobile.txt; car/phone_test_results/20261028-123123/system_gl.txt)

## 2. Texture ladder (one full-screen textured quad, 30 s per cell)
Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz; godot_lab Compat build, Adreno 740; raw = Lossless import, etc2 = VRAM compressed, astc = VRAM compressed high quality; mipmaps on.

| Size | Format | Load ms | Godot texture memory MB | p99 frame ms | Share over 20 ms (%) |
| --- | --- | --- | --- | --- | --- |
| 512 | raw | `7.2` | `20.8` | `19.39` | `0.72` |
| 512 | etc2 | `1.1` | `19.9` | `18.86` | `0.44` |
| 512 | astc | `2.6` | `20.1` | `18.72` | `0.55` |
| 1024 | raw | `26.7` | `23.8` | `19.13` | `0.77` |
| 1024 | etc2 | `5.0` | `20.4` | `18.79` | `0.39` |
| 1024 | astc | `7.3` | `21.1` | `18.67` | `0.44` |
| 2048 | raw | `91.8` | `35.8` | `19.22` | `0.66` |
| 2048 | etc2 | `14.0` | `22.4` | `18.62` | `0.28` |
| 2048 | astc | `25.2` | `25.1` | `18.40` | `0.39` |
| 4096 | raw | `321.8` | `83.8` | `18.86` | `0.39` |
| 4096 | etc2 | `46.5` | `30.4` | `19.11` | `0.61` |
| 4096 | astc | `99.1` | `41.1` | `19.43` | `0.72` |
| 8192 | raw | `1248.3` | `275.8` | `18.45` | `0.55` |
| 8192 | etc2 | `195.8` | `62.4` | `19.06` | `0.50` |
| 8192 | astc | `377.3` | `105.1` | `18.88` | `0.44` |

(src: godot_lab/results/phone2_20261028-143502/summary_s5_<size>_<format>_a1.txt and godot_lab/results/phone2_20261028-143502/bench_s5_<size>_<format>_a1_meta.txt, one pair per row)

## 3. S4 heavy model: Poly Haven ship_pinnace (CC0), 60 s per run
Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz; godot_lab Compat build, Adreno 740; raw unsmoothed frame times.

| Metric | 2K lossless | 4K ASTC + mipmaps | 4K lossless |
| --- | --- | --- | --- |
| APK size (bytes) | `141417179` | `420440556` | `394043655` |
| Primitives per frame | `148960` | `148964` | `148965` |
| Draw calls per frame | `7` | `7` | `7` |
| Texture load ms | `1900` | `1849` | `7058` |
| First frame since engine start ms | `3238` | `2579` | `7774` |
| Godot texture memory MB | `355.8` | `467.8` | `1363.8` |
| `dumpsys` TOTAL PSS KB (end) | `301106` | `702361` | `399334` |
| `dumpsys` Graphics KB (end) | `132936` | `536384` | `234612` |
| p99 frame ms | `18.46` | `17.98` | `18.03` |
| Share over 20 ms (%) | `0.17` | `0.08` | `0.19` |
| Worst frame ms | `30.74` | `28.49` | `29.23` |
| Cold start `am start -W` TotalTime ms | `561` | `522` | `583` |
| Battery temperature start to end (tenths C) | `290` to `293` | `296` to `300` | `298` to `300` |

(src: summary_*, bench_*_meta, *_meminfo_end, *_launch, *_temp_* files in godot_lab/results/phone3_20261028-150837_b_c, godot_lab/results/phone4_20261028-153046_b, godot_lab/results/phone4_20261028-153046_b_c; APK sizes from godot_lab/builds/)

## 4. Fonts and text cost
Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz; godot_lab Compat build; Bungee + Noto Sans Devanagari + Noto Sans Arabic with a Latin, Devanagari, Arabic fallback chain.

| Scene | Seconds | p99 frame ms | Share over 20 ms (%) | Worst ms | Draw calls | Objects | Process ms avg | Render CPU ms avg |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| View 16 px | `75.0` | `18.18` | `0.20` | `30.76` | `9` | `185` | `2.41` | `0.73` |
| View 32 px | `75.0` | `18.18` | `0.24` | `25.74` | `9` | `185` | `2.40` | `0.71` |
| View 64 px | `75.0` | `18.21` | `0.27` | `24.86` | `9` | `185` | `2.26` | `0.74` |
| 200 Labels | `60.0` | `18.34` | `0.28` | `27.80` | `601` | `4641` | `7.53` | `5.28` |
| Counter Label (text changes every frame) | `60.0` | `17.94` | `0.08` | `43.70` | `3` | `14` | `3.54` | `0.66` |

Text server reported by the app on the phone: `ICU / HarfBuzz / Graphite (Built-in)`; shaping `true`, bidi `true`, variable fonts `true`.
Font file sizes in bytes: Bungee `118996`, Devanagari variable `641944`, Arabic variable `844676`.

(src: godot_lab/results/phone3_20261028-150837_b_c/summary_fonts_view_*_a1.txt; godot_lab/results/phone4_20261028-153046_b_c/summary_fonts_cost_a2.txt; godot_lab/results/phone4_20261028-153046_b_c/summary_fonts_cost_counter_a2.txt; godot_lab/results/phone3_20261028-150837_b_c/bench_fonts_view_16_a1_meta.txt; godot_lab/third_party/fonts/)

## 5. AdMob test ads (Google public test IDs)
Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz; godot_lab Compat build with Poing Studios godot-admob-plugin v5.1.0; callbacks logged by `godot_lab/scripts/ads_menu.gd`.

| Callback | ms since app start |
| --- | --- |
| sdk_initialized | `1884` |
| banner_load_started | `9264` |
| banner_loaded | `10573` |
| banner_impression | `10588` |
| interstitial_loaded | `11483` |
| interstitial_shown | `11531` |
| interstitial_impression | `11581` |
| rewarded_loaded | `12841` |
| rewarded_shown | `12890` |
| rewarded_impression | `12940` |
| reward_earned | `20614` |
| rewarded_dismissed | `23297` |
| interstitial_dismissed | `27225` |
| banner_hidden | `28769` |
| lifecycle APPLICATION_PAUSED / APPLICATION_RESUMED | `11500` / `27225` |

Frame times from the Godot loop while ads were up (derived file): banner visible `386` frames, p99 `19.12` ms, worst `32.88` ms; full-screen ad open `710` frames, p99 `18.04` ms; frames over 250 ms: `0`.

(src: godot_lab/results/phone3_20261028-150837_b_c/ads_log.csv; godot_playbook/data/ads_frame_stats.txt)

## 6. Draw-call history (Road Dodge, HIGH tier, playing, 4 cars)
Measured on: Apple M3 desktop (Metal, Forward Mobile) with `tests/draw_breakdown.gd`; table copied from the project README.

| Category | Before | After |
| --- | --- | --- |
| road | `14` | `3` |
| props (trees, bushes, posts) | `111` | `9` |
| clouds | `4` | `1` |
| hills | `5` | `1` |
| traffic | `6` | `6` |
| player | `2` | `2` |
| UI | `19` | `20` |
| total | `161` | `42` |
| Tier draw calls HIGH / MEDIUM / LOW (after) | `~42` / `~38–40` / `~31` | |

(src: car/README.md)

## 7. Package sizes
Measured on: file sizes of the exported artifacts on the Mac (bytes).

| Artifact | Bytes |
| --- | --- |
| Road Dodge debug APK (non-Gradle, arm64) | `28514723` |
| Road Dodge sideload APK (arm64, release-signed) | `26699716` |
| Road Dodge release AAB | `26673034` |
| godot_lab S4 2K APK | `141417179` |
| godot_lab S4 4K ASTC APK | `420440556` |
| godot_lab S4 4K lossless APK | `394043655` |
| godot_lab fonts + ads APK (no ship textures) | `46402805` |
| godot_lab textures-only APK | `213996383` |
| Gradle debug APK, native libs stored uncompressed / compressed (MB) | `84.05` / `34.83` |

(src: car/build/; godot_lab/builds/; car/README.md)
