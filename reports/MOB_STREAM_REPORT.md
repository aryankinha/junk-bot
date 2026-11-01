# Mob Stream completion report

Date: 2026-11-01 (Asia/Kolkata). Completion of the interrupted owner-provided Mob Stream brief.

## Summary (five lines)
1. MOB-0 through MOB-3 already existed; MOB-4 content and validation were unfinished and uncommitted when this session began.
2. Completed generated Levels 2–5, optional enemy streams, nominal socket launches, deterministic cap compaction and export-safe capture drivers.
3. Fixed misleading bot tests, repeated piercing hits, stale run feedback and a final gate with no effective target; saved four rendered evidence scenes.
4. The default-game trace matches its original baseline; the complete suite passes, and a packaged-game startup smoke test now passes.
5. Keep `mob_stream` and `mob_enemy_streams` OFF: phone/human acceptance and several gate-choice/combined-experiment balance criteria remain unverified or unmet.

## Audit of the reported claims

The original, detailed audit is [MOB_AUDIT.md](../docs/MOB_AUDIT.md), committed at `627a41d`. Its original line references describe that historical revision. Current source references below describe this completion. Raw results from this session are named `results/mob_resume_*`; older `mob_dev*` and `mob_final*` files are not final acceptance evidence.

| Reported claim | Status | Evidence |
|---|---|---|
| Godot 4.7.2, Compatibility renderer, portrait, fixed 60 Hz pure sim and separate view/data | CONFIRMED | Engine banner in `results/mob_resume_batched_checks.txt`; `project.godot`; `data/constants.json:6`; `src/sim/run_sim.gd:1`, `:851`; `src/view/world_view.gd` |
| E1–E5 and metrics flags default off, nearest aiming default | CONFIRMED | `data/flags.json:3–13`; Mob Stream flags are also false |
| Original projectile / hostile / bomblet / spark instance capacities 64 / 16 / 16 / 128 | CONFIRMED | `src/view/world_view.gd:78–83`; drones add a 256-instance shared MultiMesh, with sim cap 200 |
| Dense enemy cap 14; governor heads toward 0.6 at p95 >18.5 ms or >135 draws | CONFIRMED | `data/flags.json` tuning; `src/view/run_view.gd:_govern_density`; `src/sim/run_sim.gd:386`, `:713` |
| RunSim and BossSim own the listed combat and Titan rules | CONFIRMED | `src/sim/run_sim.gd:_combat`; `src/sim/boss_sim.gd:31–60`; direct bolt/bomb/phase/exposure tests in `tests/mob_suite.gd:_resume_regressions` |
| Burst Volley, Ram Charge and Vacuum work; Strafe Run and Inferno Aura are stubs | CONFIRMED | `src/sim/run_sim.gd:tap_special`; `src/sim/robot_state.gd:combos` skips `stretch` entries in `data/combos.json` |
| E2 shots charge part gates; E3 slides alternate part pairs ±0.9 m | CONFIRMED | `src/sim/run_sim.gd:_charge_gate`, `gate_offset`; `data/flags.json` |
| 25,177 checks is the current suite count | CONTRADICTED | Current count is in `results/mob_resume_batched_checks.txt`; the old count was historical |
| Original trace, aim, pair-audit and engagement tools exist | CONFIRMED | `tests/bots/trace_hash.gd`, `aim_bot.gd`, `pair_audit.gd`, `measure_engagement.gd`; `results/mob_resume_ship_trace.txt` says `TRACE MATCH` |
| Physical phone fps/thermals/PSS, cold boot, native ads and human playtests had not run | CONFIRMED | Still not run; `results/mob_resume_devices.txt` has no attached device; phone allow-list check passes in `mob_resume_phone_protocol.txt` |
| Internal project/root/artifact names still use Scrap Dragon; stale enemy/chance keys exist | CONFIRMED | `project.godot` application name; `src/view/Boot.tscn`; `export_presets.cfg`; `data/gates_level1.json:109`; `data/level_generator.json:17–18` |

