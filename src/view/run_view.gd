extends Node3D
const UiV2Script = preload("res://src/ui/ui_v2.gd")
var ui_v2_enabled := false
var ui_v2
const NAVY = Color("34433f")
const CREAM = Color("34433f")
const MUTED = Color("68746b")
const GREEN = Color("63c96b")
const ORANGE = Color("ef952f")
const INK = Color("34433f")
const PANEL = Color("ffffff")
const TONES = {
	"green": Color("83d884"), "blue": Color("e6eee7"), "yellow": Color("ffe3a0"), "red": Color("f8d4c9"),
	"panel": Color("ffffff"), "grey": Color("e7e9e4"), "orange": Color("f6b75b")}
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
var parts_row: HFlowContainer
var parts_sig := ""
var special_ring: UiRing
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
var camera_focus := Vector3(0, 0.7, -7.5)
var pickup_glow := 0.0
var accumulator := 0.0
var runtime := 0.0
var toast_timer := 0.0
var mob_popup_at: Dictionary = {}
var paused := false
var screen := "run"
var result_recorded := false
var result_reward := 0
var result_texture: ImageTexture
var daily := false
var daily_key := ""
var bot
var flag_overrides: Dictionary = {}
var gov_frames: Array = []
var gov_timer := 0.0
var gov_draws := 0
var cluster_seen := false
var capture := false
var playtest_variant := ""
var snapshot_at := -1.0
var snapshot_path := ""
var exit_after := -1.0
var last_perf_save := 0.0
var kill_timer := 0.0
var ui_tick := 0.0
var settings_return := "hangar"
var hangar_model: RobotBuilder
var hangar_camera: Camera3D
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
var combo_label: Label
var chain_label: Label
var last_chain := 0
var combo_count := 0
var combo_timer := 0.0
var best_combo := 0
var run_kills := 0
var hp_display := 100.0
var run_min_hp := 1.0
var run_stars := 0
var new_best_stars := false
var login_banner := ""
var reward_label: Label

func _ready() -> void:
	GameData.load_all()
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("mobile") else Viewport.MSAA_4X
	display_font = load("res://assets/fonts/lilita_LilitaOne-Regular.ttf")
	body_font = load("res://assets/fonts/barlow_Barlow-SemiBold.ttf")
	save.load_save()
	for arg in OS.get_cmdline_user_args():
		if arg == "--stress" and OS.is_debug_build():
			stress_mode = true
		elif arg == "--capture":
			capture = true
		elif arg.begins_with("--perf-output="):
			perf_output = arg.get_slice("=", 1)
		elif arg.begins_with("--flags="):
			flag_overrides = JSON.parse_string(arg.substr(8))
		elif arg.begins_with("--playtest=") and OS.is_debug_build():
			var variant := arg.get_slice("=", 1)
			if variant in ["a", "b"]:
				playtest_variant = variant
		elif arg.begins_with("--snapshot-at="):
			snapshot_at = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--snapshot-path="):
			snapshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--exit-after="):
			exit_after = arg.get_slice("=", 1).to_float()
	if capture:
		save.path = "user://capture_save.json"
		save.data = save.defaults()
	elif not playtest_variant.is_empty():
		# Fresh isolated progress for an A/B session; the owner's save stays in its existing location.
		save.path = "user://mob_playtest_%s.json" % playtest_variant
		save.data = save.defaults()
		flag_overrides["mob_stream"] = playtest_variant == "b"
		flag_overrides["engagement_metrics"] = true
	ui_v2_enabled = bool(flag_overrides.get("ui_v2", GameData.flags().get("ui_v2", false)))
	if ui_v2_enabled: display_font = load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf")
	if OS.has_feature("macos") and DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--resolution") and not OS.get_cmdline_args().has("--write-movie"):
		var available := DisplayServer.screen_get_usable_rect().size
		var height := mini(1152, int(available.y * 0.86))
		get_window().size = Vector2i(int(height * 9.0 / 16.0), height)
	get_window().title = "Scrap Bot"
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
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("f3f1e9")
	sky_material.sky_horizon_color = Color("ede8dc")
	sky_material.ground_horizon_color = Color("ede8dc")
	sky_material.ground_bottom_color = Color("ded7c6")
	sky_material.sky_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff5e5")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("ede8dc")
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 140.0
	env.fog_depth_curve = 1.4
	env.glow_enabled = false
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.0
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

func style(color: Color, border := Color.TRANSPARENT, radius := 26, lip := 8) -> StyleBoxFlat:
	if ui_v2_enabled:
		radius = 6
		lip = 0
		if border.a <= 0: border = Color("66746d")
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border if border.a > 0 else Color("d9dfd5")
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.25, 0.3, 0.2, 0.10)
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, minf(lip, 4))
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 14
	box.content_margin_bottom = 14 + lip / 2
	return box

func text_label(value: String, size := 36, color := CREAM) -> Label:
	var label := Label.new()
	label.text = value
	var big := size >= 30
	label.add_theme_font_override("font", display_font if big else body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_button(value: String, action: Callable, primary := false, tone := "") -> Button:
	var button := Button.new()
	var key := tone if not tone.is_empty() else ("green" if primary else "panel")
	var fill: Color = TONES[key]
	button.text = value
	button.add_theme_font_override("font", display_font)
	button.custom_minimum_size.y = 128
	button.add_theme_font_size_override("font_size", 46)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, INK)
	button.add_theme_color_override("font_disabled_color", Color("899087"))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_outline_color", INK)
	button.add_theme_stylebox_override("normal", style(fill))
	button.add_theme_stylebox_override("hover", style(fill.lightened(0.12)))
	var pressed := style(fill.darkened(0.12), Color.TRANSPARENT, 26, 2)
	pressed.content_margin_top += 6
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", style(Color("e7e9e4"), Color.TRANSPARENT, 26, 4))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func():
		audio.play("click")
		haptics.tap(10, 0.2)
		action.call())
	button.button_down.connect(func():
		if ui_v2_enabled and bool(save.data.settings.reduce_motion): return
		button.pivot_offset = button.size / 2
		button.create_tween().tween_property(button, "scale", Vector2.ONE * 0.95, 0.06))
	button.button_up.connect(func():
		if ui_v2_enabled and bool(save.data.settings.reduce_motion): return
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return button

# Circular action button used in the run HUD.
func round_button(value: String, diameter: float, tone: String, action: Callable) -> Button:
	var button := make_button(value, action, false, tone)
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.add_theme_font_size_override("font_size", 34)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state)
		box.set_corner_radius_all(int(diameter / 2))
		box.content_margin_left = 6
		box.content_margin_right = 6
	return button

