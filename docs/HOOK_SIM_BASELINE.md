# Hook Pass simulation baseline — 2 November 2026

Read-only game-source audit at the start of Hook Pass. No gameplay, visual or data tuning is changed by this document. `scrap_bot_upgrade_lab.html` was already untracked and was not touched. Source references describe the pre-Hook implementation. Measurements below are headless simulation results, not screenshots, device performance, human preference or exact camera-visible counts.

## Verified current systems

| Reported item | Verdict | Evidence and limits |
|---|---|---|
| Godot4.7.2 / Compatibility / pure60Hz sim | CONFIRMED | Engine banner in `results/hook0_baseline_headless.txt`; `project.godot`; `RunSim extends RefCounted` (`src/sim/run_sim.gd:1`), `MobSim extends RefCounted` (`mob_sim.gd:1`); fixed60Hz tests. |
| All experiment booleans defaultoff | CONFIRMED | `data/flags.json`; `aim_mode` is the nonboolean `nearest`. `ui_v2` exists and is also false. |
| 25,320 existing checks incl59 integration | CONFIRMED this session | `results/hook0_baseline_headless.txt`:25,320 checks,0 failures; integration59,0 failures. Process completed normally. |
| Flag-off trace matches | CONFIRMED this session | `results/hook0_baseline_trace.txt`: `TRACE MATCH`, normal completion; stored baseline was not regenerated. |
| Mob packed arrays, cap200 scaled by governor | CONFIRMED | `mob_sim.gd:9–27,46–47`; `data/mob.json`; `run_sim.gd:712–714`. Nominal120–200 range follows density0.6–1; code `live_cap()` itself allows down to8 if a lower cap_scale is supplied. Champions share this cap. |
| Merged drones carry unlimited numeric payload but max visual scale2.2 | CONFIRMED with qualification | `_multiply:465–479`, `add_drone:76–112`, `_compact_one:114–148` keep damage/charge by merging. `WorldView:485–488` clamps **drawing scale**, not payload weight. Champion draw-scale limit is6.6. Thus the claim that numeric merge strength is bounded at visual2.2 is CONTRADICTED. |
| Twelve L1 mob rows and all five gate types | CONFIRMED | `data/mob.json:gates.level1`; `_apply_panel:482–517`. Generated rows are authored at setup (`run_sim.gd:117–147`). |
| Five cannon sockets | CONFIRMED as alternatives, CONTRADICTED as five independent cannons | `data/parts.json:89+` lists top_c/top_l/top_r/side_l/side_r. `RobotState.parts` is keyed by family; `add_part:58–106` upgrades the one cannon entry to maxL3, retaining one occupied socket. No five-cannon ownership/cap mechanic exists. |
| Cannon→Twin→Gatling shape levels and Hangar1–5 | CONFIRMED | `data/parts.json:103,113,123`; `StatCalc:10,26` adds8% main stat per permanent tier; RobotBuilder:145–148 gives gold trim at3/4, blue/cyan at5. There is no separate run material-quality state. |
| Bigger horde, shielded class, player-power scaling | CONTRADICTED as existing features | Enemy streams exist, but `_spawn_stream:160–164` is scrapper-only; pack sizes depend on base/road progress/density, not player power. Existing regular types scrapper/gunner/bruiser/hauler do not implement a shielded damage rule. |
| Governor thresholds18.5ms/135draws/floor0.6 | CONFIRMED | `run_view.gd:1070–1087`. Numeric cap/density changes can affect gameplay; device timing is an external deterministic-replay input, not part of the random seed. |
| Phone performance | UNVERIFIED | No phone test run by this audit; historical reports state none. Headless sim timings are not GPU/frame-rate evidence. |

## Code path inventory

