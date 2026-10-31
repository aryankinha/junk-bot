# M6 Report — Audio, feedback and optional rewarded test ads

Status: code implemented; physical/release acceptance remains pending where noted.

## Built

- Original synthesized WAV SFX, OGG loops, pooled audio players, per-sound limits, compressor, ducking and settings.
- Haptic rate limit, reduce-motion toggle, focus/back pause and safe-area margins.
- Pinned MIT AdMob 5.1.0 runtime/native core, explicit test-ad export, callback-only rewards, offline hiding, revive/re-roll/repair/double/streak hooks.

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

- Offline scene and one-time earned callback behavior are unit-tested. Native SDK callbacks, airplane-mode device behavior and physical haptics are NOT RUN.
- The main offline build has vibration permission only; the optional ad build adds the SDK permissions listed in results/.
- Consent and production IDs must be configured and reviewed before a real monetized release.

## Open acceptance tasks

Connect a physical Android phone and follow docs/playbook/docs/PHONE_TEST_PROTOCOL.md. Human judgment of feel and readability cannot be inferred from simulation or desktop images.

## Next milestone / handoff

See reports/FINAL_REPORT.md for the final evidence table and remaining work. Milestone acceptance is not marked complete merely because code exists.
