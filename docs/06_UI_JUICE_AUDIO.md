# 06 — UI, Juice, Haptics, Audio

Sensory polish is a major retention lever in hybrid-casual games. Treat this file as required work in M6 and apply the basics from M1 onward (attach feel).

## 1. Visual direction

- **Look:** chunky toy-like low-poly machines, flat colours, strong silhouettes, bright warm junkyard sand with steel and orange accents (palette in file 02, section 5).
- **Readability first:** a part must be recognisable at the gameplay camera distance on a phone. Big shapes, thick outlines of contrast colour, no tiny detail.
- **Colour language (keep it consistent everywhere):**
  - Green = good / positive gate panel
  - Orange = trade-off
  - Red = danger and telegraphs
  - Cyan = shield / energy
  - Yellow = scrap and rewards
- Use big, clear numbers and icons on gate panels. They help players decide quickly and make the footage readable in ads.

## 2. Screens

All UI sits inside the **safe area**. Minimum touch target 120 px (on a 1080 × 1920 canvas). Use one bold display font for titles and numbers, one clean sans for text.

### 2.1 HUD (during a run)

```
+-----------------------------------+
| LEVEL 3        [scrap icon] 128   |  top bar (safe-area aware)
| [HP bar ==========----]  [shield] |
| [part strip: icons of owned parts]|
|                                   |
|                                   |
|        (gameplay)                 |
|                                   |
|  [combo hint silhouette]          |
|                    [ SPECIAL ]    |  bottom-right, big, pulses when ready
+-----------------------------------+
```

- **HP bar:** green → yellow → red; threshold ticks at 75/50/25% so players see when a part may break; flash and shake on break.
- **Part strip:** small icons with level pips; a broken part greys out with a red slash.
- **Scrap counter:** count-up animation on pickups.
- **Combo hint:** faint silhouette with "1 part missing" text when exactly one part away.
- **Special button:** radial cooldown, glow when ready.
- **Boss HP bar:** top centre, segmented at 66% and 33%; plate/core icon shows current weak point state; Overdrive meter below it.
- **Streak badge:** small flame icon with the count.
- Hide debug elements in release and capture mode.

### 2.2 Gate panels (3D)

Each panel is a large 3D quad/mesh across half the road:
- Top: part icon (big).
- Middle: name in the display font ("CANNON").
- Bottom: stat delta line ("+ DAMAGE" / "+12% SPEED" / "+40% DMG  −30% HP").
- Colour: green background for part gates, orange for trade-offs, purple for the gamble crate (question-mark icon).
- Pulsing outline on both panels in the first run only.
- Panel dims and shrinks on pass; the unchosen panel breaks apart or fades.

### 2.3 Result screen

1. Banner: "VICTORY" or "DEFEATED" with the boss silhouette.
2. **Final-build image** (turntable shot) with a generated build name ("The Rocket Tank").
3. Rewards count-up: scrap → Cogs, boss bonus, streak bonus.
4. Buttons: **Next level** (primary, large), **Double Cogs (ad)**, **Hangar**.
5. After a loss: tip line, **Revive (ad)** if not used, **Save Streak (ad)**, **Try again** (primary).

Aim for the next run to start within 3 seconds of tapping Try again or Next.

### 2.4 Hangar

Based on concept art image 2: robot on a turntable at the top, a list of upgrade rows below.
- Row: icon, part name, level pips (tier 1–5), cost with Cogs icon, upgrade button.
- Pulse the cheapest affordable upgrade.
- Tabs: **Upgrades**, **Armoury** (unlock parts), **Codex**.
- Big **PLAY** button.
- Show what an upgrade changes ("+8% damage" and a preview of the new visual at tiers 3/5).

### 2.5 Codex

Grid of combos and synergies. Discovered ones are in colour with name and description; undiscovered ones are black silhouettes with "?" and a hint of the needed part categories. First discovery shows a celebration and a one-time Cogs bonus.

### 2.6 Settings

Sound, music, haptics toggles; credits (with thanks to Kenney.nl and Quaternius); privacy / ads info link; reset progress (with confirmation).

