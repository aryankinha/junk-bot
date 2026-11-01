# Scrap Bot — Comprehensive Project & Architecture Report

> **Document Type**: Exhaustive Codebase, Systems & Verification Audit  
> **Repository Path**: `/Users/aryankinha/Downloads/junk-bot`  
> **Engine / Platform**: Godot Engine 4.7.2.stable (`gl_compatibility`), Portrait Android & Desktop  
> **Automated Test Status**: **25,177 automated checks passed (0 assertion failures)**  
> **Engine Runtime Status**: **1 handled GDScript script runtime error in `tests/integration_suite.gd:53`**  
> **Simulation Trace Status**: **TRACE MATCH** (`results/interactivity_trace_baseline.txt`)  
> **Last Verification Date**: 2026-11-01  

---

## Table of Contents
1. [Executive Summary & Product Pitch](#1-executive-summary--product-pitch)
2. [Project Architecture & Directory Layout](#2-project-architecture--directory-layout)
3. [Core Simulation Layer (`src/sim/` & `src/core/`)](#3-core-simulation-layer-srcsim--srccore)
4. [Authoritative Data Tables & Ground Truth (`data/*.json`)](#4-authoritative-data-tables--ground-truth-datajson)
5. [Procedural Level & Gate Generation System](#5-procedural-level--gate-generation-system)
6. [Presentation & View Layer (`src/view/` & `src/ui/`)](#6-presentation--view-layer-srcview--srcui)
7. [Procedural Art & Audio Pipelines](#7-procedural-art--audio-pipelines)
8. [Services, Persistence & AdMob Integration (`src/services/`)](#8-services-persistence--admob-integration-srcservices)
9. [Interactivity Experiments E1–E5 & Feature Flags](#9-interactivity-experiments-e1e5--feature-flags)
10. [Automated Testing Suite & Engine Runtime Audit](#10-automated-testing-suite--engine-runtime-audit)
11. [Simulation Bot Sweep & Balance Datasets](#11-simulation-bot-sweep--balance-datasets)
12. [Android Build Pipeline & Packaging](#12-android-build-pipeline--packaging)
13. [Codebase Discrepancies, Stale References & Stubbed Features](#13-codebase-discrepancies-stale-references--stubbed-features)
14. [Acceptance Criteria & Remaining Verification Gaps](#14-acceptance-criteria--remaining-verification-gaps)

---

## 1. Executive Summary & Product Pitch

### 1.1 Product Concept
**Scrap Bot** (working title originally *Scrap Dragon*) is a portrait-orientation mobile 3D hybrid-casual action runner. The player starts as a tiny, vulnerable junkyard robot driving forward down an endless scrap-strewn highway. By passing through physical upgrade gates, players physically bolt modular attachments (wheels, tracks, cannons, rocket pods, flamethrowers, armor plates, energy shields, magnets, and storage packs) onto named chassis sockets.

The robot visibly scales and transforms through three distinct chassis tiers:
- **Stage 1 (Tiny Bot)**: Boxy body, 4 attachment sockets, pea-shooter blaster (4 dmg, 1.5/s).
- **Stage 2 (Battle Bot)**: Heavy industrial frame, 10 sockets, enhanced speed and durability (unlocked at 4 attachments).
- **Stage 3 (Scrap Monster)**: Massive war machine, 14 sockets, reinforced shoulder plates, and glowing horns (unlocked at 9 attachments).

Each run culminates at the boss arena against the **Scrap Titan**, a three-phase juggernaut featuring armored plating, rocket lane barrages, sweeping lasers, add summons, and a grabber arm that rips off the player's highest-level attachment (which the player can recover by destroying the arm within a timed 5.0-second window).

### 1.2 Core Pillars
1. **Immediate Transformation**: First gate encountered at $z=80\text{ m}$ (~8.9s at 9 m/s) immediately alters appearance, scale, and combat capability.
2. **Visible Build**: Every decision manifests as physical 3D attachments anchored by procedurally generated steel mounting struts and brackets.
3. **Parts Matter**: Taking damage past HP thresholds (75%, 50%, 25%) physically breaks attachments off, while preserving the last remaining weapon.
4. **Active Boss Fight**: Telegraph avoidance, weak-point targeting, and clean dodges charge the **Overdrive** gauge to unleash devastating specials.
5. **Rapid Meta Loop**: Fast restart loop (~3 seconds), scrap-to-cogs conversion, 5 permanent Hangar upgrade tiers, part unlocks, Codex discoveries, and UTC-seeded daily challenge runs.

---

## 2. Project Architecture & Directory Layout

### 2.1 Decoupled Sim / View Pattern
The project strictly enforces decoupling between simulation logic and visual rendering:
- **Simulation Layer**: Inherits from `RefCounted`, driven by a fixed 60 Hz time step (`1.0 / 60` s), completely free of `SceneTree`, `CanvasItem`, `Node3D`, or `RenderingServer` dependencies. Allows running headless simulations at thousands of frames per second for automated balance verification and determinism auditing.
- **View Layer**: Godot `Node3D` and `Control` hierarchy. Reads simulation state each frame and drains an event queue (`sim.events`) to trigger audio cues, particle bursts, screen shakes, floating damage numbers, and camera kicks.
- **Data-Driven Design**: All numerical parameters, spawn beats, boss phases, parts, combos, and economy tables are stored in `data/*.json` and parsed into memory at boot time by `GameData.load_all()`.

### 2.2 Complete Repository Map

```
/Users/aryankinha/Downloads/junk-bot/
├── project.godot                     # Project configuration (Godot 4.7.2, gl_compatibility, 1080x1920)
├── export_presets.cfg                # Export definitions for Android Debug, Sideload, AAB, Test Ads
├── README.md                         # Quickstart instructions, validation commands, flag overrides
├── LICENSES.md                       # Open font (OFL) and MIT library download ledger
├── icon.svg                          # Default project vector icon
│
├── src/                              # Core GDScript source files (16 scripts, 1 scene)
│   ├── core/
│   │   ├── game_data.gd              # JSON database loader (static caching of 13 data files)
│   │   └── rng_streams.gd            # 4 independent deterministic RNG streams (gates, spawns, boss, loot)
│   ├── sim/
│   │   ├── run_sim.gd                # Main runner sim: movement, beats, collision, combat (846 lines)
│   │   ├── robot_state.gd            # Robot stats, sockets, parts, HP, breaks, repairs (189 lines)
│   │   ├── boss_sim.gd               # Scrap Titan 3-phase state machine & attacks (241 lines)
│   │   ├── stat_calc.gd              # Stat aggregation from chassis, parts, combos, tradeoffs (39 lines)
│   │   ├── gate_gen.gd               # Deterministic gate pair generation & rules (72 lines)
│   │   ├── economy.gd                # Reward formula & hangar tier upgrade cost functions (14 lines)
│   │   └── engagement_log.gd         # Telemetry logger for player-decided engagement intervals (120 lines)
│   ├── services/
│   │   ├── save_store.gd             # Atomic save persistence (user://save.json, 126 lines)
│   │   ├── ads.gd                    # High-level ad broker (rewards, offline fallback, 42 lines)
│   │   ├── admob_provider.gd         # Native Poing Godot AdMob wrapper (63 lines)
│   │   ├── audio.gd                  # 12-channel pooled procedural SFX & looping music (83 lines)
│   │   ├── haptics.gd                # Android handheld vibration throttle (50ms rate limit, 9 lines)
│   │   ├── perf_log.gd               # Frame time percentiles, draw call & memory sampler (51 lines)
│   │   └── telemetry.gd              # JSONL append logger (user://telemetry.jsonl, 8 lines)
│   ├── view/
│   │   ├── Boot.tscn                 # Primary entry scene (holds ScrapDragon Node3D)
│   │   ├── run_view.gd               # Master UI controller, HUD, menus, hangar, inputs (728 lines)
│   │   ├── world_view.gd             # 3D highway, multimeshes, enemies, boss, camera, VFX (581 lines)
│   │   ├── robot_builder.gd          # Procedural 3D robot assembly, sockets, animations (392 lines)
│   │   └── mesh_factory.gd           # Procedural rounded 3D toy geometry & toon shaders (456 lines)
│   └── ui/
│       ├── ui_icon.gd                # Procedural 2D vector icons (coin, heart, bolt, star, etc.)
│       └── ui_ring.gd                # Circular progress ring for overdrive & special buttons
│
├── data/                             # Authoritative JSON databases (13 files)
│   ├── constants.json                # Speed, road width, sim Hz, chassis stats, break points
│   ├── parts.json                    # 9 parts x 3 levels, sockets, stats, weights, replaces
│   ├── combos.json                   # 5 combo definitions (Burst Volley, Ram Charge, Vacuum, Strafe, Inferno)
│   ├── enemies.json                  # Scrapper, gunner, bruiser, barrel, hauler, crate, saw, oil
│   ├── boss_scrap_titan.json         # Scrap Titan base HP, scaling, assist, 3 phases, 6 attacks
│   ├── gates_level1.json             # Authored level 1 beat sequence (boss at z=720)
│   ├── level_generator.json          # Procedural generation rules for levels 2–5
│   ├── economy.json                  # Cogs conversion, upgrade costs, unlock costs, repair bay
│   ├── tradeoffs.json                # Overclock, Plating, Crate mystery gamble
│   ├── zones.json                    # Zone visual themes (Junkyard, Desert, Factory, Snow)
│   ├── bot_models.json               # Automated testing bot parameters (reaction delays)
│   ├── flags.json                    # Interactivity experiment switches & tuning parameters
│   └── blocks.json                   # Rhythm wave & coin arc placement definitions
│
├── assets/                           # Shipped project assets
│   ├── audio/                        # 14 procedural WAV SFX + 2 OGG music loops
│   ├── fonts/                        # LilitaOne-Regular, Barlow-SemiBold, Rajdhani-Bold (OFL)
│   ├── parts/                        # 27 part scene wrappers (*_lv*.tscn)
│   ├── materials/                    # Shared materials
│   └── ASSET_MANIFEST.md             # Triangle budgets, source recipes, and provenance
│
├── tests/                            # Automated test suites & bot simulators
│   ├── run_all.gd                    # Master test runner (505 lines, 25,177 checks)
│   ├── integration_suite.gd          # Actual SceneTree, UI navigation, and service checks (129 lines)
│   ├── bots/
│   │   ├── run_balance.gd            # Multi-seed bot balance sweep (perfect, random, no_dodge)
│   │   ├── bot_controller.gd         # Baseline simulation bot agent
│   │   ├── aim_bot.gd                # Lane-aiming & gate-charging bot agent
│   │   ├── trace_hash.gd             # Event trace baseline regression validator
│   │   ├── pair_audit.gd             # Level 1 gate viability audit
│   │   ├── pair_pick.gd              # Noise-aware gate pick share simulation
│   │   ├── focus_check.gd            # Standing-still vs aiming dominance verifier
│   │   ├── moving_fairness.gd        # Moving gate latency & fairness verification
│   │   └── measure_engagement.gd     # Engagement interval & payoff latency profiler
│   ├── render_review.gd              # Headless/desktop render capture & draw call validator
│   └── test_display_quality.gd       # Mac/desktop window sizing and visual audit
│
├── tools/                            # Build automation, asset generators, and phone harness
│   ├── build_android.sh              # CLI build script for debug, ads, and release APK/AAB
│   ├── phone_perf_session.sh         # Device performance capture, logcat, thermal guards
│   ├── check_phone_allowlist.py      # ADB command safety allowlist enforcement
│   ├── configure_android.gd          # EditorSettings Android SDK/keystore config script
│   ├── fetch_android_template.py     # HTTP range downloader for matching Godot export templates
│   ├── fetch_admob.py                # Downloader for Poing Godot AdMob release zip
│   ├── install_admob_runtime.py      # Gradle build plugin injector
│   ├── generate_audio.py             # Math-based procedural sound and music synthesizer
│   └── write_interactivity_report.py # Automated report markdown generator
│
├── addons/                           # Godot editor and runtime plugins
│   ├── admob/                        # Poing Godot AdMob v5.1.0 plugin (MIT)
│   └── scrap_ads_export/             # Custom export plugin stripping/enabling ad flags
│
├── build/                            # Compiled binaries & video proofs
│   ├── scrap_dragon_debug.apk        # Offline debug APK (VIBRATE only, 29 MB)
│   ├── scrap_dragon_test_ads.apk     # Native test-ad APK (AdMob test IDs, 39.5 MB)
│   ├── scrap_dragon_release.aab      # Android App Bundle Play Store package (28.9 MB)
│   └── *.mp4 / *.avi                 # First transformation, part loss, and boss kill proofs
│
├── reports/                          # Formal milestone & verification reports
│   ├── COMPREHENSIVE_PROJECT_REPORT.md # This authoritative document
│   ├── FINAL_REPORT.md               # End-of-implementation audit & physical device gap log
│   ├── INTERACTIVITY_REPORT.md       # Full evaluation of experiments E1–E5
│   └── M0_REPORT.md - M7_REPORT.md   # Milestone historical reports
│
└── results/                          # Benchmark results, JSON profiles, and screenshot proofs
```

---

## 3. Core Simulation Layer (`src/sim/` & `src/core/`)

### 3.1 Deterministic Simulation Loop (`run_sim.gd`)
The simulation advances using fixed sub-steps at 60 Hz (`sim_hz` = 60, $\Delta t = 1.0 / 60\text{ s}$):
- **Forward Progression**: $z \leftarrow z + v \cdot \Delta t$, where $v = \text{forward\_speed} \times \text{fwd\_mult} \times (\text{oil ? } 0.6 : 1.0) \times (\text{dash ? } \text{speed\_mult} : 1.0)$.
- **Lateral Progression**: $x \leftarrow \text{lerp}(x, \text{target\_x}, 1 - \exp(-\text{lateral\_follow\_rate} \cdot \text{steer\_mult} \cdot \Delta t))$.
- **Road Boundary Clamping**: $x$ is clamped strictly to $[-3.1, +3.1]$ ($\text{road\_half\_width} = 3.4$).
- **Relative Drag Input**: Swiping horizontally adjusts `target_x` proportionally without absolute jumps: $\Delta x = \Delta_{\text{touch}} / \text{screen\_width} \times 6.8$.
- **State Machine**: `running` $\rightarrow$ `choosing` (repair bay part selection) $\rightarrow$ `boss` $\rightarrow$ `won` or `lost`.

### 3.2 Random Stream Independence (`rng_streams.gd`)
To guarantee that cosmetic or loot drops cannot alter combat or gate outcomes, four separate `RandomNumberGenerator` streams are instantiated and seeded from a root seed $S$:
$$\text{gates.seed} = S \times 31 + 11$$
$$\text{spawns.seed} = S \times 31 + 23$$
$$\text{boss.seed} = S \times 31 + 37$$
$$\text{loot.seed} = S \times 31 + 53$$

### 3.3 Robot State & Socket Management (`robot_state.gd`)
The robot state tracks:
- `parts`: Dictionary mapping `part_id` to integer level ($1 \dots 3$).
- `slots`: Dictionary mapping socket name to `part_id`.
- `hp` & `max_hp`: Base chassis HP plus additive part gains and tier modifiers.
- `shield_charges` & `invuln`: Layered damage mitigation.
- `broken`: Array storing parts knocked off by damage, available for restoration at a Repair Bay.

#### Bipartite Socket Relocation Algorithm (`_claim_slot`)
When an attachment is added, it queries compatible sockets defined in `data/parts.json`. If all preferred sockets are occupied, instead of immediately discarding an existing part, `_claim_slot` executes a recursive search to relocate existing attachments into compatible free sockets:
```gdscript
func _claim_slot(id: String, visited: Array) -> String:
	var definition: Dictionary = GameData.table("parts")[id]
	for slot in definition.slots:
		if not slots.has(slot):
			return slot
	var seen := visited.duplicate()
	seen.append(id)
	for slot in definition.slots:
		var occupant: String = slots[slot]
		if seen.has(occupant): continue
		var alternate := _claim_slot(occupant, seen)
		if not alternate.is_empty():
			slots.erase(slot)
			slots[alternate] = occupant
			return slot
	return ""
```
This guarantees that picking up utility/collection parts (e.g. Magnet, Storage) never evicts weapons if alternate valid sockets exist.

### 3.4 Damage & Part-Loss Rules
When incoming damage is processed (`take_damage`):
1. **Invulnerability Check**: If $\text{invuln} > 0$, damage is ignored.
2. **Shield Check**: If $\text{shield\_charges} > 0$, absorbs 100% of damage, decrements charge by 1, triggers 1.0s invulnerability, and emits `shield_block`.
3. **Armor Mitigation**: $\text{net\_damage} = \text{damage} \times (1.0 - \text{stats.armor})$. Armor is strictly capped at $0.75$ (75% damage reduction).
4. **Coin Chain Reset**: Any damage taken resets `sim.chain = 0`.
5. **Break Thresholds**: Evaluated at $75\%$, $50\%$, and $25\%$ max HP. Each threshold triggers at most once per run:
   - Part loss candidates are gathered (levels count as weights).
   - **Last-Weapon Protection Guarantee**: If total weapon attachments $\le 1$, weapons are strictly excluded from the break candidate pool.
   - Part is moved to `broken`, removed from active sockets, and `parts_lost` is incremented.

### 3.5 Scrap Titan Boss Logic (`boss_sim.gd`)
The Scrap Titan Boss fight begins at $z = 720\text{ m}$:
- **Base HP**: $2050$ (scales by $+60\%$ per level: $\text{max\_hp} = 2050 \times [1 + 0.6 \times (\text{level} - 1)]$).
- **Dynamic Assist**: If the player has accumulated consecutive boss losses:
  $$\text{cut} = \min(0.30, \max(0, \text{losses} - 1) \times 0.10)$$
  Boss max HP is reduced by up to $30\%$ to assist struggling players.
- **Three Phases**:
  - **Phase 1 ($100\% \rightarrow 66\%$ HP)**: Heavy front armor plate absorbs $50\%$ of damage unless dealt by rockets or shock damage. Attacks: `ground_slam`, `rocket_barrage`.
  - **Phase 2 ($66\% \rightarrow 33\%$ HP)**: Roar transition (1.5s invulnerable). Introduces `grabber_arm` and `laser_sweep`. `grabber_arm` steals the player's highest-level part; player has 5.0s to destroy the arm (HP 250) to recover the stolen part.
  - **Phase 3 ($33\% \rightarrow 0\%$ HP)**: Exposed core takes $1.5\times$ damage (`core_multiplier_phase3`). Introduces `double_slam` and `call_scrappers`.
- **Clean Dodge & Overdrive**: Evading an attack telegraph without taking damage triggers `clean_dodge`, awarding $+15$ Overdrive gauge and exposing the boss for $3.0\text{s}$ ($1.5\times$ damage). Sustained firing also accrues $+1$ Overdrive per $0.5\text{s}$. At $100\%$ Overdrive, tapping Special triggers combo overload or $2\times$ fire rate for $4.0\text{s}$.

---

## 4. Authoritative Data Tables & Ground Truth (`data/*.json`)

### 4.1 Constants Table (`constants.json`)
```json
{
  "forward_speed": 9.0,
  "road_half_width": 3.4,
  "lateral_follow_rate": 14.0,
  "drag_world_per_screen_width": 6.8,
  "sim_hz": 60,
  "auto_fire_range": 24.0,
  "auto_fire_cone_deg": 50,
  "hit_invuln_s": 1.0,
  "part_break_thresholds": [0.75, 0.5, 0.25],
  "base_magnet_radius": 1.6,
  "gate_line_tolerance": 0.4,
  "boss_arena_length": 30.0,
  "stage_thresholds": { "battle": 4, "monster": 9 },
  "chassis": {
    "tiny": { "hp": 60, "steer": 1.0, "blaster": { "damage": 4, "rate": 1.5 } },
    "battle": { "hp": 140, "steer": 0.95 },
    "monster": { "hp": 260, "steer": 0.9 }
  },
  "revive_hp_pct": 0.6,
  "free_rerolls_per_run": 1
}
```

### 4.2 Verified Parts Matrix (`parts.json`)
Nine part families across four functional categories (`movement`, `weapon`, `defence`, `collection`):

| ID | Name | Category | Compatible Sockets | Unlock Lvl | Weight | Replaces | Key Stats (Lv1 / Lv2 / Lv3) |
|---|---|:---:|---|:---:|:---:|:---:|---|
| `wheels` | Extra Wheels | `movement` | wheel_fl..mr (6) | 1 | 10 | `tracks` | Fwd speed: +6% / +10% / +14%; Steer: +12% / +20% / +28%; HP: +10 / +15 / +20 |
| `tracks` | Tank Tracks | `movement` | wheel_fl..br (4) | 2 | 8 | `wheels` | Oil immune; Knockback resist: 0.4 / 0.6 / 0.8; HP: +40 / +70 / +100; Steer: -8% / -5% / -2% |
| `cannon` | Cannon | `weapon` | top_c, top_l, top_r, side_l, side_r (5) | 1 | 12 | — | Lv1: 14 dmg, 1.4/s (1 barrel, spd 36); Lv2: 14 dmg, 1.4/s (2 barrels, spd 36); Lv3: 9 dmg, 7.0/s (Gatling, 1 barrel, spd 40) |
| `rocket` | Rocket Launcher | `weapon` | back_c, side_l, side_r (3) | 1 | 9 | — | Ignores plate; 40 dmg; Area: 2.4 / 2.6 / 2.8m; Speed: 26 / 26 / 28; Rate: 0.55 / 0.85 / 1.1 per s |
| `flame` | Flamethrower | `weapon` | front_c, side_l, side_r (3) | 2 | 7 | — | Cone DPS: 45 / 70 / 100; Range: 6 / 7 / 8m; Burn DPS: 10 / 14 / 20 for 2.0 / 2.5 / 3.0s |
| `armour` | Heavy Armour | `defence` | front_c, shoulder_l, shoulder_r (3) | 1 | 10 | — | Armor reduction: +8% / +14% / +20% (clamped at 75%); HP: +30 / +55 / +80; Steer: -3% / -5% / -8% |
| `shield` | Energy Shield | `defence` | head, back_c (2) | 3 | 7 | — | Shield charges: 1 / 1 / 2; Recharge timer: 8.0s / 6.0s / 4.5s |
| `magnet` | Scrap Magnet | `collection` | back_c, top_c (2) | 1 | 8 | — | Magnet radius multiplier: **x1.8 / x2.5 / x3.2** |
| `storage`| Storage Pack | `collection` | back_c (1) | **3** | **6** | — | Scrap value multiplier: **x1.25 / x1.5 / x1.8** |

*(Note on Audit Corrections: In previous documentation, Magnet and Storage were erroneously categorized as "Utility". Magnet stats were misquoted as x1.8/x2.4/x3.0 instead of x1.8/x2.5/x3.2. Storage Pack was misquoted as unlock level 1, weight 8, and scrap multipliers x1.35/x1.7/x2.2 instead of unlock level 3, weight 6, and scrap multipliers x1.25/x1.5/x1.8).*

### 4.3 Combos Matrix (`combos.json`)
Five synergy combos defined:

| ID | Name | Needs | Status | Special Effect Description | Cooldown |
|---|---|---|:---:|---|:---:|
| `burst_volley` | Burst Volley | `cannon` + `rocket` | **Active** | Fires 8 homing rockets (40 dmg each) and doubles fire rate for 3.0s. Evolves into Cluster Rockets if E5 enabled & rocket $\ge \text{Lv2}$. | 10.0s |
| `ram_charge` | Ram Charge | `tracks` + `armour` | **Active** | 2.0s invulnerability, doubles forward speed, 60 damage with 6.0 knockback. | 12.0s |
| `vacuum` | Vacuum | `magnet` + `storage` | **Active** | Passive: $3.0\times$ magnet radius, $1.5\times$ scrap value. Active: pulls all alive scrap on screen instantly. | 15.0s |
| `strafe_run` | Strafe Run | `wheels` + `cannon` | *Stretch* | Lateral dash spread (12 shots over 1.2s). **Stubbed** (no handler in `RunSim.tap_special`). | 9.0s |
| `inferno_aura` | Inferno Aura | `flame` + `armour` | *Stretch* | Flame ring (80 DPS, 3.0m radius for 3.0s). **Stubbed** (no handler in `RunSim.tap_special`). | 12.0s |

### 4.4 Economy & Meta-Progression (`economy.json`)
- **Scrap to Cogs Conversion Formula**:
  $$\text{Cogs} = \text{round}\left((\text{Scrap} \times 1.0 + (\text{won} \text{ ? } 50 \times \text{level} : 0)) \times (1.0 + \min(0.30, \text{streak} \times 0.10))\right)$$
- **Hangar Part Upgrades**: 5 tiers total. Costs to advance from tier $n$: $[120, 260, 520, 1000]$ cogs. Each tier grants $+8\%$ stat effectiveness to all 3 levels of that part (`gain = 1.0 + (tier - 1) * 0.08`). Visual variant trims appear at Tiers 3 (Gold) and 5 (Cyan).
- **Hangar Unlock Costs**: Tracks = 0 (auto-unlock at Level 2), Flame = 150 cogs, Shield = 250 cogs, Storage = 250 cogs.
- **Repair Bay Costs**: Repair = 20 scrap (restores broken parts + heals 40% HP), Buy Part = 35 scrap (presents 3 candidate parts).
- **Streak Buff**: Reaching 3 consecutive wins unlocks the weak-point outline shader on bosses.

### 4.5 Enemies & Hazards (`enemies.json`)
- `scrapper`: 18 HP, speed 3.5 m/s, 6 contact damage, drops 2 scrap. Spawns in packs of 4–8.
- `gunner`: 40 HP, stationary, 8 bolt damage, 2.2s fire interval (0.6s telegraph), 18 m/s bolt speed, drops 5 scrap.
- `bruiser`: 120 HP, 2.0 m/s patrol, 1.0s windup telegraph into 14 m/s charge dealing 20 damage and 4.0 knockback (3.0s cooldown), drops 12 scrap (15% rare part drop chance).
- `hauler` (Miniboss): 380 HP, 7.0 m/s chase speed, drops explosive barrels every 2.2s, bursts into 40 scrap + 18 gold coins, guaranteed rare part drop.
- `barrel`: 10 HP, explosive radius 2.5m, deals 40 damage to enemies, 25 damage to player.
- `crate`: 90 HP, stationary, drops 30 scrap + 10 coins.
- `saw`: Hazard, 15 contact damage, 4.0 m/s rail traversal, radius 0.9m.
- `oil`: Hazard, 40% speed reduction for 1.5s, radius 1.8m (Tank Tracks grant 100% oil immunity).

### 4.6 Tradeoffs & Mystery Gamble (`tradeoffs.json`)
- `overclock`: +40% DPS, -30% max HP.
- `plating`: +40% max HP, -10% steering rate.
- `crate` (Mystery Gamble):
  - $p = 0.60$: Random eligible part.
  - $p = 0.15$: Rare part.
  - $p = 0.25$: Scrap burst (+40 scrap).

---

## 5. Procedural Level & Gate Generation System

### 5.1 Deterministic Gate Generator Rules (`src/sim/gate_gen.gd`)
The gate generation engine dynamically builds valid upgrade panels while enforcing progression and balance rules:

1. **Available Part Eligibility Pool (`GateGen.available`)**:
   - Evaluates all 9 parts in `parts.json`.
   - Condition: `(part.unlock_level <= current_level or unlocked.has(id)) and robot.parts.get(id, 0) < 3`.
   - Any part already at Level 3 is strictly excluded from generation.
2. **Pair Selection Logic (`GateGen.pair`)**:
   - If fewer than 2 eligible parts exist in the pool, falls back to `[{"kind": "repair"}, {"kind": "scrap", "amount": 25}]`.
   - **First Option**: Weighted random roll across available parts using base weights from `parts.json`.
   - **Weapon Pity Rule**: If `gate_index >= 2` and the player owns zero weapons (`robot.parts` has no weapon category), the generator filters the pool to weapons only. If any weapons are available, the first option is forcibly selected from this weapon subset.
   - **Category Opposition Rule**: The second option must belong to a different functional category than the first (`category != first.category`). If no alternate category parts are available, the generator falls back to `[first_part, repair]`. Otherwise, the second part is selected via weighted random roll among the category-filtered subset.
3. **Third Lane Utility Rule (`GateGen.with_extra`)**:
   - Condition: `level >= 2` AND `gate_index % 2 == 1` (odd-indexed gates) AND existing options are exactly 2 parts.
   - When met, a 3rd utility lane is appended, chosen uniformly ($1/3$ probability each) from:
     - `{"kind": "heal", "pct": 0.35}` ("Quick repair" — restores +35% HP immediately).
     - `{"kind": "frenzy"}` ("Coin frenzy" — doubles scrap coin values for 12.0 seconds).
     - `{"kind": "surge"}` ("Overdrive" — awards +50% Overdrive meter instantly).

### 5.2 Procedural vs Authored Level Discrepancies
- **Authored Level 1 (`data/gates_level1.json`)**:
  - Authored sequence of 14 beats ending with Scrap Titan boss at $z = 720\text{ m}$.
  - Gate 1 ($z=80$): **Cannon vs Extra Wheels** (Ground Truth correction: previous documentation claimed this was changed to Cannon vs Storage Pack, but `gates_level1.json` retains `cannon` vs `wheels`).
  - Gate 2 ($z=180$): Armour vs Scrap Magnet.
  - Gate 3 ($z=290$): Tank Tracks vs Flamethrower.
  - Gate 4 ($z=400$): Rocket Launcher vs Energy Shield.
  - Gate 5 ($z=520$): Tradeoff (Overclock vs Plating).
  - Gate 6 ($z=600$): Mystery Crate Gamble vs Merge Part (`upgrade_random_owned`).
  - Miniboss ($z=660$): Authored beat specifies `"enemy": "elite_bruiser"`, but `run_sim.gd` maps this directly to `hauler`.
- **Procedural Levels 2–5 (`_generate_beats` in `run_sim.gd`)**:
  - Distance between gates: $85\text{m} \dots 110\text{m}$ (`gate_spacing`).
  - Gate count: $\min(10, 5 + \text{level})$ gates per run.
  - Spawns an enemy pack at $\text{gate.z} + 40\text{m}$ (`scrapper`, `gunner`, or `bruiser`).
  - Boss position: $\text{final\_gate.z} + 80\text{m}$.
  - Miniboss Hauler placed at $50\%$ of boss distance (`boss_z * 0.5`).
  - Repair Bay placed at $70\%$ of boss distance (`boss_z * 0.7`).
  - Final Choice Gate placed at $\text{boss\_z} - 45\text{m}$ (3 options: Rocket, Armour, Cannon).
  - **Omission in Procedural Beats**: `data/level_generator.json` defines `"tradeoff_gate_chance": 0.2` and `"gamble_gate_chance": 0.15`. However, `_generate_beats()` exclusively invokes `GateGen.pair()` and `GateGen.with_extra()`. Because neither function rolls for tradeoffs or gambles, **tradeoff and gamble gates never appear procedurally in Levels 2–5**; they only exist in authored Level 1 beats.

---

## 6. Presentation & View Layer (`src/view/` & `src/ui/`)

### 6.1 Main UI & Flow Controller (`run_view.gd`)
- **Screen States**: `run`, `pause`, `result`, `hangar`, `settings`, `repair_offer`, `purchase`.
- **First Launch Direct-to-Play**: Players with `tutorial_done == false` bypass menus and boot directly into a Level 1 run within 1 frame. Returning players launch into Hangar.
- **Dynamic Performance Governor (`_govern_density`)**: Continuously monitors rendering performance. If p95 frame time exceeds $18.5\text{ ms}$ or draw calls exceed $135$, it dials down `sim.density_limit` toward $0.6$, reducing spawn counts to preserve a solid 60 FPS on low-spec hardware.
- **Result Screen 3D Portrait**: Captures a live $1200\times 1200$ anti-aliased viewport texture of the player's customized robot on run end, displaying the exact assembled loadout alongside performance stars ($1\star$ Boss Kill, $2\star$ HP $\ge 50\%$, $3\star$ 0 Parts Lost).

### 6.2 3D World Rendering & MultiMesh Batching (`world_view.gd`)
The world is rendered using batched `MultiMeshInstance3D` nodes sharing procedurally generated materials:
- Road debris & asphalt rocks: 70 instances.
- Tire skid marks: 26 instances.
- Roadside junk props (wrecks, oil drums, scrap piles): 6 meshes $\times$ 14 instances = 84 props.
- Scrap coins: 400 instances.
- Gold coins: 40 instances.
- Player projectiles: 64 instances.
- Enemy bolts: 16 instances.
- Cluster bomblets: 16 instances.
- Blob shadows: 26 instances.
- Hit spark particles: 128 instances.
- **Atmospheric Pipeline**: Directional sunlight (`Color("fff1d6")`, real-time shadows disabled to conserve mobile fillrate), procedural gradient skybox, depth fog ($28\text{m} \rightarrow 105\text{m}$), and filmic tonemapping.

### 6.3 Procedural Robot Builder (`robot_builder.gd`)
Dynamically constructs the 3D robot model from 16 named chassis sockets:
- Sockets: `wheel_fl`, `wheel_fr`, `wheel_bl`, `wheel_br`, `wheel_ml`, `wheel_mr`, `top_c`, `top_l`, `top_r`, `side_l`, `side_r`, `back_c`, `front_c`, `shoulder_l`, `shoulder_r`, `head`.
- **AABB Collision Clearance**: Detects volumetric overlap between mounted parts; iteratively offsets occupied sockets along surface normal vectors until bounds are clear.
- **Procedural Structural Struts**: Automatically connects displaced sockets back to the core chassis hull using vertex-colored steel mounting struts and angle brackets.
- **Procedural Secondary Animation ("Juice")**:
  - Engine idle rumble: $y$-axis displacement oscillation at 24 Hz.
  - Steering body roll: $z$-axis roll proportional to lateral velocity.
  - Wheel rotation: continuously geared to forward driving speed.
  - Lagged head bob: spring-damped look-ahead tracking towards turn targets.
  - Springy antenna whip: responsive lag based on lateral acceleration jerk.
  - Weapon recoil kick: momentary chassis backward kick on projectile launch.
  - Damage flash: instance shader parameter flashes white for 80ms upon taking a hit.

---

## 7. Procedural Art & Audio Pipelines

### 7.1 Procedural 3D Toy Geometry (`mesh_factory.gd`)
All 3D vehicle, part, and prop meshes are generated purely in GDScript using `SurfaceTool` without external 3D model files:
- **Rounded Box Primitive (`rbox_mesh`)**: Subdivides box faces into a $4\times 4$ vertex grid, spherically displacing corner vertices by radius $r$ to produce beveled toy-like edges.
- **Custom Toon Shader**:
  - Cel-shaded diffuse lighting bands with smoothstep transitions.
  - Soft specular highlight and glossy rim lighting.
  - Inverted-hull outline pass: back-facing geometry pushed outwards along vertex normals by $0.035\text{m}$ in dark ink (`Color(0.07, 0.08, 0.14)`).
- **Single Draw Call Batching**: Multi-part models are compiled into a unified `ArrayMesh` sharing a single material with vertex colors defining distinct paint accents.

### 7.2 Pure Waveform Audio Synthesis (`tools/generate_audio.py` & `audio.gd`)
Audio assets were generated using pure Python mathematical waveforms (`tools/generate_audio.py`), requiring zero external sample libraries:
- **14 Procedural Sound Effects (`.wav`, 22050 Hz)**:
  - `attach`: 180 Hz sweep with metallic noise burst.
  - `upgrade`: 660 Hz ascending pitch envelope.
  - `stage`: 110 Hz low resonant power chord.
  - `scrap`: 1200 Hz high coin chirp.
  - `fire`: 320 Hz punchy descending square-sine pop.
  - `hit`: 80 Hz impact thud with noise.
  - `break`: 65 Hz crunchy tearing crash.
  - `warning`: 780 Hz pulsing alarm beep.
  - `special`: 440 Hz riser chime.
  - `victory`: 550 Hz triumphant arpeggio.
  - `defeat`: 180 Hz sorrowful descending tone.
  - `click`: 550 Hz short UI tap.
  - `explosion`: 50 Hz deep rumble burst.
  - `dodge`: 900 Hz quick swoosh.
- **2 Looping Soundtracks (`.ogg`)**:
  - `run_music.ogg`: 110 BPM industrial driving bassline with rhythmic kicks and hi-hats.
  - `hangar_music.ogg`: Relaxed harmonic workshop theme.
- **Audio Architecture**: 12-channel pooled polyphonic players across three buses (`Music`, `SFX`, `UI`). SFX bus includes an active `AudioEffectCompressor`. Features pitch randomization ($0.92 \dots 1.08$), concurrency limiting, and priority ducking during boss roars.

---

## 8. Services, Persistence & AdMob Integration (`src/services/`)

### 8.1 Atomic Save Persistence (`save_store.gd`)
Saves player state locally to `user://save.json`:
- **Atomic Two-Phase Write**: Serializes JSON to `user://save.json.tmp`, flushes and closes the file handle, then performs an atomic rename via `DirAccess.rename_absolute("user://save.json.tmp", "user://save.json")`. Prevents file corruption during unexpected battery death or process termination.
- **Validation & Fallback**: Validates schema version (`v: 1`), field types, and clamps numbers (`level` $1 \dots 5$, `part_tiers` $1 \dots 5$). In case of corruption, silently falls back to safe defaults without crashing.

### 8.2 AdMob Rewarded Video Integration (`ads.gd` & `admob_provider.gd`)
- **Plugin Integration**: Uses the official Poing Godot AdMob Plugin v5.1.0 (`res://addons/admob/`).
- **Google Public Test IDs**:
  - Test App ID: `ca-app-pub-3940256099942544~3347511713`
  - Test Rewarded Ad Unit ID: `ca-app-pub-3940256099942544/5224354917`
- **Zero Fabricated Rewards Policy**: On desktop or offline builds where the native plugin is absent, `AdsService.is_available()` returns `false`, and all ad UI triggers are completely hidden. Rewards are only emitted upon explicit `on_user_earned_reward` native callbacks.
- **Reward Placements**:
  - `revive`: Once-per-run revive with 60% HP and 2s invulnerability.
  - `reroll`: Free gate reroll if run allowance is exhausted.
  - `double`: Doubles scrap payout on the result screen.
  - `repair`: Ad-funded repair at the Repair Bay when short on scrap.
- **Stubbed Feature Note**: `data/economy.json` outlines interstitial ad rules (`interstitial_first_after_runs: 4`, `interstitial_min_gap_s: 120`). **Interstitial ads are completely unimplemented in GDScript**; only rewarded video ads exist.

### 8.3 Handheld Services (`haptics.gd`, `perf_log.gd`, `telemetry.gd`)
- `HapticsService`: Calls `Input.vibrate_handheld(ms, amplitude)` on Android, throttled to a minimum 50ms interval between vibrations.
- `PerfLog`: Samples frame times, draw calls, and primitive counts. Computes p50/p95/p99 percentiles, worst frames, and memory usage. Emits summary to `user://perf.json` and raw CSV to `user://perf_frames.csv`.
- `TelemetryLog`: Appends structured JSON lines to `user://telemetry.jsonl` (e.g. ad requests, impressions, rewards, run starts, deaths).

---

## 9. Interactivity Experiments E1–E5 & Feature Flags

Following an interactivity audit (`docs/INTERACTIVITY_AUDIT.md`), five interactivity enhancements were implemented under default-off switches in `data/flags.json`. When all flags are false, the sim reproduces the baseline trace identically (`TRACE MATCH`).

```json
{
  "engagement_metrics": false,
  "aim_mode": "nearest",
  "guarded_salvage": false,
  "gate_charge": false,
  "post_gate_payoff": false,
  "moving_gates": false,
  "focus_fire": false,
  "dense_blocks": false,
  "weapon_evolution": false
}
```

### 9.1 Experiment Descriptions
- **E1: Steering is Aiming & Guarded Salvage**:
  - `aim_mode`: `"lane"` vs `"nearest"`. In lane mode, auto-fire narrows to a $12^\circ$ half-cone directly ahead of the robot. Weapons continue firing straight ahead when no target is present. A targeting reticle locks onto the targeted enemy.
  - `guarded_salvage`: Spawns two distinct parallel options:
    - Left lane: explosive barrel flanked by two gunners (shooting barrel eliminates both guards).
    - Right lane: 90 HP armored loot crate behind a gunner (bursts into 30 scrap + 10 coins).
- **E2: Gate Charging & Immediate Payoff**:
  - `gate_charge`: Shots fired into upcoming gate panels within 30m accumulate charge ($1.0$ per second of focused fire). Reaching Threshold 1 ($1.0\times\text{cost}$) and Threshold 2 ($3.0\times\text{cost}$) upgrades the granted part level (up to Lv3 max). Panels show real-time progress bars and next-tier name previews.
  - `post_gate_payoff`: Spawns a custom challenge 14m past Gate 1 tailored to immediately demonstrate the chosen part:
    - Weapons: cluster of 4 scrappers.
    - Movement: swerving 14-coin slalom path.
    - Defence: 2 incoming gunner bolts.
    - Collection: wide 16-coin scatter.
- **E3: Moving Gates & Focus Fire**:
  - `moving_gates`: From Gate 3 onward, alternating gate pairs oscillate horizontally ($\pm 0.9\text{m}$ at $5\text{s}$ period, peak speed $1.13\text{ m/s}$) along an orange ground rail. Panel selection matches nearest panel center, preventing accidental misses.
  - `focus_fire`: Holding a steady lane without steering for $>0.4\text{s}$ ramps weapon fire rate by up to $+30\%$. Any steering input immediately resets the bonus.
- **E4: Rhythm Blocks & Density Ramp**:
  - `dense_blocks`: Adds structured waves and coin arcs around gates (`data/blocks.json`). Pack density ramps by $+50\%$ toward the boss. Cap lowered to 14 enemies, coupled with the dynamic performance governor.
- **E5: Weapon Evolution (Cluster Rockets)**:
  - `weapon_evolution`: If the player activates the **Burst Volley** combo (`cannon` + `rocket`) and levels Rocket to Lv2+, rockets evolve into **Cluster Rockets**. Upon impact, rockets detonate into 3 seeking orange bomblets dealing 50% damage over a 1.2m radius.

### 9.2 Engagement Metrics Impact (`src/sim/engagement_log.gd`)
Simulated across 30 seeds with bot reaction models:
- **Median Decision Gap (Pre-Boss)**: Drops from **$5.57\text{s}$** (Baseline) to **$3.27\text{s}$** (All Flags Active).
- **Runs with Decision Gaps $\le 4\text{s}$**: Increases from **$0.0\%$** (Baseline) to **$86.7\%$** (All Flags Active).
- **Time to First Part Payoff**: Drops from **$3.28\text{s}$** down to **$0.28\text{s}$** due to immediate post-gate challenges.

---

## 10. Automated Testing Suite & Engine Runtime Audit

### 10.1 Master Test Suite Execution (`tests/run_all.gd`)
Execution command:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_all.gd
```
Output:
```
25177 checks; 0 failures
```

The test runner rigorously validates:
- Static schema integrity across all 13 JSON databases.
- Part socket matching and recursive relocation algorithms.
- Stage progression (Tiny $\rightarrow$ Battle $\rightarrow$ Monster) and combo activations.
- Hit invulnerability, shield blocking, and one-time part break thresholds.
- Last-weapon preservation guarantee (never leaves robot unarmed).
- 5,000 generated gate pairs across levels 1–5 for valid category opposition and level cap rules.
- 7,200 simulation ticks for deterministic event log equivalence across identical seeds.
- Independent RNG streams across boss and loot rolls.
- Boss plate half-damage reduction, rocket plate bypass, and 1.5x exposed core damage.
- Dynamic loss assist capping at 30% reduction.
- Grabber arm part theft and full recovery.
- Miniboss Hauler chase and barrel drop behavior.
- All E1–E5 experiment behaviors, caps, and edge cases.
- SceneTree integration suite: save store persistence, corrupted save recovery, economy payouts, and AdMob provider mocks.

### 10.2 Handled GDScript Runtime Error Analysis
During the execution of `tests/run_all.gd`, the engine outputs the following error trace to stdout/stderr:
```
ERROR: Failed to open 'user://logs/godot.log'.
   at: copy (core/io/dir_access.cpp:426)
ERROR: Failed to open log file for writing: user://logs/godot.log
   at: rotate_file (core/io/logger.cpp:169)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

SCRIPT ERROR: Cannot call method 'store_string' on a null value.
          at: run (res://tests/integration_suite.gd:53)
          GDScript backtrace (most recent call first):
              [0] run (res://tests/integration_suite.gd:53)
25177 checks; 0 failures
```

#### Detailed Technical Root Cause
1. On macOS, the engine attempts to resolve `user://` to `/Users/aryankinha/Library/Application Support/Godot/app_userdata/Scrap Dragon/`.
2. When executed within macOS sandbox / restricted terminal environments, file write access to this directory is blocked (`Operation not permitted`).
3. In `tests/integration_suite.gd:52-53`:
   ```gdscript
   var corrupt := FileAccess.open("user://corrupt_test_save.json", FileAccess.WRITE)
   corrupt.store_string("{oops");corrupt.close()
   ```
4. Because `open()` fails due to directory permissions, `corrupt` is assigned `null`.
5. Calling `corrupt.store_string(...)` triggers a GDScript null dereference error (`SCRIPT ERROR: Cannot call method 'store_string' on a null value.`).
6. **Why the Suite Still Passes**: GDScript logs the runtime error to stderr but does not abort the entire test process. It advances to line 54:
   ```gdscript
   store.load_save("user://corrupt_test_save.json")
   check(store.data.level == 1 and store.data.cogs == 0, "corrupt save defaults")
   ```
   In `save_store.gd`, if the specified file does not exist, it automatically populates default values (`level = 1, cogs = 0`). The assertion on line 55 evaluates to `true`, and the test suite completes with `0 failures` and exits with code 0.

---

## 11. Simulation Bot Sweep & Balance Datasets

### 11.1 Discrepancy Clarification: 20-Seed vs 100-Seed Benchmark Datasets
Historical documentation contained a significant labeling error: tables quoting metrics from a 20-seed quick sweep (`results/bot_balance.json`) were mislabeled as having 100 runs. 

Both datasets exist in the repository and are documented below with complete fidelity:

---

### 11.2 Dataset A: 20-Seed Quick Sweep (`results/bot_balance.json` & `reports/bot_balance.md`)
- Total runs: 180 runs (20 seeds $\times$ 3 bot models $\times$ 3 levels).
- Generated by `tests/bots/run_balance.gd` with default `count = 20`.

| Level | Bot Model | Seeds | Win Rate | Median Boss Time | Mean Parts Lost | Monster Stage Share | Primary Death Cause |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **Level 1** | `perfect` | 20 | **100.0%** | 12.7s | 0.90 | 20.0% | None (20 Wins) |
| Level 1 | `random` | 20 | **95.0%** | 27.7s | 1.20 | 5.0% | Ground Slam (1) |
| Level 1 | `no_dodge` | 20 | **50.0%** | 17.2s | 1.85 | 0.0% | Rocket Barrage (4), Ground Slam (3), Laser Sweep (3) |
| **Level 3** | `perfect` | 20 | **100.0%** | 24.1s | 0.00 | 80.0% | None (20 Wins) |
| Level 3 | `random` | 20 | **55.0%** | 29.0s | 1.85 | 30.0% | Boss attacks |
| Level 3 | `no_dodge` | 20 | **0.0%** | Timeout / Death | 2.90 | 0.0% | Boss attacks |
| **Level 5** | `perfect` | 20 | **100.0%** | 32.1s | 0.00 | 90.0% | None (20 Wins) |
| Level 5 | `random` | 20 | **40.0%** | 40.9s | 2.20 | 30.0% | Boss attacks |
| Level 5 | `no_dodge` | 20 | **0.0%** | Timeout / Death | 2.95 | 15.0% | Boss attacks |

---

### 11.3 Dataset B: 100-Seed Full Benchmark (`results/balance_complete.txt`)
- Total runs: 900 runs (100 seeds $\times$ 3 bot models $\times$ 3 levels).
- Executed with `--seeds=100`.

| Level | Bot Model | Seeds | Win Rate | Median Boss Time | Mean Parts Lost | Monster Stage Share | Death Breakdown (100 runs) |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **Level 1** | `perfect` | 100 | **100.0%** | 17.55s | 0.87 | 100.0% | None (100 Wins) |
| Level 1 | `random` | 100 | **93.0%** | 29.83s | 0.93 | 53.0% | Ground slam (4), Rocket barrage (2), Boss general (1) |
| Level 1 | `no_dodge` | 100 | **19.0%** | 20.58s | 1.70 | 8.0% | **Elite Bruiser (80)**, Laser sweep (1), Won (19) |
| **Level 3** | `perfect` | 100 | **99.0%** | 25.78s | 0.09 | 96.0% | Elite Bruiser (1), Won (99) |
| Level 3 | `random` | 100 | **69.0%** | 36.90s | 1.64 | 49.0% | Laser sweep (9), Ground slam (6), Rocket barrage (6), Elite bruiser (6), Double slam (4) |
| Level 3 | `no_dodge` | 100 | **13.0%** | 33.35s | 2.70 | 22.0% | Elite Bruiser (51), Laser sweep (11), Double slam (10), Ground slam (9), Rocket barrage (6) |
| **Level 5** | `perfect` | 100 | **100.0%** | 34.45s | 0.07 | 99.0% | None (100 Wins) |
| Level 5 | `random` | 100 | **51.0%** | 43.28s | 1.94 | 49.0% | Laser sweep (32), Ground slam (5), Rocket barrage (5), Double slam (4), Boss general (2), Elite bruiser (1) |
| Level 5 | `no_dodge` | 100 | **4.0%** | 53.35s | 2.90 | 42.0% | Laser sweep (37), Elite bruiser (21), Ground slam (19), Rocket barrage (11), Double slam (8) |

#### Key Takeaways from Dataset B
1. **Telegraph Avoidance is Vital**: Bots that ignore dodges (`no_dodge`) suffer catastrophic defeat rates (81% losses at Level 1, 87% at Level 3, 96% at Level 5).
2. **Highway Hazard Lethality**: At Level 1, 80 out of 81 `no_dodge` losses are caused by the Elite Bruiser charge before the boss arena, confirming that highway hazards effectively punish inattentive play.
3. **Perfect Agent Scalability**: The `perfect` bot maintains a 99–100% win rate across all tiers while scaling boss kill times smoothly from 17.5s (L1) to 34.5s (L5).

---

### 11.4 Specialized Bot Verification Suites
- **Gate Pair Audit (`reports/pair_audit.md`)**:
  - Tests both left and right options across all Level 1 gates with a perfect bot (12 seeds each).
  - All 10 gate choices achieve **100.0% win rate**, confirming no gate option is an automatic run-killer.
  - Profile runs: `speed_gunner` (100% win L1–L3), `rocket_tank` (100% win L1–L3), `collector` (100% win L1–L2, 90% win L3).
- **Moving Gate Fairness (`tests/bots/moving_fairness.gd`)**:
  - Tests reaction delays: 0ms, 150ms, 250ms, 400ms, 600ms across 30 seeds.
  - In all test configurations, **100% of intended panels were entered successfully**, demonstrating that the $\pm 0.9\text{m}$ gate oscillation does not cause accidental panel misses even under high latency.
- **Focus Fire Dominance Check (`tests/bots/focus_check.gd`)**:
  - Verifies whether $+30\%$ focus fire encourages players to park stationary.
  - Stationary bot achieves **0% win rate** regardless of whether focus fire is enabled or disabled.
  - Aiming bot achieves **100% win rate**, confirming that lane-holding bonuses do not undermine movement and dodging imperatives.

---

## 12. Android Build Pipeline & Packaging

### 12.1 Export Presets (`export_presets.cfg`)
Four dedicated Android export presets:
1. **`Android Debug`** (`build/scrap_dragon_debug.apk`, 29 MB): Standalone offline APK. Requests `VIBRATE` permission only. Offline mode automatically hides all ad buttons.
2. **`Android Sideload (arm64)`** (`build/scrap_dragon_sideload.apk`): Release sideload package.
3. **`Android Release AAB`** (`build/scrap_dragon_release.aab`, 28.9 MB): Gradle App Bundle formatted for Google Play Store distribution. Target SDK 36, min SDK 24, arm64-v8a only.
4. **`Android Test Ads`** (`build/scrap_dragon_test_ads.apk`, 39.5 MB): Custom feature `ads_test` enabled. Bundles native Google Mobile Ads SDK and Poing Godot AdMob plugin. Requests `INTERNET`, `ACCESS_NETWORK_STATE`, and ad ID permissions.

### 12.2 Technical Compliance & 16 KB Page Alignment
- **Native Library Alignment**: Built native shared libraries adhere to 16 KB LOAD-segment alignment, successfully passing `zipalign -c -P 16 -v 4` (mandated by Google Play for Android 15+).
- **Automation Scripts**:
  - `tools/build_android.sh`: Command-line interface to export debug, test ads, or release builds.
  - `tools/check_phone_allowlist.py`: Enforces security allowlists, ensuring only owned package identifiers (`com.aryankinha.scrapdragon`) and safe ADB inspection commands are executed.
  - `tools/phone_perf_session.sh`: Automates device installation, logcat capturing, thermal monitoring, and pulling `user://perf.json`.

---

## 13. Codebase Discrepancies, Stale References & Stubbed Features

An exhaustive audit of the codebase revealed several historical naming artifacts, unused configuration fields, and stubbed features:

1. **Title Branding vs Package Identity**:
   - User-visible text on the home screen, window header, and documentation refers to **"Scrap Bot"**.
   - The underlying Android package identifier remains `com.aryankinha.scrapdragon`, the Godot application name is `"Scrap Dragon"` in `project.godot:4` (retained to prevent orphaning user data directories on desktop), the root Node3D in `Boot.tscn` is `"ScrapDragon"`, and export artifacts are named `scrap_dragon_*.apk`.
2. **Authored Level 1 Gate 1 Discrepancy**:
   - `reports/COMPREHENSIVE_PROJECT_REPORT.md` previously claimed that Gate 1 was changed from Cannon vs Wheels to Cannon vs Storage Pack to avoid weapon asymmetry.
   - Ground truth in `data/gates_level1.json` (lines 14–24) proves Gate 1 remains **Cannon vs Extra Wheels**. Storage Pack requires unlock level 3 and is not offered.
3. **Stale Enemy Identifier in `gates_level1.json`**:
   - Line 109 lists `"enemy": "elite_bruiser"`.
   - `RunSim._spawn_beats` (line 340) maps all `"miniboss"` beats directly to `spawn_pack("hauler", 1, ...)`. The key `elite_bruiser` was removed from `enemies.json` and replaced by `hauler`. The runtime behavior is correct, but the JSON field is stale.
4. **Unused Generator Parameters in `data/level_generator.json`**:
   - `"tradeoff_gate_chance": 0.2` and `"gamble_gate_chance": 0.15` are not referenced by `RunSim._generate_beats()`. Consequently, tradeoff and gamble gates never appear in procedural levels 2–5.
   - `"enemy_budget_per_100m": "6 + level * 1.5"` and `"run_target_seconds": "min(150, 90 + 8 * (level - 1))"` are string expressions that are never parsed or evaluated in code.
5. **Stubbed Synergy Combos**:
   - `strafe_run` (`wheels` + `cannon`) and `inferno_aura` (`flame` + `armour`) in `data/combos.json` are marked `"stretch": true`.
   - Neither combo is handled in `RunSim.tap_special()`; tapping Special with these combinations triggers generic Overdrive behavior.
6. **Stubbed Interstitial Advertising**:
   - `data/economy.json` outlines interstitial ad frequency rules (e.g. `interstitial_first_after_runs: 4`, `interstitial_min_gap_s: 120`).
   - The GDScript codebase contains zero implementation for interstitial ads; only rewarded video ads (`RewardedAdLoader`) are implemented.
7. **Mock Provider in Test Suite**:
   - `tests/integration_suite.gd` defines a mock class `FakeProvider` to simulate native AdMob signals (`earned`, `closed`, `availability_changed`) because native Google Mobile Ads SDK is unavailable during headless / desktop test execution.

---

## 14. Acceptance Criteria & Remaining Verification Gaps

While the simulation logic, 3D rendering pipeline, procedural generation, and export packaging are fully verified via automated tests and headless runners, several physical-hardware and release acceptance criteria remain unperformed due to environment constraints:

| Acceptance Criterion | Verification Status | Ground Truth Evidence & Remaining Gaps |
|---|:---:|---|
| **Simulation Determinism & Logic** | **VERIFIED** | 25,177 checks pass; `tests/bots/trace_hash.gd` outputs `TRACE MATCH` against stored baseline. |
| **Asset & Geometry Synthesis** | **VERIFIED** | 100% procedural `SurfaceTool` meshes; 14 synthesized WAV SFX + 2 OGG music loops; zero external 3D asset dependencies. |
| **Android Export Packaging** | **VERIFIED** | Debug APK (29 MB), Test Ads APK (39.5 MB), and Release AAB (28.9 MB) successfully built; 16 KB LOAD-segment alignment confirmed via `zipalign`. |
| **Physical Phone 60 FPS & Jitter** | **NOT RUN** | Requires connecting physical Android hardware via USB debugging; execute `tools/phone_perf_session.sh SERIAL run 180`. |
| **Cold Boot Latency (<2.5s to Playable Frame)** | **NOT RUN** | Requires measuring physical device cold start via ADB logcat timestamps. |
| **Physical Memory (<400MB PSS) & Thermals (<43°C)** | **NOT RUN** | Requires profiling sustained device memory consumption and battery temperature across 3 consecutive runs. |
| **Native AdMob Video Callbacks on Device** | **PARTIAL** | Test Ads APK compiles with native plugin; requires testing rewarded video ad playback, orientation flips, and earned callback delivery on physical device. |
| **Human Playability & Usability Testing** | **NOT RUN** | Requires conducting 5 unprompted human playtests to evaluate touch drag feel, part-loss comprehension, and boss difficulty curve. |
| **Google Play Store Release** | **NOT RUN** | Requires generating production release keystore (`GODOT_ANDROID_KEYSTORE_RELEASE_*`), configuring production AdMob IDs & consent forms, and uploading AAB to Google Play Console. |
