# Mob Stream audit (MOB-0)

Date: 2026-11-01. Scope: read-only audit plus baseline measurements; no gameplay change in this commit.
Engine: Godot 4.7.2 (`/Applications/Godot.app`, `Godot Engine v4.7.2.stable.official.ed1daf0bf` printed by the run), `gl_compatibility`, Apple M3 desktop. Status words: CONFIRMED, CONTRADICTED, UNVERIFIED.

## 1. How player projectiles work today

- **Data structure.** `RunSim.bullets` is a plain `Array` of `Dictionary` (`src/sim/run_sim.gd:17`). One entry per shot: `x, z, tx, tz, type, damage, wid, charge, speed, radius, ttl` (`run_sim.gd:596`). Enemy bolts live in `hostile_bullets` (`:18`).
- **Cap.** `_fire` returns when `bullets.size() + hostile_bullets.size() >= 64` (`run_sim.gd:582`); hostile bolts are capped at 16 (`:737`). CONFIRMED (claimed 64).
- **Stats to shots.** `StatCalc.compute` always adds a `blaster` weapon (4 dmg, 1.5/s, `data/constants.json` `chassis.tiny.blaster`) and one weapon per owned weapon part from `data/parts.json` (`src/sim/stat_calc.gd:7-8, 27-31`). `_combat` runs one timer per weapon: period `1 / (rate * 2 if special_time > 0 * focus_multiplier())`, then one `_fire` per barrel (`run_sim.gd:627-631`). Damage per bullet is `weapon.damage * robot.stats.dps_mult` (`:596`). Weapon table: cannon L1 14 dmg x 1.4/s, L2 two barrels, L3 gatling 9 x 7/s; rocket 40 dmg x 0.55/0.85/1.1/s, area 2.4-2.8 m, `ignores_plate`; flame is a `cone` weapon (45/70/100 dps, 6/7/8 m, burn 10/14/20 dps for 2/2.5/3 s) that damages every enemy with `|dx| < 2.4` in range every tick instead of firing bullets (`run_sim.gd:607-626`).
- **Per-tick cost.** Each bullet runs one normalise, two position updates, one nested loop over `enemies` (<= 24, or 14 with `dense_blocks`) with a `Vector2.length() < 0.85` test, an optional splash loop, and one boss test (`run_sim.gd:632-661`). Worst case today is 64 x 24 = 1,536 distance tests per tick. A 200-drone stream with the same method would be 200 x 14 = 2,800 per tick, so the drone loop must prefilter by `z` and use packed arrays (design note in section 8).
- **Hit resolution.** Enemies and crates and barrels: one shared `enemies` list (crate and barrel are enemy ids), hit radius 0.85, rockets splash `bullet.radius` around the victim (`:643-654`). Boss: any bullet with `z >= robot z + 14` while `state == "boss"` calls `boss.apply_hit(type, damage * 1.5 if exposed)` (`:655-659`); `BossSim.apply_hit` halves damage in phase 1 unless the weapon type is in `plate.ignored_by`, multiplies by `core_multiplier_phase3` in phase 3 (`src/sim/boss_sim.gd:41-60`). CONFIRMED. Gate panels: bullets charge the next part gate when they cross its z plane inside `charge_range` (`_charge_gate`, `run_sim.gd:430-443`); flame uses `_charge_cone` (`:445`). The robot, not bullets, picks the gate option (`_resolve_gates`, `:356-380`).
- **Targeting.** `_pick_target` (`:556-567`): nearest mode = enemy within a 50 degree half-angle cone (`auto_fire_cone_deg`), `lane` mode = 12 degree cone (`aim_cone_deg`, read as half-angle) plus straight fire when nothing is in the cone (`_fire`, `:585-595`).

## 2. How the view draws projectiles, and real headroom

