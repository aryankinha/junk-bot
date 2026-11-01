# UI baseline audit — 2 November 2026

Scope: current committed game before ui_v2. Exact per-element class/text/path/rectangle/font-size/tappable inventory for every state at two resolutions is in `results/ui_before/inventory.json`. Screenshots: `results/ui_before/<state>_360.png` and `_600.png` (360×640 and 600×960 windows). Logical coordinates are retained in the JSON; the normal portrait canvas is 1080×1920. These are staged review fixtures, not claimed human play sessions. Ads use an availability-only fake provider, never a fabricated earned reward.

## State inventory and source map

All states share `src/view/run_view.gd:_build_hud` (320), `_update_hud` (930), `menu` (518), `WorldView.sync` and `RobotBuilder.sync`. Inventory JSON records each rendered control rectangle and font. The following supplements it with conditions, role and motion; all dimensions refer to the 1080×1920 logical layout.

| State | Visible elements, placement, roles and motion | Source / end condition |
|---|---|---|
| First launch | Level/coin/pause row at top safe inset45, 112 pause target; HP50px, progress26px; tiny-bot strip; tutorial text30px above bottom controls; Special236px at right, reroll190px at left | `_build_hud:320`, `_update_hud:930`; tutorial first8s |
| Run start | Same calm top HUD without tutorial after onboarding; constant62° camera, moving road wear, robot suspension/wheels | `_process:829`, `WorldView.sync:548`; run end |
| Mid-run | Weapon24px chips + one equipment count; counter tint .18s; compact chain/combo28px; particles and projectiles, red enemy outlines | `_events:675`, `_update_hud:930`; counters/timers expire |
| Part gate | Next row within62m: green rail, dark name56px (42 moving,34 three-way), stats30/24/20px, 3D part icon, optional combo tag40px | `WorldView.rebuild_gate:229`; rebuilds at next gate |
| Mob gate | Two/three framed panels; value76px (56 moving/three-way); type-specific signed text, blue friendly drones; pass popup56px and at most8 sparks | `WorldView._rebuild_mob_gate`, `_events`; popup life~.77s |
| Damage | Robot flash, .12 red screen overlay, damage number≤64px, hit sound/haptic; camera stays fixed | `_events`; overlay fades1.5 alpha/s |
| Part loss | Small toast36px with name, break sound/haptic,16 sparks; chip list removes the item without leaving a lost marker | `_events`; toast1.8s |
| Repair bay | Three lanes (repair/reroll/buy); offers remain behind road decisions; purchase/repair open when appropriate | `_resolve_gates`, `show_purchase:1538`, `show_repair_offer:1550` |
| Boss intro | Boss title44px and24px HP bar below top inventory;36px instruction toast, familiar full HUD | `_events`, `_update_hud`; toast1.8s |
| Boss fight | Boss phase text, HP bar (no phase ticks), red filled circle/lane/sweep zones with shared sinusoidal material; hint30px; ready ring continuously pulses | `WorldView.sync:710+`, `UiRing`; zones end per BossSim |
| Boss kill | TITAN DOWN toast,70 sparks, boss shrinks; 1.2s end pause; no camera orbit | `_events`, `_process`; result transition |
| Win result | Menu title76px, static1200px build portrait displayed500px high, build name52px;3 animated150px stars,84px reward count-up,28px summary; Next/Home and contextual ad actions | `show_result:1118`; screen navigation |
| Loss result | Same portrait/reward structure; progress32px, tip34px; Retry/Home and contextual revive/streak actions | `show_result`; navigation |
| Hangar | Rounded white currency/settings;88px title,32px subtitle,500px live preview; Play160px height + Garage/Daily; login text30px | `_hangar_home:1233`; navigation |
| Garage | Three tabs30px; currency row,300px live preview; scrolling cards36/26px,40px star pips,230×110 buy targets; looping brightness pulse on one affordable upgrade | `_hangar_page:1289`; navigation |
| Settings | Scrolling toggles for sound/music/haptics/Reduce Motion; credits34px; reset/back; no independent volumes or handedness | `show_settings:1467`; navigation |
| Pause | Resume, Settings, Home under pause title, underlying run stopped | `show_pause:1447`; resume/navigation |
| Purchase | Three large category-colored choices, no new currency; run paused | `show_purchase:1538`; chosen purchase |
| Ad offer | Repair details, optional WATCH and Keep Going; provider decides availability | `show_repair_offer:1550`; user action |

## Coverage and activity method

The metric is a conservative union of painted control rectangles clipped to the viewport/scroll containers, plus an estimated projection of 3D popup bounds. It is not screenshot segmentation or a perceptual visibility certificate. Transparent spacers/empty labels are excluded; a painted parent and its children count once by union. Opaque menu screens are inventoried separately and are not subject to the in-run HUD budget. Attention groups count active popups, hero card, screen overlay, toast and particle cluster as groups, not individual particles. Source: `tests/ui_metrics.gd`.

