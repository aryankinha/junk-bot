# 03 — Technical Architecture (Godot 4.7.x, GDScript)

## 1. Design principles

1. **Sim / View split.** The sim is pure `RefCounted` GDScript driven by a fixed 60 Hz step with seeded RNG streams. It knows nothing about nodes. The view reads sim state and reacts to a queue of sim events. This enables headless tests, balance bots and the daily seed.
2. **Data-driven.** Parts, gates, enemies, boss and economy come from `data/*.json` (file 04).
3. **Cheap rendering.** Compatibility renderer, few materials, pooled objects, MultiMesh for scrap, CPU particles, baked-look lighting (one directional light, no realtime shadows; use blob shadow quads under the robot and enemies).
4. **Small surface area.** Few autoloads, small scripts, clear names.
5. **Measure on the phone.** Log frame-time percentiles, draw calls and memory every run.

## 2. Project settings (`project.godot` essentials)

```ini
[application]
config/name="Scrap Dragon"
run/main_scene="res://src/view/Boot.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1          ; portrait

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
anti_aliasing/quality/msaa_3d=0        ; test 2 on the phone and record the cost
environment/defaults/default_clear_color=Color(0.88, 0.76, 0.55, 1)

[physics]
common/physics_ticks_per_second=60

[input_devices]
pointing/emulate_touch_from_mouse=true ; lets you test drag on desktop

[autoload]
Audio="*res://src/services/audio.gd"
Haptics="*res://src/services/haptics.gd"
Save="*res://src/services/save_store.gd"
Ads="*res://src/services/ads.gd"
Telemetry="*res://src/services/telemetry.gd"
PerfLog="*res://src/services/perf_log.gd"
```

Keep `Data`, `Constants` and the sim as **static / class_name scripts** (not autoloads) so headless tests can use them.

Compatibility renderer notes to design around: it supports fog, glow, tonemapping, MSAA 3D and two reflection probes per mesh; it does not support SSAO, SSR, volumetric fog, TAA or custom `CompositorEffects`. Plan visuals around flat colour, vertex shading, fog and emissive accents. Automatic mesh instancing exists only in Forward+, so use `MultiMeshInstance3D` yourself for repeated meshes.

## 3. Folder layout

```
scrap_dragon/
  project.godot
  docs/                  # these md files
  reference/             # concept art (reference only)
  data/                  # json from file 04
  assets/
    models/  parts/  materials/  audio/  ui/  fonts/  vfx/
    ASSET_MANIFEST.md  CREDITS.md
  src/
    core/    constants.gd  game_data.gd  rng_streams.gd  events.gd
    sim/     run_sim.gd  robot_state.gd  stat_calc.gd  gate_gen.gd
             combat_sim.gd  enemy_sim.gd  boss_sim.gd  economy.gd
    view/    Boot.tscn  RunView.tscn(.gd)  Robot.tscn(.gd)  robot_builder.gd
             gate_view.gd  enemy_view.gd  boss_view.gd  chase_cam.gd
             scrap_field.gd  telegraph_view.gd  fx.gd  pool.gd
    ui/      Hud.tscn  Result.tscn  Hangar.tscn  Codex.tscn  Settings.tscn
    services/ audio.gd haptics.gd save_store.gd ads.gd telemetry.gd perf_log.gd
  tests/     run_all.gd  test_*.gd  bots/
  tools/     build_android.sh  phone_perf_session.sh  asset_audit.gd
  reports/   M0_REPORT.md ...
```

## 4. Sim

### 4.1 Loop and RNG streams