- Player shots: one `MultiMeshInstance3D`, `instance_count = 64` (`src/view/world_view.gd:75`), filled per frame from `sim.bullets` with a plain translation and `visible_instance_count` (`:476-487`). Enemy bolts 16 (`:76`), cluster bomblets 16 (`:77`), fx sparks 128 with per-instance colour (`:79`). CONFIRMED.
- **Draw calls are the scarce budget, not instances.** A MultiMesh with a merged mesh is one draw call regardless of instance count. Measured with E1-E5 on (this session, desktop, 95 s, bot `--capture`, `results/mob_perf_e1e5_desktop.json`): **draw calls median 113, max 146**, p50 16.66 ms, **p95 17.37 ms**, p99 18.01 ms, primitives max 172,506, static memory 84.5 MB, scene init to first playable 31 ms. The repo budget is 150 draw calls (`reports/INTERACTIVITY_REPORT.md`), so headroom is **4 draw calls** at peak. The drone MultiMesh will therefore replace the player-shot and bomblet MultiMeshes while `mob_stream` is on (same draw-call count), and mob gate panels must be merged meshes with few labels.
- Instances: 64 -> 256 is cheap (transform upload only); the vertex cost of a drone mesh matters more than instance count. Desktop is vsync-limited at 16.67 ms so desktop frame times cannot expose a phone problem.
- **Gate view.** Part gates use one pooled `gate_root` that shows only `sim.next_gate()` (`world_view.gd:551-568`); per panel it builds one merged frame mesh, 2-3 `Label3D`s, one icon and, with `gate_charge`, a charge bar (`:220-262`). Mob gates need a separate, small pool because a part gate and a mob gate can be visible together.
- Popups are pooled `Label3D`s (`world_view.gd:398-406`), reusable for gate pass numbers.

## 3. How gates are modelled; where beats are authored; cleanest way to add a kind

- **Beat = Dictionary** with `z`, `type`, optional `options` (Array of `{kind, id}`); `RunSim.beats` is sorted by `z` (`run_sim.gd:14, 91-105`). Types in use: `scrap_trail`, `gate`, `enemy_pack`, `hazard`, `miniboss` (spawns a hauler regardless of `enemy`), `repair_bay`, `final_choice`, plus `salvage`, `wave`, `coin_arc` from the flags. `_spawn_beats` spawns entities 45 m ahead and is a `match` on `beat.type` (`:333-348`).
- **Gate kinds** (`options[].kind`): `part`, `tradeoff`, `gamble`, `upgrade_random_owned`, `repair`, `reroll`, `buy`, `scrap`, `heal`, `frenzy`, `surge`. `apply_option` resolves them (`:226`). The panel is chosen by the robot's x at the gate plane (`_panel_lane`, `:397`), nearest panel centre for moving gates.
- **Authoring.** Level 1 is literal JSON, `data/gates_level1.json` (boss `z=720`). Levels 2-5 come from `RunSim._generate_beats` (`:108-120`) with `GateGen.pair` (`src/sim/gate_gen.gd:13`) and `data/level_generator.json`. E4 blocks are `data/blocks.json` (`:136-149`).
- **Moving gates** (`moving_gates`): `beat.moving = true` for index >= 2 even-indexed two-panel gates; offset `0.9 * sin(2 pi t / 5 + z * 0.37)`, panels 2.4 m wide, 2.8 m apart (`:94-96, 410-420`).
- **Cleanest way to add `mob_gate`:** a new beat type without `options` (so `next_gate()` and `_resolve_gates()` ignore it and the part-gate pool is untouched) carrying `panels: [{type, value}]`. Resolution is by projectile (drone) crossing, not by the robot, so `_resolve_gates` needs no change. Authoring goes in new data (`data/mob.json`), spawned/marked in `setup()` when `flags.mob_stream` is true. Everything stays off the hot path when the flag is false.
- **Reported leftovers.** `tradeoff_gate_chance` 0.2 and `gamble_gate_chance` 0.15 exist only in `data/level_generator.json:17-18`; `grep -rn` over `src tests tools data` finds no reader. CONFIRMED unused. `gates_level1.json` still has `"enemy": "elite_bruiser"` on the miniboss beat while `_spawn_beats` always spawns a `hauler` (`run_sim.gd:340`). CONFIRMED stale.

## 4. Overdrive, `tap_special`, combos; where a champion attaches

- `robot.overdrive` (0-100) fills +per `clean_dodge` and `per_sustained_fire_half_second` during the boss (`run_sim.gd:826-834`, `boss_sim.gd:_finish_attack`) and via the `surge` gate. `tap_special` (`:517-552`) takes the first combo whose cooldown is 0 (`burst_volley`, `ram_charge`, `vacuum`; `strafe_run`, `inferno_aura` are `stretch: true` and skipped by `RobotState.combos`, `src/sim/robot_state.gd:25-34`) or, if `overdrive >= 100`, sets `overdrive = 0` and amplifies it (1.5x burst, 1.5x ram) or, with no combo, runs the `no_combo_effect` fire-rate buff for `special_time`. CONFIRMED (the stubs are skipped, not implemented).
- **Champion attach point:** inside `tap_special` where `overcharged` is already computed (`:524-528`), add `_launch_champion()` when `flags.mob_stream and overcharged`. No new meter: the existing Overdrive bar is the supercharge. A combo special and a champion in the same tap both happen (burst volley rockets plus the champion) because the combo branch and the overcharge branch are independent today.

