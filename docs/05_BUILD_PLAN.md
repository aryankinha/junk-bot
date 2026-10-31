# 05 — Build Plan

Build in this order. Each milestone has a **scope**, **acceptance tests** and a **report**. The order tests the riskiest ideas first: attach feel, part loss, then the boss. If one of these three does not feel good on a real phone, fix it before adding content.

## Milestone overview

| M | Name | Outcome | Rough effort |
|---|---|---|---|
| M0 | Project and asset spike | Skeleton project, packs imported, look and performance confirmed | 1 day |
| M1 | Feel slice | Drag-steer, road, scrap, one gate pair with a satisfying attach | 1–2 days |
| M2 | Combat and growth | Auto-fire, 3 enemy types, chassis stages, merge, Level 1 gates | 2–3 days |
| M3 | Damage and parts loss | Hit rules, part break, hazards, mini-boss, Repair Bay | 2 days |
| M4 | Boss | Scrap Titan with 3 phases, telegraphs, weak points, Overdrive, kill sequence | 3 days |
| M5 | Meta | Result, Hangar upgrades, save, levels 1–5, streak, Codex | 3 days |
| M6 | Polish and monetization | Audio, haptics, juice, FTUE, rewarded ads (test IDs), settings | 3 days |
| M7 | Tuning and release build | Bots, phone tests, balance, AAB, capture mode | 2–3 days |

---

## M0 — Project and asset spike

**Scope**
- `git init`; create the folder layout from file 03; add `project.godot` settings; add `docs/` and `reference/`.
- Implement `GameData` (loads all JSON), `Constants`, `RngStreams`, and the headless test runner with `test_data`.
- Run the **asset spike** from file 02, section 7: manifest, palette material pass, spike scene, phone measurements.
- Create `tools/phone_perf_session.sh` (adb launch, collect logcat, pull `user://perf.json`).

**Acceptance**
- `run_all.gd` passes `test_data`.
- `assets/ASSET_MANIFEST.md` lists a source (pack file or procedural recipe) for every slot.
- Spike screenshot shows a cohesive palette across parts from different packs.
- Spike scene holds 60 fps on the phone; draw calls and memory recorded.
- A debug APK installs and launches.

## M1 — Feel slice (the 10-second test)

**Scope**
- `RunSim` (movement, beats, gate resolution for one gate), `RunView`, `ChaseCam`, `Robot.tscn` with Stage 1 chassis and sockets.
- Relative drag steering; auto-forward; road chunk recycling; fog.
- `ScrapField` MultiMesh with magnet-radius pickup, sparkle and floating "+n".
- One gate: **Cannon vs Wheels** with 3D panels (icon, label, stat delta). Attach animation, sparks, sound placeholders, haptic.
- Pea-shooter auto-fire at a few target dummies.
- Debug overlay with FPS and draw calls.

**Acceptance**
- From launch to the first attach under 12 seconds.
- Five people (or five self-tests) rate the attach moment "satisfying"; record notes.
- Steering feels immediate: input-to-motion latency under 100 ms in the phone test.
- 60 fps, ≤ 100 draw calls.
- `test_robot` covers slot resolution and merge.

## M2 — Combat and growth

**Scope**
- `CombatSim`, `EnemySim`: Scrapper, Gunner (telegraph line), Bruiser (windup charge). Nearest-target auto-fire with weapon types (projectile, rocket, cone).
- Nine parts with Lv1–Lv3 visuals (pack mesh or procedural recipe).
- Chassis stage-ups (Tiny → Battle → Monster) with the pop animation.
- Gates 1–5 of Level 1 plus the Final Choice (3 lanes).
- Enemy deaths: explosion, scrap burst, debris.
- `StatCalc` and combos Burst Volley, Ram Charge, Vacuum with the special button and HUD combo hint silhouettes.

**Acceptance**
- A full Level 1 run reaches the boss arena marker without crashing (boss stub allowed).
- Two different build paths produce visibly different silhouettes (screenshot pair in the report).
- `test_gates`, `test_robot` (combos, stage thresholds) green.
- 60 fps with 20 enemies and 40 bullets in a stress scene.