Launcher label is already **Scrap Bot** in all four export presets (`package/name`); runtime window/home branding is Scrap Bot. `package/unique_name=com.aryankinha.scrapdragon`, `SaveStore.PATH`, save schema v1 and signing configuration were preserved. The internal application name remains Scrap Dragon because changing it would move desktop `user://` data. Root node and historical artifact names are internal; a new review APK uses a harmless new filename.

## Milestones and what was missing

| Milestone | State at handoff | Completion / evidence |
|---|---|---|
| MOB-0 | Committed `627a41d` | Audit and E1–E5 desktop baseline existed. Phone baseline unavailable; preserved and explicitly labelled. |
| MOB-1 | Committed `bd20ab7` | Packed drone arrays, flag, weapon types, damage split, shared mesh and parity tests existed. Completed nominal socket origins and lateral inheritance with aim assist. |
| MOB-2 | Committed `e832305` | Static mult/add/power gates, feedback/audio/haptics existed. Repaired compatible overflow merging and cap shrinkage. |
| MOB-3 | Committed `fcd42b5` | Moving/trap/speed gates and Overdrive champion existed. Removed the above-cap champion reserve; piercing direct hits remember all prior targets. |
| MOB-4 | Uncommitted / incomplete | `adfb9e3`: generated content, optional stream dispatch, regression coverage, corrected bots, isolated manual A/B launcher and capture tools. |
| MOB-5 | Missing | Packaged startup check, SDK/export repair, feedback polish, final-gate payoff, desktop comparison, APK verification and this report. Physical-phone acceptance is NOT RUN. |

Important files: `data/mob.json`; `src/sim/mob_sim.gd`; `_add_mob_gates`, `_spawn_stream`, `_combat` and `tap_special` in `src/sim/run_sim.gd`; drone/gate pools in `src/view/world_view.gd`; feedback, capture loading and debug playtest saves in `src/view/run_view.gd`; `tests/mob_suite.gd`; `tests/bots/mob_{bot,measure,pick,level_smoke,balance_sweep}.gd`; `tests/mob_capture.gd`; `tests/test_mob_playtest.gd`; `tools/play_mob_stream.sh`.

The packaged smoke test initially found a real startup failure: `RunView` statically referenced three bot classes from `tests/`, which exports exclude (`results/mob_resume_pack_smoke.txt`). It now loads drivers only for source-tree debug captures. The exported package boots outside the source folder with no script errors (`results/mob_resume_pack_smoke_fixed.txt`); the final APK resources are checked separately in `results/mob_resume_apk_batched_smoke.txt`. A zero exit code alone was not treated as a pass: the error text was inspected.

## Values and intentional adaptations

Rendering-only crowd batching is part of MOB-5; it changes no simulation values. All production tuning is in `data/mob.json`; E1–E5 tuning is unchanged. Flags remain false in `data/flags.json`. The previous uncommitted values were preserved unless explicitly listed below.