## 5. `aim_mode = lane`, and gate charging

- Cone 12 degrees (`flags.tuning.aim_cone_deg`, used as a half-angle), spread 0 (no spread is modelled), targeting reticle = ring under the locked enemy (`world_view.gd:_build_aim_feedback`, `_sync_aim`), BLAST/LOOT tags for guarded salvage. With no target the shot flies straight along the lane for `reach/speed + 0.05` s (`_fire`, `run_sim.gd:590-595`).
- Gate charging (`gate_charge`): `_bullet_charge` = bullet damage / nominal build dps (1.0 per second of full focus); a bullet crossing the next part gate's z within `charge_range` 30 m adds that to the panel its x falls in; thresholds `charge_t1` 1.0 and `charge_t2` 3.0 times a per-part cost give +1/+2 part levels (`:383-395, 422-443`). Mob Stream will keep this for **part gates only**; drones crossing a part gate charge it with the launch-time charge value (conserved across multiplication; decision recorded in the report).

## 6. Test and bot infrastructure

- `tests/run_all.gd` (SceneTree script; run `Godot --headless --path . --script tests/run_all.gd > file`; a runtime error inside the deferred `run()` hangs the process silently, so always use a file and a `timeout`). Latest verified count in this repo: 25,220 checks, 0 failures, integration 59 checks (`reports/INTERACTIVITY_REPORT.md`). The prompt says 25,177: CONTRADICTED by a few (the extra checks were added by the interactivity work); re-run before MOB-1 shows the live number (section 9).
- `tests/bots/trace_hash.gd`: plays 36 runs (levels 1-3 x perfect/random/no_dodge x 4 seeds, `BotController`, 18,000 ticks max), concatenates every non-`NEW_EVENTS` event plus a sampled state vector into an md5 per run and compares with `results/interactivity_trace_baseline.txt`; prints `TRACE MATCH`. New mob events must be added to `NEW_EVENTS` so they never reach the hash while the flag is off (they are absent anyway when off).
- Bots: `BotController` (`perfect`, `random`, `no_dodge`; chooses gates, steers to the chosen panel within 15 m, dodges telegraphs, taps special) and `AimBot` (wraps it, adds target tracking, gate charging and a perception delay). New bot behaviour = a new class beside `aim_bot.gd` that wraps `AimBot`/`BotController`, sets `sim.target_x` in `control(sim)`, and reads only data a player could see. Analysis scripts: `measure_engagement.gd`, `pair_pick.gd` (paired seeds, forced option, noise-aware share), `pair_audit.gd` (older, part-pair statistics), `moving_fairness.gd`, `focus_check.gd`.

## 7. Performance baseline (E1-E5 on)

| Context | p50 ms | p95 ms | p99 ms | draw calls median / max | primitives max | static memory | first playable |
|---|---|---|---|---|---|---|---|
| Desktop, M3, vsync, 95 s, flags off (`results/interactivity_perf_baseline_full_desktop.json`) | 16.67 | 17.32 | 18.02 | 102 / 133 | 166,910 | 79.2 MB | 37.8 ms |
| Desktop, M3, vsync, 95 s, **E1-E5 on** (`results/mob_perf_e1e5_desktop.json`) | 16.66 | 17.37 | 18.01 | 113 / 146 | 172,506 | 84.5 MB | 31.0 ms |

- **Physical phone: NOT RUN.** `adb devices` lists no device (this session), and `results/` has no phone run. `tools/phone_perf_session.sh` requires exactly one physical device and the package `com.aryankinha.scrapdragon`. Desktop numbers are vsync-limited and are labelled as such; they are not evidence for the phone. Temperature, PSS and time-to-first-playable-frame on a phone: UNVERIFIED.

## 8. Launcher label and every user-visible "Scrap Dragon"

Already renamed in the previous task: window title (runtime), home title, Android `package/name` (4 presets in `export_presets.cfg`). Remaining occurrences (grep over the repo, outside `results/`, `reports/`, `docs/`):

