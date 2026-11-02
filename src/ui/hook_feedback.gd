extends RefCounted
# Hook-only view requests. No rewards, RNG or gameplay changes here.
var last_gate := -10.0
var reveal_time := 0.0
var reveal_value := 0
var reveal_kind := ""
var reveal_clock := 0.0
var last_digit := -1
var chips: Dictionary = {}
var last_signature := ""
var responses: Dictionary = {}
class Segments:
	extends Control
	var quality := 1
	var progress := 0.0
	func _draw() -> void:
		var colors := [Color("825c43"),Color("aa9477"),Color("67747b"),Color("d9e3e9")]
		var width := maxf(1,(size.x-9)/4)
		for i in 4:
			draw_rect(Rect2(i*(width+3),0,width,7),Color("2a3940"))
			if i < quality - 1: draw_rect(Rect2(i*(width+3)+1,1,width-2,5),colors[i])
			elif i == quality - 1: draw_rect(Rect2(i*(width+3)+1,1,(width-2)*progress,5),Color("43b975"))
func active(game) -> bool:
	if game.sim == null: return false
	for flag in ["gate_clarity","gate_preview","material_tiers","horde_scaling","jackpot_gate"]:
		if game.sim.flags.get(flag,false): return true
	return false
func reset(_game) -> void:
	last_gate = -10; reveal_time = 0; reveal_kind = ""; responses.clear(); chips.clear(); last_signature = ""
func note(game, event: Dictionary, response: String, strength: int) -> void:
	responses[event.t] = int(responses.get(event.t,0)) + 1
	game.ui_v2.record(game,str(event.t),response,strength)
func on_event(game, e: Dictionary) -> bool:
	match str(e.t):
		"mob_gate_pass":
			return bool(game.sim.flags.get("gate_preview",false))
		"tier_up":
			var quality := int(e.tier)
			var names: Array = GameData.table("tiers").names
			game.ui_v2.hero(game,"TIER UP / " + str(names[quality-1]).to_upper(),90,Color("d6e3df"),0.55)
			game.audio.play(["weld","plate_clang","polish"][clampi(quality-2,0,2)],1.0); game.haptics.tap(35+quality*5,0.45)
			if not game.save.data.settings.reduce_motion and int(game.save.data.settings.flash_limit)>0:
				game.world.player.forge(str(e.family),quality)
				game.world.burst(Vector3(game.sim.x,1.7,-0.7),6,Color("e0a254"),0.55)
			note(game,e,"material / forge / tier chip",3)
		"hook_gate_pass":
			game.ui_v2.family_guides.mob = true
			if game.runtime-last_gate >= 0.65:
				last_gate=game.runtime
				var suffix := " + FORGE" if float(e.get("converted",0))>0 else ""
				game.ui_v2.hero(game,"POWER %.0f → %.0f%s" % [float(e.input),float(e.output),suffix],65,Color("52bddb"),0.65)
				game.audio.play("gate_step",minf(1.7,1.0 + 0.12*(int(e.get("chain_step",1))-1))); game.haptics.tap(12,0.25)
			game.world.ui_feedback.mob_pass(e)
			note(game,e,"exact cohort output / lens response",2)
		"hook_chain":
			game.ui_v2.hero(game,"CHAIN / POWER %.0f → %.0f" % [float(e.get("input",0)),float(e.total)],75,Color("65c8df"),0.85)
			game.audio.play("gate_step",1.6); game.haptics.tap(25,0.4); note(game,e,"one final chain total",2)
		"hook_crush":
			game.ui_v2.hero(game,"CRUSH ×%d" % int(e.get("kills",e.get("count",0))),70,Color("43b975"),0.8)
			game.audio.play("kill_pop",1.1); game.haptics.tap(18,0.3); note(game,e,"one kill-group total",2)
		"jackpot_reveal":
			reveal_time = 0.4; reveal_clock = 0; reveal_value = int(e.value); reveal_kind = "JACKPOT"; last_digit = -1
			game.ui_v2.hero(game,"JACKPOT / ?",95,Color("eab846"),0.8); game.audio.play("jackpot",1.0); game.haptics.tap(35,0.45); note(game,e,"seed-fixed skippable reveal",3)
		"mystery_reveal":
			reveal_time = 0.4; reveal_clock = 0; reveal_value = int(e.get("amount",e.get("reward",0))); reveal_kind = "SALVAGE"; last_digit = -1
			game.ui_v2.hero(game,"SALVAGE / ?",80,Color("eab846"),0.8); game.audio.play("jackpot",0.9); game.haptics.tap(20,0.3); note(game,e,"existing reward short reveal",2)
		_:
			return false
	return true
func skip() -> void: reveal_time = 0.001
func tick(game, delta: float) -> void:
	if reveal_time>0:
		reveal_clock += delta; reveal_time = maxf(0,reveal_time-delta)
		var digit := int(reveal_clock*24) % 10
		var reduced: bool = bool(game.save.data.settings.reduce_motion)
		if reduced: reveal_time = 0
		if game.ui_v2.hero_priority <= (95 if reveal_kind=="JACKPOT" else 80):
			if reveal_time<=0:
				game.toast_label.text = "%s / %s%d" % [reveal_kind,"×" if reveal_kind=="JACKPOT" else "+",reveal_value]
			elif digit != last_digit:
				last_digit = digit; game.toast_label.text = "%s / %d" % [reveal_kind,digit]
func sync_hud(game) -> void:
	var state = game.sim.get("hook")
	if state == null: return
	if game.sim.flags.get("gate_preview",false) and state.has_method("stream_power"):
		var power: Dictionary = state.stream_power(game.sim)
		game.level_label.text = "POWER %.0f\nSECTOR %02d" % [float(power.get("value",0)),game.sim.level]
		game.level_label.add_theme_font_size_override("font_size",34)
	if not game.sim.flags.get("material_tiers",false): return
	for child in game.parts_row.get_children():
		if not (child is Label) or child.text.begins_with("+") or child.text.begins_with("×"): continue
		var family: String = "cannon" if child.text.begins_with("CANNON") else ("rocket" if child.text.begins_with("ROCKET") else "flame")
		var bar: Segments
		if child.has_meta("tier_segments"): bar = child.get_meta("tier_segments")
		else:
			bar = Segments.new(); child.add_child(bar); child.set_meta("tier_segments",bar)
			child.custom_minimum_size.y = 46; bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bar.offset_top = -7; bar.offset_bottom = 0; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.quality = state.quality(family); bar.progress = state.progress(family); bar.tooltip_text = "QUALITY / " + str(GameData.table("tiers").names[bar.quality-1]); bar.queue_redraw()
