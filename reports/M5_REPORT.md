# M5 Report — Progression and persistence

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- Result rewards, level 1–5 progression, rotating Hangar preview, five upgrade tiers with trim variants at 3/5, Armoury and Codex.
- Versioned atomic local save, invalid-save recovery, settings, streaks, local UTC daily seed and daily-best persistence.
- Run/reward bookkeeping prevents duplicate payouts across repeated results and optional revives.

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

- Economy, persistence, corrupt save and daily-mode tests pass.
- The 40–60% rational gate-pick target has not been established; the fixed-choice audit shows both choices can win.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
