extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.start_run(false)
	game.paused = true
	for i in 4:
		await process_frame
	var output: Dictionary = {"context": "Desktop Compatibility; category isolation; not phone performance", "categories": {}}
	var categories: Dictionary = {"road": game.world.road, "scenery": game.world.scenery, "lane_markings": game.world.stripes, "player": game.world.player, "scrap": game.world.scrap, "gates": game.world.gate_root, "ui": game.hud}
	for key in categories:
		for node in categories.values():
			node.visible = false
		categories[key].visible = true
		for i in 3:
			await process_frame
		output.categories[key] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	for node in categories.values():
		node.visible = true
	for i in 3:
		await process_frame
	output.total = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var file := FileAccess.open("res://results/draw_breakdown.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  "))
	print(JSON.stringify(output))
	game.queue_free()
	await process_frame
	MeshFactory.cache.clear()
	MeshFactory.material = null
	quit()
