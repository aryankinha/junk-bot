class_name GameData extends RefCounted

static var tables: Dictionary = {}
const NAMES = ["constants", "parts", "combos", "enemies", "boss_scrap_titan", "gates_level1", "level_generator", "tradeoffs", "economy", "zones", "bot_models"]

static func load_all() -> void:
	if not tables.is_empty():
		return
	for id in NAMES:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % id))
		assert(parsed is Dictionary, "Invalid data table: " + id)
		tables[id] = parsed

static func table(id: String) -> Dictionary:
	load_all()
	return tables[id]

static func constants() -> Dictionary:
	return table("constants")
