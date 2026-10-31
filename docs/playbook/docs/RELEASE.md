# RELEASE: Android release path

Purpose: build, sign and size-check a release AAB for Google Play from a Godot 4.7.2 project.
Last verified: 2026-10-28
Read this when: you prepare a store build or choose how to ship large content.

Measured on: file sizes on the Mac; Google Play limits read from Google's page on 2026-10-28.

## Build the release AAB (src: car/README.md; car/export_presets.cfg)
```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/keystores/<game>-release.jks"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="<alias>"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<typed in the shell, never saved in a file>"
godot --headless --path . --export-release "Android Release AAB" build/<game>_release.aab
```
- The preset `Android Release AAB` uses `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1`; arm64-v8a only.
- Sideload APK for friends: preset `Android Sideload (arm64)` (release-signed, no Gradle).
- Road Dodge release AAB is `26673034` bytes (src: car/build/road_dodge_release.aab).

## Keystore and signing
- Store the real keystore outside the project (for example `~/keystores/`); `*.jks`, `*.keystore`, `*.idsig` and `/build/` stay in `.gitignore`.
- Enrol in Play App Signing when creating the Play listing: Google holds the app signing key, you keep an upload key.
- Back up the keystore and its passwords in a password manager plus one encrypted offline copy; list the copy with `keytool -list -keystore <copy>`.
- Keep `export_presets.cfg` free of passwords; keystore values come from the environment variables above.
- Use a throwaway keystore only to prove the pipeline (a 30-day self-signed key in `build/_work/`).

## One package id
- Production id for each game is chosen once (for example `com.aryankinha.roaddodge`) and used by every release preset.
- Test variants add a suffix (`.gl`) or use a lab id (`com.aryankinha.labtest`) so they install next to the release app.
- Raise `version/code` (an integer) for every upload.

## SDK levels (src: car/android/build/config.gradle)
- compileSdk `36`, targetSdk `36`, minSdk `24`, build-tools `36.1.0`; the Godot template sets them, presets can leave the fields empty.
- Read Google Play's current target-API requirement before each store submission.

## Google Play size limits (compressed download size)
Source: https://support.google.com/googleplay/android-developer/answer/9859372 (section "Google Play maximum size limits", read 2026-10-28).
| Item | Limit |
| --- | --- |
| Base module | 500 MB |
| Individual feature module | 500 MB |
| All modules plus install-time asset packs | 4 GB |
| Fast-follow and on-demand asset packs | 30 GB |
| Individual asset pack | 1.5 GB |
| Asset packs per bundle | 100 |
| Total download size per app | 34 GB |
| APK (legacy publishing) | 100 MB |
- Sizes we hold: Road Dodge AAB `26673034` bytes; lab S4 2K APK `141417179` bytes; lab S4 4K ASTC APK `420440556` bytes; lab S4 4K lossless APK `394043655` bytes (src: godot_playbook/docs/FINDINGS.md section 7).
- The earliest lab debug APK was `502333982` bytes (src: godot_lab/builds/lab_compat_debug.apk); at that size, move large content to an install-time asset pack or reduce texture sizes so the base module stays under the limit.
- Godot's Gradle template contains an `assetPackInstallTime` module (src: car/android/build/assetPackInstallTime); trying it is listed in `NEXT_EXPERIMENTS.md`.
- Texture format targeting applies the download limits per texture format (Google's asset delivery page: https://developer.android.com/guide/app-bundle/asset-delivery).

## Debug versus release (src: car/README.md "Debug logs and switches")
| Feature | Debug build | Release build |
| --- | --- | --- |
| Debug overlay (F3, FPS/frame/draw calls) | available | off (`OS.is_debug_build()` is false) |
| Frame logger `perf.csv` (`--perf-log` or `user://perf_enable`) | available | never created |
| Death log `deaths.csv` (`--death-log` or `user://deaths_enable`) | available | never created |
| Warm-up skip (`--no-warmup` or `user://no_warmup`) | available | ignored |
| Cold-start log `coldstart.csv` | written | not written |
| Verbose `MOBILE_VERIFY` prints | printed | silent |
| `run-as` access for phone tests | works (APK is `application-debuggable`) | not available |
- Debug APKs report `application-debuggable` in `aapt2 dump badging` (src: car/phone_test_results/20261028-122527/01_apk_info.txt).
- Gating is covered by unit tests in `car/tests/test_integration.gd`.

## Release checklist
1. All tests pass headless; phone test done on the debug build.
2. Package id, version code and name set in the release preset.
3. Real ad IDs (if any) present in the release config only.
4. `aapt2 dump permissions` reviewed for the AAB's APK output.
5. Keystore outside the project, backed up twice; Play App Signing enabled.
6. Size within the limits above; large content in asset packs when needed.
