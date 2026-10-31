# M0 Report — Project and procedural asset spike

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- Preserved and copied the full plan and playbook; recorded research before implementation.
- Godot 4.7.2 Compatibility project, JSON data loader, four RNG streams, arm64 export presets and matching Gradle template.
- Nine procedural families × three levels, palette material, socket manifest, triangle audit and asset-spike scene.

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

- Procedural art is the allowed fallback. The requested six-pack download/import comparison was not completed; failed Kenney archive responses were HTML and are not shipped.
- Physical spike performance and APK installation are NOT RUN.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
