# PHONE_TEST_PROTOCOL: the safe, repeatable phone test

Purpose: how an agent measures a game on a physical Android phone with a fixed, audited adb command set.
Last verified: 2026-10-28
Read this when: you run any test on the phone (frame times, cold start, memory, screenshots, ads).

Measured on: OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz, Godot 4.7.2 (protocol used for every phone result in `docs/FINDINGS.md`).

## Setup (done by the developer)
- Enable USB debugging and approve the computer; allow Install via USB for adb installs.
- Phone unlocked, screen kept awake (Stay awake), Do Not Disturb on, battery above 50%, cool start.
- Exactly one physical phone attached; serial never starts with `emulator-`.
- The test packages are the developer's own debug apps; other apps stay untouched.

## Rules
- `-s <serial>` on every adb command (except `adb devices -l`); show the serial as `<serial>` in reports.
- Start and stop only the game's own package; report any other package name as `<other app>`.
- Frame and CSV data come from the app's own `user://` folder with `run-as <pkg> cat files/<name>`.
- Debug builds only (`run-as` needs a debuggable app).

## adb allow-list (src: godot_lab/PLAN.md; godot_lab/tools/check_adb_allowlist_lab3.py)
| Purpose | Command form |
| --- | --- |
| Devices | `adb devices -l` |
| Device facts | `adb -s S shell getprop <ro.product.model, ro.product.manufacturer, ro.build.version.release, ro.build.version.sdk, ro.soc.model, ro.board.platform>` |
| Installed? | `adb -s S shell pm path <pkg>` |
| Install | `adb -s S install <apk>` (`install -r <apk>` when `pm path` shows it is installed) |
| Launch | `adb -s S shell am start -W -n <pkg>/com.godot.game.GodotAppLauncher` |
| Stop, pid | `adb -s S shell am force-stop <pkg>`; `adb -s S shell pidof <pkg>` |
| Memory, battery, thermal | `adb -s S shell dumpsys meminfo <pkg>`; `dumpsys battery`; `dumpsys thermalservice` |
| Foreground test | `adb -s S shell "dumpsys window | grep mCurrentFocus"` (test the output for the package, never store it) |
| App files | `adb -s S exec-out run-as <pkg> ls files`; `... cat files/<result file>`; `... touch files/<marker>` (marker names from `markers.txt` only) |
| Screenshot | `adb -s S exec-out screencap -p > <new file on the Mac>` (only while the game is in the foreground) |
| Diagnosis | `adb -s S logcat --pid=<pid> -d` |

## Scripts
- Road Dodge: `car/tools/phone_perf_session_safe4.sh`, `car/tools/check_adb_allowlist.py`, `car/tools/summarize_perf.py`.
- Lab (use these for new games): `godot_lab/tools/lab_session3.sh`, `godot_lab/tools/check_adb_allowlist_lab3.py`, `godot_lab/tools/summarize_bench.py`, `godot_lab/markers.txt`.
- Run the checker before a session: `python3 -I tools/check_adb_allowlist_lab3.py tools/lab_session3.sh` (reads the script text, lists each adb call as OK, checks packages, APK names and the marker list).
- Phases: `preflight`, `install <variant>`, `cooldown`, `run <id> <attempt> <seconds> [shot labels]`, `collect <id> <attempt>`, `adsstart`, `adspoll`, `adscollect`, `screens`, `logcat`.

## Scene selection with marker files
- The app picks its scene from empty marker files in its own `files/` folder: `lab_run_<scene-id>_<attempt>`, attempt 1 to 3.
- The app runs the lowest-named marker without a matching `done_<marker>`, writes `bench_<id>_a<attempt>.csv` and `_meta.txt`, writes the done file, and quits.
- Markers and done files accumulate; a repeat uses the next attempt number. Every marker name is listed in `PLAN.md` and `markers.txt` before use.
- The exported launcher alias ignores intent extras, so markers carry the choice.

## Install handling
1. `pm path`, then `install` (or `install -r`).
2. While `adb install` runs and for up to 3 minutes after, test the foreground every 10 s for an install or security screen; the developer accepts it on the phone.
3. Launch the game with `am start -W` once the screen has cleared; large APKs (hundreds of MB) need the prompt accepted promptly.

## Thresholds and rhythm (src: godot_lab/tools/lab_session3.sh)
- Battery temperature stop at `43.0` C; thermal status of SEVERE (3) or higher; battery below `25`% (preflight requires above `50`%).
- Cool-down: wait until the battery temperature is within `2` C of the baseline, at most `300` s (src: godot_lab/tools/lab_session3.sh).
- Foreground watchdog: test focus before each run and every `20` s; relaunch with the launcher alias, up to `2` tries `10` s apart; a run with a lost-focus event is INVALID, excluded from statistics, and repeated with the next attempt number (maximum 2 repeats).
- If the screen is off or locked, pause and ask the developer.

## Results and report
- Save every run under `results/phone<N>_<timestamp>/`: launch output, `meminfo` start and end, temperatures, `bench_*.csv`, `summary_*.txt`, screenshots, `guard.log`, `focus_events.log`.
- Report table: `Claim | Evidence (command and raw output or file) | Status` with Status one of VERIFIED, PARTIAL, NOT RUN, INVALID.
- Per scene report: load time, memory start and end (Godot counter and `dumpsys`), average, p95, p99, p99.9, worst, share over 16.7, 20, 25 and 33 ms, draw calls, primitives, temperature start and end; list every adb command used and the count of lost-focus events.
- Example run: `godot_lab/results/phone4_20261028-153046_b_c/` (S4 4K lossless and the font-cost scene).
