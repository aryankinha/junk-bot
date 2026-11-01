# Scrap Bot UI report — 2 November 2026

## 1. Summary (five lines)

The new industrial ivory/steel UI and event feedback are implemented behind `ui_v2=false`.
Gate, pickup and upgrade feedback keeps the fixed62° camera and fixed simulation timing.
The run-start HUD drops from13.92% to9.70%; peak captured HUD/popups drops from23.84% to15.94%.
Mirrored controls, real Reduce Motion, local flash limits and independent volumes are implemented and checked.
Keep the default off pending owner review, phone measurements and five-person comprehension testing.

## 2. R1–R8 verification

The audit was completed before implementation in commit7a6b620. Source line references in that audit describe that checkout; the following files and raw outputs are current evidence.

| Claim | Verdict | Evidence / qualification |
|---|---|---|
| R1 camera62°, no routine shake/hit-stop | CONFIRMED | `src/view/run_view.gd` `_reset_camera`, `_update_camera`; `results/ui4_focus_default_final.txt`, `ui4_focus_v2_final.txt`: each completes 120 reward/steering frames without transform/FOV/offset or sim-step changes. Existing smooth boss reframing is retained; no event camera impulses were added. Synthetic event handlers also leave camera unchanged in 183 feedback checks. |
| R2 debris/skids0,12 props≥10m, fog45, bloomoff, matte | CONFIRMED | `src/view/world_view.gd` `sync`, `src/view/mesh_factory.gd` `scenery_palette`, RunView environment; both completed focus tests record12/0/0. No scenery density added. |
| R3 bursts6/12/4, dust6, popupfont≤64 | CONFIRMED for legacy | Legacy paths remain. V2 normally uses rings/counters instead of routine world text, caps the generic pool at3, reduces supporting bursts during hero feedback, and disables optional effects under Reduce Motion. `WorldView.burst`, `popup`, `configure_ui_v2`; feedback checks. |
| R4 weapon chips/equipment badge/one upgrade toast | CONFIRMED | Legacy `_update_hud`; v2 `src/ui/ui_v2.gd` `sync_hud` keeps compact weapon levels/equipment count and one prioritized hero surface. |
| R5 Mob Stream defaultoff; first gatez35 at1.2s | CONTRADICTED in location/timing | `data/flags.json`: both mob flags false. `data/mob.json`: first rowz45; robot9m/s reaches it in5s. First drone pass1.233s is not robot arrival;35/9 would3.89s. No sim timing rebalance. |
| R6 cancelled visual-focus runs | CONTRADICTED as present completion claim | This session ran original and v2 tests to normal completion, including the UI-0 rerun. No result inferred from a cancelled process. Earlier author's cancellation history remains outside the evidence. |
| R7 25320/1419 checks; desktop79 draws/p9517.86; no phone/humans | CONFIRMED as historical measurements | Current headless 25320 incl59 integration pass (`ui4_headless_final.txt`), original UI1419 before extending label checks; final flag-off 1443 and v2 1521. Desktop is capped at 60fps, vsync1 on120Hz Retina display; see performance below. No strict60fps certification. |
| R8 internalScrap Dragon names; Scrap Bot review artifacts | CONFIRMED | `project.godot`, `Boot.tscn`, existing presets retain internal names. Runtime/launcher and new APK names sayScrap Bot. Keep config/name to preserve existing desktop user:// location. |

## 3. Screenshots, inventory and measured attention

[Before inventory](../results/ui_before/inventory.json) and [after inventory](../results/ui_after/inventory.json) contain per-control rectangles in logical canvas coordinates, font sizes, classes, tap status and separate opaque-menu inventories. Windows360×640 and600×960 map to logical1080×1920 and1200×1920 respectively (expand aspect). World gate/robot elements and lifetimes are documented in [UI_AUDIT](../docs/UI_AUDIT.md). Captures are explicit fixtures, not a claim of naturally reaching every state. Ad-offer captures use a fake availability-only provider; they do not grant rewards.