| Parameter | Final value / before → after | Reason |
|---|---|---|
| Live cap | 200 × density scale, floor 8; governor range 0.6–1.0 gives 120–200 | Instance budget; includes champions. A falling limit immediately compacts live drones. |
| Overflow | Compatible same kind/weapon/gate mask first; otherwise compact nearby compatible existing drones | Preserve numeric direct damage and charge without turning new bombs/champions into bolts. Masks and hit histories are unioned in a fallback merge to prevent repeat boosts/hits. |
| Champion reserve | 8 extra slots → removed | The brief promises one global cap, not 200 plus champions. |
| Volleys (per barrel) | Blaster 3/3/3; Cannon 2/3/4; Rocket 1/2/3; Torch 3/4/5 | Visible stream growth; total per-shot damage split N ways. L2 Cannon retains its existing two barrels. |
| Lateral inheritance | 0.4 | Visible bending. Applies to assisted, straight and torch launches. |
| Launch spread | Aimed 0.025 rad; straight 0.35 m/s; jitter 0.12 m/s; muzzle 0.12 m | Compact readable stream; deterministic shot-index hash. |
| Socket origins [x, height, forward] | Blaster [0,1,.95], top_c [0,1.3,1.15], top_l/r [±1.15,1.7,.6], side_l/r [±1.35,1,.8], back_c [0,1,.1], front_c [0,.8,1.1]; stage scales .85/1.12/1.4 | Nominal chassis sockets keep simulation independent of animated/repacked view meshes. Rear/side launchers clear the body toward the road ahead. |
| Drone collision radii / life / direct pierces / base visual scale | Bolt .85 / 1.6 s / 0 / 1.25; Bomb .85 / 2 s / 0 / 1.35; Torch 1.5 / .5 s nominal / 2 / 1.1; Champion 1.7 / 4 s / 12 / 3 | Starting tuning already implemented in MOB-1/3. Torch actual life uses weapon reach/speed, not the nominal .5 s field. |
| Torch volleys | 6/s, 15 m/s, fan 1.8 m/s, boss reach 14.6 m | Direct damage budget equals cone DPS; inherited burn stats refresh the existing burn effect. |
| Weight feedback | +.3 scale per extra weight, cap 2.2 (champion cap ×3); impact buffer 32 | Heavier merged drones and impacts remain bounded. |
| Gate reach | 62 m | 6.89 s of robot travel at 9 m/s; stationary-gate drone flight is 62/36=1.72 s. Earlier text used 27 m/s incorrectly; no subtraction is needed for a stationary gate. At maximum visibility this leaves about 5.17 s before robot arrival. Actual remaining life and different weapon speeds also affect reach. |
| Add gates | +N per five passing drones, fractional group progress retained per panel | A continuous stream needs a defined group; the sign is a group bonus, not a bonus for each drone. |
| Copy spread | .22 m maximum, bounded within .8 m span, jitter .8 m/s | Previous unbounded spread sent large +N groups out of the intended lane. |
| Feedback cadence | Sim pass aggregation .35 s; visual popup/audio/haptic per panel at most every 1.2 s | Avoid a wall of overlapping text and repeated sound. Sparks still show each aggregated pass. |
| Champion | Damage 150 × build DPS multiplier ×1.5 at full Overdrive; speed 18 m/s, area 2.4 m, 12 pierces | Existing special and champion launch together; no new button/meter. Base full-charge smash is 225 before build multipliers. |
| Champion gate boosts | Mult ×value; add +.1×N; power +value%; speed +value%; traps reduce damage by .005×value, never destroy it | One large unit rather than splitting champions at every multiplier. |
| Overdrive from positive gate gain | .03 → .012 per damage gained, running phase only | Previous gain overfilled the existing meter too quickly. No added boss-phase passive fill beyond existing rules. |
| Mob-only boss HP | 1.0 → 1.3 | Existing unfinished tune counteracts gate/champion spikes. Original game is unchanged. Values 1.6/2.0/2.5 were tested, not adopted: longer fights did not reliably eliminate combined-experiment stationary wins (`mob_resume_hp_sweep.json`). |
| Level 1 tune inherited from unfinished work | z105 power +100%→+80%; z150 add +8→+10; z480 ×2 vs speed40→speed60 vs power30; z560 +8→+12; z640 row→620; final row at 690 | Preserve the previous tuning pass and quantify its remaining weak choices, rather than silently claiming all choices are balanced. |
| Final gate payoff completed here | No enemy pack → 3 Scrappers 14 m after z690 | The previous opening volley landed during Titan invulnerability and produced zero realised damage. A pack at 704 gives a real pre-boss payoff; remeasured affected rows through the boss window. |
| Generated Levels 2–5 | Midpoints between generated part gates; extra row 20 m after final choice; rotate five templates; +20 power / +1 add per level; moving every third row; third panel from L3 on alternate rows; follow-up pack 14 m, base 3+level/2 (gunners 1) | Use existing beat model and enemy cap; maintain at least 35 m separation from generated part gates in tests. |
| Optional enemy streams | L1 six columns at 78/180/290/345/520/590, x alternates±1.8, counts4/4/5/5/5/5; spacing 2.2 m. Generated: 25 m after each row, count 4+level/2 | Readable short enemy columns; off unless both mob flags are true; dense cap 14, normal cap 24. |
| Mob gate labels | Outline 12 → 0 on their dark sign | Remove unnecessary fill/outline draw passes without losing sign contrast. One nearest mob row while a part gate is visible, otherwise up to two. |
| Champion popup | 110 → 72, centered | Keep launch feedback within the portrait view. Restart clears old popups, particles, throttle state and pooled gate ordinals. |

