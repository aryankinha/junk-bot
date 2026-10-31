# M7 Report — Tuning, exports and handoff

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- 900-run fixed-seed balance sweep plus fixed-choice gate audits and three build profiles through levels 1–3.
- Offline APK, test-ad Gradle APK and debug-signed AAB pipeline; ABI/SDK/permissions/package-content/16 KB checks.
- Reproducible capture mode with isolated save and frame-driven movie replay; transformation, part-loss and Titan clips.
- Phone runner, markers, foreground checks, battery/thermal guard, raw CSV capture and an audited adb allow-list.

## Tests

Combined runner: 25,147 checks, 0 failures, including the 59-check scene/service suite. Evidence: results/regression_final.txt, results/headless_tests.json and results/integration_tests.json.

Bot evidence: reports/bot_balance.md and reports/pair_audit.md. Screenshots: results/review_*.png.

## Phone numbers

| Metric | Value | Target |
|---|---|---|
| Launcher tap to first playable frame | NOT RUN — no physical phone | <2.5 s |
| Phone p95 / p99 / share over 20 ms | NOT RUN | p95 ≤16.7 ms; report raw jitter |
| Phone draw calls / PSS memory | NOT RUN | ≤150 / ≤400 MB |
| Installed size / temperature | NOT RUN | <120 MB / guarded below 43°C |

## Feel notes and decisions

- No phone attached in results/device_discovery.txt. Two-device testing, five new players, install size and phone frame timings are NOT RUN.
- No release signing credentials or Play Console account were supplied. A production-signed AAB, release sideload APK, internal-track upload and store acceptance are NOT DONE.
- Review exact target deviations in FINAL_REPORT.md and calibrate the motor-error bot model from human play.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