At 360×640: run-start HUD13.92%; mid-run13.81%; first launch18.74%; boss intro23.84%; boss fight19.81%. The45s fixed-step bot sample has peak HUD19.60%, maximum2 visible popups. Direct steering response appears in421/2700 frames (9.36 frames/s); visible projectile/event consequences in2621/2700 (58.24 frames/s). These are explicitly different metrics: autonomous fire is not counted as direct human input. Per-second event counts and sampled clutter are in `results/ui_activity_before.json`.

## Theme fit

| Concrete cue | Category | Proposed response |
|---|---|---|
| Rounded pastel pills, circular plastic buttons, Lilita display type, star tokens | UI-fixable | Steel plates, small corner cuts, Rajdhani stencil-like headings, quieter reward accents |
| Uniform smooth floor, thin gate frames, no decision-confirmation animation | World-fixable | Broad panel seams/edge markings, reinforced gate signs and local pass confirmation |
| Low-contrast static targets without a shared feedback hierarchy | UI/world-fixable | One hero event, ring confirmations, timed hit/ready/dodge responses |
| Chunky rounded robot meshes, inverted-hull outlines, coin token geometry | Art-direction-level | Keep robot identity and silhouette; do not replace all models or import bitmap art |
| Empty time between beats despite wheels/road scrolling | Gameplay-boundary | Improve response and purposeful movement; do not add new encounters or alter pacing here |

## Thumb, safe area and accessibility

Special sits near the extreme lower right in a290px ring; reroll lower left. Pause112px falls below the120px starting target. No handedness setting exists. Android safe insets are converted to logical height; desktop uses45px. Gate numbers live in the world, not touch targets. V2 will move frequently used controls into a mirrored lower-middle dock, retain safe margins, and enforce120px targets. Existing Reduce Motion setting is stored but does not currently govern dust, idle animation, warning pulses or most effects. Native haptics on/off exists; SFX/music only have toggles.

## R1–R8 verification

| Claim | Status | Evidence |
|---|---|---|
| R1 stable62°, no shake or hit-stop, a060531 | CONFIRMED | `_reset_camera:642`, `_update_camera:650`; completed `results/ui0_visual_focus_complete.txt` |
| R2 debris70→0, skids26→0,84→12 props≥10m, fog45m, bloomoff, matte scenery | CONFIRMED | `WorldView.sync:574–588`, `MeshFactory.scenery_palette:114`, `RunView._ready:155–178`; current fixture counts |
| R3 attachment6, evolution12, gold4,dust6, popupfont≤64 | CONFIRMED | `_events:675+`, `WorldView._build_player_fx`, `popup:536` |
| R4 weapon chips + equipment count + single toast | CONFIRMED | `_update_hud:930`, `_events` |
| R5 Mob Stream implemented/defaultoff; first multiplier z35 in1.2s | CONTRADICTED | flags false in `data/flags.json`; first mob row is z45 in `data/mob.json`.1.233s is drone travel, not robot arrival; robot reaches45m at5s (35m would3.89s). `MobSim.first_multiply_t` records actual pass time |
| R6 visual-focus run unfinished/cancelled | CONTRADICTED as current result | Re-ran to completion, no termination: `results/ui0_visual_focus_complete.txt`,120 reward frames; audit cannot establish the author's earlier process history |
| R7 counts25320/1419, desktop79draws/p9517.86, phone/humansnotrun | CONFIRMED for historical metrics; current tests rechecked | `results/ui0_headless.txt`; earlier `focus_ui_review.txt`, `focus_perf_after.json`; project max_fps60, vsync default enabled. p95 above16.67 is not a60fps pass; no connected device (`ui0_devices.txt`). Current performance will be measured separately |
| R8 internal names retain Scrap Dragon; new review names Scrap Bot | CONFIRMED | `project.godot:4`, `Boot.tscn:3`, `export_presets.cfg`; retain application name to protect desktop user:// saves |

No physical device or five new people are available in this environment. Those tests remain UNVERIFIED; no answers are invented.

## Final measurement-method refinement

The original fast bot loop let UI containers resize only every300 simulation steps. Its initial peak19.68% (the earlier19.60% wording was rounded from an intermediate run) is retained in `results/ui_activity_before_unsettled.json` and commit7a6b620, but should not be compared with settled layouts. The final harness yields four process frames at each half-second sample before measuring rectangles. Re-run both variants with that method: `results/ui_activity_before.json` and `ui_activity_after.json`; see the final report for paired values. This changes measurement timing, not sim timing or inputs. The state screenshots already yielded before capture and are unaffected.

The source line numbers above describe the UI-0 checkout (7a6b620); subsequent implementation moves those functions. The JSON inventories provide the exact per-control positions and font sizes: logical1080×1920 at360×640, and1200×1920 at600×960.

Final bot coverage is collected with the real renderer and the shared gameplay HUD timer/counter method (`_tick_run_hud`), not the intermediate headless samples. Final paired values and raw per-second data are linked in `reports/UI_REPORT.md`.
