class_name GameAudio extends Node
var enabled := true
var music_enabled := true
var players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var streams: Dictionary = {}
var last_played: Dictionary = {}
var music_name := ""
var sfx_volume := 1.0
var music_volume := 1.0
var ducked := false
func _ready() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -6)
	var compressor := AudioEffectCompressor.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), compressor)
	for i in 12:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -13
		add_child(player)
		players.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -12
	add_child(music_player)
	music_player.finished.connect(func():
		if music_enabled:
			music_player.play())
	for id in ["attach", "upgrade", "stage", "scrap", "fire", "hit", "break", "warning", "special", "victory", "defeat", "click", "explosion", "dodge", "multiply", "swarm_hit", "champion", "trap", "ready", "weld", "plate_clang", "polish", "gate_step", "jackpot", "kill_pop", "run_music", "hangar_music"]:
		streams[id] = load("res://assets/audio/%s.%s" % [id, "ogg" if id.ends_with("music") else "wav"])

func play(id: String, pitch := 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not enabled or not streams.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(id, -1000)) < (100 if id == "scrap" else 60):
		return
	var active := 0
	for player in players:
		if player.playing and player.stream == streams[id]:
			active += 1
	if active >= (4 if id in ["fire", "explosion"] else 2):
		return
	for player in players:
		if not player.playing:
			player.stream = streams[id]
			player.bus = "UI" if id == "click" else "SFX"
			player.pitch_scale = clampf(pitch, 0.6, 1.8) if pitch > 0 else randf_range(0.92, 1.08)
			player.play()
			last_played[id] = now
			return

func music(id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not music_enabled:
		music_player.stop()
		return
	if id != music_name or not music_player.playing:
		music_name = id
		music_player.stream = streams[id]
		music_player.play()
func duck(active: bool) -> void:
	ducked = active
	apply_volumes(sfx_volume, music_volume)

func apply_volumes(sfx: float, music_level: float) -> void:
	sfx_volume = clampf(sfx, 0, 1)
	music_volume = clampf(music_level, 0, 1)
	for bus in ["SFX", "UI", "Music"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0: continue
		var volume := music_volume if bus == "Music" else sfx_volume
		AudioServer.set_bus_mute(index, volume <= 0)
		AudioServer.set_bus_volume_db(index, (-10.0 if ducked else -6.0) + linear_to_db(maxf(0.001, volume)) if bus == "Music" else linear_to_db(maxf(0.001, volume)))

func _exit_tree() -> void:
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	for player in players:
		player.stop()
		player.stream = null
	streams.clear()