## M3 — Damage and parts loss

**Scope**
- Damage rules: armour, shield, invulnerability, break thresholds (75/50/25%), "never break the last weapon".
- Part-break animation (debris, warning flash, haptic), HP bar and part strip in the HUD.
- Hazards: Saw, Oil, Barrel. Mini-boss (Elite Bruiser) at z≈450 with a rare drop.
- Repair Bay (Repair, Re-roll, Buy Part) with scrap costs and an "unavailable → ad offer" stub.
- Trade-off gates and the Gamble crate.
- Fail flow: instant "Try again" with a one-line tip.

**Acceptance**
- A random-choice bot loses 0.8–1.5 parts per Level 1 run on average.
- Part loss is readable on the phone: testers can say which part was lost without being told.
- `test_damage` green.

## M4 — Boss: Scrap Titan

**Scope**
- `BossSim` and `BossView`: intro, three phases, roar transitions.
- Attacks: Ground Slam, Rocket Barrage, Laser Sweep, Grabber Arm (steal + recover), Call Scrappers, Double Slam.
- Telegraph quads (red, pulsing), clean-dodge detection, Overdrive meter and special, plate and core rules, weak-point outline for streak ≥ 3.
- Boss HP scaling, hidden assist (D4).
- Kill sequence: slow motion, camera orbit, debris, rare part drop, final-build capture.
- Camera pull-back for the arena.

**Acceptance**
- Median fight duration 30–45 s with the baseline bot.
- A perfect-dodge bot wins ≥ 98%; a random bot (250 ms delay) wins 80–90% on Level 1.
- Each phase is distinguishable by a first-time viewer (screen recording).
- `test_boss` green; 60 fps during boss effects.

## M5 — Meta

**Scope**
- `Result` screen (rewards, final-build image, streak), `Hangar` (turntable, upgrade list, Play button), `Save` with versioned schema.
- Level progression 1–5 (generator for levels 2+), boss scaling per level, level-specific extra attacks.
- Part upgrade tiers with visual variants at tiers 3 and 5.
- Win streak and weak-point outline. Build Codex with silhouettes.
- Daily challenge (seeded run, local best).
- Settings (sound, music, haptics).

**Acceptance**
- Kill app mid-session; progress persists. Corrupt save file recovers to defaults without crashing.
- After Level 1, a pulsing first upgrade is visible and affordable.
- `test_economy`, `test_sim_determinism` green.

## M6 — Polish and monetization

**Scope**
- Audio: all events in file 06, bus layout, polyphony limits, music loops.
- Haptics table in file 06.
- Juice pass: screen shake, hit-stop, scale pops, number popups, shockwaves, trails.
- FTUE script from file 01 section 17 (ghost hand, highlighted panels, Repair Bay hint).
- Rewarded ads with **test IDs**: Revive, Re-roll, Free Repair, Double Cogs, Save Streak. Graceful hiding when no ad is loaded.
- Pause on app focus loss; Android back handling.

**Acceptance**
- Every Level 1 event has sound and a visual response (checklist in the report).
- With airplane mode on, the game plays normally and ad buttons are hidden.
- No audio clipping or stacking at peak combat (polyphony limits verified).

## M7 — Tuning and release build

**Scope**
- Run the bot harness and tune `data/*.json` to hit file 04 section 9 targets.
- Phone tests on at least two devices (one mid-range or budget if available).
- Capture mode (`--capture`): fixed seed, hidden debug UI, scripted input; record three ad-ready clips.
- Build AAB with a real keystore, API 36 target, 16 KB page-size check, Play Console internal test upload.
- Write `reports/FINAL_REPORT.md` including install size and a known-issues list.

**Acceptance**
- All targets in file 04 section 9 met or explained.
- 60 fps (p95 frame time ≤ 16.7 ms on the primary phone), memory ≤ 400 MB, install ≤ 120 MB.
- Playtest with 5 new players: ≥ 4 finish the Level 1 boss; ≥ 3 retry quickly after a loss.