There are 12 authored mob rows; eight lie within the first 45 seconds at base forward speed (z≤405). Part gates remain intact, and mob rows keep at least 20 m away. The authored design generally puts a target pack **after** a mob gate to demonstrate the power gained immediately; this adapts the brief's "after enemy packs" wording. It does not satisfy a literal requirement for six new rows after six preceding packs. No unrelated enemy difficulty or economy system was retuned.

Champion "high HP" is represented by 12 direct pierces and immunity to gate destruction. Incoming enemy threats still target the robot; there is no separate champion-versus-enemy HP attrition system. This is an explicit adaptation, not an implemented HP stat. Numeric damage/charge conservation is tested; merging units can approximate spatial coverage and splash/pierce behaviour. Nominal launch sockets intentionally do not track animated mesh packing.

Rocket/bomb drones use the existing rocket exemption from phase-one armour. Phase-three core ×1.5 and clean-dodge exposure ×1.5 still apply through BossSim. Overdrive can launch a champion in the same tap as Burst Volley, Ram Charge or Vacuum. Part-gate charging applies to part panels only, and multiplication divides carried charge among copies rather than multiplying it. Flame keeps its existing cone charge hook. No currency, menu, HUD meter, forced ad, save migration or monetization change was added.

The unused generator fields `tradeoff_gate_chance=.2` and `gamble_gate_chance=.15` are **still unused**, deliberately, to avoid changing flag-off generated runs. The stale `elite_bruiser` field is still listed in the audit; runtime miniboss dispatch uses Hauler.

## Automated validation and bot numbers

`results/mob_resume_batched_checks.txt`: **25,320 checks, zero failures**, including **59 integration checks, zero failures**. The Mob suite includes damage parity on eleven builds (20-second close-target damage within 4%), cap/merge conservation, deterministic event/drone traces, once-per-gate application, moving/trap/speed/champion cases, generated beat determinism, actual stream spawning, immediate governor compaction, piercing target history, true stationary steering and delayed command delivery. It does not prove equal damage against arbitrary target formations: flame now has travel, fan coverage and finite pierces.

`results/mob_resume_ship_trace.txt`: **TRACE MATCH** across 36 original seeded runs. The saved reference hash was not rewritten. `results/mob_resume_playtest_a.txt` and `_b.txt` verify isolated saves, matching seed, manual control and cleared restart feedback.

Bot tables use 30 seeds (3000–3029), fixed 60 Hz, no save upgrades, and stop at win/loss or 300 seconds. "Gap" is the median across runs of each run's maximum pre-boss decision gap, not a human engagement score. Boss duration includes reached-but-lost fights as in the existing measurement tool. `-1` means no multiplication/boss observation. "No dodge" still chooses part gates; only `stay` is stationary. Reaction delay in MobBot now delays all steering commands, including boss dodges; this is a command-delay model, not a full human perception model.

### A — current flags, Mob Stream off

Source: `results/mob_resume_off_final.json`.

