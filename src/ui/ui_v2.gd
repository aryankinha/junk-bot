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
var ready_before := false
var ready_time := 0.0
var last_parts := ""
var lost_id := ""
var lost_time := 0.0
var safe_override := Vector2.ZERO
var feedback_log: Array = []
var frame := 0
var optional_particles := 0
var gesture_seen := false
var motion_scale := 1.0

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
	game.boss_panel = VBoxContainer.new(); game.boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); game.boss_panel.offset_left = 50; game.boss_panel.offset_right = -50; support.add_child(game.boss_panel)
	game.boss_label = label(game, "SCRAP TITAN", 36); game.boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game.boss_panel.add_child(game.boss_label)
	game.boss_bar = game.bar(RED, 26); game.boss_panel.add_child(game.boss_bar)
	for phase in [0.33, 0.66]: add_tick(game.boss_bar, phase)
	hero_panel = PanelContainer.new(); hero_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); hero_panel.offset_left = -380; hero_panel.offset_right = 380; game.hud.add_child(hero_panel)
	hero_panel.add_theme_stylebox_override("panel", game.style(Color("edf3ec"), Color("4c6a5a"), 6, 0)); hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.toast_label = label(game, "", 42); game.toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game.toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hero_panel.add_child(game.toast_label); hero_panel.visible = false
	game.chain_label = label(game, "", 30, Color("936d24")); game.combo_label = label(game, "", 30, GREEN)
	for text in [game.chain_label, game.combo_label]:
		text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); text.offset_left = -400; text.offset_right = 400; text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; support.add_child(text)
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
	var marker := ColorRect.new(); marker.color = INK; marker.anchor_left = fraction; marker.anchor_right = fraction; marker.anchor_bottom = 1; marker.offset_left = -2; marker.offset_right = 2; marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; bar.add_child(marker)

func layout(game) -> void:
	var v: Vector2 = game.get_viewport().get_visible_rect().size
	var safe := Vector2(45, 45)
	if OS.has_feature("android"):
		var physical := DisplayServer.screen_get_size(); var usable := DisplayServer.get_display_safe_area()
		if physical.y > 0: safe = Vector2(maxf(45, float(usable.position.y) * v.y / physical.y), maxf(45, float(physical.y - usable.end.y) * v.y / physical.y))
	if safe_override != Vector2.ZERO: safe = safe_override
	game.top_bar.offset_top = safe.x
	var left: bool = bool(game.save.data.settings.get("left_handed", false))
	game.special_button.position = Vector2(v.x * (0.35 if left else 0.65) - 130, v.y - safe.y - 270); game.special_button.size = Vector2(260, 164)
	game.reroll_button.position = Vector2(v.x * (0.65 if left else 0.35) - 94, v.y - safe.y - 246); game.reroll_button.size = Vector2(188, 120)
	game.hint_label.offset_top = -380 - safe.y; game.hint_label.offset_bottom = -300 - safe.y
	var y: float = maxf(safe.x + 240, game.top_bar.offset_top + game.top_bar.size.y + 12)
	game.boss_panel.offset_top = y
	var boss_visible: bool = game.sim != null and (game.sim.boss != null or game.sim.enemies.any(func(e): return e.id == "hauler" and e.hp > 0))
	hero_panel.offset_top = y + (108 if boss_visible else 4); hero_panel.offset_bottom = hero_panel.offset_top + 90
	game.chain_label.offset_top = hero_panel.offset_bottom + 8; game.chain_label.offset_bottom = game.chain_label.offset_top + 34
	game.combo_label.offset_top = game.chain_label.offset_bottom; game.combo_label.offset_bottom = game.combo_label.offset_top + 34

func reset(game) -> void:
	hero_time = 0; hero_priority = 0; hero_panel.visible = false; ready_before = false; ready_time = 0; last_parts = ""; lost_time = 0; receipt.text = ""; feedback_log.clear(); frame = 0; gesture_seen = false
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
	game.special_button.text = "OVERDRIVE" if s.robot.overdrive >= 100 else ("SPECIAL READY" if ready else "SPECIAL")
	game.special_ring.value = 1.0 if ready else (s.robot.overdrive / 100.0 if s.robot.combos().is_empty() else 1.0 - clampf(cooldown / 12, 0, 1))
	game.special_ring.glow = false; charge.value = game.special_ring.value * 100
	if ready and not ready_before:
		ready_time = 0.4; game.audio.play("special"); game.haptics.tap(15, 0.25); record(game, "special_ready", "settling ready border", 1)
	ready_before = ready
	game.reroll_button.visible = s.state == "running"; game.reroll_button.disabled = s.free_rerolls <= 0 and not game.ads.is_available()
	game.reroll_button.text = "RE-ROLL\nFREE" if s.free_rerolls > 0 else ("RE-ROLL\nWATCH" if game.ads.is_available() else "RE-ROLL\nUSED")
	if s.t < 5 and not game.save.data.tutorial_done and not gesture_seen: game.hint_label.text = "← DRAG TO AIM / BUILD YOUR MACHINE →"
	elif s.boss != null and not s.boss.attack.is_empty(): game.hint_label.text = "LEAVE THE MARKED ZONE"
	elif game._gate_charging(): game.hint_label.text = "AIM THROUGH THE PANEL TO CHARGE IT"
	else: game.hint_label.text = ""
	layout(game)

