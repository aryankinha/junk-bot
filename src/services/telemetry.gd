class_name TelemetryLog extends RefCounted
static func log_event(event: Dictionary) -> void:
	var path := "user://telemetry.jsonl"
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(event))
