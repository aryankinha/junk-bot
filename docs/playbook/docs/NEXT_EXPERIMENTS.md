# NEXT_EXPERIMENTS: measurements to add next

Purpose: the open measurement opportunities, what each adds, and the command or prompt that starts it.
Last verified: 2026-10-28
Read this when: you plan the next testing session or want to widen what the playbook covers.

Measured so far on: OnePlus CPH2585, SM8550 (kalama), Adreno 740, Android 16 (SDK 36), 60 Hz, Godot 4.7.2.

| # | Experiment | What it adds | Start with |
| --- | --- | --- | --- |
| 1 | Budget-phone run with the same protocol | Real budget numbers for frame time, load time, texture memory and temperature (the current budget table is empty) | Prompt: "Follow docs/PHONE_TEST_PROTOCOL.md on this phone: S5 ladder, S4 2K, font scenes; save under results/ and compare with FINDINGS.md." |
| 2 | Mobile (Vulkan) comparison on a newer phone | Confirms the renderer choice on a second GPU; the lab already has a `Lab Mobile` preset | `godot --headless --path . --export-debug "Lab Mobile" builds/lab_mobile_debug.apk`, then the protocol with `S4` |
| 3 | Kenney and Quaternius scenes S1 to S3 | Node versus MultiMesh at about 100 instances, a 1K-texture pack, skinned characters at 1, 10 and 50 | Download the packs in a browser into `godot_lab/third_party/manual/`, add LICENSES.md rows, then run markers `s1_nodes`, `s1_mm`, `s2`, `s3_1`, `s3_10`, `s3_50` |
| 4 | ASTC 8x8 size comparison | Package size and memory for ASTC at a lower bit rate against ETC2 and ASTC 4x4 | Duplicate the S5 ladder, set the block size in the import options, compare `texture_mem_mb` and APK bytes |
| 5 | Warm-up on versus off on the phone | Phone cold-start and first-use cost of the warm-up pass | Run Road Dodge with `user://no_warmup` present and compare `coldstart.csv` rows (`warmup` column) |
| 6 | Banner-placement check | Whether the banner overlaps the game view and where to place the HUD | Run `ads` marker; screenshot with the banner up; compare with the bottom-edge marker in `ads_menu.gd` |
| 7 | Asset-pack delivery | Size of the base module with heavy textures moved into an install-time asset pack (`assetPackInstallTime`) | Prompt: "Move the 4K ship textures into an install-time asset pack and report AAB and base-module sizes." |
| 8 | Quality-tier frame cost per tier on the phone | Phone frame time and temperature per tier (HIGH, MEDIUM, LOW) | Pause menu Quality button in Road Dodge; run `perf.csv` sessions per tier |
| 9 | Fairness check with human players | Compare the latency-bot results with real play | `godot --headless --path . --script tests/test_fairness_delay.gd -- --sweep --models=0,1`, then a hand-played session log (`deaths.csv`) |
| 10 | Head-to-head against another stack | Same scene in another engine for a size and frame-time comparison | Prompt: "Build the S4 scene in <engine>, export a debug APK, run the same protocol, add a column to FINDINGS.md." |

## Budget-phone table to fill after experiment 1
Measured on: <device model, SoC, Android version>; same protocol.
| Metric | Value | Source file |
| --- | --- | --- |
| S4 2K p99 frame ms | | |
| S4 2K load ms | | |
| 2048 px ETC2 texture memory MB | | |
| Cold start TotalTime ms | | |
| Battery temperature start to end | | |