func hero(game, text: String, priority: int, color: Color, duration := 1.1) -> void:
	if hero_time > 0 and priority < hero_priority: return
	hero_time = duration; hero_priority = priority; hero_panel.visible = true; game.toast_label.text = text; game.toast_timer = duration
	game.toast_label.add_theme_color_override("font_color", color)

func record(game, action: String, response: String, strength: int) -> void:
	if OS.is_debug_build():
		feedback_log.append({"action": action, "response": response, "strength": strength, "sim_t": game.sim.t, "frame": frame, "reduce_motion": bool(game.save.data.settings.reduce_motion)})
		if feedback_log.size() > 4096: feedback_log.pop_front()

func on_event(game, event: Dictionary) -> void:
	# Feedback map is extended in UI-2. Existing persistent/ad event handling stays in RunView.
	match str(event.t):
		"scrap": game.pickup_glow = 0.18; receipt.text = "+%d" % int(event.amount); record(game, "scrap", "counter receipt", 0)
		"part_attached", "part_upgraded": hero(game, str(event.id).to_upper() + " / L%d" % int(event.level), 40, GREEN); game.audio.play("attach"); game.haptics.tap(20, 0.4); record(game, event.t, "attach receipt", 2)
		"enemy_death": game.bump_combo(); game.audio.play("explosion"); record(game, event.t, "target confirmation", 1)
		"weapon_fire": game.world.player.fire_kick = 1; game.audio.play("fire"); record(game, event.t, "muzzle recoil", 0)
		"player_hit": hero(game, "HULL HIT / −%d" % int(event.amount), 80, RED); game.audio.play("hit"); game.haptics.tap(40, 0.6); record(game, event.t, "damage receipt", 3)
		"part_broken", "part_stolen": lost_id = str(event.id); lost_time = 1.5; hero(game, "PART LOST / " + lost_id.to_upper(), 85, RED); game.audio.play("break"); game.haptics.tap(60, 0.7); record(game, event.t, "lost chip", 3)
		"boss_intro": hero(game, "SCRAP TITAN / CONTACT", 100, RED, 1.5); game.audio.play("warning"); record(game, event.t, "boss receipt", 3)
		"boss_killed": game.kill_timer = 1.2; hero(game, "TITAN DISABLED", 110, GREEN); game.audio.play("victory"); game.haptics.tap(100, 0.8); record(game, event.t, "victory receipt", 3)

func tick(game, delta: float) -> void:
	frame += 1
	motion_scale = 0.0 if bool(game.save.data.settings.reduce_motion) else 1.0
	hero_time = maxf(0, hero_time - delta); lost_time = maxf(0, lost_time - delta); ready_time = maxf(0, ready_time - delta)
	hero_panel.visible = hero_time > 0 and game.screen == "run"
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
		var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 1; slider.step = 0.1; slider.value = float(game.save.data.settings.get(id, 1.0)); slider.custom_minimum_size.y = 120; slider.tooltip_text = title.text
		slider.value_changed.connect(func(value): game.save.data.settings[key] = value; game._apply_settings())
		slider.drag_ended.connect(func(_changed): game.save.write())
		slider.focus_exited.connect(func(): game.save.write())
		column.add_child(slider)
	var flashes := OptionButton.new(); flashes.custom_minimum_size.y = 120; flashes.add_theme_font_override("font", game.body_font); flashes.add_theme_font_size_override("font_size", 36)
	for rate in 4: flashes.add_item("LOCAL FLASHES / OFF" if rate == 0 else "LOCAL FLASHES / MAX %d PER SECOND" % rate)
	flashes.selected = clampi(int(game.save.data.settings.get("flash_limit", 3)), 0, 3)
	flashes.item_selected.connect(func(index): game.save.data.settings["flash_limit"] = index; game.save.write(); game._apply_settings())
	column.add_child(flashes)