- Setup/flags/RNG: `RunSim.setup:63–114` copies flag data, seeds four independent RNG streams, creates MobSim only for mob_stream. `src/core/rng_streams.gd:6–10` seeds gates/spawns/boss/loot separately.
- Part gates: authored L1 `data/gates_level1.json`, generated levels `_generate_beats:166–178`; robot crosses gate plane in `_resolve_gates:415–439`. Ordinary and final gates, repairs all have `options`. Gate charging is separate from projectile multiplication. Gate history and `gate_choice` are emitted for all part-family options.
- Mob gates: definitions `data/mob.json:gates`; append in `_add_mob_gates:117–147`; register ordinal masks/state in `MobSim.register_gates:417–431`; lane geometry/offset `434–461`; panel application `482–537`; bounded receipt batching `540–562`.
- Volleys: `MobSim.launch_volley:187–214` looks up per-level counts (cannon2/3/4, rocket1/2/3, base blaster3), divides each barrel shot's direct damage by count, and emits that many entities. Cannon L2's two barrels each invoke a separate volley from `RunSim:707–711`. Torch `MobSim.flame:241–261` emits6 volleys/s with3/4/5 drones and old cone DPS divided across them; it carries a separate burn payload.
- Overflow: `add_drone` tries a same-kind/mask/family last entity when full; otherwise `_compact_one` frees one slot. `_multiply` spawns real copies where room exists and folds the remaining multiplication into weight/damage. `enforce_cap` compacts when governor cap shrinks. There is no lost-damage-to-tier event or ledger today.
- Stats/tiers: `StatCalc.compute:3–38`; permanent `robot.tiers` is save-derived. `RobotState.add_part:58–106` and `break_part:127–150` own physical-level transitions. `take_damage:153+` resets the existing **coin** chain; there is no persistent kill-chain sim variable (view combo is not a sim truth).
- Spawning: `RunSim._scaled:210–214`, `_spawn_wave:216+`, `_spawn_stream:160–164`, `_place:242–253`, `spawn_pack:384–389`, `_spawn_beats:391–407`. Caps are24 normal and14 with dense_blocks. All stream `_place` calls still go through the same cap. Excess pack members are not queued for later spawning.
- View-cap coupling: `WorldView:117–123` allocates24 enemy nodes and a24-instance scrapper batch; `sync:653–663` loops that pool. The shadow pool is26 and `sync:651` uses enemy-array length+1. Raising only the sim horde cap would silently omit enemies and overflow shadow capacity: pool/batch/shadow capacities must change together under the flag.
- Instrumentation: `EngagementLog.results:136–150` supplies `max_gap_pre_boss`, `max_gap_full_run`, `time_to_first_gate`, `time_to_first_multiply`; there is no literal field named max_engagement_gap. This proxy marks steering-linked hits/pickups/gates, not human engagement.

## This-session baseline measurements

Probe source and output: `results/hook0_sim_probe.gd`, `.json`, `.txt`. Reproduce with `Godot --headless --path . --script results/hook0_sim_probe.gd`. Seed20261031, MobBot delay150ms, no saved upgrades, fixed60Hz, up to300 sim seconds, stop on win/loss. `engagement_metrics=true` is enabled only for measurement in every row. New Hook flags do not exist yet and are therefore off.

| Baseline variant | State/end seconds | First part-choice s | First multiply s | Peak enemy array | Peak gate rows under pool/distance rules | Max pre-boss decision gap s |
|---|---|---:|---:|---:|---:|---:|
| Default gameplay flags off | won92.067 | 8.900 | unavailable | 10 | 1 | 5.050 |
| Existing mob_stream only | won92.467 | 8.900 | 1.233 | 9 | 2 | 2.217 |
| Existing full interactivity/Mob bundle | won91.767 | 8.900 | 1.233 | 14 | 2 | 2.817 |

The default contains **no mob gate**, so reporting an actual default-off first-mob time would be false. The1.233s figure is a drone pass; first mob rowz45 would take the base-speed robot5s to reach. First part gatez80 takes8.9s, and5.05s in earlier report tables is an engagement gap, not first part arrival. Enemy array peak counts include entities outside the exact camera frustum; the root visual audit must measure screenshot-visible enemies separately. No new graphical/desktop performance run was performed by this sub-audit.

Mob-only sample:105 drone peak,0 cap ticks,0 merges. Full bundle:200 peak,14 cap ticks,39 merges, no over-cap ticks. This matters: if material progress relies only on numeric overflow, existing standalone Mob Stream provides none in this sample. New chains / bounded merge capacity / genuine kill-chain progress need tuning to reach the requested tier timings; do not fabricate overflow where existing payload was already preserved.

## Authoring conflicts to resolve behind the flag

`results/hook0_authored_gate_spacing.json` records all distances. Current part-familyz positions:80,180,290,400,520,610,670. Most mob rows satisfy25m; z620 is10m from repair610, and z690 is20m from final670. A25m minimum must include repair/final gates, not only ordinary `type==gate`, or these hierarchy fights slip through. Generated rows' midpoint strategy usually clears spacing but must validate actual generated repair/final rows as well. Chain members can be12–20m apart **within the mob family**, while every member must still be≥the chosen part-family separation. Validation belongs on authored Hook data and generated output, without mutating the original flag-off schedule.

## Gate projection and choice: fundamental semantic conflict