func pill(icon_kind: String, label: Label, fill := PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := style(fill, Color.TRANSPARENT, 40, 6)
	box.content_margin_top = 6
	box.content_margin_bottom = 12
	box.content_margin_left = 14
	box.content_margin_right = 26
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := UiIcon.make(icon_kind, 62)
	row.add_child(icon)
	row.add_child(label)
	return panel

func bar(color: Color, height := 22) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size.y = height
	node.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color("e0e5dc")
	back.border_color = INK
	back.set_border_width_all(4)
	back.set_corner_radius_all(2 if ui_v2_enabled else int(height / 2))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2 if ui_v2_enabled else int(height / 2))
	fill.border_color = color.lightened(0.35)
	fill.border_width_top = 4
	node.add_theme_stylebox_override("background", back)
	node.add_theme_stylebox_override("fill", fill)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _build_hud() -> void:
	if ui_v2_enabled:
		ui_v2 = UiV2Script.new()
		ui_v2.build(self)
		return
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
		var logical_height := get_viewport().get_visible_rect().size.y
		if size.y > 0:
			safe_top = maxf(35, float(safe.position.y) * logical_height / size.y)
			safe_bottom = maxf(35, float(size.y - safe.end.y) * logical_height / size.y)
	top_bar = PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 34
	top_bar.offset_right = -34
	top_bar.offset_top = safe_top
	top_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	level_label = text_label("LEVEL 1", 44)
	row.add_child(pill("star", level_label))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(top_spacer)
	scrap_label = text_label("0", 48, Color("93671f"))
	scrap_label.custom_minimum_size.x = 128
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pill("coin", scrap_label))
	var pause_button := round_button("", 112, "panel", show_pause)
	pause_button.add_child(UiIcon.make("pause", 60))
	pause_button.get_child(0).set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_button.get_child(0).offset_left = -30
	pause_button.get_child(0).offset_top = -36
	pause_button.get_child(0).offset_right = 30
	pause_button.get_child(0).offset_bottom = 24
	row.add_child(pause_button)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hp_row)
	hp_row.add_child(UiIcon.make("heart", 74))
	hp_bar = bar(GREEN, 50)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for threshold in GameData.constants().part_break_thresholds:
		var tick := ColorRect.new()
		tick.color = Color(0.1, 0.07, 0.19, 0.7)
		tick.anchor_left = float(threshold)
		tick.anchor_right = float(threshold)
		tick.anchor_bottom = 1
		tick.offset_left = -2
		tick.offset_right = 2
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bar.add_child(tick)
	hp_label = text_label("60 / 60", 32)
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_bar.add_child(hp_label)
	hp_row.add_child(hp_bar)
	var track_row := HBoxContainer.new()
	track_row.add_theme_constant_override("separation", 10)
	track_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(track_row)
	progress_bar = bar(ORANGE, 26)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track_row.add_child(progress_bar)
	track_row.add_child(UiIcon.make("skull", 62))
	parts_row = HFlowContainer.new()
	parts_row.add_theme_constant_override("h_separation", 10)
	parts_row.add_theme_constant_override("v_separation", 8)
	parts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(parts_row)
	boss_panel = VBoxContainer.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_panel.offset_top = safe_top + 290
	boss_panel.offset_left = 70
	boss_panel.offset_right = -70
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_panel)
	boss_label = text_label("SCRAP TITAN  ·  PLATED", 44)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_label)
	boss_bar = bar(MeshFactory.RED, 24)
	boss_panel.add_child(boss_bar)
	toast_label = text_label("", 36)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -480
	toast_label.offset_right = 480
	toast_label.offset_top = 420
	toast_label.offset_bottom = 570
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	combo_label = text_label("", 28, Color("446750"))
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combo_label.offset_left = -400
	combo_label.offset_right = 400
	combo_label.offset_top = 640
	combo_label.offset_bottom = 760
	combo_label.pivot_offset = Vector2(400, 60)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_constant_override("outline_size", 0)
	combo_label.add_theme_color_override("font_outline_color", NAVY)
	hud.add_child(combo_label)
	chain_label = text_label("", 28, Color("736544"))
	chain_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	chain_label.offset_left = -400
	chain_label.offset_right = 400
	chain_label.offset_top = 560
	chain_label.offset_bottom = 640
	chain_label.pivot_offset = Vector2(400, 40)
	chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain_label.add_theme_constant_override("outline_size", 0)
	chain_label.add_theme_color_override("font_outline_color", NAVY)
	hud.add_child(chain_label)
	hint_label = text_label("DRAG TO STEER\nChoose a gate. Build something bigger.", 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_left = 40
	hint_label.offset_right = -40
	hint_label.offset_top = -435 - safe_bottom
	hint_label.offset_bottom = -335 - safe_bottom
	hud.add_child(hint_label)
	for floating in [hint_label, toast_label, boss_label]:
		floating.add_theme_constant_override("outline_size", 5)
		floating.add_theme_color_override("font_outline_color", Color.WHITE)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -320 - safe_bottom
	bottom.offset_bottom = -safe_bottom
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	reroll_button = round_button("RE-ROLL", 190, "blue", func():
		if sim.free_rerolls <= 0 and ads.is_available():
			ads.show_rewarded("reroll")
		elif sim.reroll():
			toast("New parts ahead")
		else:
			toast("Free re-roll used"))
	reroll_button.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(reroll_button)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_spacer)
	var special_holder := Control.new()
	special_holder.custom_minimum_size = Vector2(290, 290)
	special_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(special_holder)
	special_ring = UiRing.new()
	special_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	special_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	special_holder.add_child(special_ring)
	special_button = round_button("SPECIAL", 236, "orange", func(): sim.tap_special())
	special_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	special_button.offset_left = -118
	special_button.offset_right = 118
	special_button.offset_top = -118
	special_button.offset_bottom = 118
	special_holder.add_child(special_button)
	debug_label = text_label("", 24, Color("93671f"))
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
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("ffffff"), Color("faf8f1"), Color("efe6d2")])
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	var cover := TextureRect.new()
	cover.texture = texture
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.modulate = Color.WHITE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(cover)
	# Faint rivet stripes at the top give the menus a worn-metal feel.
	var stripe := ColorRect.new()
	stripe.color = Color("65716b") if ui_v2_enabled else Color(1, 0.55, 0.15, 0.9)
	stripe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_bottom = 14
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(stripe)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	var top := 50
	var bottom := 40
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var pixels := DisplayServer.screen_get_size()
		var logical_height := get_viewport().get_visible_rect().size.y
		if pixels.y > 0:
			top = maxi(top, int(safe.position.y * logical_height / pixels.y) + 20)
			bottom = maxi(bottom, int((pixels.y - safe.end.y) * logical_height / pixels.y) + 20)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	if title in ["SETTINGS", "TITAN DOWN!", "SO CLOSE!", "START FRESH?"]:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		margin.add_child(scroll)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(column)
	else:
		margin.add_child(column)
	if not title.is_empty():
		var heading := text_label(title, 76, INK)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(heading)
	if not subtitle.is_empty():
		var sub := text_label(subtitle, 30, MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(sub)
	return column

func spacer(parent: Control) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)

