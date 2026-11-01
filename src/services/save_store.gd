class_name SaveStore extends RefCounted
const PATH := "user://save.json"
var data: Dictionary = {}
var path := PATH

func defaults() -> Dictionary:
	return {"v": 1, "cogs": 0, "level": 1, "part_tiers": {}, "unlocked_parts": [], "codex": [], "streak": 0, "best_daily": {}, "losses_on_level": 0, "settings": {"sound": true, "music": true, "haptics": true, "reduce_motion": false, "left_handed": false, "sfx_volume": 1.0, "music_volume": 1.0, "flash_limit": 3}, "stats": {"runs": 0, "wins": 0, "best_combo": 0, "kills": 0}, "tutorial_done": false, "stars": {}, "last_login": "", "login_streak": 0}

func load_save(file_path := "") -> void:
	if not file_path.is_empty():
		path = file_path
	data = defaults()
	if not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var parsed = parser.data
	if not parsed is Dictionary or int(parsed.get("v", 0)) != 1:
		return
	for key in data:
		if parsed.has(key) and (typeof(parsed[key]) == typeof(data[key]) or (typeof(data[key]) == TYPE_INT and (parsed[key] is int or parsed[key] is float))):
			data[key] = int(parsed[key]) if typeof(data[key]) == TYPE_INT else parsed[key]
	for key in ["cogs", "level", "streak", "losses_on_level"]:
		data[key] = maxi(0, int(data[key]))
	data.level = clampi(int(data.level), 1, 5)
	for id in data.part_tiers.keys():
		if not GameData.table("parts").has(id) or not (data.part_tiers[id] is int or data.part_tiers[id] is float):
			data.part_tiers.erase(id)
		else:
			data.part_tiers[id] = clampi(int(data.part_tiers[id]), 1, 5)
	data.settings = defaults().settings.merged(data.settings, true)
	data.stats = defaults().stats.merged(data.stats, true)

func write(file_path := "") -> bool:
	if not file_path.is_empty():
		path = file_path
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func buy_upgrade(id: String) -> bool:
	if not GameData.table("parts").has(id):
		return false
	var tier := int(data.part_tiers.get(id, 1))
	var cost := Economy.upgrade_cost(tier)
	if cost < 0 or int(data.cogs) < cost:
		return false
	data.cogs -= cost
	data.part_tiers[id] = tier + 1
	write()
	return true

func unlock(id: String) -> bool:
	var costs: Dictionary = GameData.table("economy").unlock_costs
	if not costs.has(id) or data.unlocked_parts.has(id) or int(data.cogs) < int(costs[id]):
		return false
	# Free parts become available at their natural level, not early.
	if int(costs[id]) == 0 and int(data.level) < int(GameData.table("parts")[id].unlock_level):
		return false
	data.cogs -= int(costs[id])
	data.unlocked_parts.append(id)
	write()
	return true