```gdscript
class_name RunSim extends RefCounted

var t := 0.0                    # seconds
var z := 0.0                    # forward distance (m)
var x := 0.0                    # lateral position (m)
var target_x := 0.0
var robot := RobotState.new()
var enemies: Array = []         # EnemySim.Enemy
var bullets: Array = []
var scrap_nodes: Array = []     # {pos, value, alive}
var boss: BossSim = null
var events: Array = []          # drained by the view each frame
var state := "running"          # running | boss | won | lost
var rng := RngStreams.new()     # gates, spawns, boss, loot (separate seeds)

func setup(level: int, seed_value: int) -> void:
	rng.seed_all(seed_value)
	robot.reset(level)
	# build the beat list from data/gates_level1.json or the generator
	...

func drag(world_dx: float) -> void:
	target_x = clampf(target_x + world_dx, -C.road_half_width, C.road_half_width)

func tap_special() -> void:
	if robot.special_ready():
		robot.fire_special(self)

func step(dt: float) -> void:
	if state == "lost" or state == "won":
		return
	t += dt
	_move_player(dt)        # lateral follow + forward z unless in boss arena
	_spawn_from_beats()     # beats scheduled by z; uses rng.spawns
	_resolve_gates()        # when z passes a gate line, pick side by x
	CombatSim.step(self, dt)  # auto-fire, bullets, damage, part breaks
	EnemySim.step(self, dt)
	if boss: boss.step(self, dt)
	_check_end()

func emit(type: String, data := {}) -> void:
	events.append({ "t": type, "time": t }.merged(data))
```

Use four RNG streams (`gates`, `spawns`, `boss`, `loot`) seeded from one seed so the **daily seed** yields the same gates and attack order regardless of how the player plays.

### 4.2 Robot state and stats

```gdscript
class_name RobotState extends RefCounted

var parts := {}        # part_id -> level (1..3)
var slots := {}        # slot_name -> part_id
var broken := []       # [{id, level, slot}]
var hp := 60.0
var max_hp := 60.0
var scrap := 0
var combos_active := []
var cooldowns := {}    # combo_id -> remaining seconds
var overdrive := 0.0
var hp_break_stage := 0      # how many of [0.75, 0.5, 0.25] thresholds were crossed

func build_points() -> int:
	var bp := 0
	for id in parts:
		bp += int(parts[id])
	return bp

func stage() -> int:
	var bp := build_points()
	if bp >= C.stage_thresholds.monster: return 3
	if bp >= C.stage_thresholds.battle: return 2
	return 1

func add_part(id: String, sim: RunSim) -> Dictionary:
	# returns {"result": "attached"|"upgraded"|"replaced", "slot": ..., "level": ...}
	...  # slot resolution rules are in file 04, section 1

func take_damage(amount: float, sim: RunSim) -> void:
	# 1) shield: block if charge available
	# 2) armour reduction from StatCalc
	# 3) hp -= amount; start hit invulnerability
	# 4) for each threshold in C.part_break_thresholds not yet crossed:
	#      if hp / max_hp < threshold: break_part(sim)   # one part per threshold
	# 5) if hp <= 0: sim.state = "lost"
	...

func break_part(sim: RunSim) -> void:
	# candidates = attachments excluding the last weapon; weight by level
	# remove stats, record in `broken`, emit "part_broken" with slot and part id
	...
```

