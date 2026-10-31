# Pre-implementation research — 2026-10-31
Read all seven Plan-Idea documents and the complete supplied playbook before implementation. Local engine reports 4.7.2.stable.official.ed1daf0bf; matching debug/release Android templates and JDK 17 are installed. Device discovery returned an empty device list.

## Verified primary sources
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html — MultiMesh draws many repeated instances together; individual instances are not culled. Use bounded pools/chunks.
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html — JDK 17 recommended; Android SDK path required.
- https://kenney.nl/assets/space-kit — 150 models, CC0.
- https://kenney.nl/assets/blaster-kit — 40 assets, CC0; plan's older model count is stale.
- https://kenney.nl/assets/car-kit — 45 assets, CC0.
- https://kenney-assets.itch.io/conveyor-kit — 60+ models, CC0; kenney.nl/assets/conveyor-kit returned 404.
- https://quaternius.itch.io/sci-fi-essentials-kit — 60+ models, CC0; glTF supported.
- https://quaternius.com/packs/ultimatespacekit.html — 92 models, CC0, glTF supported.
- https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0 — integration source to verify against downloaded plugin, rather than trusting uncompiled class names.
- https://developer.android.com/google/play/requirements/target-sdk — re-check at actual submission; use API 36 as specified.

## Spec conflicts to resolve transparently
The authored road is 720 m (~80 seconds before speed modifiers), plus a 30–45 second boss, so 90 s cannot describe total run time. Preserve authored distances and report total separately. Five ordinary L1 gates do not guarantee 9 build points; stage growth must be tested, not assumed. Boss HP 1500 at 45–70 DPS and 50% uptime implies 43–67 seconds even before plating, rather than the claimed 30–45 seconds. Retention figures in the idea are hypotheses, not measured product outcomes. No phone performance or human satisfaction is inferred from headless runs.