## 3. Juice list (apply from M1)

| Moment | Effects |
|---|---|
| **Part attach** | Drop-in from above with scale overshoot (0.14 s) → settle; 8-point yellow spark burst; 40 ms hit-stop; metal clunk; short haptic; camera nudge forward 0.1 m |
| **Part upgrade (merge)** | Quick pulse (scale 1.25 → 1), flash white, "LV 2" floating text, ascending chime |
| **Stage-up (chassis swap)** | White flash, scale pop 0.6 → 1.1 → 1.0, shockwave ring, camera shake 0.4, big haptic, "BATTLE BOT" banner |
| **Gate pass** | Panel chime, unchosen panel breaks, chosen panel shrinks with a swoosh |
| **Scrap pickup** | Small sparkle, pitch-stepped blip (pitch rises across a streak, resets after 1 s), "+n" popup |
| **Weapon fire** | Muzzle flash billboard, soft recoil kick on the barrel mesh, tiny camera jitter on heavy weapons |
| **Enemy hit** | White flash for 60 ms, small knockback; damage numbers for rockets and boss (optional toggle) |
| **Enemy death** | Pop + explosion particles + debris + scrap burst + short thud |
| **Player hit** | Screen-edge red vignette for 0.2 s, short shake, robot flashes, haptic |
| **Part break** | Part spins off with physics, red HP-bar flash, "PART LOST" tick on the part strip, big thunk, heavy haptic, 60 ms hit-stop |
| **Telegraph** | Red quad pulses faster as the strike approaches; a 0.2 s final flash; warning blip at start |
| **Boss slam** | Camera shake 0.8, shockwave ring on the ground, dust particles, deep impact sound, haptic |
| **Phase change** | Boss roars (scale pulse), slow zoom, camera shake, plate breaks off in Phase 2 |
| **Grabber steal** | Arm shoots in, part yanks away with a trail, bold "PART STOLEN" text; recovering shows the part flying back |
| **Overdrive ready** | Button glow, ring pulse, ascending synth, HUD frame glow |
| **Boss kill** | Time scale 0.25 for 1.2 s, camera orbit, flash, boss breaks into 24 chunks, rare part flies to robot, victory jingle |
| **Revive** | Screen flash, robot reassembles with the attach animation, 2 s invulnerability |

## 4. Haptics table

`Haptics.tap(ms, amplitude)` (Android needs the VIBRATE permission in the export preset). Amplitude is 0.0–1.0.

| Event | ms | Amp |
|---|---|---|
| UI button press | 10 | 0.2 |
| Part attach | 20 | 0.4 |
| Part upgrade | 25 | 0.5 |
| Scrap streak milestone (every 10) | 10 | 0.2 |
| Player hit | 40 | 0.6 |
| Part break | 80 | 0.8 |
| Stage-up | 60 | 0.7 |
| Boss slam | 120 | 0.9 |
| Special used | 50 | 0.6 |
| Boss kill | 150 | 1.0 |

Cap haptics to one call per 50 ms and honour the settings toggle.

## 5. Audio

### 5.1 Buses

`Master` → `Music` (−6 dB), `SFX`, `UI`. Add a light compressor on `SFX`. Duck `Music` by 4 dB during boss telegraphs and the kill sequence.

### 5.2 Event map (sources from Kenney CC0 packs; confirm file names at import)