| Bot | Delay ms | Wins | Median pre-boss maximum gap s | First multiplication s | Boss duration median s | Drones mean / peak | Cap ticks | Merge operations/run | Over-cap ticks |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mob | 0 | 100.0% | 5.05 | -1.00 | 14.03 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| mob | 150 | 100.0% | 5.05 | -1.00 | 14.02 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| mob | 250 | 100.0% | 5.05 | -1.00 | 14.02 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| mob | 400 | 100.0% | 5.05 | -1.00 | 14.02 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| stay | 0 | 0.0% | 12.13 | -1.00 | 37.82 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| aim | 150 | 100.0% | 5.05 | -1.00 | 14.02 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| random | 250 | 90.0% | 5.05 | -1.00 | 27.70 | 0.0 / 0 | 0.00% | 0.0 | 0 |
| no_dodge | 0 | 43.3% | 8.90 | -1.00 | 21.28 | 0.0 / 0 | 0.00% | 0.0 | 0 |

### B — Mob Stream alone, all other experiments off

Source: `results/mob_resume_ship_only.json`.

| Bot | Delay ms | Wins | Median pre-boss maximum gap s | First multiplication s | Boss duration median s | Drones mean / peak | Cap ticks | Merge operations/run | Over-cap ticks |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mob | 0 | 100.0% | 2.98 | 1.23 | 14.33 | 19.5 / 109 | 0.00% | 0.0 | 0 |
| mob | 150 | 100.0% | 3.10 | 1.23 | 14.48 | 19.6 / 112 | 0.00% | 0.0 | 0 |
| mob | 250 | 100.0% | 3.10 | 1.23 | 14.33 | 19.6 / 112 | 0.00% | 0.0 | 0 |
| mob | 400 | 100.0% | 2.95 | 1.23 | 14.52 | 18.6 / 112 | 0.00% | 0.0 | 0 |
| stay | 0 | 0.0% | 7.93 | 1.23 | 10.22 | 5.2 / 31 | 0.00% | 0.0 | 0 |
| aim | 150 | 100.0% | 2.88 | 1.23 | 14.38 | 17.7 / 112 | 0.00% | 0.0 | 0 |
| random | 250 | 86.7% | 3.12 | 1.23 | 27.02 | 13.1 / 172 | 0.00% | 0.0 | 0 |
| no_dodge | 0 | 50.0% | 6.38 | 1.23 | 24.37 | 13.5 / 129 | 0.00% | 0.0 | 0 |

### C — Mob Stream plus all E1–E5 switches, including Focus Fire

Source: `results/mob_resume_ship_all.json`. Optional `mob_enemy_streams` remains off for this comparison.

| Bot | Delay ms | Wins | Median pre-boss maximum gap s | First multiplication s | Boss duration median s | Drones mean / peak | Cap ticks | Merge operations/run | Over-cap ticks |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mob | 0 | 100.0% | 2.82 | 1.23 | 12.88 | 88.7 / 200 | 0.89% | 80.3 | 0 |
| mob | 150 | 100.0% | 2.90 | 1.23 | 13.00 | 88.9 / 200 | 1.01% | 80.1 | 0 |
| mob | 250 | 100.0% | 2.95 | 1.23 | 13.10 | 88.7 / 200 | 0.85% | 70.5 | 0 |
| mob | 400 | 100.0% | 2.92 | 1.23 | 13.03 | 88.9 / 200 | 0.97% | 71.1 | 0 |
| stay | 0 | 30.0% | 8.02 | 1.23 | 25.90 | 11.7 / 199 | 0.00% | 0.3 | 0 |
| aim | 150 | 100.0% | 2.75 | 1.23 | 14.15 | 71.4 / 200 | 0.41% | 60.8 | 0 |
| random | 250 | 90.0% | 2.93 | 1.23 | 16.82 | 38.0 / 200 | 0.07% | 13.0 | 0 |
| no_dodge | 0 | 73.3% | 5.20 | 1.23 | 22.83 | 33.4 / 200 | 0.18% | 21.6 | 0 |