| State | Before360 | After360 | Before600 | After600 | HUD+popup % at360: before → after |
|---|---|---|---|---|---|
| first launch | [image](../results/ui_before/first_launch_360.png) | [image](../results/ui_after/first_launch_360.png) | [image](../results/ui_before/first_launch_600.png) | [image](../results/ui_after/first_launch_600.png) | 18.74 → 13.18 |
| run start | [image](../results/ui_before/run_start_360.png) | [image](../results/ui_after/run_start_360.png) | [image](../results/ui_before/run_start_600.png) | [image](../results/ui_after/run_start_600.png) | 13.92 → 9.70 |
| mid run | [image](../results/ui_before/mid_run_360.png) | [image](../results/ui_after/mid_run_360.png) | [image](../results/ui_before/mid_run_600.png) | [image](../results/ui_after/mid_run_600.png) | 13.81 → 10.35 |
| part gate | [image](../results/ui_before/part_gate_360.png) | [image](../results/ui_after/part_gate_360.png) | [image](../results/ui_before/part_gate_600.png) | [image](../results/ui_after/part_gate_600.png) | 13.81 → 10.35 |
| mob gate | [image](../results/ui_before/mob_gate_360.png) | [image](../results/ui_after/mob_gate_360.png) | [image](../results/ui_before/mob_gate_600.png) | [image](../results/ui_after/mob_gate_600.png) | 13.89 → 13.65 |
| damage | [image](../results/ui_before/damage_360.png) | [image](../results/ui_after/damage_360.png) | [image](../results/ui_before/damage_600.png) | [image](../results/ui_after/damage_600.png) | 13.94 → 13.65 |
| part loss | [image](../results/ui_before/part_loss_360.png) | [image](../results/ui_after/part_loss_360.png) | [image](../results/ui_before/part_loss_600.png) | [image](../results/ui_after/part_loss_600.png) | 17.83 → 13.88 |
| repair bay | [image](../results/ui_before/repair_bay_360.png) | [image](../results/ui_after/repair_bay_360.png) | [image](../results/ui_before/repair_bay_600.png) | [image](../results/ui_after/repair_bay_600.png) | 13.81 → 10.35 |
| boss intro | [image](../results/ui_before/boss_intro_360.png) | [image](../results/ui_after/boss_intro_360.png) | [image](../results/ui_before/boss_intro_600.png) | [image](../results/ui_after/boss_intro_600.png) | 23.84 → 15.94 |
| boss fight | [image](../results/ui_before/boss_fight_360.png) | [image](../results/ui_after/boss_fight_360.png) | [image](../results/ui_before/boss_fight_600.png) | [image](../results/ui_after/boss_fight_600.png) | 19.81 → 15.94 |
| boss kill | [image](../results/ui_before/boss_kill_360.png) | [image](../results/ui_after/boss_kill_360.png) | [image](../results/ui_before/boss_kill_600.png) | [image](../results/ui_after/boss_kill_600.png) | 23.74 → 15.94 |
| result win | [image](../results/ui_before/result_win_360.png) | [image](../results/ui_after/result_win_360.png) | [image](../results/ui_before/result_win_600.png) | [image](../results/ui_after/result_win_600.png) | 0.00 → 0.00 |
| result loss | [image](../results/ui_before/result_loss_360.png) | [image](../results/ui_after/result_loss_360.png) | [image](../results/ui_before/result_loss_600.png) | [image](../results/ui_after/result_loss_600.png) | 0.00 → 0.00 |
| hangar | [image](../results/ui_before/hangar_360.png) | [image](../results/ui_after/hangar_360.png) | [image](../results/ui_before/hangar_600.png) | [image](../results/ui_after/hangar_600.png) | 0.00 → 0.00 |
| garage | [image](../results/ui_before/garage_360.png) | [image](../results/ui_after/garage_360.png) | [image](../results/ui_before/garage_600.png) | [image](../results/ui_after/garage_600.png) | 0.00 → 0.00 |
| settings | [image](../results/ui_before/settings_360.png) | [image](../results/ui_after/settings_360.png) | [image](../results/ui_before/settings_600.png) | [image](../results/ui_after/settings_600.png) | 0.00 → 0.00 |
| pause | [image](../results/ui_before/pause_360.png) | [image](../results/ui_after/pause_360.png) | [image](../results/ui_before/pause_600.png) | [image](../results/ui_after/pause_600.png) | 0.00 → 0.00 |
| purchase | [image](../results/ui_before/purchase_360.png) | [image](../results/ui_after/purchase_360.png) | [image](../results/ui_before/purchase_600.png) | [image](../results/ui_after/purchase_600.png) | 0.00 → 0.00 |
| ad offer | [image](../results/ui_before/ad_offer_360.png) | [image](../results/ui_after/ad_offer_360.png) | [image](../results/ui_before/ad_offer_600.png) | [image](../results/ui_after/ad_offer_600.png) | 0.00 → 0.00 |

