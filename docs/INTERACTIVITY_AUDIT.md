# Interactivity audit (Step 1, no gameplay changes)

> This file is the Step 1 snapshot taken before any gameplay change (commit 6b6a13a). Line numbers refer to that commit. What was built afterwards and the before/after numbers are in `reports/INTERACTIVITY_REPORT.md`.

Branch `main`, baseline commit `f53b16c`. All line numbers are `path:line` in the tree at the audit commit; every number below was either read from a file or measured in this session (commands under "How measured"). Labels: **CONFIRMED**, **CONTRADICTED**, **PARTLY**, **UNVERIFIED**.

## 1. Facts about the project

| Item | Value | Evidence |
|---|---|---|
| Engine | Godot 4.7.2.stable, GL Compatibility renderer, GDScript | `Godot --version` -> `4.7.2.stable.official.ed1daf0bf`; `project.godot:10-13` |
| Run the game | `Godot --path .` (main scene `src/view/Boot.tscn`); desktop: A/D or arrows, Space = special, Esc = pause | `README.md:4`, `src/view/run_view.gd` `_unhandled_input` |
| Run tests | `Godot --headless --path . --script res://tests/run_all.gd` (25,155 checks, 0 failures this session); balance: `tests/bots/run_balance.gd -- --seeds=N`; pair audit: `tests/bots/pair_audit.gd` | `README.md:7-9`, command output |
| Control scheme | **Relative drag**: `sim.drag(dx)` adds `dx` to `target_x`; `dx = relative.x / viewport_width * 6.8` so one full screen-width swipe = 6.8 world units = the whole road (`road_half_width` 3.4). The robot lerps toward `target_x` at `lateral_follow_rate` 14 x `steer_mult` (exponential). Target clamps to +/-3.1. | `src/view/run_view.gd` `_unhandled_input`; `src/sim/run_sim.gd:93-95` (`drag`), `:496` (follow); `data/constants.json` |
| Forward speed | 9.0 m/s x `fwd_mult` (wheels +6/10/14 %), x0.6 in oil, faster in ram_charge dash | `data/constants.json` `forward_speed`; `run_sim.gd` `_tick` |
| Part level cap | 3 (`mini(3, ...)` in `RobotState.add_part`); every part has exactly 3 levels | `src/sim/robot_state.gd` `add_part`; `tests/run_all.gd` "level cap" |
| Sim | Fixed 60 Hz, deterministic, four seeded RNG streams (gates, spawns, boss, loot) | `src/sim/run_sim.gd` `step`, `src/core/rng_streams.gd`; test "same seed + input -> identical full event log" |

## 2. Reported but unverified claims

| Claim | Status | Evidence |
|---|---|---|
| First gate at z=80 | **CONFIRMED** (Level 1) | `data/gates_level1.json` beat `{"z": 80, "type": "gate"}` (cannon vs wheels) |
| First enemy formation at z=125 | **CONFIRMED** | same file: `{"z": 125, "type": "enemy_pack", "enemy": "scrapper", "count": 4}`; spawns when `beat.z <= z + 45` (`_spawn_beats`), i.e. at player z=80 |
| Nearest-target auto-fire | **PARTLY**. It is nearest-target, but restricted to a **50 degree half-angle cone** (`auto_fire_cone_deg` 50, i.e. a 100 degree wedge) and range 24, so most enemies on the road are always eligible. With no target outside a boss fight, nothing fires. Bullets fly to the target position fixed at fire time. | `data/constants.json`; `src/sim/run_sim.gd:298-317` (`_fire`) |
| A Hauler encounter exists | **CONFIRMED** | `data/enemies.json` `hauler`; `run_sim.gd` `_hauler` (spawns `miniboss` beat at 0.5 x `boss_z` in generated levels, authored at Level 1 z=450 as `elite_bruiser`, see below) |
| "Level 1 miniboss is the Hauler" | **CONTRADICTED for Level 1**: `data/gates_level1.json` still lists `"enemy": "elite_bruiser"` at z=450, but `_spawn_beats` ignores the field and spawns a `hauler` for every `miniboss` beat (`run_sim.gd` `_spawn_beats`: `"miniboss": spawn_pack("hauler", ...)`). `elite_bruiser` no longer exists in `enemies.json`. Behaviour is correct; the data field is stale. | files above |

## 3. Experiments E1-E5: what exists