---

## Bot harness (`tests/bots/`)

Bots run the **sim headless** at high speed using the same code as the game.

| Bot | Behaviour | Used for |
|---|---|---|
| `RandomBot` | Random gate side; steers toward scrap; dodges telegraphs with a configurable reaction delay (0, 150, 250, 400 ms) | Baseline win rates |
| `PerfectBot` | Perfect prediction of telegraphs; best-value gate by simple heuristic | Upper bound; proves fairness |
| `BuildBot(profile)` | Follows a build plan (for example "rocket + armour + tracks") | Gate balance; each profile must be able to beat Level 1–3 bosses |
| `NoDodgeBot` | Never dodges | Confirms attacks are punishing enough |
| `PairAuditBot` | For each gate pair, runs N seeds with each choice | Reports pick share and win rate per option; flags dominated options |

Report per run: win rate, median boss duration, parts lost, final stage, death cause histogram. Output a table to `reports/bot_balance.md`.

## Phone test protocol

Run at M1, M2, M4, M6 and M7 on a physical Android phone (arm64, Compatibility renderer):

1. Install the debug APK. Cold start; record **time to first playable frame**.
2. Play 3 full runs (including boss). Collect `user://perf.json`: p50/p95/p99 frame time, % frames > 16.7 ms, draw calls (max and median), memory, temperature note.
3. Run the stress scene (20 enemies, 40 bullets, explosions) for 60 s.
4. Do a **hand-feel pass**: steering response, attach satisfaction, telegraph readability, haptics strength.
5. Test: back gesture, home button and return, screen lock, low-battery mode if possible.
6. If a second, weaker device is available, repeat steps 1–3 and record the delta.
7. Record any visual glitch (inside-out meshes, missing textures, black screen) with a screenshot.

## Risk list and fallbacks

| Risk | Fallback |
|---|---|
| Pack meshes look inconsistent | Apply the palette material pass; replace with procedural recipes slot by slot |
| Attach animation feels flat | Add anticipation (drop-in from above), hit-stop of 40 ms, spark burst, haptic, camera nudge |
| Part loss feels unfair | Longer invulnerability, stronger telegraphs, softer thresholds (80/55/30) |
| Boss feels like a stat check | Add clean-dodge Overdrive gain; shorten gaps; raise telegraph clarity |
| Gate pairs get solved (one side always wins) | Use PairAuditBot; adjust weights; add trade-offs |
| CPU particles cost too much | Reduce counts; use mesh-based flashes; pool aggressively |
| GPU particles invisible on some devices | Keep `CPUParticles3D` for all effects |
| Frame drops at the boss | Lower scrap and debris counts; cap simultaneous telegraphs; disable glow |
| Install size too large | Reimport textures at 512 px; drop unused pack files; decimate meshes |
| Ads fail to load | Hide ad buttons; offer non-ad alternatives with a longer cooldown |

## Report template (`reports/Mx_REPORT.md`)

```
# Mx Report — <title>
## Built
- bullet list of what exists now
## Tests
- headless: pass/fail counts and any skipped tests
- bots: win rates vs targets (table)
## Phone numbers
| Metric | Value | Target |
| first playable frame | | < 2.5 s |
| p95 frame time | | <= 16.7 ms |
| draw calls (median / max) | | <= 150 |
| memory | | <= 400 MB |
## Feel notes
- what feels good / what feels flat (with screenshots or short clips)
## Decisions made
- defaults used and any deviations from the pack
## Open questions for the owner
1. ...
## Next milestone plan
- ...
```

## Prompt starters for the agent

- **M0:** "Read all files in `docs/`. Create the project skeleton and run the asset spike exactly as described in 02 section 7 and 05 M0. Report with the template."
- **M1:** "Build milestone M1 from `05_BUILD_PLAN.md`. Prove the 10-second attach moment on my phone and report timings."
- **M4:** "Build the Scrap Titan per `01_GAME_DESIGN.md` section 12 and `04_DATA_TABLES.md` section 4. Use the bot harness to tune until the targets in section 9 hold, then report."