Zero HUD area on opaque menus means the battlefield HUD is covered; it does not mean the menu is empty. Menu controls are inventoried separately. Rectangle unions conservatively estimate painted controls and projected popups, not exact opaque-pixel or perceptual clutter. One hero means one prioritized event card, not a claim that a human can notice only one object.

| Measurement | Before | V2 | Budget / interpretation |
|---|---:|---:|---|
| Peak bot-sample HUD+popups % | 21.55 | 14.65 | ≤22% peak |
| Peak bot visible popups | 2.00 | 0.00 | ≤3; synthetic pool saturation also checked |
| Peak bot hero cards | 0.00 | 1.00 | ≤1 v2 |
| Peak bot full-screen effects | 0.00 | 0.00 | ≤1; implemented0 |
| Peak bot attention groups | 4.00 | 2.00 | groups include transient card/text/particle cluster; not every particle |
| Run-start HUD % | 13.92 | 9.70 | ≤15%; leave the spare space clear |
| Peak captured HUD/popups % | 23.84 | 15.94 | ≤22% |
| Direct steering-response frames /2700 | 421 | 421 | 9.36frames/s; same sim, no new mechanics |
| Consequence-motion frames /2700 | 2621 | 2621 | 58.24frames/s; includes autonomous fire, not all direct input |

Sources: `results/ui_activity_before.json`, `ui_activity_after.json`, completed logs `ui4_activity_before_rendered.txt` / `ui4_activity_after_rendered.txt`; fixed45-second simulation, seed20261031,60Hz MobBot. The bot steering receipt is a documented target-change proxy, not touch latency from a person. Direct-input and consequence-motion counts are unchanged because this task does not alter simulation or add more objects. Every observed tested action is asserted against its event-count increment in the same handler frame.38 synthetic action classes additionally exercise rare/negative responses, priority suppression, saturation and comfort settings. These are delivery checks, not a measure of how much more fun it feels.

The initial fast audit loop let containers settle only every300 sim frames; interim headless samples also lacked rendered font bounds and common HUD timers. Preserve its raw19.68% peak as `ui_activity_before_unsettled.json`; final paired measurements use the real renderer, share `_tick_run_hud` with gameplay (so counter/receipt lifetimes are real), and yield four process frames per sample before inspecting layout. State fixtures already settled before capture. Final budget assertions cover all38 v2 captures and90 bot samples. `results/ui_development/README.md` identifies the failed exploratory logs; they are not passing evidence. The final rendered bot samples are the primary paired activity/clutter evidence; intermediate headless logs are not final coverage numbers. Final per-state draw counts are also in the after inventory; highest is100 in garage, below135.

## 4. Feedback map as built

All event responses are dispatched from the existing sim queue in `_events`; there is no new gameplay system. The render HUD refreshes at20Hz (up to three60Hz frames), while event sound, haptic, hero text and local effect request occur in the same handler. Human display/audio latency and native vibration timing remain unmeasured. Strength0 is continuous/support,1 a small confirmation,2 a gain/decision,3 urgent or major.

