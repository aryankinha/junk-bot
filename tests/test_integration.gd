extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures: Array = await load("res://tests/integration_suite.gd").new().run(self)
	quit(0 if failures.is_empty() else 1)
