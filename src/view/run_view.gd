extends Node3D
const NAVY = Color("17253b")
const CREAM = Color("f9efdb")
const MUTED = Color("b1bbc8")
const GREEN = Color("43d17a")
const ORANGE = Color("f28c28")
var sim: RunSim
var world: WorldView
var camera: Camera3D
var save := SaveStore.new()
var audio: GameAudio
var haptics := HapticsService.new()
var ads: AdsService
var perf := PerfLog.new()
var hud: Control
var overlay: Control
var top_bar: PanelContainer
var level_label: Label
var scrap_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var parts_label: Label
var progress_bar: ProgressBar
var boss_panel: VBoxContainer
var boss_label: Label
var boss_bar: ProgressBar
var hint_label: Label
var toast_label: Label
var special_button: Button
var reroll_button: Button
var debug_label: Label
var flash: ColorRect
var accumulator := 0.0
var runtime := 0.0
var toast_timer := 0.0
var hit_stop := 0.0
var shake := 0.0
var paused := false
var screen := "run"
var result_recorded := false
var result_reward := 0
var result_texture: ImageTexture
var daily := false
var daily_key := ""
var bot: BotController
var capture := false
var snapshot_at := -1.0
var snapshot_path := ""
var exit_after := -1.0
var last_perf_save := 0.0
var kill_timer := 0.0
var ui_tick := 0.0
var settings_return := "hangar"
var hangar_model: RobotBuilder
var display_font: Font
var body_font: Font
var reward_doubled := false
var run_paid := 0
var run_saved := false
var run_win_applied := false
var run_start_streak := 0
var streak_saved := false
var debug_touches: Dictionary = {}
var stress_mode := false
var stress_marker := ""
var stress_done := false
var last_movie_frame := -1
var perf_output := "res://results/desktop_perf.json"

func _ready() -> void:
	GameData.load_all()
	display_font = load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf")
	body_font = load("res://assets/fonts/barlow_Barlow-SemiBold.ttf")
	save.load_save()
	for arg in OS.get_cmdline_user_args():
		if arg == "--stress" and OS.is_debug_build():
			stress_mode = true
		elif arg == "--capture":
			capture = true
		elif arg.begins_with("--perf-output="):
			perf_output = arg.get_slice("=", 1)
		elif arg.begins_with("--snapshot-at="):
			snapshot_at = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--snapshot-path="):
			snapshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--exit-after="):
			exit_after = arg.get_slice("=", 1).to_float()
	if capture:
		save.path = "user://capture_save.json"
		save.data = save.defaults()
	audio = GameAudio.new()
	add_child(audio)
	ads = AdsService.new()
	add_child(ads)
	ads.reward_granted.connect(_reward_earned)
	ads.availability_changed.connect(func():
		if screen == "result":
			show_result()
		elif screen == "repair_offer":
			show_repair_offer())
	ads.dismissed.connect(func():
		if screen in ["run", "pause", "repair_offer"] and sim.state in ["running", "boss"]:
			resume_run()
		elif screen == "result":
			show_result())
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e9c98f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e7e1d5")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffefd5")
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)
	world = WorldView.new()
	add_child(world)
	camera = Camera3D.new()
	camera.fov = 62
	camera.position = Vector3(0, 7.8, 9.5)
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, -7.5))
	camera.current = true
	_build_hud()
	_apply_settings()
	start_run(false)
	if OS.is_debug_build():
		for attempt in range(1, 4):
			var marker := "scrap_stress_a%d" % attempt
			if FileAccess.file_exists("user://" + marker) and not FileAccess.file_exists("user://done_" + marker):
				stress_marker = marker
				stress_mode = true
				break
	if stress_mode:
		sim.beats.clear()
		sim.boss_z = 100000
		for id in ["cannon", "rocket", "wheels", "armour"]:
			sim.robot.add_part(id, null, 3)
	if bool(save.data.tutorial_done) and not capture and not stress_mode:
		show_hangar()

func style(color: Color, border := Color.TRANSPARENT, radius := 22) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box

