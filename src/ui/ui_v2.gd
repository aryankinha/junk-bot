extends RefCounted
# Presentation experiment. No simulation mutations; one hero receipt and bounded local feedback.
const BLUE := Color("50b9df")
const GREEN := Color("43b975")
const GOLD := Color("eab846")
const RED := Color("d75a52")
const INK := Color("303c3e")
var hero_time := 0.0
var hero_priority := 0
var hero_panel: PanelContainer
var support: Control
var dock: Control
var charge: ProgressBar
var receipt: Label
var counter_row: HBoxContainer
var decision_panel: PanelContainer
var decision_label: Label
var family_guides := {"part": false, "mob": false}
var ready_before := false
var ready_time := 0.0
var last_parts := ""
var lost_id := ""
var lost_time := 0.0
var safe_override := Vector2.ZERO
var feedback_log: Array = []
var feedback_counts: Dictionary = {}
var last_player_flash := -10.0
var last_pickup := -10.0
var flash_times: Array = []
var pending_scrap := 0
var frame := 0
var log_cursor := 0
var last_steer_frame := -1
var optional_particles := 0
var gesture_seen := false
var motion_scale := 1.0
class VolumeSlider:
	extends HSlider
	func _draw() -> void:
		var y := size.y * 0.5
		var x := 24.0 + (size.x - 48.0) * float(value - min_value) / maxf(0.001, max_value - min_value)
		draw_line(Vector2(24, y), Vector2(size.x - 24, y), Color("bec8bf"), 8)
		draw_line(Vector2(24, y), Vector2(x, y), Color("56685e"), 8)
		var points := PackedVector2Array()
		for i in 6: points.append(Vector2(x, y) + Vector2(cos(TAU * i / 6), sin(TAU * i / 6)) * 23)
		draw_colored_polygon(points, Color("34433f"))
		draw_circle(Vector2(x, y), 12, Color("edf3ec"))

func label(game, text: String, size := 36, color := INK) -> Label:
	return game.text_label(text, size, color)