`StatCalc.compute(robot)` returns a flat Dictionary (`fwd_mult`, `steer_mult`, `max_hp`, `armor`, `knockback_resist`, `oil_immune`, `magnet_radius`, `scrap_mult`, `weapons[]`, `shield_charges`, `shield_recharge_s`, `dps_mult`) by summing part-level stats, then applying Hangar tier gains (`+8%` per tier on the part's main stat), then combo passives, then trade-off effects. Recompute only when parts change.

### 4.3 Gates

```gdscript
func _resolve_gates() -> void:
	for g in active_gates:
		if not g.resolved and z >= g.z:
			g.resolved = true
			var side := 0 if x < 0.0 else 1     # left / right
			var opt = g.options[side]
			_apply_option(opt)                  # part | upgrade_random_owned | tradeoff | gamble
			emit("gate_passed", { "gate_id": g.id, "side": side, "option": opt })
```

The **Final Choice** and **Repair Bay** use three lanes: pick by `int(floor((x + C.road_half_width) / (2.0 * C.road_half_width) * 3.0))`.

`GateGen` builds gate pairs from `GameData.parts` using weights, unlock levels and the category rules in file 04. A validator test builds 1000 pairs per level and asserts the rules hold.

### 4.4 Combat

- Targeting: nearest alive enemy inside the forward cone and range.
- Projectiles are sim objects moved with simple math (no physics bodies). Hit test: distance from the bullet to each active enemy (n ≤ 24, bullets ≤ 64, so brute force is fine).
- Rockets apply area damage within `area_radius`. Flame applies cone damage per second to enemies in range and angle.
- Boss damage goes through `BossSim.apply_hit(source_weapon_type, damage, hit_region)`, which handles the plate reduction, core multiplier and arm HP.

### 4.5 Boss

`BossSim` is a state machine: `intro → phase1 → roar → phase2 → roar → phase3 → dying → dead`. Each attack is a small object with `telegraph(t)` → `active(t)` → `recover(t)` and a list of **hazard zones** (circle, lane, sweep with a safe gap) the sim reads for player damage. The view draws telegraph quads from `boss.zones` without any gameplay logic of its own. Attack choice uses `rng.boss`. The Grabber Arm is a sub-entity with its own HP.

## 5. View

### 5.1 Scene tree

```
RunView (Node3D)
  World (Node3D)          # road chunks, scenery pools
  Robot (Node3D)          # see 5.2
  Enemies (Node3D)        # pooled enemy views
  Projectiles (Node3D)    # pooled bullet meshes
  ScrapField (MultiMeshInstance3D)
  Telegraphs (Node3D)     # pooled red quads
  Fx (Node3D)             # pooled particles
  ChaseCam (Camera3D)
  Sun (DirectionalLight3D, shadows off)
  Env (WorldEnvironment)  # sky, fog, tonemap
HUD (CanvasLayer)
```

Each frame: `sim_accumulator += delta; while sim_accumulator >= 1/60: sim.step(1/60)`; then update views from `sim` and drain `sim.events`.

### 5.2 Robot assembly

`Robot.tscn` holds three chassis models (`Chassis1`, `Chassis2`, `Chassis3`), only one visible. Each chassis has a `Sockets` node with `Marker3D` children named exactly as in the slots list (`wheel_fl, wheel_fr, wheel_bl, wheel_br, wheel_ml, wheel_mr, top_c, top_l, top_r, side_l, side_r, back_c, front_c, shoulder_l, shoulder_r, head`). Stage 1 has a subset; stages 2 and 3 add sockets while keeping the same names, so parts re-parent cleanly on stage-up.

```gdscript
func attach_visual(part_id: String, level: int, slot: String) -> void:
	var scene: PackedScene = load("res://assets/parts/%s_lv%d.tscn" % [part_id, level])
	var node: Node3D = scene.instantiate()
	var marker: Marker3D = current_chassis.get_node("Sockets/" + slot)
	marker.add_child(node)
	node.scale = Vector3.ZERO
	node.position = Vector3(0, 1.2, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector3.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(node, "scale", Vector3.ONE, 0.10)
	Fx.spark(marker.global_position)
	Audio.play("attach")
	Haptics.tap(20, 0.4)
	sockets[slot] = node
```

For upgrades, swap the mesh scene for the next level with a pulse. For breaks, detach the node, reparent to `World`, turn it into a pooled debris body with an impulse and fade it in 1.5 s.

On **stage-up**: hide the old chassis, show the new one with a scale-pop (0.6 → 1.1 → 1.0 over 0.25 s), re-parent all parts by slot name, play flash, shockwave ring, sound and haptic.

### 5.3 Road and scenery

- 3 road chunk scenes (length 40 m). Keep 6 chunks alive; recycle the chunk behind the camera to the front. Scenery nodes live inside chunks.
- Fog: depth fog from 40 m to 110 m in the zone's fog colour to hide pop-in.
- Gates, enemies and hazards spawn at their beat distance, 60–70 m ahead, from pools.

### 5.4 Scrap

One `MultiMeshInstance3D` with 400 instances. A free-list of instance indices; collect by distance check against `magnet_radius` (sim side); on collect, set the instance scale to zero and spawn a sparkle plus a floating "+n" text from a pool. Tween collected scrap towards the robot during the last 0.15 s for juice.

### 5.5 Camera

```gdscript
extends Camera3D
@export var offset_run := Vector3(0, 5.2, 7.5)
@export var offset_boss := Vector3(0, 8.5, 11.0)
var shake := 0.0
func _process(delta):
	var off := offset_boss if sim.state == "boss" else offset_run
	var target := robot.global_position + off
	global_position = global_position.lerp(target, 1.0 - exp(-6.0 * delta))
	look_at(robot.global_position + Vector3(0, 1.0, -6.0))
	shake = maxf(0.0, shake - delta * 2.5)
	h_offset = randf_range(-1.0, 1.0) * shake * 0.25
	v_offset = randf_range(-1.0, 1.0) * shake * 0.25
```

FOV about 62°. Slow-motion uses `Engine.time_scale = 0.25` for 1.2 s, then restore to 1.0 (use a timer that ignores time scale: `get_tree().create_timer(1.2, true, false, true)`).

### 5.6 Input

```gdscript
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenDrag:
		var dx_world := e.relative.x / get_viewport().get_visible_rect().size.x * C.drag_world_per_screen_width
		sim.drag(dx_world)
```

The special button is a normal `TextureButton` at the bottom-right inside the safe area (`DisplayServer.get_display_safe_area()`), at least 140 px square.

## 6. Services

### Haptics

```gdscript
extends Node
var enabled := true
func tap(ms := 20, amp := 0.4) -> void:
	if enabled and OS.has_feature("android"):
		Input.vibrate_handheld(ms, amp)   # needs VIBRATE permission in the export preset
```

### Audio

A pool of 12 `AudioStreamPlayer` nodes. `Audio.play(name, pitch_jitter := 0.08)` picks a free player, sets a random pitch scale, and respects a per-sound polyphony limit (for example `laser`: 4). Buses: `Master`, `Music`, `SFX`, `UI`. Event-to-sound map in file 06.

### Save

```gdscript
const PATH := "user://save.json"
func write(data: Dictionary) -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, PATH)
```

Schema (version it): `{ "v":1, "cogs":0, "level":1, "part_tiers":{}, "unlocked_parts":[], "codex":[], "streak":0, "best_daily":0, "losses_on_level":0, "settings":{"sound":true,"music":true,"haptics":true}, "stats":{"runs":0,"wins":0} }`. Save at run end and on `NOTIFICATION_APPLICATION_PAUSED`.

### Ads (AdMob plugin by Poing Studios)

Reuse the integration proven in the `godot_lab` project (plugin v5.1.0). Wrap it behind one API so the rest of the game never touches the plugin:

```gdscript
extends Node
signal reward_granted(placement: String)
const TEST_REWARDED_ANDROID := "ca-app-pub-3940256099942544/5224354917"
var _ad: RewardedAd
var _ready_to_show := false

func _ready() -> void:
	MobileAds.initialize()
	preload_rewarded()

func preload_rewarded() -> void:
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd): _ad = ad; _ready_to_show = true
	cb.on_ad_failed_to_load = func(err: LoadAdError): _ready_to_show = false
	RewardedAdLoader.new().load(TEST_REWARDED_ANDROID, AdRequest.new(), cb)

func is_available() -> bool: return _ready_to_show

func show_rewarded(placement: String) -> void:
	if not _ready_to_show: return
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item): reward_granted.emit(placement)
	_ad.show(listener)
	_ready_to_show = false
	# after dismissal: _ad.destroy(); _ad = null; preload_rewarded()
```

Match class and callback names to the plugin version in the lab project. Show a rewarded button only when `Ads.is_available()`. Use test ad units until release. Free the previous ad (`destroy()`) before loading a new one.

### Telemetry and PerfLog

`Telemetry.log(event, dict)` appends one JSON line to `user://telemetry.jsonl`. `PerfLog` samples frame time each frame during a run and at run end writes p50/p95/p99 frame time, % of frames over 16.7 ms, draw calls (`RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`), static memory, and time-to-first-playable-frame to `user://perf.json`. Show a hidden debug overlay (five-finger tap) with FPS and draw calls.

## 7. Performance budget and techniques

| Budget | Target |
|---|---|
| Draw calls | ≤ 150 (aim 60–100) |
| Triangles | ≤ 150k |
| Materials | ≤ 8 shared |
| Active enemies | ≤ 24 |
| Active bullets | ≤ 64 |
| Scrap instances | ≤ 400 (one MultiMesh) |
| Particles | CPU, ≤ 6 emitters alive, ≤ 20 particles each |
| Memory | ≤ 400 MB on the phone |
| Physics bodies | Debris only (pooled, ≤ 12 alive) |

Techniques: pooled everything; no per-frame allocations in hot paths (reuse arrays and vectors); no realtime shadows; blob shadows as flat dark quads; `visible = false` on pooled-idle nodes; keep telegraph quads unshaded and non-transparent where possible (use alpha scissor or small alpha areas to limit fill rate); set `Engine.max_fps = 60`; keep `physics_ticks_per_second = 60` and move gameplay through the sim, not the physics engine.

## 8. Testing (headless)

`godot --headless --script res://tests/run_all.gd` loads every `tests/test_*.gd`, runs each `run()` which returns an array of failure strings, prints a summary and exits non-zero on failures.

| Suite | Checks |
|---|---|
| `test_data` | All JSON loads; every referenced id exists; level names and scene paths exist |
| `test_robot` | Slot resolution; merge to level 3; stage thresholds; combo activation; stat sums |
| `test_gates` | 1000 generated pairs per level obey category rules and unlock rules; same seed gives same gates |
| `test_damage` | Break thresholds fire once each; the last weapon never breaks; invulnerability window works |
| `test_boss` | Phase transitions; plate reduction and rocket bypass; arm recovery; overdrive fill |
| `test_economy` | Cogs formula; upgrade costs; streak bonus |
| `test_sim_determinism` | Same seed and same scripted input produce identical event logs |
| `bots/` | Balance bots (file 05) report win rates against targets in file 04 |

## 9. Android export checklist

- Create **two presets**: `Android Debug` (APK, arm64, for the phone) and `Android Release` (AAB, for Play). Both use renderer `gl_compatibility` and Gradle custom build.
- Export options to set (confirm the exact option names in the editor): `gradle_build/use_gradle_build = true`, `gradle_build/min_sdk = 24`, `gradle_build/target_sdk = 36`, `architectures/arm64-v8a = true`, `permissions/vibrate = true`, `permissions/internet = true`, `permissions/access_network_state = true` (ads), `package/unique_name = com.aryankinha.scrapdragon`, portrait orientation.
- **Play requirements to satisfy before release:** new apps and updates must target Android 16 (API 36) or higher since 31 Aug 2026; the AAB must support 16 KB memory page sizes (Godot added support in the 4.5 line; verify the exported AAB in Play Console or with bundletool/zipalign checks); sign with a **real release keystore** (keep it backed up; the throwaway keystore from earlier tests is for local builds only).
- Test the **Android back gesture** on an Android 16 device or emulator; the app should pause or show a quit confirmation rather than exit instantly.
- Pause the sim and audio on `NOTIFICATION_APPLICATION_FOCUS_OUT` and resume cleanly.
- Handle the safe area (notch) for HUD placement.
- Verify install size (APK and AAB). Import only needed assets and keep textures small.
- Release checklist for ads: swap in production ad unit ids and the AdMob app id only for the release build; keep test ids in debug; confirm any consent requirements (for example Google's User Messaging Platform in the EEA/UK) with the plugin documentation before shipping.
