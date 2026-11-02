extends SceneTree
# Deterministic state fixtures; menus with ads use a fake *availability* provider, never grant a reward.
var game
var variant := false
var output := "hook_before"
var metrics = preload("res://tests/ui_metrics.gd")
class Availability:
	extends Node
	signal earned
	signal closed
	signal availability_changed
	func is_available() -> bool: return true
	func show_rewarded(_unit: String) -> void: pass

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--after": variant = true; output = "hook_after"
	call_deferred("run")

func fixture(state: String) -> void:
	game.save.data = game.save.defaults()
	game.save.data.tutorial_done = state != "first_launch"
	game.save.data.cogs = 1600
	game.flag_overrides = {"ui_v2": variant, "mob_stream": true, "engagement_metrics": true}
	if variant:
		for flag in ["gate_clarity", "gate_preview", "material_tiers", "horde_scaling", "jackpot_gate"]: game.flag_overrides[flag] = true
	game.start_run(false)
	game.paused = true
	game.bot = null
	game.perf.enabled = false
	var s: RunSim = game.sim
	if state not in ["first_launch", "run_start"]:
		for id in ["cannon", "armour", "wheels"]: s.robot.add_part(id, null, 2)
		s.z = 155.0; s.t = 17.0
	s.events.clear()
	match state:
		"mid_run": s.spawn_pack("scrapper", 5, s.z + 18.0)
		"part_gate", "repair_bay":
			var options := [{"kind": "part", "id": "cannon"}, {"kind": "part", "id": "wheels"}]
			if state == "repair_bay": options = [{"kind": "repair"}, {"kind": "reroll"}, {"kind": "buy"}]
			s.beats = [{"type": "gate" if state == "part_gate" else "repair_bay", "z": s.z + 45, "resolved": false, "options": options}]
		"mob_gate":
			s.beats = [{"type": "mob_gate", "z": s.z + 18, "panels": [{"t": "mult", "v": 3}, {"t": "add", "v": 10}], "resolved": false}]
			s.mob.register_gates(s.beats)
			for i in 20: s.mob.add_drone(MobSim.Kind.BOLT, -1.5 + (i % 3) * 0.15, s.z + 3.0 + i * 0.7, 0, 36, 4, 0, 2)
			s.emit("mob_gate_pass", {"ord": 0, "lane": 0, "type": "mult", "v": 3, "gain": 24, "count": 6, "x": -1.7, "z": s.z + 18})
		"damage": s.emit("player_hit", {"amount": 22, "source": "fixture"})
		"part_loss":
			s.robot.remove_part("armour"); s.robot.refresh()
			s.emit("part_broken", {"id": "armour", "slot": "side_r", "level": 2})
		"boss_intro", "boss_fight", "boss_kill":
			s.state = "boss"; s.boss = BossSim.new(); s.boss.setup(1, 0)
			if state == "boss_intro": s.emit("boss_intro")
			if state == "boss_fight":
				s.boss.roar = 0; s.boss.attack = "ground_slam"; s.boss.zones = [{"shape": "circle", "x": 0.0, "radius": 1.2}]
				s.emit("telegraph", {"attack": "ground_slam"})
			if state == "boss_kill": s.state = "won"; s.boss.hp = 0; s.emit("boss_killed")
	game._events()
	game.world.sync(s, 0)
	game._update_hud()
	match state:
		"result_win", "result_loss":
			s.state = "won" if state == "result_win" else "lost"
			game.run_stars = 3 if state == "result_win" else 0
			game.result_reward = 240
			game.result_texture = await game.capture_build()
			game.show_result()
		"hangar": game.show_hangar()
		"garage": game.show_hangar("upgrades")
		"settings": game.show_settings()
		"pause": game.show_pause()
		"purchase": s.pending_parts = ["cannon", "rocket", "armour"]; game.show_purchase()
		"ad_offer": game.show_repair_offer()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://results/" + output)
	game = load("res://src/view/Boot.tscn").instantiate()
	game.flag_overrides = {"ui_v2": variant, "mob_stream": true}
	game.capture = true
	root.add_child(game)
	game.capture = true
	game.save.path = "user://hook_state_fixtures.json"
	var provider := Availability.new()
	game.ads.add_child(provider)
	game.ads.bind_provider(provider)
	var rows: Array = []
	for size in [Vector2i(360, 640), Vector2i(600, 960)]:
		root.size = size
		for state in ["run_start", "mob_gate", "part_gate", "mid_run", "damage", "boss_fight", "result_win", "hangar"]:
			await fixture(state)
			for frame in 4: await process_frame
			game._update_hud()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://results/%s/%s_%d.png" % [output, state, size.x])
			var row: Dictionary = metrics.measure(game)
			if game.overlay.visible:
				var menu_inventory: Array = []; var rectangles: Array = []
				metrics.controls(game.overlay, game.get_viewport().get_visible_rect(), menu_inventory, rectangles)
				row["menu_inventory"] = menu_inventory
			row["render_draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			row["state"] = state; row["window_size"] = [size.x, size.y]
			rows.append(row)
	if variant:
		for row in rows:
			assert(int(row.render_draw_calls) <= 135, "per-state draw budget " + row.state)
			assert(row.hud_popup_area_pct <= 22 and row.popups <= 3 and row.hero_events <= 1 and row.full_screen_effects <= 1, "peak attention budget " + row.state)
			if row.state in ["first_launch", "run_start", "mid_run", "part_gate", "repair_bay"]:
				assert(row.hud_popup_area_pct <= 15, "rest HUD budget " + row.state)
	FileAccess.open("res://results/%s/inventory.json" % output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("HOOK STATE CAPTURE ", output, ": ", rows.size(), " states/sizes completed")
	game.queue_free()
	for frame in 6: await process_frame
	quit()