func build(game) -> void:
	var canvas := CanvasLayer.new(); game.add_child(canvas)
	game.hud = Control.new(); game.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); canvas.add_child(game.hud)
	game.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support = Control.new(); support.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); support.mouse_filter = Control.MOUSE_FILTER_IGNORE; game.hud.add_child(support)
	game.top_bar = PanelContainer.new(); game.top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	game.top_bar.offset_left = 34; game.top_bar.offset_right = -34
	game.top_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); support.add_child(game.top_bar)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 10); game.top_bar.add_child(column)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14); column.add_child(row)
	game.level_label = label(game, "SECTOR 01", 38); row.add_child(game.pill("gear", game.level_label))
	var space := Control.new(); space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; space.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(space)
	game.scrap_label = label(game, "0", 42, Color("936d24")); game.scrap_label.custom_minimum_size.x = 112; game.scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(game.pill("coin", game.scrap_label))
	var pause: Button = game.make_button("Ⅱ", game.show_pause); pause.custom_minimum_size = Vector2(120, 120); row.add_child(pause)
	game.hp_bar = game.bar(GREEN, 44); game.hp_bar.custom_minimum_size.y = 48; column.add_child(game.hp_bar)
	game.hp_label = label(game, "60 / 60", 34); game.hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game.hp_bar.add_child(game.hp_label)
	for threshold in [0.25, 0.5, 0.75]: add_tick(game.hp_bar, threshold)
	game.progress_bar = game.bar(Color("7b8985"), 12); column.add_child(game.progress_bar)
	game.parts_row = HFlowContainer.new(); game.parts_row.add_theme_constant_override("h_separation", 12); column.add_child(game.parts_row)
	decision_panel = PanelContainer.new()
	var decision_style: StyleBoxFlat = game.style(Color("26343d"), Color("81929c"), 4, 0); decision_style.content_margin_top = 4; decision_style.content_margin_bottom = 4
	decision_panel.add_theme_stylebox_override("panel", decision_style); column.add_child(decision_panel)
	decision_label = label(game, "", 48, Color.WHITE); decision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; decision_label.add_theme_color_override("font_outline_color", Color("15202a")); decision_label.add_theme_constant_override("outline_size", 3); decision_panel.add_child(decision_label); decision_panel.visible = false
	game.boss_panel = VBoxContainer.new(); game.boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); game.boss_panel.offset_left = 50; game.boss_panel.offset_right = -50; support.add_child(game.boss_panel)
	game.boss_label = label(game, "SCRAP TITAN", 36); game.boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game.boss_panel.add_child(game.boss_label)
	game.boss_bar = game.bar(RED, 26); game.boss_panel.add_child(game.boss_bar)
	for phase in [0.33, 0.66]: add_tick(game.boss_bar, phase)
	hero_panel = PanelContainer.new(); hero_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); hero_panel.offset_left = -380; hero_panel.offset_right = 380; game.hud.add_child(hero_panel)
	hero_panel.add_theme_stylebox_override("panel", game.style(Color("edf3ec"), Color("4c6a5a"), 6, 0)); hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.toast_label = label(game, "", 42); game.toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game.toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hero_panel.add_child(game.toast_label); hero_panel.visible = false
	game.chain_label = label(game, "", 30, Color("936d24")); game.combo_label = label(game, "", 30, GREEN)
	counter_row = HBoxContainer.new(); counter_row.add_theme_constant_override("separation", 24); column.add_child(counter_row)
	for text in [game.chain_label, game.combo_label]:
		text.custom_minimum_size = Vector2(240, 40); counter_row.add_child(text)
	counter_row.visible = false
	game.hint_label = label(game, "", 34); game.hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); game.hint_label.offset_left = 90; game.hint_label.offset_right = -90; game.hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game.hud.add_child(game.hint_label)
	dock = Control.new(); dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dock.mouse_filter = Control.MOUSE_FILTER_IGNORE; support.add_child(dock)
	game.special_button = game.make_button("SPECIAL", func(): game.sim.tap_special(), true); game.special_button.add_theme_font_size_override("font_size", 38); dock.add_child(game.special_button)
	charge = game.bar(BLUE, 10); charge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); charge.offset_left = 12; charge.offset_right = -12; charge.offset_top = -14; charge.offset_bottom = -4; charge.mouse_filter = Control.MOUSE_FILTER_IGNORE; game.special_button.add_child(charge)
	game.special_ring = UiRing.new(); game.special_ring.visible = false; dock.add_child(game.special_ring)
	game.reroll_button = game.make_button("RE-ROLL\nFREE", func():
		if game.sim.free_rerolls <= 0 and game.ads.is_available(): game.ads.show_rewarded("reroll")
		elif game.sim.reroll(): hero(game, "PART OPTIONS RESET", 25, GREEN)
	); game.reroll_button.add_theme_font_size_override("font_size", 32); dock.add_child(game.reroll_button)
	receipt = label(game, "", 34, GOLD); receipt.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); receipt.offset_left = -400; receipt.offset_right = -180; receipt.offset_top = 166; receipt.offset_bottom = 212; receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; support.add_child(receipt)
	game.debug_label = label(game, "", 24); game.debug_label.visible = false; game.hud.add_child(game.debug_label)
	game.flash = ColorRect.new(); game.flash.color = Color(0, 0, 0, 0); game.flash.visible = false; game.flash.mouse_filter = Control.MOUSE_FILTER_IGNORE; game.hud.add_child(game.flash)
	game.overlay = Control.new(); game.overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.overlay.visible = false; canvas.add_child(game.overlay)
	game.hud.resized.connect(func(): layout(game))
	layout(game)

func add_tick(bar: Control, fraction: float) -> void:
	var marker := ColorRect.new(); marker.color = INK; marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; bar.add_child(marker)
	var place := func(): marker.position = Vector2(bar.size.x * fraction - 3, 0); marker.size = Vector2(6, bar.size.y)
	bar.resized.connect(place); place.call()