| Action / event | Visible response | Sound | Haptic ms / strength | Tier strength |
|---|---|---|---|---:|
| steer | existing robot lean; faint mode-correct ground direction, or actual nearest target; first-use hint ends | — | — | 0 |
| scrap | immediate counter; grouped +receipt at local flash limit; existing compact chain | scrap | chain milestone8/.18 | 0 |
| weapon_fire | existing projectile/muzzle recoil | fire | — | 0 |
| enemy_death | small local blue ring; existing compact combo | explosion | — | 1 |
| part_attached / part_upgraded | actual socket animation, one L# receipt, green ring | attach / upgrade | 20/.4 | 2 |
| part_replaced | actual replacement/updated chip, no false lost-part warning | existing attach response | inherited attach | 1 |
| stage_up | actual frame growth, green ring, one frame receipt | stage | 55/.6 | 3 |
| gate_choice | chosen plate confirms, alternatives dim for.5s; existing attach | attach if non-part | 15/.3 non-part | 2 |
| gate_charge_tick / gate_charged / gate_level_up | existing panel charge; one +level receipt on bonus | upgrade on level-up | 20/.4 on level-up | 1 |
| mob_gate_pass | number presses12% for.35s; real boosted drones lighten within their color role; one multiplier receipt at≤1/.8s; local ring | multiply / trap | 15/.35 | 2 |
| player_hit | throttled local hull flash, health, prioritized amount receipt | hit | 40/.6 | 3 |
| part_broken / part_stolen | crossed part marker1.5s, lost/stolen receipt | break | 60/.7 | 3 |
| clean_dodge / boss_exposed | short positive cue, persistent weak-point ring while applicable | dodge | 10/.2 | 1 |
| telegraph / enemy_warning | striped geometric danger region ahead of robot, one priority warning; music ducks | warning | 15/.3 | 3 |
| boss_attack | local impact ring, danger resolves, music returns | hit | — | 2 |
| boss_intro / boss_phase | phased health ticks at33/66%, one state receipt | warning / stage | 40/.5 | 3 |
| special_ready | one.4s3.5% settling pulse, then stable state and existing cooldown/Overdrive bar | new procedural ready | 15/.25 | 1 |
| special_used / mob_champion | one deploy receipt and blue ring | special / champion | 55/.6 | 3 |
| shield_block / surge | energy ring and held/charged receipt | special | 15/.3 | 2 |
| repaired / healed / arm_recovered | restored physical state/chip, one repair receipt | upgrade | 20/.3 | 2 |
| frenzy / salvage_looted / hauler_destroyed | existing payout/cargo confirmation, gold ring | scrap / victory | 25/.4 | 2 |
| hauler_spawn / missed, salvage_spawn, wave_spawn | one short encounter cue | warning | — | 1 |
| cluster_burst | periwinkle local impact; first evolution receipt only | stage on first | — | 2 |
| boss_killed | actual collapse, one victory receipt/ring; no camera effect | victory | 100/.8 | 3 |
| death | existing loss/result/retry, live final build | defeat | — | 3 |
| combo_active / buy_offer / station_unavailable | combo receipt / existing purchase / unavailable receipt; existing money/ad flow retained | existing flow | existing flow | 1–2 |
| run_start | sector, health, controls, first-use cue | existing music | — | 0 |
| menu purchase/navigation | existing button press, value/tier update and settled affordance | click / upgrade | existing click10/.2 | 1 |

Legacy combo resets on damage, loss, theft and replacement remain in place, so view routing does not inflate saved best-combo statistics. No new floating-text backlog. One hero lifetime≤1.5s; higher priority blocks weaker cards but local physical/counter response still happens. Parts strip dims to.65 and dock to.85 during a hero event; danger/health stay readable. Pooled world feedback:4 rings,3 chosen-gate plates,1 aim arrow,1 weak-point ring. Generic world popups capped3. No new full-screen flash. Lower-priority routine bursts are capped4 during hero feedback. Gate multipliers remain their real value; we deliberately do not fake an increasing multiplier numeral.

## 5. Changes and commits

| Commit | Change |
|---|---|
| `7a6b620 UI-0` | Baseline19-state inventory/two-size captures; verified old camera test; official reference study; concepts and budgets. |
| `53b8c52 UI-1` | Default-off flag, steel/ivory Rajdhani HUD, safe-area lower-middle120px controls, handedness, volumes and flash options. |
| `ec547d0 UI-2` | Prioritized feedback map, pooled rings/aim/weak point, gate press/confirmation, boosted tint, ready tone and response/flash tests. |
| `b4afa7b UI-3` | Live result/home build and steel platform, existing progression cue, restrained road seams; reduced-motion settling; isolated A/B launcher and review feature preset. |
| `2f43d58 UI-4` | Visible phase tick sizing, readable warning placement, actual daily-result tiers, cheaper opaque menus/garage tier labels, settled clutter measurements, shared HUD timers and reusable package checks. |
| `UI-5` evidence/report commit | Final screenshots, raw desktop/feedback/clutter/package evidence and this report. |