func text_label(value: String, size := 36, color := CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", display_font if size >= 44 else body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_button(value: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_override("font", display_font)
	button.custom_minimum_size.y = 124
	button.add_theme_font_size_override("font_size", 38)
	button.add_theme_color_override("font_color", NAVY if primary else CREAM)
	button.add_theme_color_override("font_disabled_color", Color("687789"))
	button.add_theme_stylebox_override("normal", style(GREEN if primary else Color("293d56")))
	button.add_theme_stylebox_override("hover", style(Color("66e394") if primary else Color("3b526d")))
	button.add_theme_stylebox_override("pressed", style(ORANGE))
	button.add_theme_stylebox_override("disabled", style(Color("202c3e")))
	button.pressed.connect(func():
		audio.play("click")
		haptics.tap(10, 0.2)
		action.call())
	return button

func bar(color: Color, height := 22) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size.y = height
	node.show_percentage = false
	node.add_theme_stylebox_override("background", style(Color("334154"), Color.TRANSPARENT, 8))
	node.add_theme_stylebox_override("fill", style(color, Color.TRANSPARENT, 8))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var safe_top := 45.0
	var safe_bottom := 45.0
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var size := DisplayServer.screen_get_size()
		if size.y > 0:
			safe_top = maxf(35, float(safe.position.y) * 1920.0 / size.y)
			safe_bottom = maxf(35, float(size.y - safe.end.y) * 1920.0 / size.y)
	top_bar = PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 38
	top_bar.offset_right = -38
	top_bar.offset_top = safe_top
	top_bar.add_theme_stylebox_override("panel", style(NAVY))
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	top_bar.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	level_label = text_label("JUNKYARD  /  01", 38)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(level_label)
	scrap_label = text_label("0  SCRAP", 38, MeshFactory.YELLOW)
	row.add_child(scrap_label)
	var hp_row := HBoxContainer.new()
	column.add_child(hp_row)
	hp_bar = bar(GREEN, 26)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for threshold in GameData.constants().part_break_thresholds:
		var tick := ColorRect.new()
		tick.color = NAVY
		tick.anchor_left = float(threshold)
		tick.anchor_right = float(threshold)
		tick.anchor_bottom = 1
		tick.offset_left = -2
		tick.offset_right = 2
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bar.add_child(tick)
	hp_row.add_child(hp_bar)
	hp_label = text_label("60 / 60", 30)
	hp_row.add_child(hp_label)
	parts_label = text_label("TINY BOT  ·  BUILD YOUR MACHINE", 30, MUTED)
	column.add_child(parts_label)
	progress_bar = bar(ORANGE, 8)
	column.add_child(progress_bar)
	boss_panel = VBoxContainer.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_panel.offset_top = safe_top + 245
	boss_panel.offset_left = 70
	boss_panel.offset_right = -70
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_panel)
	boss_label = text_label("SCRAP TITAN  ·  PLATED", 38, NAVY)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_label)
	boss_bar = bar(MeshFactory.RED, 24)
	boss_panel.add_child(boss_bar)
	toast_label = text_label("", 52, NAVY)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -480
	toast_label.offset_right = 480
	toast_label.offset_top = 420
	toast_label.offset_bottom = 570
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	hint_label = text_label("DRAG TO STEER\nChoose a gate. Build something bigger.", 36, NAVY)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_left = 40
	hint_label.offset_right = -40
	hint_label.offset_top = -310 - safe_bottom
	hint_label.offset_bottom = -175 - safe_bottom
	hud.add_child(hint_label)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -155 - safe_bottom
	bottom.offset_bottom = -safe_bottom
	bottom.add_theme_constant_override("separation", 16)
	hud.add_child(bottom)
	var pause_button := make_button("II", show_pause)
	pause_button.custom_minimum_size.x = 130
	bottom.add_child(pause_button)
	reroll_button = make_button("RE-ROLL", func():
		if sim.free_rerolls <= 0 and ads.is_available():
			ads.show_rewarded("reroll")
		elif sim.reroll():
			toast("New parts ahead")
		else:
			toast("Free re-roll used"))
	reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(reroll_button)
	special_button = make_button("SPECIAL", func(): sim.tap_special(), true)
	special_button.custom_minimum_size.x = 310
	bottom.add_child(special_button)
	debug_label = text_label("", 24, NAVY)
	debug_label.position = Vector2(40, 350)
	debug_label.visible = false
	hud.add_child(debug_label)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.15, 0.1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	canvas.add_child(overlay)

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.visible = true