func layout(game) -> void:
	var v: Vector2 = game.get_viewport().get_visible_rect().size
	var safe := Vector2(45, 45)
	if OS.has_feature("android"):
		var physical := DisplayServer.screen_get_size(); var usable := DisplayServer.get_display_safe_area()
		if physical.y > 0: safe = Vector2(maxf(45, float(usable.position.y) * v.y / physical.y), maxf(45, float(physical.y - usable.end.y) * v.y / physical.y))
	if safe_override != Vector2.ZERO: safe = safe_override
	game.top_bar.offset_top = safe.x
	var left: bool = bool(game.save.data.settings.get("left_handed", false))
	var compact: bool = game.sim != null and game.sim.flags.get("gate_clarity", false) and game.special_button.disabled
	var special_size := Vector2(200, 132) if compact else Vector2(260, 164)
	game.special_button.position = Vector2(v.x * (0.35 if left else 0.65) - special_size.x / 2, v.y - safe.y - 270); game.special_button.size = special_size
	game.reroll_button.position = Vector2(v.x * (0.65 if left else 0.35) - 94, v.y - safe.y - 246); game.reroll_button.size = Vector2(188, 120)
	game.hint_label.offset_top = -380 - safe.y; game.hint_label.offset_bottom = -300 - safe.y
	var y: float = maxf(safe.x + 240, game.top_bar.offset_top + game.top_bar.size.y + 12)
	if game.sim != null and game.sim.flags.get("gate_clarity", false):
		game.hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		var hint_width: float = minf(v.x - 100, game.hint_label.get_minimum_size().x + 20)
		game.hint_label.offset_left = -hint_width / 2; game.hint_label.offset_right = hint_width / 2
		game.hint_label.offset_top = y + 120; game.hint_label.offset_bottom = y + 174
	game.boss_panel.offset_top = y
	var boss_visible: bool = game.sim != null and (game.sim.boss != null or game.sim.enemies.any(func(e): return e.id == "hauler" and e.hp > 0))
	hero_panel.offset_top = y + (108 if boss_visible else 4); hero_panel.offset_bottom = hero_panel.offset_top + 90

func reset(game) -> void:
	hero_time = 0; hero_priority = 0; hero_panel.visible = false; ready_before = false; ready_time = 0; last_parts = ""; lost_time = 0; receipt.text = ""; feedback_log.clear(); log_cursor = 0; last_steer_frame = -1; feedback_counts.clear(); flash_times.clear(); last_player_flash = -10; last_pickup = -10; pending_scrap = 0; frame = 0; gesture_seen = false
	game.world.popup_limit = 3
	layout(game)

