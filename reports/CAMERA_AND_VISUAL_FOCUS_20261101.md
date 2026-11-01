# Camera stability and visual focus review

Date: 1 November 2026. Scope: presentation only; the simulation, encounter layouts, economy, saves, package ID and default experiment flags are unchanged.

## Camera diagnosis and fix

The original gate attachment/upgrade handler explicitly added 5° FOV, shake .15 and a 40 ms hit-stop. Stage growth added 12° and shake .4. Several other rewards and combat events also changed projection or camera offsets. These values are in the prior `src/view/run_view.gd` revision (886cb50); the before screenshots were replayed from an isolated committed-source copy, not reconstructed by changing the new renderer.

Ordinary `scrap` events did **not** directly assign camera shake. They produced world-space +N totals every .35 s, extra gold popups/particles and pulsing chain text. The camera also interpolated toward x=0, called `look_at`, then changed x again later in the same frame. These are separate findings: the user's coin symptom was addressed by removing pickup-related visual motion and consolidating camera ownership; no direct per-coin shake call was invented.

`src/view/run_view.gd:_reset_camera` / `_update_camera` now own a fixed 62° FOV, zero screen offsets and a centered road camera. Only boss framing changes, smoothly. Removed reward shake/zoom, all hit-stop pauses, the split lateral-follow update and the victory camera orbit. Damage is indicated by robot flash, health UI and a short .12 overlay rather than shake or continuous low-health screen pulsing. Run restart also clears the overlay/counter tint.

## Research and what was adopted

Research used enlarged promotional screenshots from official publisher store listings. They establish visible composition, not the games' camera code, player retention or measured usability.

