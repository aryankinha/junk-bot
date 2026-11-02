# Hook Pass reference study — 2 November 2026

This extends `docs/UI_REFERENCE_STUDY.md`. Official pages and enlarged store imagery were inspected in this session. No reference art, logos or exact layouts are imported. `OBSERVED` means visible in the inspected image or explicitly stated by its publisher; `INFERRED` means a Scrap Bot design recommendation. This is not a playtest or retention experiment.

## Clash of Clans: what visual upgrades communicate

| Official source | Evidence actually inspected | Useful principle and limit |
|---|---|---|
| [Town Hall 15 release notes, 10 October 2022](https://supercell.com/en/games/clashofclans/blog/release-notes/full-release-notes-2/) | **OBSERVED, image:** a dark stone central entrance, broad purple upper plates, gold corner bands and a raised pale crystal roof. The building remains a readable, chunky architectural object; accents occupy larger zones rather than becoming tiny noise. The article also describes different Spell Tower effects at different levels. | **INFERRED:** retain a weapon's base identity and let a few broad material/attachment changes communicate construction quality. This is not evidence for Scrap Bot's exact four materials or damage ratios. |
| [Town Hall 16 patch notes, 12 December 2023](https://supercell.com/en/games/clashofclans/blog/release-notes/full-patch-notes-th16/) | **OBSERVED, hero image/text:** tree-influenced architecture, warm light, green vegetation and pale/gold structural trim. **Publisher-stated:** ordinary Archer Towers were changed to show a single archer so they would not be confused with Multi-Archer Towers. The notes also correct an upgrade-information view that inconsistently mixed individual and total capacity. | **INFERRED:** different gameplay families need a shape/occupant distinction, not only a new tint. Keep one consistent meaning for every preview number. The archer change is direct primary-source support for those two safeguards. |
| [Town Hall 17 update, 25 November 2024](https://supercell.com/en/games/clashofclans/blog/game-updates/the-town-hall-17-update-is-here-2/) and [official announcement](https://supercell.com/en/news/clashofclans-townhall17/) | **OBSERVED, hero image:** a dark grey/black central fortress with thick gold braces, a pale central crest and a taller crown of details. **Publisher-stated:** the theme is justice/order; the Hero Hall adds a fresh 3D view and the skin selection view received lighting/background changes. | **INFERRED:** preview permanent upgrade details on the actual 3D object with controlled lighting. Before/after views should use the same shape, pose and camera so trim changes can be understood. |

The inspected imagery supports theme, material grouping, recognizable architecture and family differentiation. It does **not** establish every ordinary Cannon level's model progression, a universal rarity palette, an in-run reset/ascension mechanic, or a causal retention increase. Calling Scrap Bot's proposed permanent artefacts “CoC-style” is an analogy, not a claim that CoC resets upgraded weapons back to their base appearance.

## Mob Control: gates and horde readability

[Official Google Play listing](https://play.google.com/store/apps/details?id=com.vincentb.MobControl), first two enlarged promotional screenshots inspected in the browser:

- **OBSERVED:** a grey bounded corridor, a small fully visible blue cannon at the bottom, blue friendly crowd and dense red enemy mass. Large white numbers have dark outlines. One frame uses a purple `×3` panel, a friendly `5`, and a boss `1000`; another shows repeated `+1` panels, a central `×3`, enemy `150` and container `70`.
- **OBSERVED:** scenery is detailed outside the runway; the actors and decision values have stronger contrast inside it. The second promotional image is itself busy, so the claim that every Mob Control screen uses a single quiet gate row is not supported.
- **LIMIT:** stills do not establish actual node counts, continuous wave timing, player input latency, or the truth of promotional arithmetic. No new full video viewing is claimed in this session. Earlier sampled-video limitations remain in the UI reference study.

**INFERRED:** differentiate robot frames from stream lenses by silhouette and hint verbs; reserve the strongest contrast for the next required decision. Borrow crowd mass and readable arithmetic, not a wall of repeated signs or its numerical balance.

## Other checked guidance

- [Supersonic gate-runner guidance](https://supersonic.com/learn/blog/how-to-design-a-hit-gate-runner-the-basics-and-best-practices/), 29 February 2024: **publisher-stated** guidance recommends rising power, balancing repetition against excessive early mechanics, and checking goal clarity with other people. It is a starting hypothesis, not proof that exponential rewards will retain Scrap Bot players.
- [Supersonic UX case study](https://supersonic.com/?p=106545), 18 November 2025: **publisher-stated** guidance prioritizes clean backgrounds, a restrained palette, consistent visual language, transparency where it reveals useful information, and immediate input feedback. Its metallic/edged treatment for Screw Master is a relevant visual analogy. Its monetization/loss-aversion prescriptions are not adopted by this pass.
- [W3C SC2.3.1 explanation](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html): frequency and combined flashing area/luminance/red thresholds matter. A per-node three-Hz limit alone does not certify a scene containing many simultaneous muzzle flashes. Prefer a short travelling glint/weld sweep over alternating full-body brightness, disable optional motion, and avoid full-screen red.
- The supplied [Archero analysis](https://www.gamerefinery.com/archero-excels-in-engagement-by-creating-an-anticipation-for-rewards) could not be retrieved by the web tool in this session. Its detailed reveal assertions remain **UNVERIFIED** here. The user-requested skippable mystery reveal can still be implemented as an explicit design choice.
- The previous study could not verify the “half of users play one-handed” assertion. Do not repeat that percentage as fact; lower-middle mirrored controls remain a requirement independent of the statistic.

## Proposed procedural material grammar

These are **INFERRED / project choices**, not CoC asset copies:

| Run material | Large readable change | Small merged detail | Energy invariant |
|---|---|---|---|
| Scrap | medium-dark rusty brown, uneven broad panels; avoid fine noise | exposed dark bolts / one soot band | blue core/trail remains saturated and identifiable |
| Fixed | contrasting pale repair patches over the same rust | one broad strap / weld seam | same core/trail hue |
| Iron | uniform dark neutral metal with clean value breaks | a few crisp vents/rivets | same core/trail hue |
| Metal | pale steel faces and dark edges, a controlled glint | narrow blue-white seam / muzzle brake | same core/trail hue, no pure-red friendly shell |

Keep barrel count and the family silhouette tied to part **level**; material and repaired detail identify run **quality**; permanent Hangar stars add bounded accent artefacts. Do not let three simultaneous progression systems all replace the base silhouette. At phone size, a patch plate should remain a patch, not a single-pixel speck. Merge accessories into the existing material/mesh path; use the tier parameter for broad color/roughness effects, avoiding extra transparent layers on every drone.

## One honest stream metric: required implementation decision

The legacy implementation makes raw live drone count a poor power measure: launch damage is split across a volley (`src/sim/mob_sim.gd:187`), and caps fold units into heavier drones (`add_drone`, `_multiply`). Mixed family fire rates also mean there is no single naturally synchronized global volley.

More importantly, legacy `+N` adds N copies per five arrivals (`_apply_panel`, `data/mob.json` `gates.add_per=5`), so sustained `+10` behaves roughly like `×3`, regardless of current stream size. The requested small-stream/add versus large-stream/multiply crossover cannot be produced by a prettier preview of the old rule. This needs an explicit **flagged semantics change**, a shared preview/application resolver and a documented retuning; flags-off behavior must stay intact.

**Recommendation:** use a clearly named **STREAM POWER** in damage-equivalent units, with the exact normalization documented in `HOOK_PLAN.md`. Count/heavier merges and run material damage must be included; never label weighted power as an exact number of visible drones. Resolve fixed-add and multiply through the same pure function, including the incoming value, prior gate state, cap credit and rounding. If the implementation instead chooses “drones per volley,” define packet membership across families, clones and chains, and test complete packets—not just a sample frame's live count. Give power/speed panels their explicit units without inventing a second aggregate stream metric.

Legacy overflow is already damage-preserving: `_multiply` increases `dmg`/`wgt` when there is no room, while `scale_max=2.2` is a visual clamp. There is no existing hard max damage weight at that scale. Therefore material progress must be a newly defined redirect of otherwise-over-cap surplus, not an extra credit awarded on top of the same damage already merged. Maintain a ledger showing each surplus unit retained as merged damage **or** redirected to tier progress. This is a design/verification requirement arising from the current code, not a research claim about Mob Control.
