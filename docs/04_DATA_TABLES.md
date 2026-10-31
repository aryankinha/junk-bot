# 04 — Data Tables (single source of truth)

Copy each JSON block into the matching file under `data/`. All values are **starting points for tuning** by the bot harness and phone tests (file 05). Units: metres, seconds, HP points. Load each file once at boot. Add a validator test that checks every referenced id exists.

## 0. `data/constants.json`

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
  "part_break_thresholds": [0.75, 0.50, 0.25],
  "base_magnet_radius": 1.6,
  "gate_line_tolerance": 0.4,
  "boss_arena_length": 30.0,
  "stage_thresholds": { "battle": 4, "monster": 9 },
  "chassis": {
    "tiny":    { "hp": 60,  "steer": 1.0,  "blaster": { "damage": 4, "rate": 1.5 } },
    "battle":  { "hp": 140, "steer": 0.95 },
    "monster": { "hp": 260, "steer": 0.9 }
  },
  "revive_hp_pct": 0.6,
  "free_rerolls_per_run": 1
}
```

## 1. `data/parts.json`

Stat keys:
`fwd_speed_pct`, `steer_pct`, `hp_flat`, `armor_pct` (damage reduction), `knockback_resist` (0–1), `oil_immune`, `magnet_mult`, `scrap_mult`, `shield_charges`, `shield_recharge_s`, and `weapon` blocks.
Level names drive the mesh swap: the part scene for level n is `assets/parts/<id>_lv<n>.tscn`.

```json
{
  "wheels": {
    "name": "Extra Wheels", "category": "movement", "slots": ["wheel_fl","wheel_fr","wheel_bl","wheel_br","wheel_ml","wheel_mr"],
    "unlock_level": 1, "weight": 10,
    "levels": [
      { "name": "Extra Wheels",   "stats": { "fwd_speed_pct": 6,  "steer_pct": 12, "hp_flat": 10 } },
      { "name": "Big Wheels",     "stats": { "fwd_speed_pct": 10, "steer_pct": 20, "hp_flat": 15 } },
      { "name": "Monster Wheels", "stats": { "fwd_speed_pct": 14, "steer_pct": 28, "hp_flat": 20 } }
    ]
  },
  "tracks": {
    "name": "Tank Tracks", "category": "movement", "slots": ["wheel_fl","wheel_fr","wheel_bl","wheel_br"],
    "unlock_level": 2, "weight": 8, "replaces": ["wheels"],
    "levels": [
      { "name": "Tank Tracks",    "stats": { "steer_pct": -8, "hp_flat": 40,  "knockback_resist": 0.4, "oil_immune": true } },
      { "name": "Heavy Tracks",   "stats": { "steer_pct": -5, "hp_flat": 70,  "knockback_resist": 0.6, "oil_immune": true } },
      { "name": "Siege Tracks",   "stats": { "steer_pct": -2, "hp_flat": 100, "knockback_resist": 0.8, "oil_immune": true } }
    ]
  },
  "cannon": {
    "name": "Cannon", "category": "weapon", "slots": ["top_c","top_l","top_r","side_l","side_r"],
    "unlock_level": 1, "weight": 12,
    "levels": [
      { "name": "Cannon",        "weapon": { "type": "projectile", "damage": 14, "rate": 1.4, "barrels": 1, "speed": 36 } },
      { "name": "Twin Cannons",  "weapon": { "type": "projectile", "damage": 14, "rate": 1.4, "barrels": 2, "speed": 36 } },
      { "name": "Gatling",       "weapon": { "type": "projectile", "damage": 9,  "rate": 7.0, "barrels": 1, "speed": 40 } }
    ]
  },
  "rocket": {
    "name": "Rocket Launcher", "category": "weapon", "slots": ["back_c","side_l","side_r"],
    "unlock_level": 1, "weight": 9,
    "levels": [
      { "name": "Rocket Launcher", "weapon": { "type": "rocket", "damage": 40, "rate": 0.55, "area_radius": 2.4, "speed": 26, "ignores_plate": true } },
      { "name": "Dual Pod",        "weapon": { "type": "rocket", "damage": 40, "rate": 0.85, "area_radius": 2.6, "speed": 26, "ignores_plate": true } },
      { "name": "Missile Rack",    "weapon": { "type": "rocket", "damage": 40, "rate": 1.1,  "area_radius": 2.8, "speed": 28, "ignores_plate": true } }
    ]
  },
  "flame": {
    "name": "Flamethrower", "category": "weapon", "slots": ["front_c","side_l","side_r"],
    "unlock_level": 2, "weight": 7,
    "levels": [
      { "name": "Flamethrower",  "weapon": { "type": "cone", "dps": 45,  "range": 6.0, "burn_dps": 10, "burn_s": 2.0 } },
      { "name": "Flame Jet",     "weapon": { "type": "cone", "dps": 70,  "range": 7.0, "burn_dps": 14, "burn_s": 2.5 } },
      { "name": "Inferno",       "weapon": { "type": "cone", "dps": 100, "range": 8.0, "burn_dps": 20, "burn_s": 3.0 } }
    ]
  },
  "armour": {
    "name": "Heavy Armour", "category": "defence", "slots": ["front_c","shoulder_l","shoulder_r"],
    "unlock_level": 1, "weight": 10,
    "levels": [
      { "name": "Armour Plates", "stats": { "armor_pct": 8,  "hp_flat": 30, "steer_pct": -3 } },
      { "name": "Heavy Plating", "stats": { "armor_pct": 14, "hp_flat": 55, "steer_pct": -5 } },
      { "name": "Fortress Plating", "stats": { "armor_pct": 20, "hp_flat": 80, "steer_pct": -8 } }
    ]
  },
  "shield": {
    "name": "Energy Shield", "category": "defence", "slots": ["head","back_c"],
    "unlock_level": 3, "weight": 7,
    "levels": [
      { "name": "Energy Shield",  "stats": { "shield_charges": 1, "shield_recharge_s": 8.0 } },
      { "name": "Barrier",        "stats": { "shield_charges": 1, "shield_recharge_s": 6.0 } },
      { "name": "Aegis",          "stats": { "shield_charges": 2, "shield_recharge_s": 4.5 } }
    ]
  },
  "magnet": {
    "name": "Scrap Magnet", "category": "collection", "slots": ["back_c","top_c"],
    "unlock_level": 1, "weight": 8,
    "levels": [
      { "name": "Scrap Magnet", "stats": { "magnet_mult": 1.8 } },
      { "name": "Strong Magnet", "stats": { "magnet_mult": 2.5 } },
      { "name": "Mega Magnet",   "stats": { "magnet_mult": 3.2 } }
    ]
  },
  "storage": {
    "name": "Storage Pack", "category": "collection", "slots": ["back_c"],
    "unlock_level": 3, "weight": 6,
    "levels": [
      { "name": "Storage Pack",  "stats": { "scrap_mult": 1.25 } },
      { "name": "Cargo Rack",    "stats": { "scrap_mult": 1.5 } },
      { "name": "Vault",         "stats": { "scrap_mult": 1.8 } }
    ]
  }
}
```

Slot resolution: place a new part in the first free slot of its `slots` list. If none is free, upgrade the existing instance of the same part; if there is no same part, replace the lowest-level part of the same category and show a clear pop-out animation for the replaced part. Parts with `replaces` remove the listed parts' visuals (wheels → tracks) and carry over their level as `max(1, level)`.

## 2. `data/combos.json`

```json
{
  "burst_volley": {
    "name": "Burst Volley", "needs": ["cannon", "rocket"],
    "special": { "type": "burst", "duration_s": 3.0, "homing_rockets": 8, "fire_rate_mult": 2.0 },
    "cooldown_s": 10.0
  },
  "ram_charge": {
    "name": "Ram Charge", "needs": ["tracks", "armour"],
    "special": { "type": "dash", "duration_s": 2.0, "invulnerable": true, "damage": 60, "knockback": 6.0 },
    "cooldown_s": 12.0
  },
  "vacuum": {
    "name": "Vacuum", "needs": ["magnet", "storage"],
    "passive": { "magnet_mult": 3.0, "scrap_mult": 1.5 },
    "special": { "type": "pull_all_scrap" },
    "cooldown_s": 15.0
  },
  "strafe_run": {
    "name": "Strafe Run", "needs": ["wheels", "cannon"], "stretch": true,
    "special": { "type": "lateral_dash_spread", "duration_s": 1.2, "shots": 12 },
    "cooldown_s": 9.0
  },
  "inferno_aura": {
    "name": "Inferno Aura", "needs": ["flame", "armour"], "stretch": true,
    "special": { "type": "flame_ring", "duration_s": 3.0, "dps": 80, "radius": 3.0 },
    "cooldown_s": 12.0
  }
}
```

## 3. `data/enemies.json`

```json
{
  "scrapper": { "hp": 18,  "speed": 3.5, "contact_damage": 6,  "telegraph_s": 0.0, "scrap": 2,  "pack": [4, 8] },
  "gunner":   { "hp": 40,  "speed": 0.0, "bolt_damage": 8, "fire_interval_s": 2.2, "telegraph_s": 0.6, "bolt_speed": 18, "scrap": 5 },
  "bruiser":  { "hp": 120, "speed": 2.0, "charge_damage": 20, "windup_s": 1.0, "charge_speed": 14, "charge_cooldown_s": 3.0, "knockback": 4.0, "scrap": 12, "rare_drop_chance": 0.15 },
  "elite_bruiser": { "hp": 400, "speed": 2.2, "charge_damage": 28, "windup_s": 0.9, "charge_speed": 15, "double_charge": true, "knockback": 5.0, "scrap": 40, "guaranteed_rare_drop": true },
  "saw":      { "damage": 15, "rail_speed": 4.0, "radius": 0.9 },
  "oil":      { "slow_pct": 40, "duration_s": 1.5, "radius": 1.8 },
  "barrel":   { "hp": 10, "blast_radius": 2.5, "blast_damage_enemy": 40, "blast_damage_player": 25 }
}
```

## 4. `data/boss_scrap_titan.json`

```json
{
  "id": "scrap_titan",
  "base_hp": 1500,
  "hp_scale_per_level": 0.20,
  "assist": { "per_loss_hp_cut": 0.10, "max_cut": 0.30, "after_losses": 2 },
  "plate": { "reduction": 0.5, "ignored_by": ["rocket", "shock"] },
  "core_multiplier_phase3": 1.5,
  "weak_points": { "core": { "damage_mult": 1.0 }, "arm": { "hp": 250 } },
  "phases": [
    { "id": 1, "from": 1.00, "to": 0.66, "attacks": ["ground_slam", "rocket_barrage"], "gap_s": [2.0, 3.0], "end_roar_s": 1.5 },
    { "id": 2, "from": 0.66, "to": 0.33, "attacks": ["ground_slam", "rocket_barrage", "grabber_arm", "laser_sweep"], "gap_s": [1.8, 2.6], "end_roar_s": 1.5 },
    { "id": 3, "from": 0.33, "to": 0.00, "attacks": ["double_slam", "rocket_barrage", "laser_sweep", "call_scrappers"], "gap_s": [1.2, 1.9], "end_roar_s": 0.0 }
  ],
  "attacks": {
    "ground_slam":   { "telegraph_s": 1.2, "shape": "circle", "radius": 2.6, "damage": 30, "knockback": 5.0 },
    "double_slam":   { "telegraph_s": 1.0, "shape": "circle", "radius": 2.6, "damage": 30, "repeat": 2, "repeat_gap_s": 0.7 },
    "rocket_barrage":{ "telegraph_s": 1.0, "shape": "lanes", "lane_count": 3, "lane_width": 1.8, "rockets": 5, "duration_s": 2.0, "damage": 14 },
    "laser_sweep":   { "telegraph_s": 1.2, "shape": "sweep", "duration_s": 2.4, "safe_gap": 2.2, "damage": 25 },
    "grabber_arm":   { "telegraph_s": 1.5, "arm_hp": 250, "recover_window_s": 5.0, "steals": "highest_level_part" },
    "call_scrappers":{ "telegraph_s": 0.8, "spawn": 6 }
  },
  "overdrive": { "max": 100, "per_sustained_fire_half_second": 1, "per_clean_dodge": 15, "no_combo_effect": { "fire_rate_mult": 2.0, "duration_s": 4.0 }, "combo_power_mult": 1.5 },
  "kill": { "slowmo_scale": 0.25, "slowmo_s": 1.2, "debris_pieces": 24, "rare_part_drop": true },
  "level_extra_attacks": { "3": "double_slam_in_phase_1", "5": "laser_sweep_in_phase_1" }
}
```

HP check: Level 1 boss HP = 1500. A typical L1 end build deals about 45–70 dps with about 50% fire uptime, so the first win takes about 30–45 s.

## 5. `data/gates_level1.json` (authored)

Distances are metres from the start. Boss arena begins at `boss_z`. Beat types: `scrap_trail`, `gate`, `enemy_pack`, `hazard`, `miniboss`, `repair_bay`, `final_choice`.

```json
{
  "level": 1, "zone": "junkyard", "boss_z": 720, "target_seconds": 90,
  "beats": [
    { "z": 15,  "type": "scrap_trail", "length": 45 },
    { "z": 80,  "type": "gate", "options": [ { "kind": "part", "id": "cannon" }, { "kind": "part", "id": "wheels" } ] },
    { "z": 125, "type": "enemy_pack", "enemy": "scrapper", "count": 4, "lane": "center" },
    { "z": 180, "type": "gate", "options": [ { "kind": "part", "id": "armour" }, { "kind": "part", "id": "magnet" } ] },
    { "z": 240, "type": "enemy_pack", "enemy": "scrapper", "count": 6, "lane": "spread" },
    { "z": 270, "type": "hazard", "kind": "saw", "lane": "rail_cross" },
    { "z": 290, "type": "gate", "options": [ { "kind": "part", "id": "rocket" }, { "kind": "upgrade_random_owned" } ] },
    { "z": 345, "type": "enemy_pack", "enemy": "gunner", "count": 1, "lane": "left" },
    { "z": 380, "type": "hazard", "kind": "barrel", "lane": "right" },
    { "z": 400, "type": "gate", "options": [ { "kind": "tradeoff", "id": "overclock" }, { "kind": "tradeoff", "id": "plating" } ] },
    { "z": 450, "type": "miniboss", "enemy": "elite_bruiser" },
    { "z": 520, "type": "gate", "options": [ { "kind": "gamble", "id": "crate" }, { "kind": "part", "id": "armour" } ] },
    { "z": 570, "type": "enemy_pack", "enemy": "scrapper", "count": 8, "lane": "spread" },
    { "z": 610, "type": "repair_bay" },
    { "z": 670, "type": "final_choice", "pool_size": 3 }
  ]
}
```

L1 tutorial rules: (a) the first gate fires on a `tutorial_pause_bias` of zero (no pause); highlight both panels with a pulsing outline for the first run only; (b) enemy HP × 0.8; (c) boss attacks use the Phase 1 set only up to 60% HP, and telegraphs are 20% longer.

### Level generator (levels 2+)

```json
{
  "gate_count": "min(10, 5 + level)",
  "gate_spacing": [85, 110],
  "category_rules": ["no_two_same_category_in_pair", "weapon_by_gate_3_if_none_owned", "no_part_at_lv3_offered"],
  "special_beats": { "miniboss_at_fraction": 0.5, "repair_bay_at_fraction": 0.7, "final_choice_before_boss": true },
  "tradeoff_gate_chance": 0.2,
  "gamble_gate_chance": 0.15,
  "enemy_budget_per_100m": "6 + level * 1.5",
  "run_target_seconds": "min(150, 90 + 8 * (level - 1))"
}
```

## 6. `data/tradeoffs.json` and gamble crate

```json
{
  "overclock": { "name": "Overclock", "desc": "+40% damage, -30% max HP", "effects": { "dps_mult": 1.4, "max_hp_mult": 0.7 }, "tone": "orange" },
  "plating":   { "name": "Plating",   "desc": "+40% max HP, -10% steering", "effects": { "max_hp_mult": 1.4, "steer_pct": -10 }, "tone": "orange" },
  "crate": { "outcomes": [
    { "p": 0.60, "result": "random_part" },
    { "p": 0.15, "result": "rare_part" },
    { "p": 0.25, "result": "scrap_burst", "scrap": 40 }
  ] }
}
```

Rare part = a part at level 2 directly (or a random owned part upgraded by 2 levels, capped at 3).

## 7. `data/economy.json`

```json
{
  "cogs": { "per_scrap": 1.0, "boss_bonus_per_level": 50, "streak_bonus_per_step": 0.10, "streak_bonus_max": 0.30 },
  "repair_bay": { "repair_cost": 20, "buy_part_cost": 35, "repair_heal_pct": 0.40 },
  "upgrade_costs": [120, 260, 520, 1000],
  "upgrade_stat_gain_per_tier": 0.08,
  "visual_variant_tiers": [3, 5],
  "unlock_costs": { "tracks": 0, "flame": 150, "shield": 250, "storage": 250 },
  "streak": { "wins_for_weakpoint_outline": 3 },
  "ads": {
    "interstitial_first_after_runs": 4,
    "interstitial_first_after_minutes": 10,
    "interstitial_every_n_runs": 2,
    "interstitial_min_gap_s": 120
  }
}
```

Unlock rule: a part enters the gate pool when its `unlock_level` is reached; Cogs `unlock_costs` apply to the Hangar "Armoury" purchase for parts that unlock early; a cost of 0 means free at the unlock level.

## 8. `data/zones.json`

```json
{
  "junkyard": { "levels": [1, 5],   "sky": "junkyard_sky",  "fog_color": "#E9C98F", "modifiers": [] },
  "desert":   { "levels": [6, 10],  "sky": "desert_sky",    "fog_color": "#F2B36B", "modifiers": ["deep_sand_patches"] },
  "factory":  { "levels": [11, 15], "sky": "factory_sky",   "fog_color": "#8A8F9C", "modifiers": ["conveyor_lanes"] },
  "snow":     { "levels": [16, 20], "sky": "snow_sky",      "fog_color": "#DDE8F5", "modifiers": ["ice_grip"] }
}
```

Modifier behaviour: `deep_sand_patches` = oil-like slow zones that wheels suffer in and tracks ignore; `conveyor_lanes` = constant lateral push of ±2.5 m/s in marked lanes; `ice_grip` = lateral follow rate × 0.5 (tracks use × 0.8).

## 9. Balance targets (checked by the bot harness)

| Metric | Target |
|---|---|
| L1 boss first-attempt win (random-choice bot with delay 250 ms) | 80–90% |
| L1 boss win (perfect-dodge bot, any build) | ≥ 98% |
| L3 boss win (random bot) | 55–70% |
| L5 boss win (random bot) | 40–55% |
| Gate pick share, rational bot | each side 40–60% |
| Average parts lost per L1 run (random bot) | 0.8–1.5 |
| Boss fight duration (median) | 30–45 s |
