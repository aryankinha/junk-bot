extends SceneTree
var game
var failures: Array = []
var checks := 0
var v2 := false
var output_prefix := "ui_20261101"
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	v2 = OS.get_cmdline_user_args().has("--v2")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-prefix="):
			output_prefix = arg.substr(13)
			assert(output_prefix.is_valid_filename())
	call_deferred("run")
func settle() -> void:
	for i in 5: await process_frame
func audit_controls(node: Node, bounds: Rect2) -> void:
	for child in node.get_children():
		if child is ScrollContainer:
			check(child.get_global_rect().size.x <= bounds.size.x, "Scroll page fits viewport width")
			continue
		if child is Label and child.is_visible_in_tree() and not child.text.is_empty():
			check(bounds.grow(2).encloses(child.get_global_rect()), "Label outside viewport: " + child.text)
			if child.autowrap_mode == TextServer.AUTOWRAP_OFF:
				check(child.size.x + 2 >= child.get_minimum_size().x, "Label text width fits: " + child.text)
		if child is Button and child.is_visible_in_tree():
			check(bounds.grow(2).encloses(child.get_global_rect()), "Button outside viewport: " + child.text)
		audit_controls(child, bounds)
func run() -> void:
	game = load("res://src/view/Boot.tscn").instantiate()
	game.flag_overrides = {"ui_v2": v2}
	game.capture = true
	root.add_child(game)
	game.capture = true
	game.save.path = "user://ui_review_20261101.json"
	game.save.data = game.save.defaults()
	game.save.data.cogs = 1800
	game.start_run(false)
	game.paused = true
	for level in range(1,4):
		for order in 12:
			var robot := RobotState.new()
			var ids: Array = GameData.table("parts").keys()
			ids = ids.slice(order % ids.size()) + ids.slice(0, order % ids.size())
			for id in ids: robot.add_part(id, null, level)
			robot.tiers = {"cannon": 5, "rocket": 3, "armour": 5}
			game.world.player.sync(robot, false)
			var rig: RobotBuilder = game.world.player
			var keys := rig.attachments.keys()
			for i in keys.size():
				var box := rig.attachment_bounds(keys[i])
				check(not box.intersects(AABB(Vector3(-0.9,1.05,-0.9),Vector3(1.8,1.75,1.8))), "Head overlap: " + keys[i])
				if keys[i] in ["wheels", "tracks"]: check(box.position.y >= 0, "Movement part under road")
				for j in range(i+1, keys.size()): check(not box.intersects(rig.attachment_bounds(keys[j])), "Part overlap: %s/%s" % [keys[i],keys[j]])
			check(not rig.wheels[0].visible, "Base wheels hidden for movement upgrades")
	# Invalidate meshes on tier changes even when the attachment level stays the same.
	var preview := RobotState.new()
	preview.add_part("cannon")
	game.world.player.sync(preview,false)
	preview.tiers.cannon = 3
	game.world.player.sync(preview,false)
	check(game.world.player.attachments.cannon.get_child_count() == 1, "Tier trim refreshed")
	game.show_hangar()
	await settle()
	check(game.overlay.find_children("*", "Button", true, false).size() == 4, "Home has only Play, Garage, Daily and Settings")
	game.navigate_back()
	check(game.screen == "hangar", "Menu Back cannot resurrect run")
	var full := RobotState.new()
	for id in GameData.table("parts"): full.add_part(id, null, 3)
	game.sim.robot = full
	for dimensions in [Vector2i(432,768),Vector2i(360,640),Vector2i(600,960)]:
		root.size = dimensions
		await settle()
		for page in ["home","upgrades","armoury","codex","settings","pause","result"]:
			if page == "settings": game.show_settings()
			elif page == "pause": game.show_pause()
			elif page == "result": game.show_result()
			else: game.show_hangar(page)
			await settle()
			for scroller in game.overlay.find_children("*", "ScrollContainer", true, false):
				var buttons: Array = scroller.find_children("*", "Button", true, false)
				if not buttons.is_empty():
					scroller.ensure_control_visible(buttons.back())
					await settle()
					check(game.get_viewport().get_visible_rect().grow(2).encloses(buttons.back().get_global_rect()), "Last scroll action reachable: " + page)
					scroller.scroll_vertical = 0
					await settle()
			# Scroll contents may intentionally lie outside their clip; audit home and settings.
			if page in ["home","settings","pause","result"]:
				audit_controls(game.overlay, game.get_viewport().get_visible_rect())
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://results/%s_%s_%d.png" % [output_prefix,page,dimensions.x])
	game.sim.boss = BossSim.new()
	game.sim.boss.setup(1, 0)
	game.sim.state = "boss"
	game.screen = "run"
	game.paused = true
	game.overlay.visible = false
	game.hud.visible = true
	if v2:
		game.chain_label.text = "CHAIN ×20"; game.combo_label.text = "COMBO ×15"
	game.world.visible = true
	game.world.sync(game.sim, 0)
	for dimensions in [Vector2i(432,768), Vector2i(360,640), Vector2i(600,960)]:
		root.size = dimensions
		game._update_hud()
		await settle()
		game._update_hud()
		await settle()
		check(not game.top_bar.get_global_rect().intersects(game.boss_panel.get_global_rect()), "Boss bar clears wrapped inventory")
		check(not game.boss_panel.get_global_rect().intersects(game.toast_label.get_global_rect()), "Toast clears boss bar")
		check(not game.chain_label.get_global_rect().intersects(game.combo_label.get_global_rect()), "Combo and pickup chain do not overlap")
		if v2:
			check(game.top_bar.get_global_rect().encloses(game.chain_label.get_global_rect()) and game.top_bar.get_global_rect().encloses(game.combo_label.get_global_rect()), "active counters remain inside stable header")
			for marker in game.boss_bar.get_children():
				check(marker.size.y == game.boss_bar.size.y and marker.size.x >= 4, "boss phase marker spans visible bar")
			for left in [false, true]:
				game.save.data.settings.left_handed = left
				for insets in [Vector2.ZERO, Vector2(140, 100)]:
					game.ui_v2.safe_override = insets
					game._update_hud(); await settle(); game._update_hud(); await settle()
					var a: Rect2 = game.special_button.get_global_rect()
					var b: Rect2 = game.reroll_button.get_global_rect()
					var bounds: Rect2 = game.get_viewport().get_visible_rect()
					check(a.size.x >= 120 and a.size.y >= 120 and b.size.x >= 120 and b.size.y >= 120, "120px logical targets")
					check(not a.intersects(b), "handedness controls do not overlap")
					check(bounds.encloses(a) and bounds.encloses(b), "safe-area controls fit")
					var x := a.get_center().x / bounds.size.x
					var y := a.get_center().y / bounds.size.y
					check(x >= 0.25 and x <= 0.75 and y >= 0.65 and y <= 0.92, "special in lower-middle thumb zone")
					check((x < 0.5) == left, "special mirrors handedness")
			game.save.data.settings.reduce_motion = true; game._apply_settings(); game.ui_v2.tick(game, 0.1)
			check(game.world.reduce_motion and game.special_button.scale == Vector2.ONE, "Reduce Motion applied to layout and world")
			game.save.data.settings.left_handed = false; game.save.data.settings.reduce_motion = false
			game.ui_v2.safe_override = Vector2.ZERO; game._apply_settings(); game._update_hud(); await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://results/%s_hud_%d.png" % [output_prefix,dimensions.x])
	print("UI REVIEW: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: printerr(failure)
	var file := FileAccess.open("res://results/%s_checks.json" % output_prefix,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.queue_free()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