func menu(title: String, subtitle: String) -> VBoxContainer:
	_clear_overlay()
	var cover := ColorRect.new()
	cover.color = Color(0.045, 0.08, 0.13, 0.94)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cover)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 70)
	overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	column.add_child(text_label("S C R A P   D R A G O N", 30, ORANGE))
	column.add_child(text_label(title, 76))
	var sub := text_label(subtitle, 34, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)
	return column

func spacer(parent: Control) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)

func start_run(is_daily := false) -> void:
	daily = is_daily
	daily_key = Time.get_date_string_from_system(true)
	var seed_arg := int(daily_key.replace("-", "")) if daily else int(Time.get_unix_time_from_system())
	if capture:
		seed_arg = 20261031
	var level := 1 if daily else int(save.data.level)
	sim = RunSim.new()
	sim.setup(level, seed_arg, {} if daily else save.data.part_tiers, 0 if daily else int(save.data.losses_on_level), [] if daily else save.data.unlocked_parts)
	bot = BotController.new(seed_arg, "perfect", 0) if capture else null
	perf = PerfLog.new()
	reward_doubled = false
	run_paid = 0
	run_saved = false
	run_win_applied = false
	run_start_streak = int(save.data.streak)
	streak_saved = false
	result_recorded = false
	result_texture = null
	kill_timer = 0
	screen = "run"
	paused = false
	accumulator = 0
	toast_timer = 0
	toast_label.text = ""
	overlay.visible = false
	hud.visible = true
	world.boss_root.scale = Vector3.ONE
	world.gate_signature = ""
	audio.music("run_music")
	world.sync(sim, 0)

func toast(value: String) -> void:
	toast_label.text = value
	toast_timer = 1.8

func _events() -> void:
	for event in sim.events:
		if event.t not in ["scrap", "weapon_fire"]:
			TelemetryLog.log_event(event)
		match str(event.t):
			"part_attached", "part_upgraded":
				var id: String = event.id
				toast(GameData.table("parts")[id].levels[int(event.level) - 1].name.to_upper() + "  +")
				audio.play("upgrade" if event.t == "part_upgraded" else "attach")
				haptics.tap(20, 0.4)
				world.burst(Vector3(sim.x, 1.3, 0))
				shake = 0.15
				hit_stop = 0.04
			"stage_up":
				toast("BATTLE BOT" if event.stage == 2 else "SCRAP MONSTER")
				audio.play("stage")
				haptics.tap(60, 0.7)
				world.burst(Vector3(sim.x, 0.5, 0), 20)
				shake = 0.4
			"part_broken", "part_stolen", "part_replaced":
				toast(("PART STOLEN" if event.t == "part_stolen" else "PART LOST") + "\n" + GameData.table("parts")[event.id].name)
				audio.play("break")
				haptics.tap(80, 0.8)
				world.burst(Vector3(sim.x, 1.3, 0), 12)
				hit_stop = 0.06
			"player_hit":
				audio.play("hit")
				haptics.tap(40, 0.6)
				flash.color.a = 0.22
				shake = 0.4
			"shield_block": toast("SHIELD BLOCKED THE HIT")
			"enemy_death":
				audio.play("explosion")
				world.burst(Vector3(event.x, 0.8, sim.z - float(event.z)), 6)
			"scrap": audio.play("scrap")
			"weapon_fire": audio.play("fire")
			"telegraph", "enemy_warning":
				audio.play("warning")
				audio.duck(true)
			"boss_attack":
				audio.duck(false)
				audio.play("hit")
				shake = 0.5
			"buy_offer":
				if sim.state == "choosing":
					show_purchase()
			"boss_intro": toast("SCRAP TITAN\nDodge the red warnings")
			"boss_phase":
				toast("CORE EXPOSED" if event.phase == 2 else "ENRAGED")
				audio.play("stage")
				shake = 0.5
			"clean_dodge": audio.play("dodge")
			"special_used":
				toast("OVERDRIVE" if event.id == "overdrive" else GameData.table("combos")[event.id].name.to_upper())
				audio.play("special")
				haptics.tap(50, 0.6)
			"combo_active":
				if not daily and not save.data.codex.has(event.id):
					save.data.codex.append(event.id)
					save.data.cogs += 25
					save.write()
			"repaired", "arm_recovered":
				toast("PARTS RESTORED")
				audio.play("upgrade")
			"boss_killed":
				audio.play("victory")
				haptics.tap(150, 1)
				world.burst(Vector3(0, 3.5, -17), 24)
				kill_timer = 1.2
				toast("TITAN DOWN")
			"station_unavailable":
				toast("Not enough scrap")
				if ads.is_available():
					show_repair_offer()
	sim.events.clear()

