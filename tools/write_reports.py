from pathlib import Path
import json,os
r=Path(__file__).resolve().parents[1]
def load(name):return json.loads((r/'results'/name).read_text())
checks=load('headless_tests.json')
exports=load('export_verification.json')
bots=load('bot_balance.json')
render=load('render_review.json')
phone='''| Metric | Value | Target |
|---|---|---|
| Launcher tap to first playable frame | NOT RUN — no physical phone | <2.5 s |
| Phone p95 / p99 / share over 20 ms | NOT RUN | p95 ≤16.7 ms; report raw jitter |
| Phone draw calls / PSS memory | NOT RUN | ≤150 / ≤400 MB |
| Installed size / temperature | NOT RUN | <120 MB / guarded below 43°C |
'''
scopes={
0:('Project and procedural asset spike',['Preserved and copied the full plan and playbook; recorded research before implementation.','Godot 4.7.2 Compatibility project, JSON data loader, four RNG streams, arm64 export presets and matching Gradle template.','Nine procedural families × three levels, palette material, socket manifest, triangle audit and asset-spike scene.'],['Procedural art is the allowed fallback. The requested six-pack download/import comparison was not completed; failed Kenney archive responses were HTML and are not shipped.','Physical spike performance and APK installation are NOT RUN.']),
1:('Feel slice',['Relative drag, keyboard testing controls, auto-forward, road recycling, batched scrap and physical gate panels.','Visible attach / merge animation, pooled debris and sparks, synthesized SFX, haptics, camera response and debug overlay.'],['Cannon/Wheels resolves at the authored 80 m (~8.9 simulated seconds at base speed). Launcher timing, touch latency and five-person attach ratings are NOT RUN.']),
2:('Combat and growth',['Bounded enemy/projectile pools, auto-fire targeting, projectile/rocket/cone damage, nine part families, level merges and three chassis stages.','Burst Volley, Ram Charge and Vacuum; upgrade hints and special button; full authored L1 road and generated levels 2–5.','Recursive socket relocation prevents later pickups from unnecessarily removing an attachment; tested Magnet-first Vacuum plus preserved weapon combo.'],['Rendered Battle and Monster screenshots exist. The stress snapshot uses 20 enemies and 40 bullets; sustained phone FPS is NOT RUN.','Enemies use prototype primitive silhouettes and simplified telegraphed attack presentation.']),
3:('Damage, part loss and recovery',['Armour, rechargeable shields, damage invulnerability, one-time 75/50/25% breaks, weighted loss and last-weapon protection.','Saw, oil, barrel contact hazard, Elite encounter, trade-offs, gamble, Repair/Re-roll/Buy station choices and instant retry.','Buy Part presents three candidates; repairs restore lost attachment levels.'],['Random L1 parts-lost average is reported in bot_balance.md. Part identification by unprompted phone testers is NOT RUN.','Barrel chain reactions, turret bolts, physical charges and Elite double charges are tested in the pure simulation.']),
4:('Scrap Titan',['Three phases with plated/core damage rules, roars, circles, multi-rocket lane barrage, moving laser gap, grabber steal/recover, scrapper calls and double slams.','Combo specials, Overdrive, hidden loss assist, boss camera, debris/slow visual kill and final-build viewport portrait.'],['Phase and arm-recovery rules are tested; all three phase captures exist.','Full-screen native effects, telegraph readability and human first-failure learning remain phone acceptance tasks.']),
5:('Progression and persistence',['Result rewards, level 1–5 progression, rotating Hangar preview, five upgrade tiers with trim variants at 3/5, Armoury and Codex.','Versioned atomic local save, invalid-save recovery, settings, streaks, local UTC daily seed and daily-best persistence.','Run/reward bookkeeping prevents duplicate payouts across repeated results and optional revives.'],['Economy, persistence, corrupt save and daily-mode tests pass.','The 40–60% rational gate-pick target has not been established; the fixed-choice audit shows both choices can win.']),
6:('Audio, feedback and optional rewarded test ads',['Original synthesized WAV SFX, OGG loops, pooled audio players, per-sound limits, compressor, ducking and settings.','Haptic rate limit, reduce-motion toggle, focus/back pause and safe-area margins.','Pinned MIT AdMob 5.1.0 runtime/native core, explicit test-ad export, callback-only rewards, offline hiding, revive/re-roll/repair/double/streak hooks.'],['Offline scene and one-time earned callback behavior are unit-tested. Native SDK callbacks, airplane-mode device behavior and physical haptics are NOT RUN.','The main offline build has vibration permission only; the optional ad build adds the SDK permissions listed in results/.','Consent and production IDs must be configured and reviewed before a real monetized release.']),
7:('Tuning, exports and handoff',['900-run fixed-seed balance sweep plus fixed-choice gate audits and three build profiles through levels 1–3.','Offline APK, test-ad Gradle APK and debug-signed AAB pipeline; ABI/SDK/permissions/package-content/16 KB checks.','Reproducible capture mode with isolated save and frame-driven movie replay; transformation, part-loss and Titan clips.','Phone runner, markers, foreground checks, battery/thermal guard, raw CSV capture and an audited adb allow-list.'],['No phone attached in results/device_discovery.txt. Two-device testing, five new players, install size and phone frame timings are NOT RUN.','No release signing credentials or Play Console account were supplied. A production-signed AAB, release sideload APK, internal-track upload and store acceptance are NOT DONE.','Review exact target deviations in FINAL_REPORT.md and calibrate the motor-error bot model from human play.'])
}
for i,(title,built,notes) in scopes.items():
 text=f'# M{i} Report — {title}\n\nStatus: code implemented; physical/release acceptance remains pending where noted.\n\n## Built\n\n'+''.join('- '+s+'\n' for s in built)
 text+=f'\n## Tests\n\nCombined runner: {checks["checks"]:,} checks, {len(checks["failures"])} failures, including the 59-check scene/service suite. Evidence: results/regression_final.txt, results/headless_tests.json and results/integration_tests.json.\n\nBot evidence: reports/bot_balance.md and reports/pair_audit.md. Screenshots: results/review_*.png.\n\n## Phone numbers\n\n'+phone
 text+='\n## Feel notes and decisions\n\n'+''.join('- '+s+'\n' for s in notes)
 text+='\n## Open acceptance tasks\n\nConnect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.\n'
 text+='\n## Next milestone / handoff\n\nSee reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.\n'
 (r/f'reports/M{i}_REPORT.md').write_text(text)