`ui_v2` and all gameplay experiments remain false in `data/flags.json`. Normal debug APK uses that default. The opt-in preview opens Home so review does not begin with an unattended run. Review APK's explicit `ui_v2_review` feature enables only the new UI and fresh `ui_review_b.json`; it does not silently turn on Mob Stream. Both retain package`com.aryankinha.scrapdragon` and existing signing. Source previews: `tools/play_ui_v2.sh a` (current) or `tools/play_ui_v2.sh b` (new), same seed20261031, manual steering, separate fresh saves. To inspect Mob Stream as well, pass its existing flag via the Godot CLI; it remains a separate experiment.

Save root/version staysv1. Only optional preferences are merged into the existing settings dictionary: handedness, SFX/music volumes, flash limit. Legacy v1 load/value preservation is checked. Rewarded availability, earned reward callbacks, currencies, economy, physics and package identity are unchanged. New ready WAV is original generated procedural audio, covered by the existing CC0 credit; no new bitmap art, external asset dependency or copied reference layout.

Reduce Motion suppresses optional hull/enemy flashes, rings, particles, drive/idle bob, antenna sway, gate scale pulse, ready pulse, menu/result idle rotation and result count/star tween. Existing in-flight attach/growth tweens settle; turning it on clears an in-flight shader flash. Essential enemy/projectile/road movement and static danger/weak-point shapes remain. Flash setting0–3/s additionally throttles each local flashing element; there is no saturated red full-screen flash. This is not a WCAG photosensitivity certification.

## 6. Rejected directions and limits

- Rejected a receipt for every bullet/pickup and a queued toast backlog: too many simultaneous demands. Group coins, keep actual continuous fire, prioritize one receipt.
- Rejected camera shake/FOV/hit-stop, including rare-event camera effects: the stable camera is an explicit accepted decision.
- Rejected extra debris, smoke and distant enemy landmarks: they add targets/noise without answering input. Broad low-contrast road wear is sufficient.
- Rejected a ghost finger after the first real gesture: static drag arrows with a clear end avoid suggesting another required control.
- Rejected perpetual affordable-upgrade brightness pumping and extra progress meters: one existing affordability/next-blueprint text cue, real tier labels and live robot suffice.
- Kept rounded robot meshes, outlines, coins and result stars as identity; replacing all models is a separate art-direction task. Steel plates, restrained soot/rust outside the corridor, hard panel edges and display type address the UI portion.
- The small result screenshot is an early count-up frame; the completion check separately verifies actual240 payout after1.5s and immediate settlement under Reduce Motion.

## 7. Performance and package verification

Final paired90-second runs from source commit`2f43d58`, sequential on the same Apple M3 Mac, Compatibility renderer, seed20261031, Mob Stream on in both variants and only`ui_v2` changed. No other Godot tests ran concurrently. Actual recorded window648×1152 (the requested432×768 was not the final window), screen scale2, display120Hz, engine cap60 and vsync mode1. Both raw logs include initialization/first-use spikes; no samples are discarded. Boss arrival is at80 simulation seconds; the70s screenshots show the late approach, not the boss. Protocol: `results/ui_perf_protocol.json`.

| Metric | Current/off | V2/on |
|---|---:|---:|
| Sampled gameplay frames | 5365 | 5372 |
| p50 ms | 16.666 | 16.666 |
| p95 ms | 17.63 | 17.618 |
| p99 ms | 18.556 | 18.592 |
| Worst ms | 683.799 | 789.472 |
| Median draw calls | 85 | 83 |
| Peak draw calls | 108 | 105 |
| Static allocation bytes | 63500739 | 71152172 |
| Frames over20ms | 0.541% | 0.521% |

Frame0 is the worst in both raw CSVs; smaller first-use/runtime spikes remain. Median rendering cost falls slightly; timing differences are within normal run variation. V2 is below the18.5ms/135-draw governor limits on this desktop run, but p95 exceeds16.67ms, so this is **not** a strict60fps pass or phone certification. V2 uses about7.65MB more Godot static allocation (fonts/controller/effect resources); this is not whole-process RSS. Raw data: `results/ui_perf_full_before_frames.csv`, `ui_perf_full_after_frames.csv`; summaries and70s images use the same stems. Earlier45s and intermediate90s comparisons are retained with distinct initial/previous names, not substituted for the final pair.