| Exp | Idea | Status | Evidence |
|---|---|---|---|
| E1 | Steering is aiming: `aim_mode = lane \| nearest`, 12 degree cone, straight fire fallback | **Not built.** Only the legacy nearest-in-cone rule exists, with a 50 degree half-angle. No lane mode, no straight-ahead fallback (it returns without firing when nothing is in the cone). No targeting reticle or lock feedback in `world_view.gd` (grep for reticle/crosshair/lock: no match). | `run_sim.gd:298-317`; `world_view.gd` |
| E1 | Guarded-salvage choices | **Not built.** Ingredients exist: explosive `barrel` blast damages enemies (`run_sim.gd` `_combat`, `blast_damage_enemy` 40) and the Hauler drops barrels and carries a crate (`_hauler`). No lane-vs-lane choice of targets. | `data/enemies.json`, `run_sim.gd` |
| E2 | Charge the gates | **Not built.** A gate resolves once, when `z >= beat.z`, from the robot's lane (`_resolve_gates`); shots never touch gate panels. | `run_sim.gd:240-259` |
| E2 | Preview of next part level on the panel | **PARTLY.** Panels show `LV n > n+1` for an owned part and `COMBO!` if it completes a combo (`world_view.gd:191-206` `_gate_tag`). Nothing for a first-time part. | `world_view.gd` |
| E2 | Gates visible 3-4 s ahead | **PARTLY.** The next unresolved gate is always drawn (`world_view.gd` sync: `gate_root.visible = not gate.is_empty()`), but depth fog runs 28-105 m with curve 1.4 (`run_view.gd:154-156`), so a gate at 36 m (4 s) is in the fog ramp. Not yet measured in a screenshot. | files above |
| E2 | Payoff formation right after gate 1 | **Not built.** First pack arrives 45 m (5.0 s) after the gate. Measured time from gate 1 to the first hit by the chosen cannon: **3.3 s median** (see section 6). Wheels has no visible payoff at all in the baseline. | measurement |
| E3 | Moving gates | **Not built.** The only moving obstacle is the `saw` hazard (`hazard.x = sin(t*2)*2.8`). Gates are static `z`/lane slabs. | `run_sim.gd` `_tick` |
| E3 | focus_fire | **Not built.** | - |
| E4 | Rhythm blocks / density | **Not built as blocks.** Level 1 is hand-placed beats; generated levels place a gate every 85-110 m (9.4-12.2 s at base speed), one enemy pack 40 m after each, one miniboss, one repair bay, one final choice (`run_sim.gd:74-86`). Coin layouts rotate (`_coin_x`). No block authoring. | `data/level_generator.json`, `run_sim.gd` |
| E5 | Weapon evolution | **Not built.** Combos exist (`burst_volley`, `ram_charge`, `vacuum` active; `strafe_run`, `inferno_aura` flagged `stretch` and skipped by `RobotState.combos`) but they are cooldown specials triggered by the special button, not changed weapon behaviour. | `data/combos.json`, `robot_state.gd` `combos` |

## 4. Firing, caps, authoring

- **Weapons** (`data/parts.json`): blaster 4 dmg x 1.5/s (always); cannon L1 14 x 1.4/s, L2 two barrels, L3 gatling 9 x 7/s; rocket 40 dmg, 0.55/0.85/1.1 per s, area 2.4-2.8 m; flame is a **lane cone**: hits anything with `|dx| < 2.4` within 6/7/8 m (`run_sim.gd` `_combat`). Bullet speed 36 (rockets 26-28), ttl 2 s, range 24, special burst fires 4 homing rockets.
- **Caps**: bullets + hostile bolts <= 64 (`run_sim.gd:299`), hostile bolts <= 16 (`:443`), enemies <= 24 (`spawn_pack`, `:216`), coins <= 400 (`_spawn_beats`), world pools match (`tests/integration_suite.gd`: 24 enemy nodes, 64 bullets, 400 scrap).
- **Authoring**: Level 1 beats are literal JSON, `data/gates_level1.json` (boss at z=720). Levels >= 2 are generated by `RunSim._generate_beats()` from `data/level_generator.json` with seeded `rng.gates`; gate pairs come from `GateGen.pair` (`src/sim/gate_gen.gd`), a third utility lane from level 2 (`GateGen.with_extra`).
- **First five Level 1 gates**: z = 80, 180, 290, 400, 520 (spacing 100, 110, 110, 120 m; 8.9, 11.1, 12.2, 12.2, 13.3 s apart at 9 m/s). Further beats: `repair_bay` z=610, `final_choice` z=670, boss z=720 (seven choices in total; boss reached at ~80 s).
- **Systems that must keep working**: coin chains (`pickup_coin`, +1.5 %/step, cap +60 %), frenzy / heal / surge utility gates, combos and the special button (`tap_special`), daily login gift and daily run (`save_store.gd`, `run_view.gd` `_claim_login`), Hauler chase (`_hauler`), Scrap Titan (`boss_sim.gd`), repair bay, stars, revive. All covered by `tests/run_all.gd`.

