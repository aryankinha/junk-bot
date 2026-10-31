# AGENTS.md: Godot Android Game Playbook

Purpose: entry point that gives an agent our stack, workflow, definition of done and where measurements live.
Last verified: 2026-10-28
Read this when: you start a new game, an optimisation pass, a phone test or a release in this workspace.

## What this playbook is
A set of short documents built from two real projects and their result files: `car/` (Road Dodge, a finished
3-lane game) and `godot_lab/` (asset, font and ads test project). Every number in it names its source file.

## Reading order
1. `docs/STACK.md`: engine, project settings, presets, architecture.
2. `docs/NEW_GAME_CHECKLIST.md`: the steps and reusable prompts for a new game.
3. `docs/FINDINGS.md`: measured results (tables with their "Measured on" line).
4. `docs/OPTIMISATION.md`: what to change, ordered by measured gain.
5. `docs/ASSETS_AND_FONTS.md`, `docs/ADS.md`: asset pipeline, fonts, AdMob.
6. `docs/PHONE_TEST_PROTOCOL.md`: the repeatable phone test and its scripts.
7. `docs/RELEASE.md`: AAB, keystore, Play limits.
8. `docs/NEXT_EXPERIMENTS.md`: measurements to add next.

## Our stack (5 lines)
- Godot 4.7.2 (`godot_lab/project.godot` features line 4.7); GDScript only.
- Compat (OpenGL) renderer as the default; Mobile (Vulkan) kept as a feature-tag comparison build.
- Android first: arm64-v8a, Gradle custom build, debug APK for testing, release AAB for Play.
- Gameplay in a pure logic class with headless tests; visuals built from code until real assets are needed.
- An AI agent builds, tests and measures; a human plays, judges looks and accepts install prompts.

## Workflow for every new game, with definition of done
| Stage | Definition of done |
| --- | --- |
| 1. Spec | One page: loop, controls, scoring, target phones, size budget, art source. |
| 2. Logic + headless tests | `RefCounted` logic class; `godot --headless --path . --script tests/test_logic.gd` passes; a seeded simulation test exists. |
| 3. Presentation | Main scene builds from code; integration test passes; draw calls recorded with `tests/draw_breakdown.gd`. |
| 4. Exports | Debug APK (Compat), sideload arm64 APK, release AAB build; `aapt2 dump permissions` listed in the report. |
| 5. Phone test | Protocol in `docs/PHONE_TEST_PROTOCOL.md`; CSVs and summaries saved under `results/`. |
| 6. Optimise | Pick items from `docs/OPTIMISATION.md`; re-measure with the same protocol; record before/after. |
| 7. Assets, fonts, ads | Licence table updated; fonts and ads checked with the lab scenes when the game uses them. |
| 8. Release | `docs/RELEASE.md` checklist complete; keystore outside the project. |

## Rules
- Write every measurement to a file under `results/` and cite that path next to the number.
- Use raw frame times (`Time.get_ticks_usec`) with `run/delta_smoothing=false` for jitter; report p99, share over 20 ms and worst.
- Phone work: `-s <serial>` on every adb command, our own packages only, adb allow-list from the protocol.
- New files get new names; keep earlier results in place.
- Copy this playbook into each game's `docs/playbook/` (a copy; the master stays here).

## Where things live
- Road Dodge: `car/` (README.md, scripts/, tests/, tools/, export_presets.cfg).
- Lab: `godot_lab/` (PLAN.md, LICENSES.md, scripts/, tools/, results/, markers.txt).
- Phone results: `car/phone_test_results/`, `godot_lab/results/phone*/`.
- Playbook tools: `godot_playbook/tools/build_findings.py`, `godot_playbook/tools/check_playbook.py`.