report='''# Scrap Dragon implementation and verification report

Date: 2026-10-31 (Asia/Kolkata). Status: playable prototype implemented; physical-device and production-release acceptance incomplete.

The idea and all supplied playbook documents were read before implementation. Research and version/source verification are recorded in docs/RESEARCH.md. The original documents remain under Plan-Idea/ and godot_playbook instructions/; copies live in docs/ and docs/playbook/.

## Delivered

A portrait 3D runner with relative drag, physical upgrade gates, nine part families and three levels each, Tiny/Battle/Monster bodies, pooled auto-combat, breakable/recoverable attachments, hazards, trade-offs, gamble, repair choices, combos, a three-phase Scrap Titan, results, Hangar upgrades and preview, Codex, local progression/daily mode, settings, audio/haptics and an optional native rewarded-test-ad build. Capture mode isolates its save and uses a frame clock when recording movies; ordinary gameplay/performance logging uses raw elapsed time.

Implementation is procedural GDScript with a pure RefCounted fixed-step sim, separate RNG streams and a thin node/mesh view. Original art is the approved procedural fallback; downloaded fonts retain OFL and the pinned optional ad runtime retains MIT licensing.

## Automated verification

'''
report+=f'- Combined headless runner: **{checks["checks"]:,} checks, zero failures** (`results/regression_final.txt`). This includes 5,000 generated pairs and a 59-check actual scene/service suite.\n'
report+='''- Rules include merge/socket relocation, stages/combos, last-weapon protection, invulnerability, deterministic full event logs, RNG independence, boss plating/core/arm recovery, economy, atomic save/reload, corrupt saves, daily persistence, purchases and one-time ad rewards.
- 900 benchmark runs: 100 seeds for each of three bot models at levels 1, 3 and 5 (`results/balance_complete.txt`, `results/bot_balance.json`).
- Fixed-choice audit: 120 full runs; both options at each of five L1 gates can win with the perfect controller. Build profiles add 90 full runs across levels 1–3 (`results/pair_audit_complete.txt`, `reports/pair_audit.md`). These are viability checks; they do not establish equal rational pick share.
- Actual rendered captures cover first attach, Battle, Monster, all boss phases, result, Hangar, Codex, settings and a 20-enemy/40-bullet snapshot (`results/render_review.json`).
- Procedural parts pass the ≤800-triangle-per-part budget (`results/asset_triangles.json`); all 27 variants appear in `results/asset_spike.png`.
- Phone runner passes its command allow-list checker (`results/phone_allowlist.txt`); no device commands besides discovery were executed against a phone.

## Balance results and limits

| Level | Bot | Runs | Wins | Median successful boss fight | Mean parts lost |
|---|---|---|---|---|---|
'''
for row in bots:
 report+=f"| {row['level']} | {row['bot']} | {row['runs']} | {row['win_rate']*100:.0f}% | {row['boss_median_s']:.1f} s | {row['parts_lost_mean']:.2f} |\n"