Current `add` addsN copies every5 individual incoming drones (`MobSim:497–502`, data add_per5). Long-run gain isN/5, independent of stream size. Current ×2 gain is1.0; +5 is equal, +10 is always bigger. `MobBot.panel_value:20+` mirrors that fraction and caches a noisy lane choice once per row. The desired “+10 wins small / ×2 wins large” cannot be achieved by merely drawing a live counter. It requires a new flag-only per-volley/cohort contract, plus a bot that reads its projection live rather than the legacy constant fraction.

Recommended contract:

1. Assign a packed cohort ID to each barrel/torch volley; store family, launch nominal per-unit direct damage, current weighted units and gate-history references in bounded metadata. In-flight units retain their launch material tier to avoid retroactively injecting unaccounted payload at a forge moment.
2. Apply a gate atomically to the active cohort when its lead member reaches the plane, choosing one lane from a documented lead/centroid rule. This removes partial-arrival preview races. One pure `project_units(U,panel)` returns `U×v`, `U+v`, `U×(1+v/100)`, `U`, or the deterministic trap result; the actual application uses the same math. All cohort members/copies get the gate bit at once.
3. Use one label everywhere: **STREAM POWER**, expressed either as weighted drone-equivalent units per volley or canonical direct-damage units per volley. If using family-specific nominal units, identify the family because cannon and rocket unit damage differ. Canonical direct-damage units are simpler to combine across families but must not be labelled raw drone entity count. Choose once and document; entities can merge without making the number false.
4. +N applies once per cohort; new bonus entities/weight sum to exactlyN canonical units, not N per arrival. ×N transforms the whole cohort. A counter over arbitrary current live entities is not an honest preview of a future volley after travel/hits.
5. Merge only cohort-compatible snapshots in Hook mode; legacy compatibility keys and arithmetic stay untouched off. If no compatible physical capacity exists, account the new/residual payload in tier credit, never silently cross-merge incompatible gate histories. Bound metadata by active cohort references and clean up after the last entity expires.

## Material overflow ledger / deterministic safety

- Existing merged direct payload is **already conserved** even beyond the visual2.2 clamp. Do not give tier credit for all current merges as well as retaining their full damage: that creates a reward from the same surplus twice.
- Under material_tiers only, derive a real per-kind maximum weight from the visual rule: `w_max = 1 + (scale_max / kind_base_scale - 1) / scale_per_extra_weight` (ordinary bolt≈3.533, bomb≈3.099, torch≈4.333). Champions have their separate scale exception. Clamp/allocate only the Hook branch; legacy numeric payload stays unlimited.
- For each allocation, define `incoming nominal direct payload = physically stored nominal payload + credited residual nominal payload`. Existing payload cannot be counted again as fresh surplus. Reconcile launch overflow, multiplier/add bonus overflow and governor shrink through one ledger, with separate trap loss, hit consumption and expiry counters. Progress credit can be denominated in canonical surplus units; document its normalization and tuning.
- Do not claim conservation of future landed DPS, splash coverage, pierces or burning: those depend on target layout and nonstacking status effects. Existing compaction uses max burn/radius and OR masks (`_compact_one:137–146`). Direct payload/charge is the defensible invariant.
- The prompt allows primary-family progress routing instead of a rolling damage-attribution system. Prefer that explicitly recorded simplification. A sim-side unbroken kill streak can supplement progress; do not read the view-only combo into the sim.
- Tier multiplication should apply at launch to per-drone payload without creating entities. Store tier/family snapshot for rendering. Tier progress never decreases; damage pause affects the progress timer only, not already-earned tiers.
- Power-dependent spawning is deterministic with the same sim inputs, including the density governor schedule. `RunView` derives that schedule from real device timing; seed alone therefore cannot guarantee the same counts on every device. Record/replay governor inputs or state this limitation. Decide jackpot values up front from `rng.gates`, never from render/reveal time; keep spawn/loot streams independent.

## Existing bot target and measurement limitations

`tests/bots/mob_measure.gd` already runs0/150/250/400ms, plus stay/aim/random/no_dodge. `MobBot` now delays whole steering commands including boss dodges, not human perception. Existing report's aiming-bot acceptance target is100% in its sampled30 seeds (`reports/MOB_STREAM_REPORT.md:139`); this is a completion target, not healthy difficulty by itself. Historical independent Mob and bundle runs were100% for all four aiming delays; stationary and random controls must also be reported to expose triviality. Existing `mob_pick.gd` uses realised damage over a window; near-equal choices and trap rows can violate the older40–60% criterion. New pure projection choice tests should deliberately sample both sides of `U=N/(mult−1)` and require both options to win; do not use random tie noise to manufacture20% pick shares.