Aiming bots meet the existing 100% perfect-bot completion target at these sampled delays. The standalone Mob Stream stationary test is distinct from the combined-experiment result. Neither high bot wins nor a lower decision-gap proxy establishes human fun. The 3.27 s reference is a reported historical all-flags value; comparison is descriptive because this session corrected the bot model and uses different seeded samples.

Generated levels with Mob Stream + optional streams + dense blocks, delay 250 ms: L2 7/8 wins, L3–5 each 8/8, no timeouts or entity-cap violations (`results/mob_resume_levels.json`). This small sample only establishes end-to-end coverage.

### Gate-choice audit

The paired audit is a **counterfactual landed-damage preference**, not observed human choice or a promise of a rational policy's actual pick share. It swaps lane positions on alternate seeds, forces A then B, credits actual direct/splash damage to traversed gates (no overkill/roar credit), and compares paired seeds. "Noise-aware" uses the existing logistic approximation; it is a second descriptive statistic, not a statistical acceptance certificate. Three-panel rows are pairwise comparisons, not a three-way 40–60% claim. Zero-damage pairs cannot establish balance.

Sources: `results/mob_resume_pick_final.json` for z<620, `results/mob_resume_pick_last_pack.json` for affected final rows (20 seeds each). The earlier zero-damage last-row result was fixed and remeasured.

| Gate z | Pair | Paired preference A | Noise-aware A | Both-zero pairs |
|---:|---|---:|---:|---:|
| 45 | mult2.0 vs add5.0 | 50.0% | 56.4% | 0/20 |
| 105 | mult2.0 vs power80.0 | 30.0% | 44.0% | 0/20 |
| 150 | mult3.0 vs add10.0 | 60.0% | 51.8% | 0/20 |
| 215 | speed40.0 vs mult2.0 | 65.0% | 58.2% | 0/20 |
| 255 | mult2.0 vs add5.0 | 67.5% | 67.0% | 3/20 |
| 320 | mult2.0 vs add5.0 | 50.0% | 47.0% | 0/20 |
| 320 | mult2.0 vs power100.0 | 47.5% | 49.9% | 0/20 |
| 320 | add5.0 vs power100.0 | 52.5% | 53.9% | 0/20 |
| 375 | mult3.0 vs trap50.0 | 50.0% | 50.4% | 0/20 |
| 435 | mult3.0 vs trap50.0 | 100.0% | 97.8% | 0/20 |
| 480 | speed60.0 vs power30.0 | 52.5% | 46.2% | 0/20 |
| 560 | mult3.0 vs add12.0 | 52.5% | 56.9% | 0/20 |
| 620 | mult2.0 vs add5.0 | 52.5% | 42.4% | 0/20 |
| 620 | mult2.0 vs power100.0 | 42.5% | 44.0% | 0/20 |
| 620 | add5.0 vs power100.0 | 45.0% | 49.4% | 0/20 |
| 690 | mult2.0 vs power100.0 | 47.5% | 52.3% | 0/20 |


**The literal 40–60% criterion is not met for every row.** The moving trap row at 435 is intentionally dominated: a rational damage-maximiser should prefer ×3 over losing half its drones. The competitive row at 255 also favours ×2 in this sample; some other paired shares exceed 60% even where the noise-aware proxy is within range. These are acceptance exceptions, not hidden passes. Do not make labels numerically equivalent solely to satisfy a noisy proxy. Next experiment: rebalance target positions/group timing around 255 and test sign comprehension with people; keep trap rows as sparse readable hazards, or obtain owner approval to replace them with two beneficial choices.

## Desktop rendering measurements (not phone performance)

Same Apple M3 desktop, Compatibility renderer, 432×768 requested window, 4× desktop MSAA, 95 s capture each, sequential runs after CPU bot sweeps completed. E1–E5 are enabled in both; only Mob Stream differs. Raw samples use `Time.get_ticks_usec` via PerfLog, delta smoothing disabled. Sources: `results/mob_resume_perf_control_off.json`, `results/mob_resume_perf_batched_on.json`.

