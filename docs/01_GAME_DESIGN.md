# 01 — Game Design

## 1. Pitch

> Start as a tiny junkyard robot. Drive through physical upgrade gates that bolt real parts onto your body. Grow into a huge custom war machine. Beat a giant boss with the machine **you** built.

Portrait, one-thumb, 90–150 s per run, a boss at the end of every level. The hook is the **visible build**: players see their decisions on the robot, and bosses reward different builds in different ways.

## 2. Why it should hook (design rationale)

These points come from market research on hybrid-casual runners and from the owner's goals:

- **Early value is everything.** Median D1 retention across mobile games sits near 22%; top games reach about 40%. D7 median is about 4% vs about 12% for the top tier. Players decide in the first 5–15 minutes. So the first 10 seconds must show a transformation, and the first run must end in a boss win that teaches the game.
- **Optimise D7, not just D1.** Hybrid-casual games live on D7/D14. Long-term pull comes from the build codex, hangar upgrades, new parts entering the gate pool, zones and bosses.
- **Mob Control is the benchmark.** It started as a pure gate game, then added a building meta, card collection, boss levels and events, and reached about 4.9% D30. Scrap Dragon's equivalents: Hangar part upgrades, build codex, boss levels, daily seed.
- **Sensory polish drives engagement.** Haptics, smooth animation and satisfying attach/destroy feedback are a major retention lever. Budget real time for juice (file 06).
- **Core loop first.** Monetization and meta cannot fix a weak core. Prove attach-feel, part-loss and the boss before building content.
- **Short-form video is the competitor.** Build for shareable moments: the transformation, the part rip-off, the slow-motion boss kill, the final-build "photo".

## 3. Pillars

1. **Visible build** — decisions appear on the robot.
2. **Meaningful choice** — both gate options are attractive; trade-offs exist; builds differ.
3. **Skill matters** — steering, dodging telegraphs, timing the special; not a pure stat check.
4. **Loss hurts a little, recovery feels good** — parts can break off and can be recovered.
5. **Respect the player's time** — 3-second restart, fair ads, no grind walls.

## 4. Controls

- **Drag horizontally anywhere** on the screen to steer. Use *relative* drag: finger delta moves the robot's lateral target, so the thumb never covers the robot.
- **Auto-forward** at constant base speed (wheels raise it a little).
- **Auto-fire** at the nearest enemy in a forward cone. The player focuses on steering and choices.
- **Special button** (large, bottom-right, thumb-reachable): appears once a combo is active or the Overdrive meter is full. One tap triggers it.
- Support one-hand portrait play. Keep UI inside the safe area.

## 5. Run structure

A level is a sequence of **beats** placed by distance. The robot moves at about 9 m/s, so 1 s ≈ 9 m. Level 1 is a shorter, authored tutorial run (about 90 s). Later levels run about 150 s.

| Time (L1 / later) | Beat |
|---|---|
| 0–5 s | Tiny bot collects its first scrap trail. A "drag to steer" hint shows once. |
| ~8 s / ~10 s | **Gate 1**: Cannon vs Wheels. The chosen part attaches with animation, sound and haptic. |
| 12–15 s | First obstacle or scrapper pack. The new weapon destroys it so the choice pays off at once. |
| 15–50 s | Gates 2–4, enemy packs, scrap fields, first hazard (saw blade, oil, barrel). Chassis grows to **Battle** stage around the 3rd–4th part. |
| ~50 s | **Mini-boss** (Elite Bruiser). Short fight, previews boss rules (telegraphed charge). Drops a rare part. |
| 50–80 s | Gates 5–7 including a **trade-off gate** and a **gamble crate**. Chassis can reach **Monster** stage. |
| ~65–75% | **Repair Bay fork** (3 lanes: Repair, Re-roll, Buy Part). |
| Final gate | **Final Choice**: three floating parts in three lanes, pick one. |
| End | **Boss arena**: boss fight (30–45 s). |
| After | Result screen → Hangar → Play. |

Gate spacing keeps a choice every 10–20 s. Scrap fields and enemy packs fill the gaps so the screen is always active.

## 6. The robot

### 6.1 Chassis stages (visible growth)

| Stage | Name | Build points to enter | Look |
|---|---|---|---|
| 1 | Tiny Bot | 0 | Small boxy body, one pea-shooter, 4 sockets |
| 2 | Battle Bot | 4 | Larger body, 10 sockets |
| 3 | Scrap Monster | 9 | Huge body, 14 sockets, glow accents |

Build points: each part at level 1 = 1 point, each upgrade level adds 1. On stage-up the chassis swaps with a scale-pop, white flash, shockwave ring, haptic and sound. Existing parts move to the matching socket names on the new chassis (all stages share socket names; larger stages add more).