| Primary source | Observed visual pattern | Scrap Bot adaptation |
|---|---|---|
| [Count Masters — Freeplay](https://play.google.com/store/apps/details?id=freeplay.crowdrun.com) | Nearly blank pale track, broad faint markings, clear crowd colors and numeric gates | Quiet play surface, subtle broad wear instead of tiny moving litter, compact feedback |
| [Mob Control — VOODOO](https://play.google.com/store/apps/details?id=com.vincentb.MobControl) | Bounded track, separated friendly/opponent colors and large numerical gate signs; current desert imagery also includes detailed scenery | Preserve road boundaries and readable values; use blue for friendly fire and gold for pickups |
| [Tall Man Run — Supersonic](https://play.google.com/store/apps/details?id=com.VectorUpGames.TallManRun) | Distinct player silhouette and signed green/red gates over a bounded forward path; city scenery is not uniformly minimal | Keep signed values and threat colors while reducing noninteractive background contrast |

The sparse junkyard is our adaptation; this report does not claim every competitor has an empty background or a motionless camera. Research was delegated to the read-only `visual_clarity_research` subagent; implementation and validation were performed in this workspace.

## Graphics, materials and feedback

- Decorative scenery: 84 → **12** instances, retaining wrecked cars, tyre stacks and salvage heaps. These are moved at least 10 m from the road center. Three of the six existing scenery batches remain active, four instances each.
- Ground clutter: **70 litter + 26 skid instances → 0**. The playable road has pale edges, a muted sage-gray surface and faint broad wear rather than high-frequency texture noise. All gameplay coins, enemies, hazards, gates and collisions remain present.
- Materials: a simple procedural road shader supplies subtle 1.2% broad wear that scrolls with world travel; no new bitmap assets/downloads. Scenery gets a separate matte material, 15% retained hue mixed 72% toward a sand tint, with no actor-style black outline or glossy highlights. Robot/enemy toy shading is retained.
- Lighting: ivory sky/horizon and warm neutral ambient, saturation/contrast 1.0 instead of 1.2/1.06, bloom disabled; fog begins at 45 m instead of 28 m. Noninteractive scenery recedes while signs and actors remain stronger.
- Color roles: regular friendly projectiles and bolt drones are blue, bomb drones periwinkle, torch drones amber; enemies/hostile bolts remain red, coins gold, part gains green. Signs/icons still carry meaning independently of color.
- Gate visibility: the nearest part row appears within 62 m (about 6.9 s at base road speed), consistent with Mob Stream's existing reveal range. Mob-gate visibility is evaluated after the current part-gate visibility, eliminating a one-frame stale-priority decision. No gate's simulation position or charge range changed. Old gate children are detached before deferred cleanup, so a rebuilt sign cannot coexist in the active gate tree with its predecessor.
- Pickups: a brief .18 s counter tint and existing audio/haptics replace repeated floating totals and chain scale pulses. Counter width stays fixed across ordinary digit changes.
- HUD: weapon-level chips plus one equipment count replace listing every attachment; full build information remains in Garage and on the robot. Upgrade confirmation is a single smaller toast rather than duplicate headline/world text. Combo/chain text is compact, static and below the HUD; persistent speculative combo recipes no longer cover the road. Contextual tutorial, gate-charge, Hauler and boss instructions remain.
- Effects: attachment particles 14 → 6, growth 40 → 12, gold pickup 10 → 4; dust 14 → 6 with .3 s life instead of .55 s and smaller/slower puffs. Mob-pass bursts are throttled with their popup and capped at 8. Removed per-shot extra sparks; bullets, muzzle motion and impacts retain feedback. World popups cap at font size 64 and no longer scale up in front of targets.

## Verification

- `results/focus_logic_final.txt`: **25,320 checks, zero failures**, including 59 integration checks.
- `results/focus_trace.txt`: **TRACE MATCH**, original saved gameplay baseline unchanged.
- `results/focus_after.json` / `focus_visual_final.txt`: **120 real update-loop reward frames** with fixed camera transform/FOV/offsets and no lost simulation time, including coins, upgrades, stage growth and multiplied gates. Steering during these frames also leaves the camera centered.
- The same seeded normal and Mob Stream fixtures reach exactly identical time, position, HP, coins and parts before/after (`focus_before.json`, `focus_after.json`). Only scenery/litter/skid counts differ. Damage tint is explicitly cleared in both comparison captures so palette assessment is independent of a transient hit.
- `results/focus_ui_checks.json` / `focus_ui_review.txt`: **1,419 checks, zero failures**, menus and loaded HUD at 360×640, 432×768 and 600×960. The UI review tool now accepts an output prefix to preserve earlier evidence.

Before/after captures: [normal before](../results/focus_before_normal.png), [normal after](../results/focus_after_normal.png), [Mob before](../results/focus_before_mob.png), [Mob after](../results/focus_after_mob.png). These use the same logical replay fixture, not a claimed human playtest.

## Desktop measurement

Two sequential 45-second early-run captures on the same Mac, Compatibility renderer, requested 432×768 window, default flags off, seed 20261031. No other renderer or bot sweep ran concurrently. Raw frame times are preserved in `results/focus_perf_before_frames.csv` and `focus_perf_after_frames.csv`; summaries in `focus_perf_before.json` and `focus_perf_after.json`. This covers early gates/coin collection, not a sustained phone or boss test.

| Metric | Before | After |
|---|---:|---:|
| Frames | 2682 | 2677 |
| p50 ms | 16.664 | 16.663 |
| p95 ms | 18.33 | 17.861 |
| p99 ms | 18.853 | 18.597 |
| Worst ms | 530.969 | 618.411 |
| Draw calls median | 101 | 79 |
| Draw calls peak | 118 | 96 |
| Godot static allocation bytes | 67844553 | 57414518 |

The worst sample in both runs is frame 0 (startup). Other first-use spikes remain in the raw logs; the change removes deliberate reward camera impulses and pauses, not every possible renderer/OS stall. These are desktop measurements, not physical-phone certification or proof that every first-use asset upload is free of a frame spike. Camera/reward stability is separately asserted in the view test. Device touch feel, thermals and sustained phone frame rate remain untested here.

## Review build

`build/scrap_bot_focus.apk`: 29181994 bytes; SHA-256 `d4d1ec9b25fb389c163f0abe0aef17b061215cb6ba6d087c6cb5394a1b168ec0`. Default flags, package ID and signing setup are unchanged. The offline debug APK requests VIBRATE only, passes 16 KB ZIP/native alignment, and excludes tests/reports/results/docs (`results/focus_apk.json`, `focus_apk_permissions.txt`). Its extracted resources boot outside the repository with no script errors (`focus_apk_smoke.txt`); this is not an on-device test.