| Metric | Mob off | Mob on |
|---|---:|---:|
| Frame samples | 5537 | 5607 |
| p50 ms | 16.664 | 16.669 |
| p95 ms | 17.144 | 18.135 |
| p99 ms | 18.034 | 18.7 |
| Worst ms | 642.377 | 588.363 |
| Share >20 ms | 0.00270904822105833 | 0.00588550026752274 |
| Draw calls median | 113 | 115 |
| Draw calls peak | 146 | 141 |
| Primitives peak | 171978 | 209820 |
| Godot static allocation bytes | 85198531 | 91696895 |
| Scene init to first sampled gameplay frame ms | 51.871 | 28.844 |

Approximate fps from median frame time: 60.0 off / 60.0 on. This is a desktop render comparison, not a phone certification. The draw-call peak is now 141, within the 150-call budget. The p95 of 18.135 ms still exceeds a strict 16.67 ms frame target; sustained 60 fps is not certified.


A first desktop capture overlapped CPU bot sweeps (`results/mob_resume_perf_e1e5_desktop.json`): p95=17.484 ms but p99=72.696 ms and worst 682.874 ms. It is preserved as a load-contaminated diagnostic, excluded from the controlled comparison. Scene-init-to-first-sample is not a cold boot measurement, and Godot static allocation is not Android PSS. Vsync, background apps and OS scheduling limit conclusions; a strict 16.67 ms 60 fps p95 is not certified here.

Before crowd batching, the controlled Mob-on peak was 157 draw calls (`results/mob_resume_perf_control_on.json`), above 150. Scrappers now share one MultiMesh with the same toon outline, animated transforms and per-instance hit-flash data, only while Mob Stream is active (`src/view/world_view.gd`, `src/view/mesh_factory.gd:crowd_palette`). The accelerated draw-state diagnostic fell from 151 to 133 peak calls (`mob_resume_draw_diagnosis.txt`, `mob_resume_draw_batched.txt`); those accelerated runs are **not frame-time measurements**. The table uses the real-time 95-second rerun after this change. The flag-off baseline was collected before this view-only batching addition; no inactive batch is drawn with the flag off.

Phone 60 fps/p95, memory, first playable, battery temperature and a three-run thermal session: **NOT RUN / UNVERIFIED**, no device. Native haptics and ads also unverified. `tools/phone_perf_session.sh` remains the device protocol; its 20 explicit-serial owned-package adb calls pass the allow-list check. No phone performance result or release approval is invented. The Android resource inspection prints a template `themed_icon.xml` reference warning; physical launcher appearance remains unverified (raw APK inspection logs retain the warning).

## Evidence scenes

These are rendered game captures, not mockups. First multiplication is a natural seeded run. The other three use explicitly staged fixtures to show the mechanism clearly; fixture details and first-multiply timestamp are recorded in `results/mob_resume_capture.json`, generated by `tests/mob_capture.gd`.

- [First multiplication](../results/mob_resume_first_multiply.png):1.2333 s (target≤12 s).
- [×3 with loaded stream](../results/mob_resume_x3_stream.png): Cannon L3 + Rocket L3, clear road to expose drones.
- [Champion launch](../results/mob_resume_champion_launch.png): supplied full Overdrive, existing combo special coexists.
- [Boss hit by multiplied volley](../results/mob_resume_boss_multiplied_hit.png): same multiplied volley, boss roar skipped and high HP fixture to record contact without ending the scene.

Fixtures are evidence of rendering/integration, not natural encounter balance, a phone capture, or human playtesting.

## Reviewed build and repeatable checks