func start_run(is_daily := false) -> void:
	_configure_ui_v2(bool(flag_overrides.get("ui_v2", GameData.flags().get("ui_v2", false))))
	daily = is_daily
	daily_key = Time.get_date_string_from_system(true)
	var seed_arg := int(daily_key.replace("-", "")) if daily else int(Time.get_unix_time_from_system())
	if capture or not playtest_variant.is_empty():
		seed_arg = 20261031
	var level := 1 if daily else int(save.data.level)
	sim = RunSim.new()
	sim.flag_overrides = flag_overrides
	sim.setup(level, seed_arg, {} if daily else save.data.part_tiers, 0 if daily else int(save.data.losses_on_level), [] if daily else save.data.unlocked_parts)
	bot = null
	if capture and OS.is_debug_build():
		# Test drivers are excluded from player exports. Resolve them only for source-tree captures;
		# static class references here made the packaged game fail to parse at startup.
		var driver_path := "res://tests/bots/" + ("mob_bot.gd" if sim.flags.mob_stream else "aim_bot.gd" if sim.flags.aim_mode == "lane" else "bot_controller.gd")
		if ResourceLoader.exists(driver_path):
			var driver = load(driver_path)
			bot = driver.new(seed_arg, 0.15) if sim.flags.mob_stream or sim.flags.aim_mode == "lane" else driver.new(seed_arg, "perfect", 0)
	perf = PerfLog.new()
	mob_popup_at.clear()
	reward_doubled = false
	run_paid = 0
	run_saved = false
	run_win_applied = false
	cluster_seen = false
	run_start_streak = int(save.data.streak)
	streak_saved = false
	result_recorded = false
	result_texture = null
	kill_timer = 0
	combo_count = 0
	combo_timer = 0
	best_combo = 0
	run_kills = 0
	pickup_glow = 0.0
	scrap_label.modulate = Color.WHITE
	flash.color.a = 0.0
	hp_display = 100.0
	run_min_hp = 1.0
	combo_label.text = ""
	chain_label.text = ""
	screen = "run"
	paused = false
	accumulator = 0
	toast_timer = 0
	toast_label.text = ""
	overlay.visible = false
	hud.visible = true
	world.boss_root.scale = Vector3.ONE
	world.player.rotation = Vector3.ZERO
	_reset_camera()
	world.gate_signature = ""
	world.reset_run_feedback()
	audio.music("run_music")
	world.sync(sim, 0)
	if ui_v2_enabled: ui_v2.reset(self)

func _configure_ui_v2(enabled: bool) -> void:
	if enabled != ui_v2_enabled:
		var old_canvas = hud.get_parent()
		remove_child(old_canvas)
		old_canvas.queue_free()
		ui_v2_enabled = enabled
		display_font = load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf" if enabled else "res://assets/fonts/lilita_LilitaOne-Regular.ttf")
		ui_v2 = null
		_build_hud()
	world.configure_ui_v2(enabled, bool(save.data.settings.reduce_motion), int(save.data.settings.get("flash_limit", 3)))
	world.popup_limit = 3 if enabled else 10

# One camera update owns the transform. Rewards never change projection, offsets or simulation timing.
func _reset_camera() -> void:
	camera.position = Vector3(0, 7.8, 9.5)
	camera_focus = Vector3(0, 0.7, -7.5)
	camera.look_at(camera_focus)
	camera.fov = 62.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0

func _update_camera(delta: float) -> void:
	var in_boss := sim.boss != null
	var blend := 1.0 - exp(-maxf(0.0, delta) * 5.0)
	camera.position = camera.position.lerp(Vector3(0, 8.5, 11) if in_boss else Vector3(0, 7.8, 9.5), blend)
	camera_focus = camera_focus.lerp(Vector3(0, 0.7, -8.0) if in_boss else Vector3(0, 0.7, -7.5), blend)
	camera.look_at(camera_focus)
	camera.fov = 62.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0

func toast(value: String) -> void:
	if ui_v2_enabled:
		ui_v2.hero(self, value, 30, GREEN)
		return
	toast_label.text = value
	toast_timer = 1.8
	toast_label.pivot_offset = toast_label.size / 2
	toast_label.scale = Vector2.ONE

func bump_combo() -> void:
	combo_count += 1
	run_kills += 1
	best_combo = maxi(best_combo, combo_count)
	combo_timer = 2.4
	if combo_count >= 3:
		combo_label.text = "COMBO ×%d" % combo_count
		combo_label.scale = Vector2.ONE