## 5. Telemetry and performance baseline

- **Existing telemetry**: `TelemetryLog.log_event(dict)` appends JSON lines to `user://telemetry.jsonl` (`src/services/telemetry.gd`). `run_view.gd:630` logs every sim event except `scrap` and `weapon_fire`; `PerfLog` (`src/services/perf_log.gd`) writes `user://perf.json` (frame ms percentiles, draw calls, primitives, static memory) and raw `perf_frames.csv`.
- **Desktop baseline** (this session, Apple M3, vsync, `--capture` perfect bot, 45 s, `--perf-output`): p50 16.66 ms, **p95 17.17 ms**, p99 17.80 ms, worst 530 ms (startup/shader compile), 0.30 % of frames > 20 ms, **draw calls median 101, max 118**, primitives max 151,142, static memory 62.6 MB (engine static only, not PSS).
- **Target phone**: **UNVERIFIED / NOT RUN.** No device is attached (`adb devices` lists none) and `results/` contains no phone run. Existing budgets from `reports/FINAL_REPORT.md`: p95 <= 16.7 ms, draw calls <= 150, PSS <= 400 MB. Desktop numbers are not evidence for the phone.

## 6. Baseline engagement measurement (flags off)

Measurement tooling (added in this step, no gameplay change): `src/sim/engagement_log.gd` (hooked from `RunSim.emit`, one impact hook and one tick hook, active only when `flags.engagement_metrics` is true), `data/flags.json`, `tests/bots/measure_engagement.gd`, `tests/bots/trace_hash.gd`. Level 1, seeds 1000-1019, same fixed-step sim as gameplay:

| Bot | win % | first gate s | payoff s (median) | payoff <= 2 s | max gap pre-boss, median | p90 | runs with gap <= 4 s |
|---|---|---|---|---|---|---|---|
| perfect, delay 0 / 150 / 250 / 400 ms | 100 | 8.9 | 3.3 | 0 % | 5.6 s | 5.6 s | 0 % |
| random (28 % missed telegraphs) | 95 | 8.9 | 3.3 | 0 % | 5.0 s | 5.6 s | 0 % |
| no_dodge | 60 | 8.9 | 3.3 | 0 % | 10.0 s | 11.7 s | 0 % |

Notes: reaction delay only affects the boss-telegraph response in the existing `BotController`, so the four perfect rows are identical (not a bug; E1 adds an aiming bot with real delays). The 5.6 s gap is the road between the first coin trail and gate 1 plus the walk to the first enemy. Definitions are in section 7. Trace fingerprint of 36 bot runs (levels 1-3 x 3 bots x 4 seeds) was stored before any change: `results/interactivity_trace_baseline.txt`; with the new files and every flag off it reproduces exactly (`TRACE MATCH`).

## 7. Metric definitions (what is counted)

A **player-decided outcome** is logged as: `shot` (a bullet lands on an enemy whose |x - robot x| <= 1.2 m, i.e. in the lane the player is standing in; shots on enemies off to the side do not count), `gate` (gate pass), `charge` (E2 charge tick), `dodge` (an enemy or boss telegraph resolved with the robot >= 1 m from the marked lane after having moved >= 0.8 m since the telegraph began), `pickup` (coin picked up while the target position moved >= 0.3 m in the last second), `special` (special used), `payoff` (E2). `time_to_first_gate` = sim time of the first gate pass. `time_to_first_payoff` = seconds from crossing gate 1 until the chosen part shows its effect: weapons = first landed hit by that weapon id; armour = first hit taken with armour; shield = block; magnet/storage = next coin; wheels/tracks = an explicit `payoff` event (none exists in the baseline, so these runs report no payoff). `max_engagement_gap` = longest span between consecutive marks from run start to boss entry (a second, full-run value is also stored).

## 8. Naming and assets that say "Scrap Dragon" (for the end of the work)

`project.godot:4` `config/name`, `export_presets.cfg` (`package/name` x4; `package/unique_name` = `com.aryankinha.scrapdragon` stays), `src/view/run_view.gd:1181` home title, `README.md`, `addons/scrap_ads_export/plugin.cfg`, `tools/write_reports.py`. Godot derives the desktop `user://` folder from `config/name`; renaming it without `config/use_custom_user_dir` would orphan existing saves, so it will be paired with a custom user dir that keeps the old folder name.

## 9. Experiments I will build

E1 (aim modes + guarded salvage), E2 (gate charge + payoff formation), E3 (moving gates + focus_fire flag), E4 (rhythm blocks + density ramp), E5 (one weapon evolution). Nothing on the list already exists in full, so none is skipped. Not built: chase threat, visible victory destination (need owner approval after playtest).
