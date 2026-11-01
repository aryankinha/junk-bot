extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	assert(game.playtest_variant in ["a", "b"])
	assert(game.save.path == "user://mob_playtest_%s.json" % game.playtest_variant)
	assert(game.save.path != SaveStore.PATH and game.save.data.v == 1)
	game.start_run(false)
	assert(game.sim.seed_value == 20261031 and game.bot == null)
	assert((game.sim.mob != null) == (game.playtest_variant == "b"))
	# Restart clears old feedback and rebuilds pooled gate signs even when ordinals are reused.
	game.world.popup("OLD", Vector3.ZERO)
	game.world.mob_gate_nodes[0].ord = 44
	game.world.fx_items.append({})
	game.start_run(false)
	assert(game.world.popups.all(func(p): return not p.visible))
	assert(game.world.fx_items.is_empty())
	assert(game.world.mob_gate_nodes.all(func(s): return s.ord != 44))
	print("PLAYTEST ", game.playtest_variant, ": isolated save, manual controls, matching seed, restart feedback passed")
	quit()
