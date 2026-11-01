extends SceneTree
var failures: Array = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g = load("res://src/view/Boot.tscn").instantiate()
	g.flag_overrides = {"ui_v2": true, "mob_stream": true}; g.capture = true; root.add_child(g); g.set_process(false)
	g.capture = true; g.save.path = "user://ui_v2_tests.json"; g.save.data = g.save.defaults(); g.start_run(false); g.paused = true; g.bot = null
	check(not bool(GameData.flags().ui_v2), "ui_v2 defaults off")
	check(g.audio.streams.ready != null, "procedural ready sound imported")
	var cases := {
		"scrap": {"amount": 2, "chain": 10, "gold": false}, "part_attached": {"id": "cannon", "level": 1}, "part_upgraded": {"id": "cannon", "level": 2}, "stage_up": {"stage": 2}, "part_replaced": {"id": "wheels"}, "part_broken": {"id": "armour"}, "part_stolen": {"id": "cannon"}, "weapon_fire": {"id": "cannon"}, "enemy_death": {"id": "scrapper", "x": 0, "z": 12}, "player_hit": {"amount": 8}, "gate_choice": {"side": 0, "z": 8, "option": {"kind": "part", "id": "cannon"}}, "gate_charge_tick": {}, "gate_level_up": {"bonus": 1}, "mob_gate_pass": {"ord": 0, "lane": 0, "type": "mult", "v": 3, "count": 5, "gain": 10, "x": -1.7, "z": 20}, "telegraph": {"attack": "ground_slam"}, "enemy_warning": {}, "boss_attack": {}, "clean_dodge": {}, "boss_exposed": {}, "boss_intro": {}, "boss_phase": {"phase": 2}, "special_used": {"id": "overdrive"}, "mob_champion": {}, "shield_block": {}, "surge": {}, "repaired": {}, "healed": {}, "arm_recovered": {}, "frenzy": {}, "salvage_looted": {"x": 0, "z": 20}, "hauler_destroyed": {"x": 0, "z": 20}, "hauler_spawn": {}, "hauler_missed": {}, "salvage_spawn": {}, "wave_spawn": {}, "cluster_burst": {"x": 0, "z": 10}, "boss_killed": {}, "death": {}}
	var initial: Transform3D = g.camera.transform
	for action in cases:
		var frame: int = g.ui_v2.frame
		g.sim.emit(action, cases[action]); g._events()
		check(g.ui_v2.feedback_counts.has(action), "feedback map answers " + action)
		check(g.ui_v2.feedback_log.back().frame == frame, "same-frame response " + action)
		check(g.ui_v2.hero_panel.visible == (g.ui_v2.hero_time > 0), "one hero surface")
		g.ui_v2.tick(g, 1.0 / 60); g.world.sync(g.sim, 1.0 / 60); g._update_camera(1.0 / 60)
		check(g.camera.transform.is_equal_approx(initial) and g.camera.fov == 62, "no routine camera effect " + action)
	g.sim.emit("part_attached", {"id": "cannon", "level": 1}); g._events()
	check(g.ui_v2.hero_priority == 110, "lower priority receipt cannot replace a major event")
	for i in 20: g.world.popup("TEST", Vector3.ZERO)
	check(g.world.popups.filter(func(p): return p.visible).size() <= 3, "world popup pool capped at three")
	g.world.reset_run_feedback()
	for i in 120:
		g.sim.t = float(i) / 60
		g.sim.emit("player_hit", {"amount": 1}); g._events(); g.ui_v2.tick(g, 1.0 / 60)
	for time in g.ui_v2.flash_times:
		var count: int = g.ui_v2.flash_times.filter(func(t): return t <= time and t > time - 1).size()
		check(count <= 3, "local flash budget in rolling second")
	g.world.player.flash()
	g.world.player._process(0.01)
	g.save.data.settings.reduce_motion = true; g._apply_settings()
	check(is_zero_approx(float(g.world.player.body.get_instance_shader_parameter("flash"))), "enabling Reduce Motion clears an in-flight flash")
	var starts: int = g.world.ui_feedback.optional_starts
	g.sim.emit("stage_up", {"stage": 2}); g.sim.emit("player_hit", {"amount": 2}); g._events(); g.world.burst(Vector3.ZERO, 20); g.world.sync(g.sim, 0.1); g.ui_v2.tick(g, 0.1)
	check(g.world.ui_feedback.optional_starts == starts and g.world.fx_items.is_empty(), "Reduce Motion stops optional effects")
	check(not g.world.dust_fx.emitting and not g.world.flame_fx.emitting and g.world.player.reduced_motion, "Reduce Motion reaches world and robot")
	check(g.special_button.scale == Vector2.ONE, "Reduce Motion disables ready scale")
	check(not g.flash.visible, "no full-screen saturated flash")
	g.sim.boss = BossSim.new(); g.sim.boss.setup(1, 0); g.sim.state = "boss"
	g.sim.boss.phase = 2; g.sim.boss.zones = [{"shape": "circle", "x": 0.0, "radius": 1.2}]
	g.world.sync(g.sim, 0)
	check(g.world.ui_feedback.weakpoint.visible, "exposed core has one persistent target ring")
	check(g.world.warnings[0].visible and g.world.warnings[0].position.z < -10, "danger shape remains ahead of the robot silhouette")
	check(g.world.warnings[0].position.x == 0 and is_equal_approx(g.world.warnings[0].scale.x, 2.4), "danger shape retains actual horizontal hit range")
	for action in ["player_hit", "part_broken", "part_stolen", "part_replaced"]:
		g.combo_count = 4
		g.sim.emit(action, {"id": "cannon", "amount": 2}); g._events()
		check(g.combo_count == 0, "v2 preserves legacy combo reset: " + action)
	g.audio.apply_volumes(0, 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "zero volumes mute audio buses")
	g.audio.apply_volumes(1, 1)
	# Existing v1 saves retain their values; optional settings require no root/schema migration.
	var save := SaveStore.new(); save.path = "user://ui_v2_legacy_save.json"
	FileAccess.open(save.path, FileAccess.WRITE).store_string('{"v":1,"cogs":123,"level":2,"settings":{"sound":false,"music":true,"haptics":false,"reduce_motion":false}}')
	save.load_save(); check(save.data.v == 1 and save.data.cogs == 123 and save.data.level == 2 and not save.data.settings.sound, "legacy v1 save values preserved")
	check(save.data.settings.has("left_handed") and save.data.settings.has("sfx_volume"), "optional preference defaults merged into v1")
	var drag := InputEventScreenDrag.new(); drag.relative = Vector2(20, 0); g.paused = false; g._unhandled_input(drag)
	check(g.ui_v2.feedback_counts.has("steer"), "actual drag input produces steering feedback")
	g.save.data.settings.reduce_motion = false
	g.result_reward = 240; g.sim.state = "won"; g.show_result()
	check(g.hangar_model != null, "result includes live final build")
	await create_timer(1.5).timeout
	check(g.reward_label.text == "240", "result reward count finishes at actual payout")
	g.save.data.settings.reduce_motion = true; g.show_result()
	check(g.reward_label.text == "240" and g.hangar_model.reduced_motion, "Reduced Motion settles result reward and model immediately")
	check(not g.world.visible, "opaque menus do not render the hidden battlefield")
	g.resume_run(); check(g.world.visible, "resuming restores the battlefield")
	var report := {"checks": checks, "failures": failures, "feedback_classes": cases.keys(), "flash_starts": g.ui_v2.flash_times, "camera_fov": g.camera.fov}
	FileAccess.open("res://results/ui_v2_feedback_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("UI V2: ", checks, " checks, ", failures.size(), " failures")
	for failure in failures: printerr(failure)
	g.queue_free(); for frame in 6: await process_frame
	quit(0 if failures.is_empty() else 1)