Completed checks:25320 headless (including59 integration),1443 legacy UI,1521 v2 UI (three sizes, active counters, mirrored hands, safe insets, visible phase ticks, Reduce Motion),183 feedback/comfort/parity checks,38 state captures with clutter/draw assertions,90 rendered bot samples with same-frame response/budget assertions, both completed120-frame camera regressions, and `TRACE MATCH`. Sources are the `results/ui4_*_final.txt`, `ui4_activity_*_rendered.txt`, `ui_v2_feedback_checks.json` and `ui_*_review_20261102_checks.json` files.

Both debug APKs build and boot from extracted resources outside the repository. The normal package selects`ui_v2=false`; the explicit review feature selects`ui_v2=true` with`user://ui_review_b.json`. `results/ui4_apk_verification.json` records SHA-256/size/signature and16KB native/ZIP alignment; permissions are VIBRATE only. Both contain only arm64 native libraries, with no tests/docs/results/reports in the package. Smoke outputs: `ui4_apk_smoke_default.txt`, `ui4_apk_smoke_v2.txt`. This is a resource/startup check on desktop, not an Android device test. Signing and package id remain unchanged; no release signing or store upload was performed.

| Review package | Bytes | SHA-256 |
|---|---:|---|
| `build/scrap_bot_ui_default.apk` | 29219368 | `8c52db5c363974dde7951a122cff5c45147d8f1e26027f973ba2e3a44cb6f9ba` |
| `build/scrap_bot_ui_v2_review.apk` | 29219368 | `b3d3ad32ddf3cc9a2c7fe4f7da3db81c6fe049d1b4a10021d2f9404bf929e235` |


## 8. Playtest / five-second protocol

No physical device is attached (`results/ui4_devices.txt`); no new participants are available. **UNVERIFIED:** phone thermals/frame pacing, native touch/haptic feel, photosensitivity comfort, player comprehension and preference/fun/retention. The [synthetic all-parts/high-tier run fixture](../results/ui_v2_review_20261102_hud_432.png) can extend outer equipment beyond a camera edge; attachment/head collision checks pass, but maximum-build framing needs a separate model/framing pass. This UI pass retains the established model geometry and camera. Desktop automation is not a substitute.

Recruit at least five people new to Scrap Bot. Counterbalance A/B order and handedness; use the same seeded first run. Show a five-second crop with no spoken explanation. Ask exactly: “What is happening?”, “What would you do next?”, “What did that gate do?” Record each answer verbatim, time to identify hero/upgrade/threat, wrong taps, missed part loss, and any motion/flash discomfort. Then let each play for three minutes, repeating with Reduce Motion and left-handed controls as appropriate. Do not teach the answer or infer retention from preference. On an allow-listed phone run the playbook's sustained test and save raw frame times, thermal/battery state and touch notes with explicit device serial. Participants/owner accept installs themselves.

## 9. Unverified items, assumptions and owner questions

Official screenshots and sampled official video frames were inspected; the full uninterrupted Mob Control preview and input-to-response timing were not established. Promotional screenshots are not complete live HUD inventories. See [UI_REFERENCE_STUDY](../docs/UI_REFERENCE_STUDY.md) for OBSERVED versus INFERRED rules, official source URLs and limits. The supplied “half play one-handed” assertion remains unverified and is not repeated as fact.

Assumptions: right-handed default with a mirrored option; reduced HUD area below12% is preferable to filling it; clean gameplay corridor with restrained outer grit. Questions for the owner after playing: is the industrial treatment strong enough, is left-handed comfortable, and are multiplication/part-loss/threat cues understood without explanation? No gameplay/monetization expansion is implied by this review.

## 10. Recommendation

Keep `ui_v2=false` until owner review and the phone/five-person checks. The preview opens the home menu; press Play to begin. The implementation is reviewable now in `build/scrap_bot_ui_v2_review.apk`; flag-off comparison is `build/scrap_bot_ui_default.apk`. On Mac use `tools/play_ui_v2.sh b` or `a`. Next UI step: review comprehension of the gate and lost-part cues with people, then tune hierarchy/lifetimes from their actual misses. Do not add another mechanic to compensate for an unmeasured visual problem.

Actual fresh-save Mac preview: [Home](../results/ui_preview_home.png). The manual preview is open on the isolated B save; it is not a bot run.