### 6.2 Parts

Nine prototype parts, four categories. Every part has levels 1–3 and a **different mesh per level** so merging is visible (for example Cannon → Twin Cannons → Gatling). Taking the same part again upgrades it instead of adding a duplicate (cap level 3).

| Category | Parts |
|---|---|
| Movement | Extra Wheels, Tank Tracks |
| Weapons | Cannon, Rocket Launcher, Flamethrower |
| Defence | Heavy Armour, Energy Shield |
| Collection | Scrap Magnet, Storage Pack |

Stretch parts (after M6): Shock Coil, Robot Arm, Bigger Chassis. Full numbers are in file 04.

### 6.3 Silhouette goal

A fast, wheeled, machine-gun-style build and a slow, tracked, rocket-and-armour tank must be recognisable from the shape alone. Assign wheels and tracks to lower sockets, weapons to top and side sockets, rocket pods to the back, armour to the front and shoulders.

## 7. Gates

### 7.1 Physical gates

Two large panels span the road. The robot passes through one. The robot's lateral position at the gate line decides the side. Each panel shows a **big icon, a short label and a clear stat delta**, coloured green for pure upside and orange for trade-offs. Big numbers and clear icons also make the game readable in ads.

### 7.2 Gate types

| Type | Behaviour |
|---|---|
| **Part gate** | Option A / Option B, each a part from different categories. |
| **Trade-off gate** | Strong upside with a cost, for example "Overclock: +40% damage, −30% max HP" vs "Plating: +40% HP, −10% steering". |
| **Gamble crate** | Mystery crate in one lane: 60% random part, 15% rare part, 25% junk (scrap burst). The other lane is a safe known part. |
| **Final Choice** | Three floating parts in three lanes; pick one. Used once before the boss. |
| **Repair Bay** | Three stations: Repair, Re-roll, Buy Part (see section 11). |

### 7.3 Rules that keep gates interesting

- Both options must be viable. Use the **pair validator** in tests: for every generated pair, a bot with the matching build must be able to win; no option is dominated by the other.
- Never offer two parts from the same category in one gate (except Trade-off gates).
- Never offer a part the player already has at level 3.
- If the player owns no weapon by gate 3, one option at gate 3 is a weapon.
- Introduce categories gradually: Level 1 authored order is in file 04.
- Gate generation is seeded, so the daily challenge gives everyone the same gates.

### 7.4 Re-roll

Each run has 1 free re-roll (usable at the Repair Bay or via a button at any gate approach once). Extra re-rolls cost a rewarded ad. A re-roll replaces the next gate pair.

## 8. Combos

A combo activates when the robot owns both parts (any levels). A faint **silhouette hint** in the HUD shows "1 part missing" combos so players chase them. When active, the **special button** appears.

| Combo | Parts | Special (tap) | Cooldown |
|---|---|---|---|
| **Burst Volley** | Cannon + Rocket Launcher | 8 homing rockets + cannon barrage for 3 s | 10 s |
| **Ram Charge** | Tank Tracks + Heavy Armour | 2 s invulnerable dash forward through enemies, knockback | 12 s |
| **Vacuum** | Scrap Magnet + Storage Pack | Passive: scrap magnet radius ×3 and scrap ×1.5. Tap: pull all scrap on screen | 15 s |

Stretch combos: **Strafe Run** (Wheels + Cannon: lateral dash that fires a spread), **Inferno Aura** (Flamethrower + Heavy Armour: damaging flame ring).

## 9. Damage and part loss

- Robot has HP. Armour reduces damage by a percentage. Shield blocks one hit every few seconds.
- Each time HP **crosses below 75%, 50% and 25%** of max for the first time, one attachment breaks off. Selection: random among attachments, weighted toward higher level, **never the last weapon**, never the chassis.
- A broken part spins off (physics debris, fades in 1.5 s) and its stats are removed. A short **warning flash** and haptic make the loss readable.
- **Recovery:** Repair stations and boss rewards restore lost parts. During the boss fight, the grabber arm steals parts that can be recovered by destroying the arm.
- 1 s invulnerability after each hit stops chain loss.
- HP 0 = run failed: instant "Try again" with a one-line tip about the cause of death.

## 10. Enemies and hazards (prototype)

| Enemy | Behaviour | Threat |
|---|---|---|
| **Scrapper** | Small swarm bot that rushes the robot | Chip damage in numbers; teaches auto-fire |
| **Gunner Turret** | Static, shows a laser line for 0.6 s then fires | Teaches telegraphs and dodging |
| **Bruiser** | Large, winds up 1 s then charges in a line | Teaches lane-dodging; drops rare scrap |
| **Elite Bruiser** | Mini-boss version with 3× HP and double charge | Mid-run exam |

