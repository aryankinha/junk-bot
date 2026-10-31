# M3 Report — Damage, part loss and recovery

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- Armour, rechargeable shields, damage invulnerability, one-time 75/50/25% breaks, weighted loss and last-weapon protection.
- Saw, oil, barrel contact hazard, Elite encounter, trade-offs, gamble, Repair/Re-roll/Buy station choices and instant retry.
- Buy Part presents three candidates; repairs restore lost attachment levels.

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

- Random L1 parts-lost average is reported in bot_balance.md. Part identification by unprompted phone testers is NOT RUN.
- Barrel chain reactions, turret bolts, physical charges and Elite double charges are tested in the pure simulation.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
