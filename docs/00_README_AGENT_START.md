# SCRAP DRAGON — Agent Start Here

You are building **Scrap Dragon** (working title; originally "SCRAP BOT"): a portrait mobile 3D gate-runner where a tiny robot grows into a huge battle machine through physical part-attaching gates, then fights a boss. Engine: **Godot 4.7.x, GDScript, Compatibility renderer, Android first**.

This pack has seven files. Read them in this order, then build in the order of `05_BUILD_PLAN.md`.

| # | File | What it gives you |
|---|---|---|
| 00 | `00_README_AGENT_START.md` | This file: priorities, rules, open decisions |
| 01 | `01_GAME_DESIGN.md` | What the game is, how a run flows, every system and why it exists |
| 02 | `02_ASSET_PLAN.md` | Free CC0 packs to use, slot-by-slot asset mapping, procedural fallbacks |
| 03 | `03_TECH_ARCHITECTURE.md` | Project settings, folder layout, sim/view split, key code skeletons |
| 04 | `04_DATA_TABLES.md` | Every number: parts, gates, combos, enemies, boss, economy (single source of truth) |
| 05 | `05_BUILD_PLAN.md` | Milestones M0–M7, acceptance tests, bots, phone-test protocol, report template |
| 06 | `06_UI_JUICE_AUDIO.md` | Screens, juice, haptics, SFX map, camera, VFX |

Put these files in `docs/` inside the project. Put the AI-generated concept art in `reference/` as a visual target (use it for look-and-feel reference; build the shipped art from the CC0 packs in file 02).

---

## 1. The five things that make this game work (protect them in every decision)

1. **Immediate transformation.** The first gate choice changes the robot's look and power within 10 seconds of launch.
2. **Visible build.** Every choice shows up physically on the robot. Two players end with two clearly different silhouettes.
3. **Parts matter.** Enemy hits can knock parts off, so players protect their build and feel loss.
4. **A real boss.** A three-phase fight with telegraphed attacks, weak points that reward specific parts, and a satisfying kill.
5. **Fast loop.** From failure or victory back into the next run in about 3 seconds. No menu before the first run.

When a design question is unclear, choose the option that strengthens one of these five.

## 2. Hard targets

| Target | Value |
|---|---|
| Run length | 90 s (Level 1) to 150 s (later levels) |
| Choice cadence | An interesting choice every 10–20 s |
| Frame rate | 60 fps on a mid-range phone; draw calls ≤ 150 per gameplay frame |
| Install size | Under 120 MB (aim for under 60 MB) |
| First playable frame | Under 2.5 s from tap on the launcher icon |
| Retention goals (for later live testing) | D1 ≥ 35%, D7 ≥ 10% (hybrid-casual benchmark range) |

## 3. Stack rules (positive form)

- Use **Godot 4.7.x**, renderer `gl_compatibility` for every export preset. Use `CPUParticles3D` for effects (verify any `GPUParticles3D` on the phone before relying on it).
- Write gameplay logic as **pure `RefCounted` classes** (the "sim"), driven by a fixed 60 Hz step and a seeded RNG. Write the "view" (nodes, meshes, particles, UI) as a thin layer that reads sim state and reacts to sim events. This makes headless tests and bot balancing possible.
- Keep **all numbers in `data/*.json`** (content from `04_DATA_TABLES.md`). Load them once at boot into typed dictionaries.
- Use **one shared palette material** for all robot parts (see file 02) so assets from different packs look like one family and batch well.
- Use **MultiMeshInstance3D** for scrap pickups, **object pools** for bullets, enemies, debris and floating text.
- Run `git init` on day one and **commit at the end of every milestone**.
- Test on a **real Android phone** at each milestone. Use `tools/phone_perf_session.sh` style logging (frame-time percentiles, draw calls, memory, first playable frame).

## 4. Working agreement per milestone

1. Build only the current milestone's scope.
2. Run headless tests (`godot --headless --script res://tests/run_all.gd`) and fix to green.
3. Run the phone test described in `05_BUILD_PLAN.md`.
4. Write `reports/Mx_REPORT.md` using the template at the end of `05_BUILD_PLAN.md`. Include screenshots, measured numbers, and open questions, so the human owner can review it with Claude.
5. Commit with message `Mx: <summary>`.

## 5. Open decisions (defaults apply until the owner changes them)

| # | Decision | Default |
|---|---|---|
| D1 | Boss identity | Zone 1 boss is the **Scrap Titan** (giant robot, red eyes, matches the concept art). The **Scrap Dragon** is reserved as the Zone 4 final boss and marketing hero; no prototype work depends on it. |
| D2 | Zones in the prototype | Zone 1 (Junkyard) only. Data supports Desert, Factory, Snow (see file 04) for later. |
| D3 | Robot growth model | Chassis swaps at 3 stages (Tiny → Battle → Monster) plus visible attached parts. |
| D4 | Hidden assist | After 2 consecutive boss losses, boss HP −10% per loss (max −30%), resets on win. |
| D5 | Ads in prototype | Rewarded ads only (revive, re-roll, double reward, repair). Test IDs only. Interstitials arrive after the core is proven. |
| D6 | Daily challenge | Local seeded run with a local best score. Online leaderboard is post-prototype. |
| D7 | Package id | `com.aryankinha.scrapdragon` (placeholder) |

## 6. Definition of "prototype done"

A person who has never seen the game can: launch, drag to steer, choose gates, see the robot transform at least twice, lose a part to an enemy, reach the boss, learn from one failure, beat the boss within 3 attempts, and see a result screen with a hangar upgrade. All on a physical phone at 60 fps.

## 7. Glossary

- **Run**: one level from spawn to boss kill or death.
- **Gate**: a pair of physical panels across the road; the robot's lateral position at the gate line selects left or right.
- **Part**: an attachable component (wheels, cannon…) with levels 1–3.
- **Socket**: a named attach point (`Marker3D`) on the chassis.
- **Chassis stage**: Tiny, Battle or Monster body model.
- **Combo**: a pair of owned parts that unlocks a tap-to-use special.
- **Scrap**: in-run currency. **Cogs**: meta currency spent in the Hangar.
- **Sim / View**: pure logic layer / node-and-mesh layer.
