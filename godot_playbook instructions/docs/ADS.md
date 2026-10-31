# ADS: AdMob test ads in Godot 4.7.2

Purpose: the AdMob integration that worked on the phone, its measured behaviour, and the path to real ads.
Last verified: 2026-10-28
Read this when: a game shows ads, or you plan monetisation.

Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz, Godot 4.7.2, Compat build (godot_lab), Google test IDs only.

## Plugin and install (src: godot_lab/LICENSES.md; godot_lab/PLAN.md)
- Plugin: Poing Studios godot-admob-plugin **v5.1.0** (https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0); its release notes list testing through Godot 4.7.2.
- Android binary: `android-template-v4.7.2.zip` from the same release (the file name carries the engine version).
- Steps: copy `addons/admob` into the project; unzip `package.gd` and `ads/*` from the template into `addons/admob/android/bin/` (core ads library only); enable the plugin under `[editor_plugins]` in `project.godot`; export with the Gradle build (the plugin checks `gradle_build/use_gradle_build`).
- Add `third_party/admob/.gdignore` so an extracted copy of the plugin is not scanned.
- Gradle pulls Google's `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0` from Google Maven at build time.
- Preset options: `permissions/internet=true`, `permissions/access_network_state=true` (src: godot_lab/export_presets.cfg).

## Google public test IDs
- App ID `ca-app-pub-3940256099942544~3347511713` (https://developers.google.com/admob/android/quick-start: "While testing, use the sample app ID"). The plugin's default App ID setting holds this value (src: godot_lab/third_party/admob/extracted/poing-godot-admob/addons/admob/internal/services/project_settings_service.gd).
- Ad units (https://developers.google.com/admob/android/test-ads): banner `ca-app-pub-3940256099942544/6300978111`, interstitial `ca-app-pub-3940256099942544/1033173712`, rewarded `ca-app-pub-3940256099942544/5224354917`.
- The plugin's App ID setting path is `admob/general/android/app_id` (same plugin file).

## Test menu (src: godot_lab/scripts/ads_menu.gd)
- Buttons: Load Banner, Show Interstitial, Show Rewarded, Hide Banner; a moving bar and a bottom-edge marker show the loop and the banner overlap.
- API used: `AdView.new(id, AdSize.BANNER, AdPosition.BOTTOM)` with `AdListener`; `InterstitialAdLoader` and `RewardedAdLoader` with load callbacks; `FullScreenContentCallback`; `OnUserEarnedRewardListener`; call `destroy()` on dismiss.
- Every callback is appended with timestamps to `user://ads_log.csv`; raw frame times with banner and full-screen flags go to `user://ads_frames.csv`.
- Callbacks logged: sdk_initialize_called, sdk_initialized, banner_load_started, banner_loaded, banner_impression, banner_failed_to_load, banner_clicked, interstitial_loaded, interstitial_shown, interstitial_impression, interstitial_dismissed, rewarded_loaded, rewarded_shown, rewarded_impression, reward_earned, rewarded_dismissed, lifecycle (FOCUS_OUT, APPLICATION_PAUSED, APPLICATION_RESUMED, FOCUS_IN), frame_check_after_ad.

## Measured behaviour (src: godot_lab/results/phone3_20261028-150837_b_c/ads_log.csv; godot_playbook/data/ads_frame_stats.txt)
- SDK initialised `1884` ms after app start; banner loaded `10573` ms; interstitial shown `11531` ms; reward earned `20614` ms (amount `10`, type coins); rewarded dismissed `23297` ms; interstitial dismissed `27208` ms.
- All three formats loaded and were dismissed; no load or show errors were logged.
- Lifecycle: APPLICATION_PAUSED at `11500` ms and APPLICATION_RESUMED at `27225` ms.
- The Godot loop kept running during the ads: `710` full-screen-open frames with p99 `18.04` ms; frames over 250 ms: `0`.
- Banner visible: `386` frames, p99 `19.12` ms.
- After each ad a pixel check read the background colour (no black frame) (src: godot_lab/results/phone3_20261028-150837_b_c/ads_log.csv, `frame_check_after_ad`).

## Practices
- Pause game logic on `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_APPLICATION_FOCUS_OUT`; resume on `APPLICATION_RESUMED` and `FOCUS_IN` (the loop keeps ticking while an ad covers the game).
- Request the next ad after a dismissal; destroy finished ad objects.
- Show interstitials at natural breaks (game over, level end); offer rewarded ads as an opt-in.
- Keep real IDs in release builds only: a release config file that is not committed, or environment values injected at export. Debug builds keep the test IDs.
- Use `RequestConfiguration.test_device_ids` for your own phone once real IDs exist.

## Permissions in the lab APK (src: godot_playbook/data/ads_permissions.txt)
| Permission | Purpose |
| --- | --- |
| `INTERNET`, `ACCESS_NETWORK_STATE` | declared by us; ad requests and connectivity checks |
| `AD_ID` (`android.permission` and `com.google.android.gms.permission`) | advertising ID used by the ads SDK |
| `READ_BASIC_PHONE_STATE` | basic network and carrier state read by the ads SDK |
| `WAKE_LOCK` | keeps the CPU awake while an ad loads or plays |
| `FOREGROUND_SERVICE` | lets the SDK run a foreground service for ad work |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX internal permission, prefixed with the package id |

## Checklist: moving to real ads
1. The developer creates the AdMob account (agent does not create accounts or enter credentials).
2. Register the app in AdMob with the production package id; create banner, interstitial and rewarded ad units.
3. Put the real App ID and ad unit IDs in release builds only.
4. Add the consent flow (the plugin ships UMP examples in `addons/admob/skills/godot-admob-get-started/SKILL.md`).
5. Fill the Play Console data-safety and ads declarations.
6. Test the release build with test devices registered, then publish.