report+='''
Random uses a 250 ms reaction delay **and a 28% per-telegraph missed-response assumption** (`data/bot_models.json`). Perfect uses the best-value/profile choice and deterministic avoidance. NoDodge uses random gate choices and never avoids warnings. These model assumptions require calibration against real play; simulated win rates are not player retention or human success measurements. Outcome `boss` means a 300-second simulation timeout, not a win; timeouts are counted as failures.

Compare the measured completion and duration values above against the authored ranges in docs/04_DATA_TABLES.md. The random controller is a declared model, and strong optimal builds can finish substantially faster. In this sweep L1 random completion is 93% against the 80–90% range; its 29.8 s median is 0.2 s below the 30 s lower bound. L3/L5 random completion is within the respective authored ranges. These remaining tutorial deviations are left for phone-led tuning. Socket preservation improved collector paths, so the current forgiving tutorial tuning is left for the first physical playtest. L1 part-loss mean is within 0.8–1.5. The rational 40–60% pick-share target is NOT VERIFIED.

## Desktop rendering evidence

Measured on Apple M3, OpenGL Compatibility. These results do not certify Android FPS, memory, thermals or launcher time.

'''
report+=f'- Rendered 20-enemy / 40-bullet snapshot: {render["stress"]["draw_calls"]} draw calls, {render["stress"]["primitives"]:,} primitives (`results/render_review.json`). This is a snapshot, not the required 60-second phone run.\n'
report+='''- Category-isolated scene: 32 total draw calls in the initial scene (`results/draw_breakdown.json`); isolated categories include a rendering baseline and are not additive.
- Earlier 586-frame desktop sample: p95 17.489 ms, p99 19.627 ms, worst 228.634 ms including initial startup/shader work; 0.853% over 20 ms (`results/desktop_perf.json`). This short development sample is not the final phone acceptance protocol. The scene-init counter in that historical file is not launcher-tap time.
- Debug stress mode sustains bounded enemy/projectile populations, writes raw app CSVs and completes after 60 seconds; short boot/exit verification is in `results/stress_boot.txt`. The sustained physical run is still required.

## Android artifacts

All artifacts below are debug-signed development artifacts. Package: `com.aryankinha.scrapdragon`, arm64-v8a only, min SDK 24 / target SDK 36. Export manifests, SHA-256 values, ELF segment alignment and package-content checks are in `results/export_verification.json` and `results/scrap_dragon_*_badging.txt`.

| Artifact | Bytes | SHA-256 |
|---|---|---|
'''
for row in exports:
 report+=f"| {row['file']} | {row['bytes']:,} | `{row['sha256']}` |\n"