func sync_hud(game) -> void:
	var s: RunSim = game.sim
	game.level_label.text = "DAILY" if game.daily else "SECTOR %02d" % s.level
	game.scrap_label.text = str(s.robot.scrap); game.hp_label.text = "%d / %d" % [s.robot.hp, s.robot.max_hp]; game.hp_bar.value = s.robot.hp / s.robot.max_hp * 100.0
	game.progress_bar.value = s.z / s.boss_z * 100
	var signature := str(s.robot.parts) + lost_id + str(lost_time > 0)
	if signature != last_parts:
		last_parts = signature
		for child in game.parts_row.get_children(): game.parts_row.remove_child(child); child.queue_free()
		var equipment := 0
		for id in s.robot.parts:
			if GameData.table("parts")[id].category != "weapon": equipment += 1; continue
			var text: String = {"cannon": "CANNON", "rocket": "ROCKET", "flame": "TORCH"}.get(id, str(id).to_upper())
			game.parts_row.add_child(label(game, "%s  L%d" % [text, s.robot.parts[id]], 32, BLUE))
		if equipment > 0: game.parts_row.add_child(label(game, "+%d EQUIPMENT" % equipment, 30, Color("64716a")))
		if lost_time > 0: game.parts_row.add_child(label(game, "× " + lost_id.to_upper(), 30, RED))
	var clarity: bool = bool(s.flags.get("gate_clarity", false))
	var next: Dictionary = s.next_gate()
	decision_panel.visible = clarity and s.state == "running" and not next.is_empty() and float(next.z) - s.z <= 45 and hero_time <= 0
	if decision_panel.visible:
		var choices: Array = next.get("options", []).map(func(o): return GateGen.label(o).to_upper().replace("LAUNCHER", "RKT").replace("EXTRA ", ""))
		decision_label.text = "DRIVE / " + "  |  ".join(choices)
		decision_label.add_theme_font_size_override("font_size", 48 if choices.size() <= 2 else 42)
	counter_row.visible = not game.chain_label.text.is_empty() or not game.combo_label.text.is_empty()
	game.boss_panel.visible = s.boss != null
	if s.boss != null:
		game.boss_label.text = "SCRAP TITAN / " + ["ARMOURED", "CORE OPEN", "ENRAGED"][s.boss.phase - 1]
		game.boss_bar.value = s.boss.hp / s.boss.max_hp * 100
	else:
		for enemy in s.enemies:
			if enemy.id == "hauler" and enemy.hp > 0:
				game.boss_panel.visible = true; game.boss_label.text = "HAULER / BREAK THE CARGO"; game.boss_bar.value = float(enemy.hp) / float(enemy.max_hp) * 100
	var ready: bool = s.robot.overdrive >= 100
	var cooldown := 99.0
	for combo in s.robot.combos():
		cooldown = minf(cooldown, float(s.robot.cooldowns.get(combo, 0)))
		ready = ready or cooldown <= 0
	game.special_button.disabled = not ready
	game.special_button.text = "OVERDRIVE" if s.robot.overdrive >= 100 else ("SPECIAL\nREADY" if ready else "SPECIAL")
	game.special_ring.value = 1.0 if ready else (s.robot.overdrive / 100.0 if s.robot.combos().is_empty() else 1.0 - clampf(cooldown / 12, 0, 1))
	game.special_ring.glow = false; charge.value = game.special_ring.value * 100
	if ready and not ready_before:
		ready_time = 0.4; game.audio.play("ready"); game.haptics.tap(15, 0.25); record(game, "special_ready", "settling ready border", 1)
	ready_before = ready
	game.reroll_button.visible = s.state == "running"; game.reroll_button.disabled = s.free_rerolls <= 0 and not game.ads.is_available()
	game.reroll_button.text = "RE-ROLL\nFREE" if s.free_rerolls > 0 else ("RE-ROLL\nWATCH" if game.ads.is_available() else "RE-ROLL\nUSED")
	if s.t < 5 and not game.save.data.tutorial_done and not gesture_seen: game.hint_label.text = "← DRAG TO AIM / BUILD YOUR MACHINE →"
	elif s.boss != null and not s.boss.attack.is_empty(): game.hint_label.text = "LEAVE THE MARKED ZONE"
	elif game._gate_charging(): game.hint_label.text = "AIM THROUGH THE PANEL TO CHARGE IT"
	else: game.hint_label.text = ""
	if clarity:
		var gate_gap: float = float(next.get("z", INF)) - s.z
		game.reroll_button.visible = s.state == "running" and gate_gap > 0 and gate_gap <= 28 and s.free_rerolls > 0
		game.special_button.modulate.a = 0.5 if game.special_button.disabled else 1.0
		if not gesture_seen: game.hint_label.text = "← DRAG TO AIM →"
		elif not family_guides.part and gate_gap <= 45: game.hint_label.text = "DRIVE THROUGH TO PICK A PART"
		elif not family_guides.mob and s.mob != null and s.state == "running": game.hint_label.text = "SHOOT THROUGH TO BOOST YOUR STREAM"
		else: game.hint_label.text = ""
		if s.state != "running" or hero_time > 0: game.hint_label.text = ""
	layout(game)

func hero(game, text: String, priority: int, color: Color, duration := 1.1) -> void:
	if hero_time > 0 and priority < hero_priority: return
	hero_time = duration; hero_priority = priority; hero_panel.visible = true; game.toast_label.text = text; game.toast_timer = duration
	game.toast_label.add_theme_color_override("font_color", color)

func record(game, action: String, response: String, strength: int) -> void:
	if OS.is_debug_build():
		feedback_counts[action] = int(feedback_counts.get(action, 0)) + 1
		var item := {"action": action, "response": response, "strength": strength, "sim_t": game.sim.t, "frame": frame, "reduce_motion": bool(game.save.data.settings.reduce_motion)}
		if feedback_log.size() < 4096: feedback_log.append(item)
		else: feedback_log[log_cursor] = item; log_cursor = (log_cursor + 1) % 4096

