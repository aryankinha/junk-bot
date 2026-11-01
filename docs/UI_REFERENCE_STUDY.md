# UI reference study — 2 November 2026

No owner media exists in `reference/mob_control/` (only `reference/README.md` was present). Official store imagery was therefore inspected in the browser, not inferred from descriptions. No art or exact layout is copied.

## Screen anatomy

| Reference / primary source | Observed anatomy | Motion evidence and limits |
|---|---|---|
| [Mob Control (VOODOO, Google Play)](https://play.google.com/store/apps/details?id=com.vincentb.MobControl), [official App Store preview](https://apps.apple.com/us/app/mob-control/id1562817072) | Blue friendly units, red enemy mass, gray bounded runway, large outlined unit/enemy values, purple signed multiplier. Desert props remain detailed outside the track. Promotional crop has very little persistent HUD; it is not a representative measurement of every live UI state. | Official video loaded (30.113s duration), playback confirmed at3.378s. Short sampled frames show a cannon stream and changed counts/positions around gates; the background player later paused/reset. Full uninterrupted timing and input agency are UNVERIFIED. |
| [Count Masters (Freeplay)](https://play.google.com/store/apps/details?id=freeplay.crowdrun.com) | Pale track with broad faint chevrons; blue/red crowds with one number badge each; signed +50 and ×12 gates; large open corridor, blue backdrop. Gate values and crowd counts dominate. | Screenshot inspection only: continuous crowd motion and player-triggered timing cannot be established from the still. |
| [Tall Man Run (Supersonic)](https://play.google.com/store/apps/details?id=com.VectorUpGames.TallManRun) | Orange player silhouette, green gain/red loss panels with large signed values; busy city/water backdrop is lower contrast than player and panels; several future rows visible. Marketing caption occupies the bottom of the image and is not treated as HUD. | Screenshot only. No claim that its camera or background is uniformly minimalist. |

## Rules extracted

- **OBSERVED:** semantic actor colors and signed values separate sides and outcomes without relying on text paragraphs (all three references).
- **OBSERVED:** a bounded corridor keeps scenery away from the immediate decision path; scenery need not be entirely absent.
- **OBSERVED:** large gate/count numerals read over simpler surfaces; decorative captions in promotional imagery are not actual persistent UI.
- **INFERRED:** give Scrap Bot one strongest event at a time, local supporting effects, and a compact stable HUD. The exact three-popup cap and duck durations are our testable design choices, not copied observations.
- **INFERRED:** a plate/stencil industrial vocabulary better matches Scrap Bot than additional plastic pills. Keep the physical robot and blue stream; frame them with restrained steel and rust rather than adding objects to imply activity.
- **INFERRED:** a local ring, panel press and attach receipt can deliver the stream-growth satisfaction without restoring camera motion. Human comprehension remains to be tested.

## Extended source checks

[Supersonic gate-runner design](https://supersonic.com/learn/blog/how-to-design-a-hit-gate-runner-the-basics-and-best-practices/) discusses readable choices and theme as a differentiator. Its reward/difficulty prescriptions are not permission to rebalance this UI-only task.

[Supersonic's UX case study](https://supersonic.com/?p=106545) explicitly relates visual language to theme: soft/curved surfaces for yarn, harder metallic/edged surfaces for precision. It also advocates clear backgrounds and consistent buttons. We use that as a design rationale, not causal proof of retention for Scrap Bot. [2025 lessons](https://supersonic.com/?p=106607) recommends sensory polish; its monetization advice is out of scope here.

[W3C WCAG2.2 SC2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) permits no more than three flashes in a one-second period, or output below defined general/red-flash thresholds. A mere three-Hz throttle is not a complete WCAG certification: area/luminance/red thresholds still matter. This build avoids full-screen saturated-red flashes, offers0–3 local flashes/s, and disables optional flash/motion in Reduce Motion. Photosensitivity/comfort validation with people remains unverified.

The supplied KDE one-hand URL was unavailable through the text browser. We do not repeat the unverified claim that half of users play one-handed. Lower-middle controls, minimum120px logical targets, mirrored handedness and a notch-safe layout are design requirements tested in the local build.