func _process(delta: float) -> void:
	# Raw wall-time logging stays enabled in gameplay; movie replay advances by frame.
	if capture and OS.get_cmdline_args().has("--write-movie"):
		var drawn := Engine.get_frames_drawn()
		delta = (1.0 / 60.0) if last_movie_frame < 0 else maxf(0.0, float(drawn - last_movie_frame) / 60.0)
		last_movie_frame = drawn
	runtime += delta
	if sim == null:
		return
	if screen == "run" and not paused:
		var frame_delta := minf(delta, 0.1)
		if hit_stop > 0:
			hit_stop -= frame_delta
		else:
			accumulator += frame_delta
			while accumulator >= 1.0 / 60:
				if bot != null:
					bot.control(sim)
				if stress_mode:
					sim.robot.hp = sim.robot.max_hp
					sim.spawn_pack("scrapper", maxi(0, 20 - sim.enemies.size()), sim.z + 15)
					for enemy in sim.enemies:
						if float(enemy.z) - sim.z < 5:
							enemy.z = sim.z + 15
					for shot in maxi(0, 40 - sim.bullets.size()):
						sim._fire({"id": "stress", "type": "projectile", "damage": 14, "speed": 36})
				sim.step(1.0 / 60)
				accumulator -= 1.0 / 60
		_events()
		world.sync(sim, frame_delta * (0.25 if kill_timer > 0 else 1))
		perf.sample()
		if runtime - last_perf_save > 5:
			perf.write()
			last_perf_save = runtime
		var offset := Vector3(0, 8.5, 11) if sim.boss != null else Vector3(0, 7.8, 9.5)
		if kill_timer > 0:
			var angle := (1.2 - kill_timer) / 1.2 * PI / 3
			offset = Vector3(sin(angle) * 10, 7.5, cos(angle) * 10)
		camera.position = camera.position.lerp(offset, 1 - exp(-delta * 5))
		camera.look_at(Vector3(0, 0.7, -8 if sim.boss != null else -7.5))
		shake = maxf(0, shake - delta * 2.5)
		var motion := 0.3 if save.data.settings.get("reduce_motion", false) else 1.0
		camera.h_offset = sin(runtime * 95) * shake * 0.2 * motion
		camera.v_offset = cos(runtime * 83) * shake * 0.15 * motion
		toast_timer -= delta
		if toast_timer <= 0:
			toast_label.text = ""
		flash.color.a = maxf(0, flash.color.a - delta * 1.5)
		ui_tick += delta
		if ui_tick > 0.1:
			_update_hud()
			ui_tick = 0
		if sim.state in ["won", "lost"]:
			if kill_timer > 0:
				kill_timer -= delta
			else:
				_finish_run()
	elif screen == "hangar":
		world.player.rotation.y += delta * 0.3
		if is_instance_valid(hangar_model):
			hangar_model.rotation.y += delta * 0.4
	if stress_mode and not stress_done and runtime >= 60:
		stress_done = true
		perf.write()
		if not stress_marker.is_empty():
			FileAccess.open("user://done_" + stress_marker, FileAccess.WRITE).store_string("completed")
		screen = "stress_done"
		toast_label.text = "STRESS TEST COMPLETE"
	if snapshot_at >= 0 and runtime >= snapshot_at:
		snapshot_at = -1
		await RenderingServer.frame_post_draw
		if not snapshot_path.is_empty():
			get_viewport().get_texture().get_image().save_png(snapshot_path)
	if exit_after > 0 and runtime >= exit_after:
		perf.write()
		perf.write(perf_output)
		get_tree().quit()

