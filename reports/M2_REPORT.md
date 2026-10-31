# M2 Report — Combat and growth

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- Bounded enemy/projectile pools, auto-fire targeting, projectile/rocket/cone damage, nine part families, level merges and three chassis stages.
- Burst Volley, Ram Charge and Vacuum; upgrade hints and special button; full authored L1 road and generated levels 2–5.
- Recursive socket relocation prevents later pickups from unnecessarily removing an attachment; tested Magnet-first Vacuum plus preserved weapon combo.

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

- Rendered Battle and Monster screenshots exist. The stress snapshot uses 20 enemies and 40 bullets; sustained phone FPS is NOT RUN.
- Enemies use prototype primitive silhouettes and simplified telegraphed attack presentation.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