Hazards: **Saw blade** (moves across the road on a rail), **Oil patch** (slows; Tracks are immune), **Explosive barrel** (shoot it to damage nearby enemies; harms the robot if hit by contact).

Every enemy has a **telegraph** (0.4–1.2 s) before it deals damage. Telegraphs use red, flat, pulsing quads.

## 11. Repair Bay

At ~65–75% of the level, the road splits into three lanes with stations. Costs are in scrap.

| Station | Cost | Effect |
|---|---|---|
| **Repair** | 20 | Heal 40% max HP and restore every broken part |
| **Re-roll** | Free | Next gate pair is replaced |
| **Buy Part** | 35 | Pick 1 of 3 parts (one gate-style choice) |

If the player cannot afford a station, show a rewarded-ad alternative ("Watch to repair free"). This gives scrap a purpose beyond score and places the ad exactly where the player feels pressure.

## 12. Boss fight

### 12.1 Goals

A boss is a **real encounter**, not a damage race. The player steers to dodge telegraphs, uses the special at the right time, and benefits from build-specific counters.

### 12.2 Scrap Titan (Zone 1 boss)

Giant junk-built robot with red eyes. Boss HP scales with level (see file 04). Camera pulls back and up when the arena starts; the robot keeps auto-forward locked to the arena (the world stops scrolling; the robot only moves laterally and can back off slightly).

**Phase 1 — Plated (100–66% HP)**
- Front plate reduces non-area damage by 50%. **Rockets and Shock ignore the plate.**
- Attacks: **Ground Slam** (red circle telegraph, 1.2 s), **Rocket Barrage** (three red lane telegraphs, 1.0 s, then 5 rockets over 2 s).
- A short invulnerable roar at the end of the phase.

**Phase 2 — Grabber (66–33%)**
- Plate opens; core visible.
- New attack: **Grabber Arm** reaches in (1.5 s telegraph). If it connects, it rips the highest-level attachment off the robot. **Destroying the arm within 5 s returns the part**; otherwise it stays lost for the fight.
- New attack: **Laser Sweep** across the road with a 2.2 m safe gap.

**Phase 3 — Enraged (33–0%)**
- Attack cadence −30%. Core takes ×1.5 damage from every source.
- Calls a pack of Scrappers (good for Magnet and Flamethrower builds).
- Ground Slam becomes a double slam.

### 12.3 Weak points and part counters

| Part | Boss payoff |
|---|---|
| Rocket Launcher | Ignores the Phase 1 plate |
| Flamethrower | Burns Scrapper packs; strong at close range on the core |
| Cannon | Reliable single-target; best vs the Grabber Arm |
| Tracks | Resist Ground Slam knockback; immune to oil |
| Wheels | Faster lateral dodging |
| Armour | Reduces Rocket Barrage damage |
| Shield | Blocks one slam or one rocket |
| Magnet | Pulls boss debris and scrap during Phase 3 for Overdrive fuel |

### 12.4 Overdrive finisher

An Overdrive meter (0–100) fills from hits landed (+1 per 0.5 s of sustained fire) and from **clean dodges** (+15 per telegraph avoided without damage). At 100, the special button pulses. If a combo is active, tapping unleashes it at ×1.5 power. Otherwise Overdrive doubles fire rate for 4 s.

### 12.5 The kill

Slow motion (time scale 0.25 for 1.2 s), camera orbit, the boss breaks into pooled scrap chunks, a rare part drops and flies to the robot, then the result screen. Capture a **final-build image** (SubViewport turntable shot) for the result screen and sharing.

### 12.6 Difficulty target

| Level | First-attempt boss win rate (target) |
|---|---|
| 1 | 85% |
| 2–3 | 65% |
| 4–5 | 50% |

Tune so players who lose often finish with the boss at 10–20% HP ("one more try"). The hidden assist (decision D4) helps after repeated losses.

### 12.7 Later bosses

Crusher (dodge-heavy), Gunship (shield-heavy), Swarm-Mother (spawns minions; magnet and flame shine), Scrap Dragon (Zone 4 finale).

## 13. Zones

| Zone | Look | Modifier |
|---|---|---|
| **Junkyard** (prototype) | Sand, scrap piles, rusty buildings | None; clean tutorial |
| Desert | Orange sand, cacti, ruined towers | Deep-sand patches slow wheels; Tracks excel |
| Factory | Conveyors, pipes, sparks | Conveyor lanes push the robot sideways |
| Snow | Ice, white hills | Ice reduces steering grip; Tracks hold grip |

Zones change gate weights so different parts shine in different places.

## 14. Progression and meta

### 14.1 Hangar (between runs)

