# Scrap Bot
A playable portrait Godot 4.7.2 Android prototype: relative drag steering, visible part assembly, nine part families with three levels, breakable attachments, auto-combat, repair choices, combos, the three-phase Scrap Titan, Hangar upgrades, local saves, a Codex and a UTC-seeded daily challenge.

Open project.godot in Godot 4.7.2 and press Play. First launch enters gameplay directly. Returning players enter the Hangar. Drag anywhere outside the buttons; desktop also supports A/D or left/right arrows, Space for special, Escape to pause and F3 for diagnostics. Android back pauses; five simultaneous touches toggle debug diagnostics.

## Validation
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_all.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/bots/run_balance.gd -- --seeds=100
```
The main runner includes logic, determinism, 5,000 generated gate pairs, the actual scene tree, persistence, economy, daily mode, reward idempotency, part purchases and arm recovery. See reports/FINAL_REPORT.md for measured results, scope deviations and pending acceptance checks.

## Android
```
tools/build_android.sh debug
tools/build_android.sh ads
```
The offline APK is build/scrap_dragon_debug.apk. The separate native rewarded-test-ad APK is build/scrap_dragon_test_ads.apk; it uses Google public test IDs only. Offline builds hide ad placements and never fabricate rewards. Actual native callbacks are not device-verified yet.

For a clean machine, install the matching Godot export templates, JDK 17 and Android SDK. tools/fetch_android_template.py fetches only the matching Android source entry from the official template archive using HTTP ranges. tools/configure_android.gd records the installed local SDK paths in Godot editor settings; update those paths for another computer. Native Gradle work is under ignored android/.

```
python3 tools/check_phone_allowlist.py
tools/phone_perf_session.sh SERIAL preflight
tools/phone_perf_session.sh SERIAL install
PHONE_RESULT_DIR=results/phone_NEW_RUN tools/phone_perf_session.sh SERIAL run 180
PHONE_RESULT_DIR=results/phone_NEW_STRESS tools/phone_perf_session.sh SERIAL stress 1
```
Exactly one physical Android phone is required. Use a fresh PHONE_RESULT_DIR and stress attempt 1–3. The script uses an explicit serial, the owned package only, thermal/battery guards, raw app frame logs and foreground-gated screenshots. Follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md for human checks.

The debug-signed build/scrap_dragon_pipeline_debug.aab proves the bundle pipeline only. A real release requires the three GODOT_ANDROID_KEYSTORE_RELEASE_* environment values and tools/build_android.sh release. No real release key, Play account, production ad IDs or consent setup is included.

## Content and reports
Balance and content are in data/*.json. The original supplied plan is preserved under Plan-Idea/ and copied under docs/. The supplied playbook is preserved and copied under docs/playbook/. Read docs/RESEARCH.md, assets/ASSET_MANIFEST.md and LICENSES.md for decisions and provenance. Detailed milestone reports distinguish implemented code from unrun phone/human/store acceptance criteria.

## Interactivity experiments (flags)
`data/flags.json` holds default-off switches for the interactivity experiments (lane aiming, guarded salvage, gate charge, post-gate payoff, moving gates, focus fire, rhythm blocks, weapon evolution, engagement metrics). Override them for a run with `-- --flags='{"aim_mode":"lane","gate_charge":true}'` or per sim with `RunSim.flag_overrides`. With every flag off the sim reproduces `results/interactivity_trace_baseline.txt` (check with `tests/bots/trace_hash.gd`). Audit: `docs/INTERACTIVITY_AUDIT.md`; results: `reports/INTERACTIVITY_REPORT.md`.
