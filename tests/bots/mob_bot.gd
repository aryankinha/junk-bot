class_name MobBot extends RefCounted
# Plays the Mob Stream: AimBot behaviour (targets, part gates, dodging, reaction delay) plus steering the stream
# into the best mob-gate panel it can see. Gate values are read late by `delay` seconds like everything else.
var aim: AimBot
var delay := 0.0

func _init(seed_arg := 1, reaction := 0.0, build: Array = [], inner_mode := "perfect") -> void:
	aim = AimBot.new(seed_arg, reaction, build, inner_mode)
	delay = reaction

func control(sim: RunSim) -> void:
	aim.control(sim)
