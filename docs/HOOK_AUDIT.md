# Hook Pass audit — 2 November 2026 (HOOK-0)

No gameplay or presentation changed for this baseline. Existing source: b5f4915. User-owned `scrap_bot_upgrade_lab.html` is untracked and left alone. Godot playbook, UI_AUDIT/UI_PLAN/MOB_AUDIT and latest UI/Mob reports read. New brief takes precedence: it explicitly permits flagged gameplay/material changes and static camera reframing that the UI-only plan excluded.

## Reported code facts (section 3)

| Claim | Verdict | Evidence |
|---|---|---|
| Godot4.7.2 Compat, pure60Hz sim/data/view split | CONFIRMED | `project.godot`; engine banners in `results/hook0_baseline_headless.txt`; `RunSim.step`; `src/sim`, `src/view`, `data` |
| All experiments off;25320 checks / trace | CONFIRMED | `data/flags.json`; completed `hook0_baseline_headless.txt` (incl59 integration), `hook0_baseline_trace.txt` TRACE MATCH |
| SoA Mob,200 live cap /120 governor floor | CONFIRMED | `MobSim` packed arrays, live_cap; RunView `_govern_density`0.6 floor |
| Merge up to2.2× and preserves damage | PARTLY CONTRADICTED |2.2 is a view-scale clamp. Damage/weight can grow without bound in add_drone/_multiply/_compact_one. There is no silently discarded direct damage to reclaim today. New tiers must redirect only explicitly bounded residual payload, never credit retained damage twice. |
| 12 L1 rows, five gate types, champion | CONFIRMED | `data/mob.json`, `RunSim._add_mob_gates`, `MobSim.launch_champion` |
| Five cannon sockets / levels1–3 / Hangar1–5 | CONFIRMED with important limit | Five alternative mounts, NOT five separately owned cannon instances. `RobotState.parts` has one family key; repeated pickups upgrade that one part. `parts.json`, `RobotState.add_part`; trims3/5 in RobotBuilder.sync. No socket-full cannon-count mechanic is invented. |
| Stable62° and colors; chips/equipment/popups≤64 | CONFIRMED | RunView camera helpers and event handler, WorldView.popup; existing completed UI visual-focus logs. UI-v2 already implements small dock, handedness and prioritized feedback but is off by default. |
| Procedural toon/single merged ArrayMesh/socket robot | CONFIRMED | MeshFactory.TOON_SHADER/merged, RobotBuilder.sync/_layout_attachments |
| Governor18.5ms/135draws and phone untested | CONFIRMED | RunView._govern_density; UI_REPORT and device log. A fresh phone check will be recorded. Frame-dependent governor inputs mean daily seed alone cannot guarantee identical density across devices; deterministic tests hold density schedules fixed. |

## Owner screenshots (section 4), re-captured

New captures: `results/hook_before/` eight states ×360×640 and600×960; exact rectangles/draw counts in inventory.json. This capture explicitly enables the existing Mob Stream to show both gate families; all new flags are off and ui_v2 is off. Separate default-game performance/bot baselines have Mob off.

| Observation | Verdict | Evidence/qualification |
|---|---|---|
| S1 pale cream fog/grey road | CONFIRMED | run_start/mid_run screenshots; RunView environment. “Small robot” is not universal: later builds occupy substantial screen space. Maximum synthetic loadout edge clipping was documented by UI pass and will be checked with the new static framing. |
| S2 similar framed mob/part families; part names small at distance | CONFIRMED | mob_gate/part_gate screenshots; WorldView.rebuild_gate/_rebuild_mob_gate. Legacy +N means N copies per5 arrivals, not +N per volley: no stream-size choice crossover is possible. |
| S3 a few figures rather than horde | CONFIRMED for baseline | mid_run screenshot; spawn_pack cap24 /14 dense; existing short columns are not a new horde-scaling system. |
| S4 soft pills/HP/progress/tiny-bot caption | CONFIRMED for default, CONTRADICTED for ui_v2 | default screenshots vs existing UI-v2 captures/code. Reuse v2 instead of rebuilding it. |
| S5 big empty percentage and reroll circles | CONFIRMED for default, CONTRADICTED for ui_v2 | legacy _build_hud vs v2 small stable SPECIAL state. New clarity uses v2 and contextual reroll. |
| S6 text collisions with hero/gates | CONFIRMED for legacy; PARTLY fixed by v2 | baseline screenshots; v2 counter row was already moved inside header. Hook will retain that and measure gate bounds/hint placement. |

## Code paths / baseline and reuse

- `RunSim.setup/_add_mob_gates/_generate_beats/_spawn_beats/spawn_pack/_combat/emit`: setup, authoring, capped spawning, damage and events. `data/blocks.json` and mob.enemy_streams already provide rhythm/columns; reuse them, do not duplicate systems.
- `MobSim.launch_volley/flame/_apply_panel/_multiply/add_drone/_compact_one/register_gates`: split payload, add-per-five semantics, unbounded merge, gate masks and pass counters. New arithmetic uses isolated cohort semantics and preserves the complete legacy branch.
- `StatCalc.compute`, `RobotState.add_part`, `data/parts.json`, `economy.json`: part level changes shape, permanent Hangar tiers add8% main stat per tier. In-run material state belongs to the run, not the save or these existing star tiers.
- `WorldView.rebuild_gate/_rebuild_mob_gate/_sync_mob_gates/sync`: gate geometry/numbers, already pooled mob gates, boosted tint, scrapper MultiMesh and shadows. Reuse current instancing, enlarge capacity only for horde candidate.
- `MeshFactory.palette/crowd_palette/part/drone/merged`; `RobotBuilder.sync/_layout_attachments`: shared shader, merged hardware, socket packing. Material artifacts must not change gameplay hitboxes.
- `RunView._events/_tick_run_hud/_reset_camera/_update_camera/_govern_density` and `UiV2`: one hero, grouped receipts, fixed chain row,120px mirrored controls, volume/flash/RM preferences. Reuse and extend.
- `EngagementLog.results`: max_gap_pre_boss and max_gap_full_run already exist. They are proxies, not a human engagement score.

Gate-spacing evidence: `results/hook0_authored_gate_spacing.json`. Parts at80,180,290,400,520,610,670; old mob620 is10m from repair610 and690 is20m from final670. Enforce a new25m rule on candidate authoring, preserving legacy data. First actual part choice8.900s; old5.05 report value was an engagement gap, not the first part gate. Baseline metrics and p95 are in `hook0_*` results; no phone/human outcomes are invented.

Measured baseline (desktop, engine cap60/vsync1, actual648×1152 Retina2): p95 18.334ms, median79/peak96 draws, worst595.641ms; all raw samples retained in hook0_perf_default_frames.csv. This is not a strict60fps pass. The current Mob-only baseline first pass1.233s/part8.900s, peak enemy9/drone105 and max pre-boss engagement gap2.217s come from hook0_sim_probe.json. Default peak enemies10/gap5.050s; pool-distance gate counts2 vs1 are not exact frustum visibility.