func _update_hud() -> void:
	level_label.text = "DAILY  /  JUNKYARD" if daily else "JUNKYARD  /  %02d" % sim.level
	scrap_label.text = "%d  SCRAP" % sim.robot.scrap
	hp_bar.value = sim.robot.hp / sim.robot.max_hp * 100
	hp_label.text = "%d / %d" % [sim.robot.hp, sim.robot.max_hp]
	var names: Array[String] = []
	for id in sim.robot.parts:
		names.append("%s %d" % [str(id).to_upper(), int(sim.robot.parts[id])])
	parts_label.text = " · ".join(names) if not names.is_empty() else "TINY BOT  ·  BUILD YOUR MACHINE"
	parts_label.add_theme_font_size_override("font_size", 26 if names.size() > 3 else 30)
	progress_bar.value = sim.z / sim.boss_z * 100
	boss_panel.visible = sim.boss != null
	if sim.boss != null:
		var tag: String = ["PLATED", "GRABBER", "ENRAGED"][sim.boss.phase - 1]
		boss_label.text = "SCRAP TITAN  /  " + tag
		if int(save.data.streak) >= 3:
			boss_label.text += "  ◇ CORE"
		boss_bar.value = sim.boss.hp / sim.boss.max_hp * 100
	var combos := sim.robot.combos()
	var ready := sim.robot.overdrive >= 100
	var available_combo := ""
	var minimum := 99.0
	for id in combos:
		var cooldown := float(sim.robot.cooldowns.get(id, 0))
		minimum = minf(minimum, cooldown)
		if cooldown <= 0:
			ready = true
			available_combo = id
	special_button.disabled = not ready
	special_button.text = "OVERDRIVE" if sim.robot.overdrive >= 100 else ("SPECIAL" if ready else ("%ds" % ceil(minimum) if not combos.is_empty() else "%d%%" % sim.robot.overdrive))
	reroll_button.visible = sim.state == "running"
	reroll_button.disabled = sim.free_rerolls <= 0 and not ads.is_available()
	reroll_button.text = "RE-ROLL · WATCH" if sim.free_rerolls <= 0 and ads.is_available() else "RE-ROLL"
	if sim.t < 8 and not bool(save.data.tutorial_done):
		hint_label.text = "←  DRAG TO STEER  →\nChoose a gate. Build something bigger."
	elif sim.boss != null:
		hint_label.text = "MOVE OUT OF THE RED" if not sim.boss.attack.is_empty() else ("BREAK THE ARM TO RECOVER YOUR PART" if sim.boss.arm_hp > 0 else "AUTO-FIRE ACTIVE  ·  DODGE & BUILD OVERDRIVE")
	elif not available_combo.is_empty():
		hint_label.text = GameData.table("combos")[available_combo].name.to_upper() + " READY"
	else:
		hint_label.text = ""
		for id in GameData.table("combos"):
			var def: Dictionary = GameData.table("combos")[id]
			if def.get("stretch", false):
				continue
			var owned := int(sim.robot.parts.has(def.needs[0])) + int(sim.robot.parts.has(def.needs[1]))
			if owned == 1:
				var missing: String = def.needs[1] if sim.robot.parts.has(def.needs[0]) else def.needs[0]
				hint_label.text = "%s + ?  →  %s" % [missing.to_upper(), def.name.to_upper()]
				break
	debug_label.text = "%d FPS  ·  %d DRAWS  ·  %s" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), sim.state]
	debug_label.visible = debug_label.visible and OS.is_debug_build() and not capture