report+='''
The native libraries have 16 KB LOAD-segment alignment, and the APKs pass `zipalign -c -P 16 -v 4`. Test/development report folders are absent from packages. APK file sizes are not measured installed sizes.

The offline APK requests VIBRATE only. The explicit test-ad build also requests INTERNET, ACCESS_NETWORK_STATE, advertising ID, READ_BASIC_PHONE_STATE, WAKE_LOCK, FOREGROUND_SERVICE and its AndroidX receiver permission; inspect `results/scrap_dragon_test_ads_permissions.txt`. All ad IDs are public Google test IDs. Native loading/showing/earned/dismissed callbacks are NOT VERIFIED on hardware. The adapter only grants an earned callback, clears state on dismissal/failure, destroys finished ads and hides unavailable offers.

The AAB proves Gradle/bundle packaging only. It is debug-signed and cannot substitute for a real upload-key release. The release/sideload presets read real signing values from the environment and store no release passwords in the repository. Godot template badging includes a themed-icon warning; validate launcher/adaptive icons on the phone.

## Captures

- `build/first_transformation_release.mp4`: reproducible L1 first-gate attachment.
- `build/part_loss_release.mp4`: an actual simulated attachment break and visible loss message.
- `build/titan_battle_release.mp4`: the actual boss encounter and final build reveal.

These are development captures at 432×768 / 60 movie frames per second, not recordings of device performance. Frame proofs are under `results/movie_*_release.png`. Refresh marketing exports after phone feedback and final art approval.

## Changes from the supplied starting values

Boss HP is 2050 (from 1500); level HP scale is 0.60, with per-level attack damage scale 1.15. Slam/barrage/laser damage was adjusted based on recorded bots. L1 adds an oil beat, a rare Wheels reward from the Elite, a rare final-choice merge and one additional merge so Monster growth is reachable. The Elite encounter temporarily arrests forward travel to allow the rare reward to be earned. These starting-point adjustments live in JSON; the original plan data is preserved.

Socket assignment now relocates compatible attachments through free sockets before replacement, which makes collection combos obtainable in either pickup order. Unsupported pack downloads are substituted with the plan's permitted original procedural recipes. Native SDK work is isolated to an explicit test-ad build; the default APK works without an ad SDK.

Turret bolts, physical/double charges, barrel chain reactions, persistent burns, track knockback resistance, dash speed and time-based sustained-fire Overdrive are implemented and covered by focused regression checks. Original synthesized audio and primitive artwork remain prototype content pending human feel review. The supplied raw-time profile revealed that movie capture needs a separate frame-driven replay clock; normal gameplay still samples raw time.

## Remaining acceptance and release tasks

'''+phone+'''
1. Connect an unlocked physical phone with USB debugging, then run preflight/install, three complete runs, the 60-second stress marker, focus/back/lock checks and the hand-feel pass. Repeat on a second device. No phone was attached during this task (`results/device_discovery.txt`).
2. Have five new players test steering, both transformations, part-loss readability, the boss learning loop and rapid retry. Human satisfaction and usability are NOT VERIFIED.
3. Verify actual rewarded callbacks, airplane-mode behavior, post-ad resume and consent setup on hardware. Production IDs/account configuration are not supplied.
4. Provide the real upload keystore via environment variables, verify its backups, build the production-signed AAB and sideload release, and upload to a Play Console internal track. Release credentials/account access were not available; no store upload occurred.
5. Review combat/feedback on a phone, re-run the same bots after adjustments, and measure rational gate preference/retention with actual play data. The initial six-pack art comparison and a concept-art reference were not completed; no concept attachment was supplied.

Milestone reports M0–M7 record implemented code separately from unrun acceptance. Work progressed through code scopes because no physical device was available; this is a documented departure from the plan's per-milestone phone gate. Local history contains the initial plan/research snapshot, the coupled implementation snapshot and final verification/handoff, rather than fabricated per-day milestone history.

## Claim / evidence / status

| Claim | Evidence | Status |
|---|---|---|
| Runnable local prototype and complete automated suite | results/regression_final.txt | VERIFIED |
| Visible chassis changes and boss phases | results/review_*.png; results/render_review.json | VERIFIED on desktop |
| Debug APKs / AAB pipeline / alignment | results/export_verification.json | VERIFIED on host |
| Native test ads and physical haptics | Native adapter compiles; no device callbacks | PARTIAL |
| Exact balance targets | results/bot_balance.json; limits above | PARTIAL |
| 60 fps, startup, PSS and installed size on phone | No physical device | NOT RUN |
| Real release signing, store upload and five-player acceptance | Credentials/device/testers unavailable | NOT RUN |
'''
(r/'reports/FINAL_REPORT.md').write_text(report)
(r/'results/release_prerequisites.json').write_text(json.dumps({key:bool(os.environ.get(key)) for key in ['GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']},indent=2))
print('Wrote M0–M7 and final evidence report')