func _events() -> void:
	for event in sim.events:
		if event.t not in ["scrap", "weapon_fire", "gate_charge_tick", "wave_spawn", "cluster_burst", "mob_gate_pass"]:
			TelemetryLog.log_event(event)
		if ui_v2_enabled:
			ui_v2.on_event(self, event)
			if event.t not in ["combo_active", "buy_offer", "station_unavailable"]: continue
		match str(event.t):
			"part_attached", "part_upgraded":
				var id: String = event.id
				toast(GameData.table("parts")[id].levels[int(event.level) - 1].name.to_upper() + "  +")
				audio.play("upgrade" if event.t == "part_upgraded" else "attach")
				haptics.tap(20, 0.4)
				world.burst(Vector3(sim.x, 1.3, 0), 6, MeshFactory.GREEN, 0.65)
			"stage_up":
				toast("BATTLE BOT" if event.stage == 2 else "SCRAP MONSTER")
				audio.play("stage")
				haptics.tap(60, 0.7)
				world.burst(Vector3(sim.x, 0.5, 0), 12, MeshFactory.GREEN, 0.8)
			"part_broken", "part_stolen", "part_replaced":
				toast(("PART STOLEN" if event.t == "part_stolen" else "PART LOST") + "\n" + GameData.table("parts")[event.id].name)
				audio.play("break")
				haptics.tap(80, 0.8)
				world.burst(Vector3(sim.x, 1.3, 0), 16, MeshFactory.STEEL, 1.3)
				combo_count = 0
			"player_hit":
				audio.play("hit")
				haptics.tap(40, 0.6)
				world.player.flash()
				flash.color.a = 0.12
				combo_count = 0
				combo_label.text = ""
				world.burst(Vector3(sim.x, 1.2, 0), 8, MeshFactory.RED)
				world.popup("-%d" % int(event.amount), Vector3(sim.x, 2.8, 0), MeshFactory.RED, 80)
			"shield_block":
				toast("SHIELD BLOCKED THE HIT")
				world.burst(Vector3(sim.x, 1.2, 0), 14, MeshFactory.BLUE, 1.4)
			"enemy_death":
				audio.play("explosion")
				var kill_pos := Vector3(event.x, 0.8, sim.z - float(event.z))
				world.burst(kill_pos, 8, MeshFactory.ORANGE if event.id != "barrel" else MeshFactory.YELLOW, 1.1)
				bump_combo()
				if event.id == "bruiser":
					world.popup("SMASH!", kill_pos + Vector3(0, 1.5, 0), MeshFactory.ORANGE, 90)
			"scrap":
				audio.play("scrap")
				pickup_glow = 0.18
				if event.has("chain"):
					last_chain = int(event.chain)
					if bool(event.gold):
						world.burst(Vector3(sim.x, 1.0, 0), 4, MeshFactory.YELLOW, 0.4)
			"healed":
				toast("QUICK REPAIR")
				audio.play("upgrade")
				world.burst(Vector3(sim.x, 1.4, 0), 18, MeshFactory.GREEN, 1.2)
			"frenzy":
				toast("COIN FRENZY\nCoins x2 · wider magnet")
				audio.play("stage")
			"surge":
				toast("OVERDRIVE CHARGED")
				audio.play("special")
				world.burst(Vector3(sim.x, 1.4, 0), 18, MeshFactory.PURPLE, 1.4)
			"hauler_spawn":
				toast("SCRAP HAULER!\nChase it · shoot the crate")
				audio.play("warning")
			"hauler_destroyed":
				toast("JACKPOT!")
				audio.play("victory")
				haptics.tap(60, 0.7)
				var loot_pos := Vector3(event.x, 1.8, sim.z - float(event.z))
				world.burst(loot_pos, 16, MeshFactory.YELLOW, 1.0)
			"hauler_missed":
				toast("IT GOT AWAY...")
			"salvage_spawn":
				toast("SALVAGE!\nBlast the barrel or crack the crate")
				audio.play("warning")
			"cluster_burst":
				var split_pos := Vector3(event.x, 1.0, sim.z - float(event.z))
				world.burst(split_pos, 14, MeshFactory.ORANGE, 1.4)
				if not cluster_seen:
					cluster_seen = true
					toast("CLUSTER ROCKETS!\nRockets split on impact")
					audio.play("stage")
				haptics.tap(15, 0.3)
			"wave_spawn":
				toast("INCOMING!\nHold the line")
				audio.play("warning")
			"salvage_looted":
				toast("LOOT!")
				audio.play("victory")
				var crate_pos := Vector3(event.x, 1.2, sim.z - float(event.z))
				world.burst(crate_pos, 8, MeshFactory.YELLOW, 0.8)
			"gate_level_up":
				var bonus_text := "LEVEL %d" % (1 + int(event.bonus))
				audio.play("upgrade")
				haptics.tap(15, 0.3)
				world.popup("CHARGED  " + bonus_text, Vector3(sim.x, 3.4, 0), MeshFactory.YELLOW, 70)
			"boss_exposed":
				world.popup("EXPOSED  x1.5", Vector3(0, 5.5, -16), MeshFactory.YELLOW, 90)
				audio.play("dodge")
			"weapon_fire":
				audio.play("fire")
				world.player.fire_kick = 1.0
			"telegraph", "enemy_warning":
				audio.play("warning")
				audio.duck(true)
			"boss_attack":
				audio.duck(false)
				audio.play("hit")
			"buy_offer":
				if sim.state == "choosing":
					show_purchase()
			"boss_intro": toast("SCRAP TITAN\nDodge the red warnings")
			"boss_phase":
				toast("CORE EXPOSED" if event.phase == 2 else "ENRAGED")
				audio.play("stage")
			"clean_dodge": audio.play("dodge")
			"mob_champion":
				audio.play("champion")
				haptics.tap(70, 0.8)
				world.popup("CHAMPION!", Vector3(0, 3.4, -2.0), Color("5fd0ff"), 54)
				world.burst(Vector3(sim.x, 1.3, -1.0), 12, Color("5fd0ff"), 1.0)
			"mob_gate_pass":
				var pass_type := str(event.type)
				var pass_color := world._mob_panel_color(pass_type)
				var pop_key := int(event.ord) * 4 + int(event.lane)
				if runtime - float(mob_popup_at.get(pop_key, -9.0)) >= 1.2:
					mob_popup_at[pop_key] = runtime
					world.popup(world._mob_panel_text({"t": pass_type, "v": event.v}), Vector3(float(event.x), 3.0, sim.z - float(event.z)), Color("43b975") if pass_type != "trap" else Color("ff6b7a"), 56)
					audio.play("trap" if pass_type == "trap" else "multiply")
					haptics.tap(12, 0.3)
					world.burst(Vector3(float(event.x), 1.3, sim.z - float(event.z)), 4 + mini(4, int(event.count)), pass_color, 0.7)
			"special_used":
				toast("OVERDRIVE" if event.id == "overdrive" else GameData.table("combos")[event.id].name.to_upper())
				world.burst(Vector3(sim.x, 1.2, -1), 30, MeshFactory.BLUE, 2.0)
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
				world.burst(Vector3(0, 3.5, -17), 70, MeshFactory.ORANGE, 2.2)
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
		if sim.flags.dense_blocks or sim.flags.mob_stream:
			_govern_density(delta)
		if world.impact_count >= 3:
			audio.play("swarm_hit")
		if runtime - last_perf_save > 5:
			perf.write()
			last_perf_save = runtime
		_update_camera(delta)
		toast_timer -= delta
		if toast_timer <= 0:
			toast_label.text = ""
		flash.color.a = maxf(0, flash.color.a - delta * 1.5)
		var hp_fraction: float = sim.robot.hp / sim.robot.max_hp
		run_min_hp = minf(run_min_hp, hp_fraction)
		hp_label.modulate = Color("c44840") if hp_fraction < 0.3 else Color.WHITE
		hp_display = lerpf(hp_display, hp_fraction * 100.0, minf(1.0, delta * 8.0))
		hp_bar.value = hp_display
		combo_timer -= delta
		if sim.chain >= 3 or sim.frenzy_time > 0:
			var text := ""
			if sim.chain >= 3:
				text = "CHAIN ×%d  +%d%%" % [sim.chain, int(minf(sim.chain, 40) * 1.5)]
			if sim.frenzy_time > 0:
				text += ("   " if not text.is_empty() else "") + "FRENZY %ds" % ceili(sim.frenzy_time)
			chain_label.text = text
		else:
			chain_label.text = ""
		if combo_timer <= 0:
			combo_count = 0
			combo_label.text = ""
		pickup_glow = maxf(0.0, pickup_glow - delta)
		scrap_label.modulate = Color.WHITE.lerp(Color(1.0, 0.85, 0.5), pickup_glow / 0.18)
		ui_tick += delta
		if ui_tick > (0.05 if ui_v2_enabled else 0.1):
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
			if is_instance_valid(hangar_camera):
				frame_model(hangar_camera, hangar_model, 1.9)
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
	if ui_v2_enabled: ui_v2.tick(self, delta)
	if exit_after > 0 and runtime >= exit_after:
		perf.write()
		perf.write(perf_output)
		get_tree().quit()