func _finish_run() -> void:
	if not result_recorded:
		result_recorded = true
		var won := sim.state == "won"
		result_reward = Economy.reward(sim.robot.collected, sim.level, won, run_start_streak) * (2 if reward_doubled else 1)
		if daily:
			save.data.best_daily[daily_key] = maxi(int(save.data.best_daily.get(daily_key, 0)), result_reward)
		else:
			save.data.cogs += maxi(0, result_reward - run_paid)
			run_paid = maxi(run_paid, result_reward)
			if not run_saved:
				save.data.stats.runs = int(save.data.stats.runs) + 1
				run_saved = true
			save.data.tutorial_done = true
			if won and not run_win_applied:
				run_win_applied = true
				save.data.level = mini(5, sim.level + 1)
				save.data.streak = run_start_streak + 1
				save.data.stats.wins = int(save.data.stats.wins) + 1
				save.data.losses_on_level = 0
			else:
				save.data.streak = 0
				save.data.losses_on_level += 1
			save.write()
		save.write()
		perf.write()
		# Capture the actual final build before covering the gameplay view.
		if DisplayServer.get_name() != "headless":
			screen = "finishing"
			result_texture = await capture_build()
	show_result()

func capture_build() -> ImageTexture:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 600)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var backdrop := WorldEnvironment.new()
	backdrop.environment = Environment.new()
	backdrop.environment.background_mode = Environment.BG_COLOR
	backdrop.environment.background_color = NAVY
	backdrop.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	backdrop.environment.ambient_light_color = CREAM
	backdrop.environment.ambient_light_energy = 0.9
	viewport.add_child(backdrop)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(sun)
	var model := RobotBuilder.new()
	viewport.add_child(model)
	model.rotation_degrees.y = 155
	model.sync(sim.robot, false)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 3.3, 5.8)
	viewport.add_child(cam)
	cam.look_at(Vector3(0, 1, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return texture

func show_result() -> void:
	screen = "result"
	hud.visible = false
	var won := sim.state == "won"
	var column := menu("TITAN DOWN" if won else "REBUILD. RETRY.", "The machine you built made it this far.")
	if result_texture != null:
		var image := TextureRect.new()
		image.texture = result_texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size.y = 500
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(image)
	column.add_child(text_label(build_name(), 44, ORANGE))
	column.add_child(text_label("%d COGS   ·   %d PARTS LOST" % [result_reward, sim.robot.parts_lost], 38))
	if daily:
		column.add_child(text_label("Daily best  %d" % save.data.best_daily.get(daily_key, 0), 34, MUTED))
	if not won:
		var tip := text_label("Tip: move before the red warning resolves. Rockets bypass the Titan's front plate.", 34, MUTED)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(tip)
	if ads.is_available():
		if not reward_doubled:
			column.add_child(make_button("DOUBLE COGS  ·  WATCH", func(): ads.show_rewarded("double")))
		if not won and run_start_streak > 0 and not streak_saved:
			column.add_child(make_button("SAVE STREAK  ·  WATCH", func(): ads.show_rewarded("streak")))
		if not won and not sim.revived:
			column.add_child(make_button("REVIVE  ·  WATCH", func(): ads.show_rewarded("revive")))
	column.add_child(make_button("NEXT LEVEL" if won else "TRY AGAIN", func():
		TelemetryLog.log_event({"t": "retry"})
		start_run(daily), true))
	column.add_child(make_button("HANGAR", show_hangar))

func build_name() -> String:
	if sim.robot.parts.has("rocket") and sim.robot.parts.has("armour"):
		return "THE ROCKET TANK"
	if sim.robot.parts.has("wheels"):
		return "THE SCRAP SPEEDSTER"
	if sim.robot.parts.has("magnet"):
		return "THE JUNK COLLECTOR"
	return "THE IRON SURVIVOR"

func show_hangar(tab := "upgrades") -> void:
	screen = "hangar"
	hud.visible = false
	audio.music("hangar_music")
	world.player.rotation.y = 0
	var column := menu("THE HANGAR", "%d COGS  /  LEVEL %d  /  STREAK %d" % [save.data.cogs, save.data.level, save.data.streak])
	_hangar_preview(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for id in ["upgrades", "armoury", "codex"]:
		var tab_id: String = id
		var button := make_button(id.capitalize(), func(): show_hangar(tab_id), tab == id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 31)
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	if tab == "codex":
		for id in GameData.table("combos"):
			var def: Dictionary = GameData.table("combos")[id]
			if def.get("stretch", false):
				continue
			var found: bool = save.data.codex.has(id)
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", style(Color("26384e")))
			list.add_child(card)
			var txt := text_label((def.name if found else "?  UNDISCOVERED") + "\n" + " + ".join(def.needs), 38, GREEN if found else MUTED)
			card.add_child(txt)
	else:
		var highlighted := false
		for id in GameData.table("parts"):
			var part_id: String = id
			var def: Dictionary = GameData.table("parts")[id]
			if tab == "armoury":
				if not GameData.table("economy").unlock_costs.has(id):
					continue
				var cost: int = int(GameData.table("economy").unlock_costs[id])
				var unlocked: bool = save.data.unlocked_parts.has(id) or int(save.data.level) >= int(def.unlock_level)
				var button := make_button("%s  /  %s" % [def.name, "AVAILABLE" if unlocked else "%d COGS" % cost], func():
					save.unlock(part_id)
					show_hangar("armoury"))
				button.disabled = unlocked or int(save.data.cogs) < cost
				list.add_child(button)
			else:
				var tier := int(save.data.part_tiers.get(id, 1))
				var cost := Economy.upgrade_cost(tier)
				var title := "%s   %d/5\n%s" % [def.name, tier, ("MAX TIER" if cost < 0 else "+8%% MAIN STAT   ·   %d COGS" % cost)]
				var affordable := cost > 0 and int(save.data.cogs) >= cost
				var highlight := affordable and not highlighted
				highlighted = highlighted or highlight
				var button := make_button(title, func():
					if save.buy_upgrade(part_id):
						audio.play("upgrade")
					show_hangar(), highlight)
				button.add_theme_font_size_override("font_size", 34)
				button.custom_minimum_size.y = 150
				button.disabled = cost < 0 or int(save.data.cogs) < cost
				list.add_child(button)
				if highlight:
					var pulse := button.create_tween().set_loops()
					pulse.tween_property(button, "modulate", Color(0.75, 1, 0.85), 0.65)
					pulse.tween_property(button, "modulate", Color.WHITE, 0.65)
	column.add_child(make_button("PLAY  /  LEVEL %d" % save.data.level, func(): start_run(false), true))
	column.add_child(make_button("DAILY CHALLENGE", func(): start_run(true)))
	column.add_child(make_button("SETTINGS & CREDITS", func():
		settings_return = "hangar"
		show_settings()))

func _hangar_preview(column: VBoxContainer) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size.y = 290
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 290)
	viewport.own_world_3d = true
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15243a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(sun)
	hangar_model = RobotBuilder.new()
	viewport.add_child(hangar_model)
	hangar_model.rotation_degrees.y = 155
	hangar_model.sync(sim.robot, false)
	var cam := Camera3D.new()
	cam.fov = 35
	cam.position = Vector3(0, 2.8, 5.7)
	viewport.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))

