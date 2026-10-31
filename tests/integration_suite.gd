extends RefCounted
var checks := 0
var failures: Array = []
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
func run(tree: SceneTree) -> Array:
	var game = load("res://src/view/Boot.tscn").instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	game.save.path = "user://integration_save.json"
	game.save.data = game.save.defaults()
	game.start_run(false)
	check(game.sim != null and game.world.player != null, "boot constructs sim and world")
	game.capture = true
	game.bot = BotController.new(777, "perfect", 0)
	for i in 12:
		await tree.process_frame
	game.sim.robot.add_part("cannon", game.sim, 3)
	game.sim.robot.add_part("rocket", game.sim, 3)
	game.sim.robot.add_part("wheels", game.sim, 3)
	game.world.sync(game.sim, 0)
	check(game.world.player.attachments.size() == 3, "attachments sync to view")
	check(game.world.player.stage_value == 3, "Monster chassis view")
	check(game.world.enemy_nodes.size() == 24, "enemy pool is bounded")
	check(game.world.projectiles.multimesh.instance_count == 64, "bullet pool")
	check(game.world.scrap.multimesh.instance_count == 400, "scrap batch")
	game.show_pause()
	check(game.paused and game.screen == "pause", "pause")
	var time: float = game.sim.t
	await tree.process_frame
	check(game.sim.t == time, "paused simulation does not advance")
	game.resume_run()
	check(not game.paused and game.screen == "run", "resume")
	game.show_hangar()
	check(game.screen == "hangar" and game.overlay.visible, "hangar")
	game.show_hangar("armoury")
	game.show_hangar("codex")
	game.show_settings()
	check(game.screen == "settings", "settings")
	game.show_reset()
	game.save.data.cogs = 400
	check(game.save.buy_upgrade("cannon"), "affordable upgrade")
	check(game.save.data.cogs == 280 and game.save.data.part_tiers.cannon == 2, "upgrade transaction")
	var store := SaveStore.new()
	store.load_save("user://integration_save.json")
	check(store.data.cogs == 280 and store.data.part_tiers.cannon == 2, "save numeric values roundtrip")
	check(not store.buy_upgrade("bogus"), "invalid upgrade rejected")
	store.data.cogs = 0
	check(not store.buy_upgrade("cannon"), "insufficient cogs rejected")
	var corrupt := FileAccess.open("user://corrupt_test_save.json", FileAccess.WRITE)
	corrupt.store_string("{oops");corrupt.close()
	store.load_save("user://corrupt_test_save.json")
	check(store.data.level == 1 and store.data.cogs == 0, "corrupt save defaults")
	check(Economy.reward(100, 1, true, 3) == 195, "reward and streak cap")
	check(Economy.reward(100, 1, false, 0) == 100, "failure earns collected scrap")
	check(Economy.upgrade_cost(5) == -1, "tier cap")
	check(not game.ads.is_available(), "offline ads hidden")
	var service := AdsService.new()
	tree.root.add_child(service)
	var provider := FakeProvider.new()
	service.bind_provider(provider)
	service.add_child(provider)
	var rewards: Array = []
	service.reward_granted.connect(func(placement): rewards.append(placement))
	check(service.show_rewarded("repair"), "loaded rewarded provider can show")
	check(not service.show_rewarded("repair"), "duplicate show blocked")
	provider.earned.emit()
	provider.earned.emit()
	check(rewards == ["repair"], "earned callback grants exactly once")
	provider.closed.emit()
	check(service.pending.is_empty(), "dismiss clears pending reward")
	service.queue_free()
	game.sim.state = "won"
	game.sim.robot.collected = 100
	await game._finish_run()
	check(game.screen == "result", "result screen")
	var cogs: int = game.save.data.cogs
	await game._finish_run()
	check(game.save.data.cogs == cogs, "result rewards granted once")
	game.start_run(true)
	check(game.daily and game.sim.level == 1 and game.sim.robot.tiers.is_empty(), "daily ignores meta advantages")
	game.sim.state = "won"
	game.sim.robot.collected = 50
	await game._finish_run()
	var daily_store := SaveStore.new()
	daily_store.load_save("user://integration_save.json")
	check(daily_store.data.best_daily.has(game.daily_key), "daily best persists")
	game.start_run(false)
	game.sim.robot.scrap = 100
	game.sim.apply_option({"kind": "buy"})
	check(game.sim.state == "choosing" and game.sim.pending_parts.size() == 3, "buy station offers three parts")
	var purchase: String = game.sim.pending_parts[0]
	check(game.sim.choose_purchase(purchase) and game.sim.robot.parts.has(purchase), "purchase selection attaches chosen part")
	check(game.sim.robot.scrap == 65, "purchase charged once")
	game.show_pause()
	var triangles: Dictionary = {}
	for id in GameData.table("parts"):
		for level in range(1, 4):
			var mesh := MeshFactory.part(id, level)
			var count := mesh.surface_get_array_index_len(0) / 3
			triangles["%s_lv%d" % [id, level]] = count
			check(count <= 800, "part triangle budget: " + id)
	var asset_file := FileAccess.open("res://results/asset_triangles.json", FileAccess.WRITE)
	asset_file.store_string(JSON.stringify(triangles, "  "))
	print("INTEGRATION: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	var file := FileAccess.open("res://results/integration_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	game.queue_free()
	for i in 8:
		await tree.process_frame
	MeshFactory.cache.clear()
	MeshFactory.material = null
	return failures

class FakeProvider:
	extends Node
	signal earned
	signal closed
	signal availability_changed
	var loaded := true
	func is_available() -> bool:
		return loaded
	func show_rewarded(_unit: String) -> void:
		loaded = false
