# NEW_GAME_CHECKLIST: copy this into each new game

Purpose: ordered checklist and reusable agent prompts for starting a Godot Android game with this stack.
Last verified: 2026-10-28
Read this when: you start a new game.

## Checklist
- [ ] `git init`, add `.gitignore` (`.godot/`, `/android/`, `/build/`, `*.jks`, `*.keystore`, `*.idsig`), first commit.
- [ ] Copy `godot_playbook/` into the game as `docs/playbook/` (a copy; the master stays in `godot_playbook/`).
- [ ] Write the one-page spec in `docs/SPEC.md` (loop, controls, scoring, target phones, size budget, art source).
- [ ] Project skeleton from `docs/STACK.md`: `project.godot` settings, `Main.tscn`, `scripts/`, `tests/`, `tools/`, presets, `build/.gdignore`.
- [ ] Install the Gradle template for the same Godot version; set the JDK 17 path in Editor Settings.
- [ ] Logic class first; headless tests pass (`godot --headless --path . --script tests/test_logic.gd`); add a seeded simulation test.
- [ ] Presentation built from code; integration test; draw-call breakdown saved under `results/`.
- [ ] Debug gating for overlay and loggers via `OS.is_debug_build()`; copy `perf_logger.gd` and `death_logger.gd` if useful.
- [ ] Exports: debug APK (Compat), sideload arm64 APK, release AAB build with the keystore from the environment.
- [ ] Phone test per `docs/PHONE_TEST_PROTOCOL.md`; summaries saved under `results/phone<N>_<timestamp>/`.
- [ ] Optimisation pass from `docs/OPTIMISATION.md`; before/after numbers recorded.
- [ ] Asset and font checks (`docs/ASSETS_AND_FONTS.md`); `LICENSES.md` row for every download.
- [ ] Ads step if needed (`docs/ADS.md`): test IDs first, real IDs in release only.
- [ ] Release step (`docs/RELEASE.md`): size, signing, permissions, store listing.

## Standard prompts (copy one at a time)
1. **Start.** "Read AGENTS.md and docs/playbook/docs/STACK.md. Create the project skeleton for the game described in docs/SPEC.md: Compat renderer, portrait, Gradle template installed, a pure logic class under scripts/, and a headless test runner under tests/. Run the tests and show the output."
2. **Logic.** "Implement the game rules in scripts/game_logic.gd as a RefCounted class with signals and no nodes. Add tests/test_logic.gd and a seeded simulation test. Keep every balance constant in one labelled block at the top. Run both tests."
3. **Presentation.** "Build the scene from code in scripts/main.gd and connect it to the logic class. Use merged meshes and MultiMesh for repeated geometry, one shared material, and a pooled spawn list. Add an integration test, then run tests/draw_breakdown.gd and save the table to results/."
4. **Exports.** "Add presets for debug APK (Compat), sideload arm64 APK and release AAB following docs/playbook/docs/STACK.md. Build the debug APK, print its size and SHA-256, and list its permissions with aapt2."
5. **Phone test.** "Follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Check the adb allow-list script, run preflight, install, and run the scenes in this order: [list]. Save everything under results/ and finish with the Claim | Evidence | Status table."
6. **Optimise.** "Read docs/playbook/docs/OPTIMISATION.md and results/. Propose the three changes with the best measured gain for this game, apply them one at a time, re-run the same phone scenes after each, and report p99, share over 20 ms, worst frame, draw calls and memory before and after."
7. **Assets and fonts.** "Add [asset pack or font] following docs/playbook/docs/ASSETS_AND_FONTS.md: confirm the licence on the source page, download into third_party/, add the LICENSES.md row with SHA-256, set texture imports to ETC2 or ASTC with mipmaps at 2K, and run the texture and model scenes."
8. **Ads.** "Integrate AdMob following docs/playbook/docs/ADS.md with Google's public test IDs only. Add the test menu, pause game logic on app pause, run the ads session on the phone while I tap, and report every callback."
9. **Release.** "Follow docs/playbook/docs/RELEASE.md: build the release AAB with the keystore from environment variables, list permissions, compare the AAB size with the Play limits, and write the release notes."
