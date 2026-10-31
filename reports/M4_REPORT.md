# M4 Report — Scrap Titan

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- Three phases with plated/core damage rules, roars, circles, multi-rocket lane barrage, moving laser gap, grabber steal/recover, scrapper calls and double slams.
- Combo specials, Overdrive, hidden loss assist, boss camera, debris/slow visual kill and final-build viewport portrait.

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

- Phase and arm-recovery rules are tested; all three phase captures exist.
- Full-screen native effects, telegraph readability and human first-failure learning remain phone acceptance tasks.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