func chip_style(category: String) -> StyleBoxFlat:
	var fill: Color = {"weapon": Color("ff6a3d"), "movement": Color("3aa0ff"), "defence": Color("43c678"), "collection": Color("b57bff")}.get(category, Color("6a5fa0"))
	var box := style(fill, Color.TRANSPARENT, 20, 4)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 2
	box.content_margin_bottom = 8
	return box

func _update_hud() -> void:
	if ui_v2_enabled:
		ui_v2.sync_hud(self)
		return
	level_label.text = "DAILY" if daily else "LEVEL %d" % sim.level
	scrap_label.text = "%d" % sim.robot.scrap
	if paused or screen != "run":
		hp_display = sim.robot.hp / sim.robot.max_hp * 100
		hp_bar.value = hp_display
	hp_label.text = "%d / %d" % [sim.robot.hp, sim.robot.max_hp]
	var sig := JSON.stringify(sim.robot.parts)
	if sig != parts_sig:
		parts_sig = sig
		for child in parts_row.get_children():
			parts_row.remove_child(child)
			child.queue_free()
		if sim.robot.parts.is_empty():
			parts_row.add_child(text_label("TINY BOT  ·  BUILD YOUR MACHINE", 26, MUTED))
		var equipment := 0
		for id in sim.robot.parts:
			if GameData.table("parts")[id].category != "weapon":
				equipment += 1
				continue
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", chip_style(str(GameData.table("parts")[id].category)))
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(text_label("%s %d" % [str(GameData.table("parts")[id].name).to_upper(), int(sim.robot.parts[id])], 24))
			parts_row.add_child(chip)
		if equipment > 0:
			parts_row.add_child(text_label("+%d EQUIPMENT" % equipment, 24, MUTED))
	progress_bar.value = sim.z / sim.boss_z * 100
	var elite_guard = null
	for enemy in sim.enemies:
		if enemy.id == "hauler" and enemy.hp > 0 and float(enemy.z) - sim.z < 60:
			elite_guard = enemy
	boss_panel.offset_top = maxf(340, top_bar.offset_top + top_bar.size.y + 20)
	toast_label.offset_top = boss_panel.offset_top + (120 if sim.boss != null or elite_guard != null else 0)
	toast_label.offset_bottom = toast_label.offset_top + 85
	chain_label.offset_top = toast_label.offset_bottom
	chain_label.offset_bottom = chain_label.offset_top + 36
	combo_label.offset_top = chain_label.offset_bottom
	combo_label.offset_bottom = combo_label.offset_top + 36
	boss_panel.visible = sim.boss != null or elite_guard != null
	parts_row.visible = not boss_panel.visible
	if elite_guard != null and sim.boss == null:
		boss_label.text = "SCRAP HAULER  /  SHOOT THE CRATE"
		boss_bar.value = float(elite_guard.hp) / float(elite_guard.max_hp) * 100
	if sim.boss != null:
		var tag: String = ["PLATED", "GRABBER", "ENRAGED"][sim.boss.phase - 1]
		boss_label.text = "SCRAP TITAN  /  " + tag
		if int(save.data.streak) >= 3:
			boss_label.text += "  ◇ CORE"
		boss_bar.value = sim.boss.hp / sim.boss.max_hp * 100
	var combos := sim.robot.combos()
	var ready := sim.robot.overdrive >= 100
	var minimum := 99.0
	for id in combos:
		var cooldown := float(sim.robot.cooldowns.get(id, 0))
		minimum = minf(minimum, cooldown)
		if cooldown <= 0:
			ready = true
	special_button.disabled = not ready
	special_ring.value = 1.0 if ready else (sim.robot.overdrive / 100.0 if combos.is_empty() else 1.0 - clampf(minimum / 12.0, 0, 1))
	special_ring.glow = ready
	special_ring.color = Color("ffd23f") if ready else Color("a6b5a4")
	special_ring.queue_redraw()
	special_button.text = "OVERDRIVE" if sim.robot.overdrive >= 100 else ("SPECIAL" if ready else ("%ds" % ceil(minimum) if not combos.is_empty() else "%d%%" % sim.robot.overdrive))
	reroll_button.visible = sim.state == "running"
	reroll_button.disabled = sim.free_rerolls <= 0 and not ads.is_available()
	reroll_button.text = "RE-ROLL\nWATCH" if sim.free_rerolls <= 0 and ads.is_available() else "RE-ROLL\nFREE"
	if sim.t < 8 and not bool(save.data.tutorial_done):
		hint_label.text = "←  DRAG TO STEER  →\nChoose a gate. Build something bigger."
	elif sim.boss != null:
		hint_label.text = "MOVE OUT OF THE RED" if not sim.boss.attack.is_empty() else ("BREAK THE ARM TO RECOVER YOUR PART" if sim.boss.arm_hp > 0 else "AUTO-FIRE ACTIVE  ·  DODGE & BUILD OVERDRIVE")
	elif elite_guard != null:
		hint_label.text = "SHOOT THE CRATE  ·  WATCH THE BARRELS"
	elif _gate_charging():
		hint_label.text = "HOLD YOUR LANE  ·  SHOOT THE GATE TO CHARGE IT"
	elif sim.robot.overdrive >= 100:
		hint_label.text = "OVERDRIVE READY"
	else:
		hint_label.text = ""
	debug_label.text = "%d FPS  ·  %d DRAWS  ·  %s" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), sim.state]
	debug_label.visible = debug_label.visible and OS.is_debug_build() and not capture