func on_event(game, event: Dictionary) -> void:
	var s: RunSim = game.sim
	var world = game.world
	var reduced: bool = bool(game.save.data.settings.reduce_motion)
	var rate := clampi(int(game.save.data.settings.get("flash_limit", 3)), 0, 3)
	var action := str(event.t)
	if action == "gate_choice": family_guides.part = true
	if action in ["mob_gate_pass", "hook_gate_pass"]: family_guides.mob = true
	var point := Vector3(float(event.get("x", s.x)), 0.1, s.z - float(event.get("z", s.z)))
	match action:
		"run_start": record(game, action, "sector / controls visible", 0)
		"death": game.audio.play("defeat"); record(game, action, "loss result / retry", 3)
		"combo_active": hero(game, "COMBO ONLINE / " + str(GameData.table("combos")[event.id].name).to_upper(), 50, BLUE); record(game, action, "combo receipt", 2)
		"buy_offer": record(game, action, "purchase screen", 1)
		"station_unavailable": hero(game, "NOT ENOUGH SCRAP", 50, INK); record(game, action, "unavailable receipt / optional offer", 1)
		"scrap":
			if event.has("chain"): game.last_chain = int(event.chain)
			pending_scrap += int(event.amount)
			if not reduced and rate > 0 and s.t - last_pickup >= 1.0 / rate + 0.002:
				game.pickup_glow = 0.18; receipt.text = "+%d" % pending_scrap; pending_scrap = 0; last_pickup = s.t
			if reduced or rate == 0: pending_scrap = 0
			game.audio.play("scrap")
			if int(event.get("chain", 0)) > 0 and int(event.get("chain", 0)) % 10 == 0: game.haptics.tap(8, 0.18)
			record(game, action, "counter / grouped receipt", 0)
		"part_attached", "part_upgraded":
			hero(game, str(event.id).to_upper() + " / L%d" % int(event.level), 40, GREEN)
			world.ui_feedback.ring(Vector3(s.x, 0.06, 0), GREEN, s.z)
			game.audio.play("upgrade" if action == "part_upgraded" else "attach"); game.haptics.tap(20, 0.4)
			record(game, action, "socket animation / attach receipt", 2)
		"stage_up":
			hero(game, "BATTLE FRAME ONLINE" if event.stage == 2 else "MONSTER FRAME ONLINE", 70, GREEN)
			world.ui_feedback.ring(Vector3(s.x, 0.06, 0), GREEN, s.z); game.audio.play("stage"); game.haptics.tap(55, 0.6)
			record(game, action, "evolution ring / frame receipt", 3)
		"part_replaced":
			game.combo_count = 0
			record(game, action, "socket replacement / updated chip", 1)
		"enemy_death":
			game.bump_combo(); world.ui_feedback.ring(point, BLUE, s.z); game.audio.play("explosion")
			record(game, action, "target ring / compact combo", 1)
		"weapon_fire":
			world.player.fire_kick = 1; game.audio.play("fire"); record(game, action, "muzzle recoil / visible projectile", 0)
		"player_hit":
			game.combo_count = 0; game.combo_label.text = ""
			hero(game, "HULL HIT / −%d" % int(event.amount), 80, RED)
			if not reduced and rate > 0 and s.t - last_player_flash >= 1.0 / rate + 0.002:
				world.player.flash(); last_player_flash = s.t; flash_times.append(s.t)
			game.audio.play("hit"); game.haptics.tap(40, 0.6)
			record(game, action, "local hull flash / health receipt", 3)
		"part_broken", "part_stolen":
			game.combo_count = 0
			lost_id = str(event.id); lost_time = 1.5
			hero(game, ("PART STOLEN / " if action == "part_stolen" else "PART LOST / ") + lost_id.to_upper(), 85, RED)
			game.audio.play("break"); game.haptics.tap(60, 0.7); record(game, action, "crossed lost-part chip", 3)
		"gate_choice":
			world.ui_feedback.confirm(int(event.side), world.gate_panel_count, float(event.z))
			if event.option.kind != "part": game.audio.play("attach"); game.haptics.tap(15, 0.3)
			record(game, action, "chosen lane / dimmed alternatives", 2)
		"gate_charge_tick", "gate_charged", "gate_level_up":
			if action == "gate_level_up":
				hero(game, "+%d LEVEL / CHARGE BONUS" % int(event.bonus), 55, GREEN); game.audio.play("upgrade"); game.haptics.tap(20, 0.4)
			record(game, action, "panel charge / bonus number", 1)
		"mob_gate_pass":
			world.ui_feedback.mob_pass(event)
			var trap: bool = event.type == "trap"
			var key := int(event.ord) * 4 + int(event.lane)
			if game.runtime - float(game.mob_popup_at.get(key, -10.0)) >= 0.8:
				game.mob_popup_at[key] = game.runtime
				hero(game, world._mob_panel_text({"t": event.type, "v": event.v}) + (" / STREAM REDUCED" if trap else " / STREAM BOOSTED"), 90 if trap else 60, RED if trap else GREEN, 0.9)
				game.audio.play("trap" if trap else "multiply"); game.haptics.tap(15, 0.35)
			world.ui_feedback.ring(point, RED if trap else BLUE, s.z)
			record(game, action, "gate number press / boosted drone tint", 2)
		"telegraph", "enemy_warning":
			hero(game, "DANGER / " + str(event.get("attack", "MARKED LANE")).replace("_", " ").to_upper(), 105, RED, 1.0)
			game.audio.play("warning"); game.audio.duck(true); game.haptics.tap(15, 0.3)
			record(game, action, "striped danger shape / priority warning", 3)
		"boss_attack":
			game.audio.duck(false); game.audio.play("hit"); world.ui_feedback.ring(Vector3(s.x, 0.05, -1.2), RED, s.z)
			record(game, action, "local impact / threat resolution", 2)
		"clean_dodge", "boss_exposed":
			hero(game, "CLEAN DODGE" if action == "clean_dodge" else "CORE OPEN / ×1.5", 45 if action == "clean_dodge" else 75, GREEN, 0.8)
			game.audio.play("dodge"); game.haptics.tap(10, 0.2); record(game, action, "dodge confirmation / weak-point ring", 1)
		"boss_intro", "boss_phase":
			var text := "SCRAP TITAN / CONTACT" if action == "boss_intro" else ("CORE EXPOSED" if event.phase == 2 else "TITAN ENRAGED")
			hero(game, text, 100, RED if action == "boss_intro" or event.get("phase", 3) == 3 else GREEN, 1.4)
			game.audio.play("warning" if action == "boss_intro" else "stage"); game.haptics.tap(40, 0.5); record(game, action, "boss state / phased health bar", 3)
		"special_used", "mob_champion":
			var text := "CHAMPION DEPLOYED" if action == "mob_champion" else ("OVERDRIVE RELEASED" if event.id == "overdrive" else str(GameData.table("combos")[event.id].name).to_upper())
			hero(game, text, 85 if action == "mob_champion" else 70, BLUE)
			world.ui_feedback.ring(Vector3(s.x, 0.06, -1), BLUE, s.z); game.audio.play("champion" if action == "mob_champion" else "special"); game.haptics.tap(55, 0.6)
			record(game, action, "deploy ring / special receipt", 3)
		"shield_block", "surge":
			hero(game, "SHIELD HELD" if action == "shield_block" else "OVERDRIVE CHARGED", 60, BLUE); game.audio.play("special"); game.haptics.tap(15, 0.3); world.ui_feedback.ring(Vector3(s.x, 0.06, 0), BLUE, s.z)
			record(game, action, "energy ring / ready state", 2)
		"repaired", "healed", "arm_recovered":
			hero(game, "PART RECOVERED" if action == "arm_recovered" else "REPAIR COMPLETE", 55, GREEN); game.audio.play("upgrade"); game.haptics.tap(20, 0.3); record(game, action, "restored chip / repair receipt", 2)
		"frenzy", "salvage_looted", "hauler_destroyed":
			hero(game, "SALVAGE BONUS / COINS ×2" if action == "frenzy" else "CARGO SECURED", 65, GOLD); game.audio.play("scrap" if action == "frenzy" else "victory"); game.haptics.tap(25, 0.4); world.ui_feedback.ring(point, GOLD, s.z)
			record(game, action, "gold payout / cargo ring", 2)
		"hauler_spawn", "hauler_missed", "salvage_spawn", "wave_spawn":
			var text: String = {"hauler_spawn": "HAULER / BREAK THE CARGO", "hauler_missed": "HAULER ESCAPED", "salvage_spawn": "SALVAGE / CHOOSE A TARGET", "wave_spawn": "INCOMING / HOLD YOUR LINE"}[action]
			hero(game, text, 50, INK); game.audio.play("warning"); record(game, action, "encounter cue", 1)
		"cluster_burst":
			world.ui_feedback.ring(point, Color("8197cf"), s.z)
			if not game.cluster_seen: game.cluster_seen = true; hero(game, "CLUSTER ROCKETS ONLINE", 55, BLUE); game.audio.play("stage")
			record(game, action, "cluster impact / first evolution receipt", 2)
		"boss_killed":
			game.kill_timer = 1.2; hero(game, "TITAN DISABLED", 110, GREEN); world.ui_feedback.ring(Vector3(0, 0.05, -17), GREEN, s.z); game.audio.play("victory"); game.haptics.tap(100, 0.8); record(game, action, "victory receipt / titan collapse", 3)