| Where | Visible to players? | Can change without touching package id, save paths or signing? |
|---|---|---|
| `project.godot:4` `config/name="Scrap Dragon"` | No (desktop `user://` folder is derived from it) | **No**: changing it moves `user://`, orphaning desktop saves. Left alone. |
| `src/view/Boot.tscn:3` root node `ScrapDragon` | No (node name) | Yes, but no player value and tests may reference the path; owner decision. |
| `export_presets.cfg:10,55,84,120` `build/scrap_dragon_*` artifact names | No | Yes, but `tools/*.sh`, `verify_exports.py` and docs reference them; owner decision. |
| `export_presets.cfg:26,66,98,136` `package/unique_name=com.aryankinha.scrapdragon`, `scrapdragon/rewarded_test_ads` | No | **No** (package id). |
| `README.md:18,31`, `tools/write_reports.py:33,80` | Docs only | Text only; the artifact names there must match the files. |
| `Plan-Idea/*` | Planning notes (Scrap Dragon is the boss name in D1) | No change needed. |

The launcher label is `package/name` and is already "Scrap Bot"; no player-visible string says "Scrap Dragon" in the game scenes. Nothing in this task changes the package id, save paths or signing.

## 9. Status of reported claims (section 3 of the brief)

| Claim | Status | Evidence |
|---|---|---|
| Godot 4.7.2, gl_compatibility, portrait; sim (`src/sim`, `RefCounted`, 60 Hz) separate from view; data in `data/*.json` | CONFIRMED | Engine banner above; `data/constants.json` `sim_hz 60`; `class_name RunSim extends RefCounted` |
| `data/flags.json` flags, all default off, `aim_mode` nearest default | CONFIRMED | `data/flags.json` |
| MultiMesh 64 / 16 / 16 / 128 | CONFIRMED | `world_view.gd:75-79` |
| `dense_blocks` enemy cap 14 | CONFIRMED | `spawn_pack`, `run_sim.gd:328` |
| `_govern_density` lowers `density_limit` toward 0.6 when p95 > 18.5 ms or draws > 135 | CONFIRMED (draws are the max over the 2 s window) | `run_view.gd:1017-1034` |
| `RunSim` movement/beats/collision/combat; `BossSim` Titan with plate x0.5 phase 1, core x1.5 phase 3, clean dodges fill Overdrive | CONFIRMED | `boss_sim.gd:41-60, _finish_attack` |
| `tap_special` handles `burst_volley`, `ram_charge`, `vacuum`; `strafe_run`, `inferno_aura` stubs | CONFIRMED | `run_sim.gd:517-552`; `combos.json` `stretch: true` |
| `gate_charge` E2; `moving_gates` +-0.9 m | CONFIRMED | `run_sim.gd:383-443, 410-413` |
| Tests: `run_all.gd` 25,177 checks, trace_hash, aim_bot, pair_audit, measure_engagement exist | CONTRADICTED: files exist; count is 25,220 in the recorded audit run | `reports/INTERACTIVITY_REPORT.md`; live re-run below |
| NOT RUN items (phone fps/thermals/memory, cold boot, native ads, human playtests) | CONFIRMED still not run | no device; see section 7 |
| Leftovers: project name, root node, `scrap_dragon_*`, `elite_bruiser`, unused chance keys | CONFIRMED (all five) | section 3 and 8 |

Live checks run at the start of MOB-0: see "Baseline checks" at the end.

## 10. Contradictions found

1. Test count: 25,220 (latest recorded), not 25,177.
2. "Player projectiles are drawn from a MultiMesh with 64 instances" is true, but the 64 is also the **sim cap shared with enemy bolts**; the drone cap of 200 needs the sim cap lifted for drones only, and a drone view capacity above 64.
3. "Flame fires projectiles" is not how it works: flame is an instantaneous cone, so the torch drone design changes flame from area-over-time to projectiles; damage parity must be defined per target in range.
4. The `mob_stream` brief says to cap at 200 live drones; the existing budget gives only 4 spare draw calls at peak (section 2). The cap is an instance cap, not a draw-call cap; draw calls are protected by sharing one MultiMesh and merging gate meshes.

## 11. Plan: how sections 5-7 are adapted to the real code