# Enemy density only rises while the frame budget holds: back off when p95 frame time or draw calls
# exceed the limits, creep back toward full density when healthy. The sim reads density_limit at spawn time.
func _govern_density(delta: float) -> void:
	gov_frames.append(delta * 1000.0)
	if gov_frames.size() > 180:
		gov_frames.pop_front()
	gov_draws = maxi(gov_draws, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	gov_timer += delta
	if gov_timer < 2.0 or gov_frames.size() < 90:
		return
	gov_timer = 0.0
	var sorted := gov_frames.duplicate()
	sorted.sort()
	var p95: float = sorted[int(sorted.size() * 0.95)]
	var draws := gov_draws
	gov_draws = 0
	if p95 > float(sim.flags.tuning.governor_p95_ms) or draws > int(sim.flags.tuning.governor_draws):
		sim.density_limit = maxf(0.6, sim.density_limit - 0.1)
		TelemetryLog.log_event({"t": "density_governor", "limit": sim.density_limit, "p95_ms": p95, "draws": draws})
	elif sim.density_limit < 1.0:
		sim.density_limit = minf(1.0, sim.density_limit + 0.05)

func _gate_charging() -> bool:
	var gate := sim.next_gate()
	if sim.state != "running" or gate.is_empty() or not gate.has("charge"):
		return false
	var gap := float(gate.z) - sim.z
	return gap > 2.0 and gap < float(sim.flags.tuning.charge_range) + 6.0

func _finish_run() -> void:
	if not result_recorded:
		result_recorded = true
		if sim.engage != null:
			TelemetryLog.log_event({"t": "run_metrics", "level": sim.level, "state": sim.state}.merged(sim.engage.results(sim.t)))
		var won := sim.state == "won"
		run_stars = 0
		new_best_stars = false
		if won:
			run_stars = 1 + int(sim.robot.hp / sim.robot.max_hp >= 0.5) + int(sim.robot.parts_lost == 0)
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
			save.data.stats.kills = int(save.data.stats.kills) + run_kills
			save.data.stats.best_combo = maxi(int(save.data.stats.best_combo), best_combo)
			var star_key := str(sim.level)
			if run_stars > int(save.data.stars.get(star_key, 0)):
				save.data.stars[star_key] = run_stars
				new_best_stars = true
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
	viewport.size = Vector2i(600, 600) if OS.has_feature("mobile") else Vector2i(1200, 1200)
	viewport.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("mobile") else Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var backdrop := WorldEnvironment.new()
	backdrop.environment = Environment.new()
	backdrop.environment.background_mode = Environment.BG_CLEAR_COLOR
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
	frame_model(cam, model)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return texture

func show_result() -> void:
	screen = "result"
	hud.visible = false
	var won := sim.state == "won"
	var column := menu("TITAN DOWN!" if won else "SO CLOSE!", "")
	if result_texture != null:
		var image := TextureRect.new()
		image.texture = result_texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size.y = 500
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(image)
	var build_title := text_label(build_name(), 52, Color("9d541c"))
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(build_title)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 24)
	column.add_child(stars_row)
	if won:
		for i in 3:
			var star := UiIcon.make("star", 150, Color("ffd23f") if i < run_stars else Color("d5dacf"))
			star.pivot_offset = Vector2(75, 75)
			star.scale = Vector2.ZERO
			stars_row.add_child(star)
			var tween := star.create_tween()
			tween.tween_interval(0.25 + i * 0.28)
			tween.tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if new_best_stars:
			var best_label := text_label("NEW BEST  ·  LEVEL %d" % sim.level, 36, GREEN)
			best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(best_label)
	else:
		var reached := text_label("REACHED  %d%%  OF THE WAY TO THE TITAN" % int(clampf(sim.z / sim.boss_z, 0, 1) * 100), 32, MUTED)
		reached.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(reached)
	reward_label = text_label("0", 84, Color("93671f"))
	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 14)
	reward_row.add_child(UiIcon.make("coin", 90))
	reward_row.add_child(reward_label)
	column.add_child(reward_row)
	var shown_label := reward_label
	var count := shown_label.create_tween()
	count.tween_method(func(v: float): shown_label.text = "%d" % int(v), 0.0, float(result_reward), 0.9).set_delay(0.3)
	var summary := text_label("%d KILLS   ·   BEST COMBO x%d   ·   %d PARTS LOST" % [run_kills, best_combo, sim.robot.parts_lost], 28, MUTED)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(summary)
	if daily:
		column.add_child(text_label("Daily best  %d" % save.data.best_daily.get(daily_key, 0), 34, MUTED))
	if not won:
		var tip := text_label("Tip: move before the red warning resolves. Rockets bypass the Titan's front plate.", 34, MUTED)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(tip)
	if ads.is_available():
		if not reward_doubled:
			column.add_child(make_button("DOUBLE COGS  ·  WATCH", func(): ads.show_rewarded("double"), false, "yellow"))
		if not won and run_start_streak > 0 and not streak_saved:
			column.add_child(make_button("SAVE STREAK  ·  WATCH", func(): ads.show_rewarded("streak"), false, "orange"))
		if not won and not sim.revived:
			column.add_child(make_button("REVIVE  ·  WATCH", func(): ads.show_rewarded("revive"), false, "blue"))
	column.add_child(make_button("NEXT LEVEL" if won else "TRY AGAIN", func():
		TelemetryLog.log_event({"t": "retry"})
		start_run(daily), true))
	column.add_child(make_button("HOME", show_hangar, false, "grey"))

# One gift per UTC day; consecutive days raise it (day 7 and on pay the most).
func _claim_login() -> void:
	login_banner = ""
	if capture or not bool(save.data.tutorial_done):
		return
	var today := Time.get_date_string_from_system(true)
	if str(save.data.last_login) == today:
		return
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	save.data.login_streak = int(save.data.login_streak) + 1 if str(save.data.last_login) == yesterday else 1
	var gift := 40 * mini(int(save.data.login_streak), 7)
	save.data.cogs += gift
	save.data.last_login = today
	save.write()
	login_banner = "DAILY GIFT  +%d COGS   ·   DAY %d" % [gift, int(save.data.login_streak)]