func show_pause() -> void:
	paused = true
	screen = "pause"
	var column := menu("TAKE A BREATH", "Your build is waiting.")
	spacer(column)
	column.add_child(make_button("RESUME", resume_run, true))
	column.add_child(make_button("SETTINGS", func():
		settings_return = "pause"
		show_settings()))
	column.add_child(make_button("HANGAR", show_hangar))

func resume_run() -> void:
	paused = false
	screen = "run"
	overlay.visible = false
	hud.visible = true
	accumulator = 0
	perf.previous = 0
	audio.music("run_music")

func show_settings() -> void:
	screen = "settings"
	var column := menu("MAKE IT YOURS", "Sound, comfort and credits")
	for id in ["sound", "music", "haptics", "reduce_motion"]:
		var key: String = id
		var enabled: bool = bool(save.data.settings.get(id, false))
		column.add_child(make_button("%s   /   %s" % [id.replace("_", " ").to_upper(), "ON" if enabled else "OFF"], func():
			save.data.settings[key] = not bool(save.data.settings[key])
			save.write()
			_apply_settings()
			show_settings()))
	var privacy := "Google test ads may use device and network information." if Engine.has_singleton("PoingGodotAdMob") else "This build sends no game data to a server."
	var credits := text_label("Original procedural models & sound.\nBuilt with Godot.\nThanks: Kenney.nl & Quaternius.\nProgress stays on this device.\n" + privacy, 34, MUTED)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(credits)
	if Engine.has_singleton("PoingGodotAdMob"):
		column.add_child(make_button("GOOGLE PRIVACY INFORMATION", func(): OS.shell_open("https://policies.google.com/privacy")))
	spacer(column)
	column.add_child(make_button("RESET PROGRESS", show_reset))
	column.add_child(make_button("BACK", func():
		if settings_return == "pause":
			show_pause()
		else:
			show_hangar(), true))