- **New files:** `src/sim/mob_sim.gd` (drone struct-of-arrays, `RefCounted`, owned by `RunSim` only when `flags.mob_stream`), `data/mob.json` (all tuning and Level 1 / generated rows), `tests/bots/mob_bot.gd`, `tests/bots/mob_measure.gd`, `tests/bots/mob_pick.gd`.
- **Hooks in `RunSim`** (all behind `if mob != null`): `_fire` becomes "launch a volley" (damage conserved: per-shot damage split across N drones); flame cone becomes torch volleys; `_combat` bullet loop calls `mob.step`; boss hits per drone; `tap_special` adds the champion; `setup()` adds `mob_gate` beats; `_spawn_beats` marks them. With the flag off the code paths are unchanged, verified by `trace_hash.gd`.
- **View:** one drone MultiMesh (per-instance colour for bolt / bomb / torch / champion tint) replaces the shot and bomblet MultiMeshes while on; a small mob-gate pool (max two) with one merged frame mesh per gate and one `Label3D` per panel; gate-pass popups from the existing popup pool; SFX through `GameAudio.play` after `tools/generate_audio.py` adds three sounds; haptics through `HapticsService.tap`.
- **Density governor** gets a second output: `sim.mob.cap_scale` (drone cap 200 x density_limit).
- **Gates and metrics:** `EngagementLog` gets a `mob_gate_pass` mark and `time_to_first_multiply`. Part-gate charging stays for part gates only.
- **Milestones** follow the brief, with the Level 1 authoring in `data/mob.json` rather than `gates_level1.json` so the flag-off file is untouched.
- **Phone:** if still no device at MOB-5, the flag stays off by default and desktop numbers are labelled as such.

## Baseline checks (live, this session)

- `Godot --headless --script tests/run_all.gd`: **25,220 checks; 0 failures**; INTEGRATION 59 checks (the prompt's 25,177 is CONTRADICTED by +43).
- `Godot --headless --script tests/bots/trace_hash.gd`: **TRACE MATCH** (36 runs).
- Desktop perf with E1-E5 on: section 7. Phone: NOT RUN.


## Resumed implementation audit (2026-11-01)

The sections above describe the MOB-0 revision `627a41d`; their source line numbers refer to that revision. The interrupted work reached commit `fcd42b5` (MOB-3), with generated content, bot instrumentation and tuning still uncommitted. The final current-state evidence and acceptance exceptions are in `reports/MOB_STREAM_REPORT.md`.

- CONFIRMED: the resumed full suite passes 25,320 checks plus 59 integration checks, with no failures (`results/mob_resume_final_checks.txt`). The original reported 25,177 was historical, not the present count.
- CONFIRMED: flag-off replay is unchanged (`results/mob_resume_trace.txt`, `TRACE MATCH`). No baseline was regenerated.
- CONFIRMED: current drone core uses packed arrays and a per-drone direct-hit history, with nominal weapon-socket origins (`src/sim/mob_sim.gd:177`). Multiplication and capacity compaction conserve direct damage and charge; the capacity now includes champions (`mob_sim.gd:114`, `:150`, `:232`).
- CONTRADICTED: the earlier champion implementation exempted champions from the advertised global cap. It is repaired; there is no reserve above the cap.
- CONTRADICTED: the previous `stay` bot was stationary, or its "perfect" inner controller applied a reaction delay to boss dodges. `tests/bots/mob_bot.gd` now holds x=0 for `stay` and delays complete steering commands for the aiming bot. Earlier bot result files are historical, not current acceptance evidence.
- CONTRADICTED: authored `enemy_stream` beats were enough to produce enemy streams. The spawn dispatch was missing; it is now connected (`src/sim/run_sim.gd:396`) and covered by a regression test.
- CONFIRMED: generated Levels 2–5 complete without entity-cap violations or timeouts in the small end-to-end sample (`results/mob_resume_levels.json`). This is not human difficulty validation.
- UNVERIFIED: phone fps, PSS, cold boot, temperature, three-run thermals, haptics, native ad callbacks and five-player acceptance. No physical device is connected (`results/mob_resume_devices.txt`). The phone protocol allow-list passes (`results/mob_resume_phone_protocol.txt`).

The new launch origins are deterministic nominal sockets, rather than feeding animated view transforms back into the pure simulation. Champion durability is represented by its 12 pierces and gate immunity; there is no unused HP stat or separate enemy-versus-drone health system. Ordinary incoming threats still damage the robot. Neither adaptation changes the save schema.