func build_name() -> String:
	if sim.robot.parts.has("rocket") and sim.robot.parts.has("armour"):
		return "THE ROCKET TANK"
	if sim.robot.parts.has("wheels"):
		return "THE SCRAP SPEEDSTER"
	if sim.robot.parts.has("magnet"):
		return "THE JUNK COLLECTOR"
	return "THE IRON SURVIVOR"

func currency_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	row.add_child(pill("flame", text_label("%d" % save.data.streak, 44, Color("a75c20"))))
	row.add_child(pill("star", text_label("LV %d" % save.data.level, 44)))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	row.add_child(pill("coin", text_label("%d" % save.data.cogs, 48, Color("93671f"))))

func show_hangar(tab := "home") -> void:
	screen = "hangar"
	hud.visible = false
	audio.music("hangar_music")
	world.player.rotation.y = 0
	_claim_login()
	if tab == "home":
		_hangar_home()
	else:
		_hangar_page(tab)

func _hangar_home() -> void:
	var column := menu("", "")
	var header := HBoxContainer.new()
	column.add_child(header)
	var balance := text_label("%d COGS" % save.data.cogs, 42)
	header.add_child(pill("coin", balance))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var settings := make_button("", func():
		settings_return = "hangar"
		show_settings(), false, "grey")
	settings.tooltip_text = "Settings"
	settings.custom_minimum_size = Vector2(124, 124)
	var gear := UiIcon.make("gear", 62, INK)
	gear.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gear.offset_left = -31
	gear.offset_top = -31
	gear.offset_right = 31
	gear.offset_bottom = 31
	settings.add_child(gear)
	header.add_child(settings)
	var title := text_label("SCRAP BOT", 88, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := text_label("Build your next big thing", 32, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_hangar_preview(column, 500)
	if not login_banner.is_empty():
		var banner := text_label(login_banner, 30, MUTED)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(banner)
	var play := make_button("PLAY  ·  LEVEL %d" % save.data.level, func(): start_run(false), true)
	play.custom_minimum_size.y = 160
	play.add_theme_font_size_override("font_size", 62)
	column.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var garage := make_button("GARAGE", func(): show_hangar("upgrades"))
	garage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _any_affordable():
		garage.tooltip_text = "An upgrade is available"
	row.add_child(garage)
	var daily_button := make_button("DAILY RUN", func(): start_run(true), false, "yellow")
	daily_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(daily_button)

func _any_affordable() -> bool:
	for id in GameData.table("parts"):
		var cost := Economy.upgrade_cost(int(save.data.part_tiers.get(id, 1)))
		if cost > 0 and int(save.data.cogs) >= cost:
			return true
	return false

func _hangar_page(tab: String) -> void:
	var column := menu("GARAGE", "")
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	column.add_child(navigation)
	for entry in [["upgrades", "UPGRADES"], ["armoury", "PARTS"], ["codex", "COLLECTION"]]:
		var destination: String = entry[0]
		var button := make_button(entry[1], func(): show_hangar(destination), tab == destination)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 30)
		navigation.add_child(button)
	currency_row(column)
	_hangar_preview(column, 300)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 20)
	scroll.add_child(list)
	if tab == "codex":
		for id in GameData.table("combos"):
			var def: Dictionary = GameData.table("combos")[id]
			if def.get("stretch", false):
				continue
			var found: bool = save.data.codex.has(id)
			var names: Array = def.needs.map(func(need): return str(GameData.table("parts")[need].name))
			var card := card_row(UiIcon.make("star" if found else "lock", 84, Color("ffd23f")), (def.name if found else "???").to_upper(), " + ".join(names) if found else "Combine two parts to discover", found)
			list.add_child(card)
	else:
		var highlighted := false
		for id in GameData.table("parts"):
			var part_id: String = id
			var def: Dictionary = GameData.table("parts")[id]
			var badge := UiIcon.make("dot", 84, chip_style(str(def.category)).bg_color)
			if tab == "armoury":
				if not GameData.table("economy").unlock_costs.has(id):
					badge.free()
					continue
				var cost: int = int(GameData.table("economy").unlock_costs[id])
				var unlocked: bool = save.data.unlocked_parts.has(id) or int(save.data.level) >= int(def.unlock_level)
				var card := card_row(badge, str(def.name).to_upper(), "UNLOCKED" if unlocked else "Early access", unlocked)
				if not unlocked:
					var buy := make_button("%d" % cost, func():
						save.unlock(part_id)
						show_hangar("armoury"), false, "green")
					buy.disabled = int(save.data.cogs) < cost
					buy.custom_minimum_size = Vector2(230, 120 if ui_v2_enabled else 110)
					card.get_child(0).add_child(buy)
				list.add_child(card)
			else:
				var tier := int(save.data.part_tiers.get(id, 1))
				var cost := Economy.upgrade_cost(tier)
				var affordable := cost > 0 and int(save.data.cogs) >= cost
				var highlight := affordable and not highlighted
				highlighted = highlighted or highlight
				var card := card_row(badge, str(def.name).to_upper(), "", false)
				var pips := HBoxContainer.new()
				pips.add_theme_constant_override("separation", 4)
				for i in 5:
					pips.add_child(UiIcon.make("star", 40, Color("ffd23f") if i < tier else Color("d5dacf")))
				card.get_child(0).get_child(1).add_child(pips)
				card.get_child(0).get_child(1).get_child(1).text = "+8% MAIN STAT" if cost > 0 else "MAX TIER"
				if cost > 0:
					var buy := make_button("%d" % cost, func():
						if save.buy_upgrade(part_id):
							audio.play("upgrade")
						show_hangar("upgrades"), highlight, "green" if affordable else "grey")
					buy.disabled = not affordable
					buy.custom_minimum_size = Vector2(230, 120 if ui_v2_enabled else 110)
					card.get_child(0).add_child(buy)
					if highlight and not ui_v2_enabled:
						var pulse := buy.create_tween().set_loops()
						pulse.tween_property(buy, "modulate", Color(1.15, 1.15, 1.15), 0.55)
						pulse.tween_property(buy, "modulate", Color.WHITE, 0.55)
				list.add_child(card)
	column.add_child(make_button("BACK", func(): show_hangar("home"), false, "red"))

