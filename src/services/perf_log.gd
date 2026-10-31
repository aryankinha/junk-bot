class_name PerfLog extends RefCounted
var frames: Array[float] = []
var draws: Array[int] = []
var previous := 0
var boot_tick := Time.get_ticks_usec()
var first_playable_ms := 0.0
var max_primitives := 0
var enabled := OS.is_debug_build()
func sample() -> void:
	if not enabled:
		return
	var now := Time.get_ticks_usec()
	if previous > 0:
		frames.append((now - previous) / 1000.0)
	previous = now
	if first_playable_ms == 0:
		first_playable_ms = (now - boot_tick) / 1000.0
	draws.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	max_primitives = maxi(max_primitives, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))

func summary() -> Dictionary:
	if frames.is_empty():
		return {"status": "NO_SAMPLES"}
	var sorted := frames.duplicate()
	sorted.sort()
	var calls := draws.duplicate()
	calls.sort()
	var out := {"context": "Headless" if DisplayServer.get_name() == "headless" else ("Android" if OS.has_feature("android") else "Desktop"), "renderer": RenderingServer.get_current_rendering_method(), "samples": sorted.size(), "scene_init_to_first_playable_ms": first_playable_ms, "worst_ms": sorted.back(), "draw_calls_median": calls[calls.size() / 2], "draw_calls_max": calls.back(), "primitives_max": max_primitives, "static_memory_bytes": OS.get_static_memory_usage()}
	for percentile in [50, 95, 99]:
		out["p%d_ms" % percentile] = sorted[mini(sorted.size() - 1, int(sorted.size() * percentile / 100.0))]
	for threshold in [16.7, 20.0, 25.0, 33.0]:
		var count := 0
		for frame in sorted:
			if frame > threshold:
				count += 1
		out["share_over_%s_ms" % threshold] = float(count) / sorted.size()
	return out

func write(path := "user://perf.json") -> void:
	if not enabled:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary(), "  "))
	if path == "user://perf.json":
		var raw := FileAccess.open("user://perf_frames.csv", FileAccess.WRITE)
		if raw != null:
			raw.store_line("frame,raw_ms,draw_calls")
			for i in frames.size():
				raw.store_line("%d,%.4f,%d" % [i, frames[i], draws[mini(i + 1, draws.size() - 1)]])