The Hangar is the home screen after the first run. It shows the robot on a turntable and the upgrade list (concept art image 2).

- **Part upgrades** (tiers 1–5) cost Cogs and add +8% to the part's main stat per tier. At tiers 3 and 5 the part gets a **visual variant** (paint or added detail), so meta progress is visible.
- **Part unlocks** add parts to the gate pool (for example Shield unlocks at Level 3).
- **Build Codex**: a grid of combos and part synergies with silhouettes for undiscovered ones. Discovering a combo gives a one-time Cogs bonus.
- **Starter bots** (stretch): cosmetic starting chassis.

Meta progress must change the gameplay, not only numbers: a Cannon at tier 3 looks different and the Codex shows what remains.

### 14.2 Win streak

Beating bosses in a row builds a streak. At **3 wins**, boss weak points are outlined during the next boss fight (information advantage) and a streak badge shows in the HUD. A loss resets it. Offer a **rewarded ad to save the streak** after a loss (pressure moment).

### 14.3 Daily challenge

Same seed for everyone (gate pairs, enemy packs, boss attack order). Local best score is stored in the prototype. Online leaderboard later.

## 15. Economy

- **Scrap** (in-run): picked up on the road, dropped by enemies, spent at the Repair Bay.
- **Cogs** (meta): at run end, Cogs = scrap collected + boss bonus (50 × level) + streak bonus (+10% per streak step, max +30%). Spend in the Hangar.
- Upgrade costs and gains are in file 04. Keep upgrades affordable: a typical player should afford one meaningful upgrade after each run in the first 5 levels.

## 16. Monetization (prototype scope and plan)

Rewarded-first, ad placements at natural moments of need (the player feels pressure or wants more):

| Placement | Offer |
|---|---|
| Boss defeat | **Revive** once per run with 60% HP |
| Gate approach / Repair Bay | **Re-roll** an extra time |
| Repair Bay (cannot afford) | **Free repair** |
| Result screen | **Double Cogs** |
| Pre-run (optional) | **Starter boost**: begin with a part of your choice |
| After a loss | **Save streak** |

Interstitials (post-prototype): hold the first one back until after the 4th completed run or about 10 minutes of play, then show at most one every 2 runs with a minimum gap of 120 s, only on the result screen, never during a run or boss. Mirror every future IAP perk as a rewarded-ad version so non-spenders still monetise. IAP ideas for later: Remove Ads, Season Pass, Starter Bundle.

Use AdMob **test ad units** until release. Report ad load failures gracefully (hide the button).

## 17. First-time user experience

No splash longer than 1 s and no menu before gameplay on the first launch.

| Time | Experience |
|---|---|
| 0–5 s | Tiny bot enters; drag hint (ghost hand) shown once; scrap collected |
| 5–10 s | Gate 1 appears (Cannon vs Wheels) with big labels |
| 10–15 s | Chosen part attaches; first obstacle destroyed by the new weapon |
| 15–45 s | Gates 2–3, chassis grows to Battle stage, one scrapper pack |
| ~45 s | Simple turret teaches a telegraph |
| ~60 s | Repair Bay (first time shown with a hint) |
| ~80 s | Boss with simplified L1 tuning; first failure is forgiving |
| After win | Hangar opens with a pulsing first upgrade |

## 18. Balance targets and KPIs

- Level 1 completion time: median ≤ 3 min including the boss.
- Retry after a loss within 10 s: ≥ 60% of players.
- Players who lose the L1 boss and win on the next attempt: ≥ 70%.
- Gate balance: across bot runs, each part in a pair is picked 40–60% of the time by a rational bot. Investigate pairs outside this band.
- Boss time: 30–45 s for the first win.

## 19. Telemetry (local first)

Write JSON lines to `user://telemetry.jsonl`: `run_start`, `gate_choice` (gate id, side, time), `part_attached`, `part_broken`, `combo_active`, `special_used`, `boss_phase`, `death` (cause, time, boss HP%), `retry`, `ad_offer`, `ad_watched`. Playtest sessions review this file. An optional analytics SDK can be added later.

## 20. Marketing-ready by design

Support these capture moments: the first-gate transformation, a part ripped off by the boss, the slow-motion boss kill, the final-build image. Provide a **capture mode** (`--capture` user arg): fixed seed, hides debug UI, uses a scripted input path for clean ad footage. Ad concepts to support: split-screen "build battle", "wrong choice" fails, and a tiny-bot-to-Dragon time-lapse. Ads must show real gameplay.

## 21. Out of scope for the prototype

Online leaderboards, multiplayer, IAP, interstitials, more than one zone, more than the Scrap Titan boss, robot-skin store, localisation, iOS builds.