func show_reset() -> void:
	var column := menu("START FRESH?", "This removes local Cogs, upgrades and records.")
	spacer(column)
	column.add_child(make_button("KEEP MY BUILD", show_settings, true))
	column.add_child(make_button("RESET LOCAL PROGRESS", func():
		save.data = save.defaults()
		save.write()
		_apply_settings()
		start_run(false)))

func _apply_settings() -> void:
	audio.enabled = bool(save.data.settings.sound)
	audio.music_enabled = bool(save.data.settings.music)
	haptics.enabled = bool(save.data.settings.haptics)
	if audio.music_player != null:
		if not audio.music_enabled:
			audio.music_player.stop()
		else:
			audio.music("hangar_music" if screen == "hangar" else "run_music")

func _reward_earned(placement: String) -> void:
	match placement:
		"revive":
			if sim.revive():
				result_recorded = false
				resume_run()
		"double":
			if not reward_doubled:
				save.data.cogs += result_reward
				run_paid += result_reward
				result_reward *= 2
				reward_doubled = true
				save.write()
			show_result()
		"streak":
			streak_saved = true
			save.data.streak = run_start_streak
			save.write()
			show_result()
		"repair":
			sim.robot.repair(sim)
			resume_run()
		"reroll":
			sim.free_rerolls += 1
			sim.reroll()

func show_purchase() -> void:
	screen = "purchase"
	paused = true
	var column := menu("PICK YOUR PART", "One new attachment. Make it count.")
	spacer(column)
	for id in sim.pending_parts:
		var part_id: String = id
		column.add_child(make_button(GameData.table("parts")[id].name, func():
			sim.choose_purchase(part_id)
			resume_run(), true))

func show_repair_offer() -> void:
	screen = "repair_offer"
	paused = true
	var column := menu("REPAIR BAY", "Restore your lost parts and repair 40% HP.")
	spacer(column)
	if ads.is_available():
		column.add_child(make_button("FREE REPAIR  ·  WATCH", func(): ads.show_rewarded("repair"), true))
	column.add_child(make_button("KEEP GOING", resume_run))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and OS.is_debug_build() and not capture:
		if event.pressed:
			debug_touches[event.index] = true
		else:
			debug_touches.erase(event.index)
		if debug_touches.size() >= 5:
			debug_label.visible = not debug_label.visible
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3 and OS.is_debug_build() and not capture:
			debug_label.visible = not debug_label.visible
		if event.keycode == KEY_ESCAPE:
			if screen == "run":
				show_pause()
			elif screen == "pause":
				resume_run()
		if event.keycode == KEY_SPACE and screen == "run":
			sim.tap_special()
	if screen != "run" or paused:
		return
	if event is InputEventScreenDrag:
		sim.drag(event.relative.x / get_viewport().get_visible_rect().size.x * float(GameData.constants().drag_world_per_screen_width))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		sim.drag(event.relative.x / get_viewport().get_visible_rect().size.x * 6.8)
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_A]:
			sim.drag(-2.2)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			sim.drag(2.2)

func _notification(what: int) -> void:
	if capture and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if save != null and not save.data.is_empty():
			save.write()
		if is_instance_valid(audio) and audio.music_player != null:
			audio.music_player.stream_paused = true
		if is_instance_valid(overlay) and screen == "run":
			show_pause()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		if is_instance_valid(audio) and audio.music_player != null:
			audio.music_player.stream_paused = false
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(overlay):
			show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save != null and not save.data.is_empty():
			save.write()
		perf.write()
		get_tree().quit()

func _exit_tree() -> void:
	MeshFactory.cache.clear()
	MeshFactory.material = null
