# Scrap Dragon implementation and verification report

Date: 2026-10-31 (Asia/Kolkata). Status: playable prototype implemented; physical-device and production-release acceptance incomplete.

The idea and all supplied playbook documents were read before implementation. Research and version/source verification are recorded in docs/RESEARCH.md. The original documents remain under Plan-Idea/ and godot_playbook instructions/; copies live in docs/ and docs/playbook/.

## Delivered

A portrait 3D runner with relative drag, physical upgrade gates, nine part families and three levels each, Tiny/Battle/Monster bodies, pooled auto-combat, breakable/recoverable attachments, hazards, trade-offs, gamble, repair choices, combos, a three-phase Scrap Titan, results, Hangar upgrades and preview, Codex, local progression/daily mode, settings, audio/haptics and an optional native rewarded-test-ad build. Capture mode isolates its save and uses a frame clock when recording movies; ordinary gameplay/performance logging uses raw elapsed time.

Implementation is procedural GDScript with a pure RefCounted fixed-step sim, separate RNG streams and a thin node/mesh view. Original art is the approved procedural fallback; downloaded fonts retain OFL and the pinned optional ad runtime retains MIT licensing.

## Automated verification

- Combined headless runner: **25,147 checks, zero failures** (`results/regression_final.txt`). This includes 5,000 generated pairs and a 59-check actual scene/service suite.
- Rules include merge/socket relocation, stages/combos, last-weapon protection, invulnerability, deterministic full event logs, RNG independence, boss plating/core/arm recovery, economy, atomic save/reload, corrupt saves, daily persistence, purchases and one-time ad rewards.
- 900 benchmark runs: 100 seeds for each of three bot models at levels 1, 3 and 5 (`results/balance_complete.txt`, `results/bot_balance.json`).
- Fixed-choice audit: 120 full runs; both options at each of five L1 gates can win with the perfect controller. Build profiles add 90 full runs across levels 1–3 (`results/pair_audit_complete.txt`, `reports/pair_audit.md`). These are viability checks; they do not establish equal rational pick share.
- Actual rendered captures cover first attach, Battle, Monster, all boss phases, result, Hangar, Codex, settings and a 20-enemy/40-bullet snapshot (`results/render_review.json`).
- Procedural parts pass the ≤800-triangle-per-part budget (`results/asset_triangles.json`); all 27 variants appear in `results/asset_spike.png`.
- Phone runner passes its command allow-list checker (`results/phone_allowlist.txt`); no device commands besides discovery were executed against a phone.

## Balance results and limits

| Level | Bot | Runs | Wins | Median successful boss fight | Mean parts lost |
|---|---|---|---|---|---|
| 1 | perfect | 100 | 100% | 17.6 s | 0.87 |
| 1 | random | 100 | 93% | 29.8 s | 0.93 |
| 1 | no_dodge | 100 | 19% | 20.6 s | 1.70 |
| 3 | perfect | 100 | 99% | 25.8 s | 0.09 |
| 3 | random | 100 | 69% | 36.9 s | 1.64 |
| 3 | no_dodge | 100 | 13% | 33.3 s | 2.70 |
| 5 | perfect | 100 | 100% | 34.4 s | 0.07 |
| 5 | random | 100 | 51% | 43.3 s | 1.94 |
| 5 | no_dodge | 100 | 4% | 53.3 s | 2.90 |

Random uses a 250 ms reaction delay **and a 28% per-telegraph missed-response assumption** (`data/bot_models.json`). Perfect uses the best-value/profile choice and deterministic avoidance. NoDodge uses random gate choices and never avoids warnings. These model assumptions require calibration against real play; simulated win rates are not player retention or human success measurements. Outcome `boss` means a 300-second simulation timeout, not a win; timeouts are counted as failures.

Compare the measured completion and duration values above against the authored ranges in docs/04_DATA_TABLES.md. The random controller is a declared model, and strong optimal builds can finish substantially faster. In this sweep L1 random completion is 93% against the 80–90% range; its 29.8 s median is 0.2 s below the 30 s lower bound. L3/L5 random completion is within the respective authored ranges. These remaining tutorial deviations are left for phone-led tuning. Socket preservation improved collector paths, so the current forgiving tutorial tuning is left for the first physical playtest. L1 part-loss mean is within 0.8–1.5. The rational 40–60% pick-share target is NOT VERIFIED.

## Desktop rendering evidence

Measured on Apple M3, OpenGL Compatibility. These results do not certify Android FPS, memory, thermals or launcher time.

- Rendered 20-enemy / 40-bullet snapshot: 56 draw calls, 19,136 primitives (`results/render_review.json`). This is a snapshot, not the required 60-second phone run.
- Category-isolated scene: 32 total draw calls in the initial scene (`results/draw_breakdown.json`); isolated categories include a rendering baseline and are not additive.
- Earlier 586-frame desktop sample: p95 17.489 ms, p99 19.627 ms, worst 228.634 ms including initial startup/shader work; 0.853% over 20 ms (`results/desktop_perf.json`). This short development sample is not the final phone acceptance protocol. The scene-init counter in that historical file is not launcher-tap time.
- Debug stress mode sustains bounded enemy/projectile populations, writes raw app CSVs and completes after 60 seconds; short boot/exit verification is in `results/stress_boot.txt`. The sustained physical run is still required.

## Android artifacts

All artifacts below are debug-signed development artifacts. Package: `com.aryankinha.scrapdragon`, arm64-v8a only, min SDK 24 / target SDK 36. Export manifests, SHA-256 values, ELF segment alignment and package-content checks are in `results/export_verification.json` and `results/scrap_dragon_*_badging.txt`.

| Artifact | Bytes | SHA-256 |
|---|---|---|
| build/scrap_dragon_debug.apk | 29,036,687 | `56dd0f0e6ecec02e58f689b8656dd25ffbf41b22fd3a737eb500ca0bd09928bf` |
| build/scrap_dragon_pipeline_debug.aab | 28,919,196 | `36043d2a99d46d6c5251863d79990257a96215d4348d9a1c1fd21e30153f6d19` |
| build/scrap_dragon_test_ads.apk | 39,482,099 | `6aa346b9446891a3ab65ba8469d0c45ba1e5f9d3b44dd24d3f2dd7eb14e2aaca` |

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

| Metric | Value | Target |
|---|---|---|
| Launcher tap to first playable frame | NOT RUN — no physical phone | <2.5 s |
| Phone p95 / p99 / share over 20 ms | NOT RUN | p95 ≤16.7 ms; report raw jitter |
| Phone draw calls / PSS memory | NOT RUN | ≤150 / ≤400 MB |
| Installed size / temperature | NOT RUN | <120 MB / guarded below 43°C |

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
