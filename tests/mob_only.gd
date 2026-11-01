extends SceneTree
# Runs only the Mob Stream checks: Godot --headless --path . --script tests/mob_only.gd > out.txt
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var suite = load("res://tests/mob_suite.gd").new()
	suite.run()
	print("%d mob checks; %d failures" % [suite.checks, suite.failures.size()])
	for failure in suite.failures:
		printerr("FAIL: " + failure)
	quit(0 if suite.failures.is_empty() else 1)