func steering(game) -> void:
	gesture_seen = true
	if last_steer_frame != frame:
		last_steer_frame = frame; record(game, "steer", "robot lean / mode-correct aim cue", 0)

func tick(game, delta: float) -> void:
	frame += 1
	motion_scale = 0.0 if bool(game.save.data.settings.reduce_motion) else 1.0
	hero_time = maxf(0, hero_time - delta); lost_time = maxf(0, lost_time - delta); ready_time = maxf(0, ready_time - delta)
	hero_panel.visible = hero_time > 0 and game.screen == "run"
	hero_panel.modulate.a = 1.0 if motion_scale == 0 else minf(1, hero_time / 0.15)
	if game.world.ui_feedback != null: game.world.ui_feedback.duck = hero_time > 0
	if hero_time > 0: game.hint_label.text = ""
	if hero_time <= 0: hero_priority = 0
	# Supporting info ducks slightly; danger/health remains fully readable.
	game.parts_row.modulate.a = 0.65 if hero_time > 0 else 1.0
	dock.modulate.a = 0.85 if hero_time > 0 else 1.0
	receipt.modulate.a = clampf(game.pickup_glow / 0.18, 0, 1)
	game.special_button.scale = Vector2.ONE * (1.0 + sin(ready_time / 0.4 * PI) * 0.035 * motion_scale)

