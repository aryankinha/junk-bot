class_name HapticsService extends RefCounted
var enabled := true
var last_tick := 0
func tap(ms := 20, amplitude := 0.4) -> void:
	var now := Time.get_ticks_msec()
	if enabled and OS.has_feature("android") and now - last_tick >= 50:
		Input.vibrate_handheld(ms, amplitude)
		last_tick = now
