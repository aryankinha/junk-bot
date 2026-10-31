# STACK: engine and project setup

Purpose: the engine settings, presets and architecture that worked across Road Dodge and the lab.
Last verified: 2026-10-28
Read this when: you create a project skeleton or change export settings.

## Engine and tools
- Godot 4.7.2 stable, GDScript. Android export templates `4.7.2.stable` installed (Editor Settings).
- JDK 17 for Gradle: set `export/android/java_sdk_path` to the zulu-17 home (Editor Settings, `editor_settings-4.7.tres`).
- Gradle template: unzip the official `android_source.zip` of the same Godot version into `android/build` and write
  `android/.build_version` (`4.7.2.stable`) (src: car/android/.build_version).
- Versions in the template: Gradle 8.11.1, AGP 8.6.1, compileSdk 36, minSdk 24, targetSdk 36, build-tools 36.1.0
  (src: car/android/build/config.gradle; car/android/build/gradle/wrapper/gradle-wrapper.properties).

## project.godot settings used (src: godot_lab/project.godot)
```
run/delta_smoothing=false                          ; raw frame times for measurement
window/size/viewport_width=720  viewport_height=1280
window/stretch/mode="canvas_items"  window/stretch/aspect="expand"
window/handheld/orientation=1                      ; portrait lock
renderer/rendering_method="gl_compatibility"       ; Compat default
renderer/rendering_method.mobile="gl_compatibility"; keep Compat on Android (Android applies a built-in .mobile override)
renderer/rendering_method.mobile_cmp="mobile"      ; opt-in Mobile build via preset custom_features="mobile_cmp"
textures/vram_compression/import_etc2_astc=true
```
- 60 fps cap: `run/max_fps=60` (src: car/project.godot); the lab leaves it unset and records `refresh_hz` in each result.
- Road Dodge uses the inverse pair: `renderer/rendering_method="mobile"` plus `renderer/rendering_method.gl_compat="gl_compatibility"`
  selected by preset `Android Compat (GL)` with `custom_features="gl_compat"` (src: car/project.godot; car/export_presets.cfg).

## Export presets (src: car/export_presets.cfg; godot_lab/export_presets.cfg)
| Preset | Output | Notes |
| --- | --- | --- |
| Android | `build/road_dodge_debug.apk` | non-Gradle debug APK, arm64 |
| Android Compat (GL) | `build/road_dodge_gl_debug.apk` | feature tag `gl_compat`, package id with `.gl` suffix |
| Android Sideload (arm64) | `build/road_dodge_sideload_arm64.apk` | release APK for sideloading |
| Android Release AAB | `build/road_dodge_release.aab` | `gradle_build/use_gradle_build=true`, `export_format=1` |
| Lab presets | `builds/lab_*_debug.apk` | one preset per asset set; `exclude_filter` selects the content |
- `architectures/arm64-v8a=true`, the other three `false`.
- `exclude_filter="tests/*, build/*, android/*, tools/*, docs/*"` keeps dev folders out of every export.
- Package ids: one production id (`com.aryankinha.roaddodge`); test variants add a suffix (`.gl`); lab app `com.aryankinha.labtest`.
- Launch with the exported alias `com.godot.game.GodotAppLauncher` in `am start -W -n <pkg>/com.godot.game.GodotAppLauncher`
  (src: car/phone_test_results/20261028-122527/02_manifest_activities.txt).
- Gradle APK size: native libs stored compressed (`compress_native_libraries=true`) give the smaller artifact (see FINDINGS section 7).

## Folder layout
```
Main.tscn  scenes/  scripts/  tests/  tools/  docs/  export_presets.cfg  project.godot  build/ (git-ignored, .gdignore)
```
- `build/.gdignore` stops Godot scanning exports and scratch files; add `*.jks`, `*.keystore`, `*.idsig`, `/build/` to `.gitignore`.
- After adding a `class_name` script run `godot --headless --path . --import` once.

## Architecture that worked (src: car/README.md; car/scripts/)
- `game_logic.gd`: pure `RefCounted` model (lanes, spawning, scoring, collisions), signals out, no nodes.
- `main.gd`: builds the world from code, syncs the logic model to nodes, owns input, camera, tiers, warm-up, traffic pool.
- `vehicle_mesh.gd`: merged vertex-coloured meshes with one shared material; boxes use clockwise front faces and outward normals.
- Deterministic collision: `update()` splits large deltas into steps of at most 1/60 s.
- Tests under `tests/`: logic (55 checks), integration (120), gameplay simulation (8), mesh winding (6), seeded fairness bot (200 seeds).
- Debug tooling (overlay, perf logger, death logger, warm-up switch) is gated on `OS.is_debug_build()`.
- Procedural code-built visuals are the starting point; imported assets arrive through `docs/ASSETS_AND_FONTS.md`.