func settings_ui(game, column: VBoxContainer) -> void:
	for id in ["sound", "music", "haptics", "reduce_motion", "left_handed"]:
		var key: String = id
		var on: bool = bool(game.save.data.settings.get(id, false))
		var title: String = {"sound": "SOUND", "music": "MUSIC", "haptics": "HAPTICS", "reduce_motion": "REDUCE MOTION", "left_handed": "LEFT-HANDED CONTROLS"}[id]
		column.add_child(game.make_button(title + (" / ON" if on else " / OFF"), func():
			game.save.data.settings[key] = not bool(game.save.data.settings.get(key, false)); game.save.write(); game._apply_settings(); game.show_settings(), false, "green" if on else "panel"))
	for id in ["sfx_volume", "music_volume"]:
		var key: String = id
		var title := label(game, ("SFX" if id == "sfx_volume" else "MUSIC") + " VOLUME", 36)
		column.add_child(title)
		var slider := VolumeSlider.new(); slider.min_value = 0; slider.max_value = 1; slider.step = 0.1; slider.value = float(game.save.data.settings.get(id, 1.0)); slider.custom_minimum_size.y = 120; slider.tooltip_text = title.text
		slider.value_changed.connect(func(value): game.save.data.settings[key] = value; game._apply_settings(); slider.queue_redraw())
		slider.drag_ended.connect(func(_changed): game.save.write())
		slider.focus_exited.connect(func(): game.save.write())
		column.add_child(slider)
	var flashes := OptionButton.new(); flashes.custom_minimum_size.y = 120; flashes.add_theme_font_override("font", game.body_font); flashes.add_theme_font_size_override("font_size", 36)
	for state in ["normal", "hover", "pressed"]: flashes.add_theme_stylebox_override(state, game.style(Color("edf3ec")))
	flashes.add_theme_color_override("font_color", INK)
	for rate in 4: flashes.add_item("LOCAL FLASHES / OFF" if rate == 0 else "LOCAL FLASHES / MAX %d PER SECOND" % rate)
	flashes.selected = clampi(int(game.save.data.settings.get("flash_limit", 3)), 0, 3)
	flashes.item_selected.connect(func(index): game.save.data.settings["flash_limit"] = index; game.save.write(); game._apply_settings())
	column.add_child(flashes)