# A list card: badge on the left, title and caption in the middle, extra controls appended to get_child(0).
func card_row(badge: Control, title: String, caption: String, done: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var box := style(Color("ffffff") if not done else Color("edf7e9"), Color.TRANSPARENT, 28, 6)
	box.content_margin_top = 12
	box.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var heading := text_label(title, 36)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(heading)
	var detail := text_label(caption, 26, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail)
	return card

func _hangar_preview(column: VBoxContainer, height := 290) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size.y = height
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL if height > 400 else Control.SIZE_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, height)
	viewport.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("mobile") else Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff5df")
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(sun)
	var pedestal := MeshFactory.instance(MeshFactory.merged([
		MeshFactory.cylinder(1.9, 0.3, Vector3(0, -0.16, 0), Color("d7d6c9"), Vector3.ZERO, -1.0, 28),
		MeshFactory.cylinder(1.8, 0.34, Vector3(0, -0.14, 0), Color("ff8a1f"), Vector3.ZERO, -1.0, 28),
		MeshFactory.cylinder(1.7, 0.36, Vector3(0, -0.12, 0), Color("f3efe3"), Vector3.ZERO, -1.0, 28)], true))
	viewport.add_child(pedestal)
	hangar_model = RobotBuilder.new()
	viewport.add_child(hangar_model)
	hangar_model.rotation_degrees.y = 155
	var preview := RobotState.new()
	preview.parts = sim.robot.parts.duplicate()
	preview.slots = sim.robot.slots.duplicate()
	preview.tiers = save.data.part_tiers.duplicate()
	preview.refresh()
	hangar_model.sync(preview, false)
	var cam := Camera3D.new()
	cam.fov = 35
	cam.position = Vector3(0, 3.0 if height > 400 else 2.8, 6.6 if height > 400 else 5.7)
	viewport.add_child(cam)
	hangar_camera = cam
	frame_model(cam, hangar_model, 1.9)

func frame_model(cam: Camera3D, model: RobotBuilder, platform_radius := 0.0) -> void:
	var bounds := model.visual_bounds()
	var center := Vector3(0, bounds.get_center().y, 0)
	var extents := Vector3(maxf(absf(bounds.position.x), absf(bounds.end.x)), bounds.size.y / 2, maxf(absf(bounds.position.z), absf(bounds.end.z)))
	var radius := maxf(platform_radius, extents.length())
	var dimensions := cam.get_viewport().get_visible_rect().size
	var aspect := dimensions.x / maxf(1, dimensions.y)
	var half_fov := atan(tan(deg_to_rad(cam.fov / 2)) * minf(1, aspect))
	var distance := radius / sin(half_fov) * 1.08
	cam.position = center + Vector3(0, 0.32, 1).normalized() * distance
	cam.look_at(center)

func show_pause() -> void:
	paused = true
	screen = "pause"
	var column := menu("PAUSED", "")
	spacer(column)
	column.add_child(make_button("RESUME", resume_run, true))
	column.add_child(make_button("SETTINGS", func():
		settings_return = "pause"
		show_settings(), false, "blue"))
	column.add_child(make_button("QUIT TO HOME", show_hangar, false, "red"))

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
	var column := menu("SETTINGS", "")
	if ui_v2_enabled:
		ui_v2.settings_ui(self, column)
	for id in ["sound", "music", "haptics", "reduce_motion"]:
		if ui_v2_enabled: break
		var key: String = id
		var enabled: bool = bool(save.data.settings.get(id, false))
		column.add_child(make_button("%s   %s" % [id.replace("_", " ").to_upper(), "ON" if enabled else "OFF"], func():
			save.data.settings[key] = not bool(save.data.settings[key])
			save.write()
			_apply_settings()
			show_settings(), false, "green" if enabled else "grey"))
	var privacy := "Google test ads may use device and network information." if Engine.has_singleton("PoingGodotAdMob") else "This build sends no game data to a server."
	var credits := text_label("Original procedural models & sound.\nBuilt with Godot.\nFonts: Lilita One, Rajdhani, Barlow (OFL).\nProgress stays on this device.\n" + privacy, 34, MUTED)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(credits)
	if Engine.has_singleton("PoingGodotAdMob"):
		column.add_child(make_button("GOOGLE PRIVACY INFORMATION", func(): OS.shell_open("https://policies.google.com/privacy")))
	spacer(column)
	column.add_child(make_button("RESET PROGRESS", show_reset, false, "red"))
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
		start_run(false), false, "red"))

func _apply_settings() -> void:
	audio.enabled = bool(save.data.settings.sound)
	audio.music_enabled = bool(save.data.settings.music)
	haptics.enabled = bool(save.data.settings.haptics)
	audio.apply_volumes(float(save.data.settings.get("sfx_volume", 1.0)) if ui_v2_enabled else 1.0, float(save.data.settings.get("music_volume", 1.0)) if ui_v2_enabled else 1.0)
	if ui_v2_enabled and ui_v2 != null:
		ui_v2.layout(self)
		if world != null: world.configure_ui_v2(true, bool(save.data.settings.reduce_motion), int(save.data.settings.get("flash_limit", 3)))
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
	var column := menu("PICK A PART", "")
	spacer(column)
	for id in sim.pending_parts:
		var part_id: String = id
		var category := str(GameData.table("parts")[id].category)
		column.add_child(make_button(str(GameData.table("parts")[id].name).to_upper(), func():
			sim.choose_purchase(part_id)
			resume_run(), false, {"weapon": "orange", "movement": "blue", "defence": "green"}.get(category, "panel")))

func show_repair_offer() -> void:
	screen = "repair_offer"
	paused = true
	var column := menu("REPAIR BAY", "Restore lost parts and 40% HP")
	spacer(column)
	if ads.is_available():
		column.add_child(make_button("FREE REPAIR  ·  WATCH", func(): ads.show_rewarded("repair"), false, "yellow"))
	column.add_child(make_button("KEEP GOING", resume_run, true))

func navigate_back() -> void:
	match screen:
		"run": show_pause()
		"pause": resume_run()
		"settings":
			if settings_return == "pause": show_pause()
			else: show_hangar()
		"hangar": show_hangar()
		"purchase", "repair_offer": pass
		_: show_hangar()

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
			navigate_back()
		if event.keycode == KEY_SPACE and screen == "run":
			sim.tap_special()
	if screen != "run" or paused:
		return
	if event is InputEventScreenDrag:
		if ui_v2_enabled: ui_v2.steering(self)
		sim.drag(event.relative.x / get_viewport().get_visible_rect().size.x * float(GameData.constants().drag_world_per_screen_width))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		if ui_v2_enabled: ui_v2.steering(self)
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
			navigate_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save != null and not save.data.is_empty():
			save.write()
		perf.write()
		get_tree().quit()

func _exit_tree() -> void:
	MeshFactory.cache.clear()
	MeshFactory.material = null
