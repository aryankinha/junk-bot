class_name RngStreams extends RefCounted
var gates := RandomNumberGenerator.new()
var spawns := RandomNumberGenerator.new()
var boss := RandomNumberGenerator.new()
var loot := RandomNumberGenerator.new()
func seed_all(value: int) -> void:
	gates.seed = value * 31 + 11
	spawns.seed = value * 31 + 23
	boss.seed = value * 31 + 37
	loot.seed = value * 31 + 53