`build/scrap_bot_mob_review.apk`: **29186090 bytes**, SHA-256 `87a9285bfc2297a377f51ebf0fc920f4cbcd50ea2e54f50d6fcee2af320672d5`. ZIP16 KB alignment passes; each native ELF LOAD alignment is≥16 KB. Package and launcher label/permissions are recorded in `results/mob_resume_apk_badging_final.txt` and `_permissions_final.txt`; SDK setup/export logs are preserved. `results/mob_resume_apk_final.json` records no bundled tests/reports/results/docs. This is a debug-signed offline build with Mob Stream false, not a store release.

The default-off Android debug APK is a packaging deliverable, not a completed phone test. A source-tree manual A/B launcher is included; there is no separate enabled Android build approved for release. Exported source/test tools are excluded; the packaged startup smoke check was run from `/tmp` to prevent the source directory masking missing files.

```sh
# Standard logic and unchanged-default trace
Godot --headless --path . --script tests/run_all.gd
Godot --headless --path . --script tests/bots/trace_hash.gd
# Manual desktop A/B; same seed, new isolated save on each launch
bash tools/play_mob_stream.sh a
bash tools/play_mob_stream.sh b
# Independent bot / gate comparison; pass --label=NEW_NAME to preserve earlier results
Godot --headless --path . --script tests/bots/mob_measure.gd -- --seeds=30 --label=NEW_NAME
Godot --headless --path . --script tests/bots/mob_pick.gd -- --seeds=20 --label=NEW_NAME
```

## Five-player A/B checklist (not yet performed)

1. Recruit five people new to Scrap Bot; alternate A/B order across participants. Both variants start at Level 1 with no save upgrades and the same seed. A is the current default flags; B changes only Mob Stream. Do not bundle the earlier E1–E5 experiments into B for this first comparison.
2. Run `bash tools/play_mob_stream.sh a` or `b`. These use fresh isolated progress and manual steering; the owner's normal save path and schema stay unchanged. Give the same short control instruction and observe a full run or clear death in each variant.
3. Record time to first multiplication; chosen stream lanes; part-gate versus mob-gate confusion; when steering changed a hit; champion use; death cause; boring/repetitive periods; sign readability and overlapping feedback. Note any apparent drone/enemy/cap glitch with its timestamp.
4. Ask exactly: **"What did your aiming change?"** and **"When did you feel powerful? When were you bored?"** Ask participants to explain +N group bonuses and distinguish the two gate families without coaching.
5. On the connected phone, run the playbook's preflight and three sustained runs per candidate. Record raw frames, p95/p99/worst, share over 20 ms, draw calls/primitives, PSS, cold boot, battery/thermal status and focus validity. Stop at 43°C, severe thermal state or the protocol battery threshold. Do not infer this from desktop measurements.
6. Owner reviews the observations and performance data before enabling `mob_stream`. The flag remains false until that approval.

## Unverified items, assumptions and recommendation

- **UNVERIFIED:** physical-phone performance/thermals/PSS/cold boot, touch/haptic feel, native ad callbacks, five-player comparison and owner approval.
- **UNMET / explained:** every-row40–60% rational choice, combined-experiment stationary resilience, literal six-gates-after-preceding-packs authoring, and a separate high-HP champion attrition model. These should not be relabelled as completed acceptance tests.
- **Assumption:** shared packed-array drones and deterministic nominal sockets fit this repository better than physics bodies or view-to-sim transforms. Incoming threats retain existing robot damage and part-loss rules.
- **Assumption:** conservative numeric overflow conservation is preferable to dropping damage; extreme cross-mask/kind compaction can approximate spatial/pierce/splash coverage and needs a device/human review.
- **Owner decisions to record after playtest:** Are sparse deliberately bad trap choices acceptable instead of 40–60% picks? Is pierce durability sufficient for the champion? Should any E1–E5 flags be combined with Mob Stream? Which internal/historical artifact names should eventually be renamed without touching package/save identity?

**Recommendation: leave both new flags off.** The implementation is reviewable and the default game is preserved; start the five-player comparison with Mob Stream alone, address the gate 255 choice and feedback comprehension, then profile that candidate on a real phone. Do not enable the full experiment bundle based on bot wins alone.