| Event | Source pack | Notes |
|---|---|---|
| Part attach | Impact Sounds (metal) + Interface Sounds (confirm) | Layer a metal clunk and a short chime |
| Part upgrade | Interface Sounds / Digital Audio | Rising two-note blip |
| Stage-up | Sci-Fi Sounds (engine / power-up) + Impact | Bigger, longer |
| Gate pass | Interface Sounds | Short positive for part gates; lower tone for trade-offs |
| Scrap pickup | Digital Audio / Interface | Very short; pitch steps up with streak |
| Cannon fire | Sci-Fi Sounds (laser/blaster) | Pitch jitter ±8%; polyphony 4 |
| Gatling | Sci-Fi Sounds (short blip) | Rate-limited loop feel; polyphony 3 |
| Rocket launch / blast | Sci-Fi Sounds (explosion) | Whoosh + blast layers |
| Flamethrower | Sci-Fi Sounds (engine loop), looped while firing | Fade in/out |
| Enemy hit | Impact Sounds (soft) | Polyphony 6 |
| Enemy death | Sci-Fi explosion (small) | Polyphony 4 |
| Player hit | Impact Sounds (heavy) | Always plays |
| Part break | Impact Sounds (metal crash) | Longer, with a rattle |
| Telegraph start | Sci-Fi Sounds (scan / alarm) | Short warning |
| Boss slam | Impact Sounds (heavy) + low explosion | Duck music |
| Boss roar | Sci-Fi engine pitched down | 1–1.5 s |
| Overdrive ready | Sci-Fi power-up | Rising |
| Special use | Sci-Fi laser burst / dash | Per combo |
| UI click / confirm / error | Interface Sounds / UI Audio | Consistent set |
| Victory | Music Jingles | 2–3 s |
| Defeat | Short descending jingle | Soft, not punishing |

Music: one gameplay loop (energetic, 100–120 BPM), one Hangar loop (calmer), CC0 only; record the license in `CREDITS.md`. Boss music (stretch): same loop with added percussion layer.

### 5.3 Implementation rules

- Use WAV for short SFX, OGG for music.
- Pool 12 `AudioStreamPlayer` nodes; per-sound polyphony limits; randomise pitch ±8%.
- Play UI sounds on the `UI` bus so they stay audible during ducking.
- Respect sound and music toggles; fade music when the app loses focus.

## 6. Camera

- Run camera: offset (0, 5.2, 7.5), FOV 62, smooth follow (exp rate 6).
- Boss camera: offset (0, 8.5, 11.0), eases in over 1.5 s on arena entry.
- Kill camera: orbit 90° over 1.2 s at slow motion.
- Shake: trauma value that decays at 2.5/s, applied as small `h_offset` and `v_offset`; cap total at 0.25.
- Respect a "reduce motion" setting that scales shake by 0.3.

## 7. VFX list (CPU particles, pooled)

| Effect | Spec |
|---|---|
| Spark burst | 8 particles, yellow, 0.25 s, gravity low |
| Muzzle flash | Billboard quad, 2 frames, 0.06 s |
| Explosion small | 12 particles orange/yellow + smoke grey, 0.4 s + flash quad + ring |
| Explosion big | 20 particles + stronger ring + camera shake |
| Dust | 10 particles tan, 0.5 s, slow |
| Rocket trail | 6 particles grey/orange following the rocket |
| Fire cone | 12 particles, orange→red, 0.4 s lifetime, additive |
| Shield flicker | Translucent cyan sphere, hit ripple via scale and alpha |
| Shockwave ring | Flat ring mesh scaled up with fading alpha |
| Telegraph | Flat red quad with pulse (shader parameter or scale/alpha tween) |
| Scrap sparkle | 4 yellow points, 0.2 s |
| Debris | 6–10 pooled small boxes with physics, fade at 1.5 s |

Keep effect counts within the budget in file 03 section 7. Verify any effect on the phone before adding more.

## 8. Accessibility and comfort

- Haptics, sound and music toggles; "reduce motion" toggle.
- Telegraph shapes use **shape and motion**, not only colour (circle, lane stripes, sweep line) so colour-blind players can read them.
- Text at least 36 px on the 1080 × 1920 canvas; high contrast between text and panel.
- One-handed reachability: all primary buttons in the lower two-thirds of the screen.

## 9. Capture mode (marketing)

Launch with `--capture` (read via `OS.get_cmdline_user_args()`):
- Fixed seed and scripted input path for reproducible footage.
- Hide FPS, debug and any ad UI.
- Option to record input and replay it for multiple takes.
- Required clips: first-gate transformation, a part ripped off, "wrong choice" fail, split-screen build battle (two sims side by side or two takes composited), slow-motion boss kill, final-build reveal.
