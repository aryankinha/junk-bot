extends SceneTree
var failures: Array = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	GameData.load_all()
	var sim := RunSim.new()
	sim.flag_overrides = {"mob_stream":true,"gate_preview":true}
	sim.setup(1,41)
	var mob: MobSim = sim.mob
	mob.gates.clear(); sim.beats.clear(); sim.enemies.clear()
	mob.n = 0
	var gate := {"type":"mob_gate","z":20.0,"panels":[{"t":"mult","v":2},{"t":"add","v":10}]}
	mob.register_gates([gate])
	var weapon := {"id":"cannon","type":"projectile","damage":14.0,"speed":36.0}
	mob.launch_volley(sim,weapon,0)
	check(mob.n == 2,"cannon emits one two-unit cohort")
	check(mob.cohort[0] == mob.cohort[1],"siblings share cohort")
	for i in mob.n: mob.px[i] = 1.7
	var preview: Dictionary = sim.hook.preview(sim,gate,gate.panels[1])
	check(preview.input == 2 and preview.output == 12,"add10 applied once per cohort preview")
	sim.hook.apply_gate(sim,mob,0,gate,1)
	var units := 0.0; var damage := 0.0
	for i in mob.n: units += mob.wgt[i]; damage += mob.dmg[i]
	check(is_equal_approx(units,12) and is_equal_approx(damage,84),"actual additive outcome equals preview; payload uses launch nominal damage")
	check(mob.n == 12,"bonus units become visible when room exists")
	var before := damage
	sim.hook.apply_gate(sim,mob,1,gate,1)
	damage = 0
	for i in mob.n: damage += mob.dmg[i]
	check(damage == before,"cohort gate applies once")
	var additive := 0; var multiply := 0
	for count in [2,4,6,8,12,16,24,32,64]:
		var m: float = sim.hook.resolve(count,{"t":"mult","v":2})
		var a: float = sim.hook.resolve(count,{"t":"add","v":10})
		additive += int(a > m); multiply += int(m > a)
	check(additive >= 2 and multiply >= 2,"both options win at least20percent across representative sizes")
	for row in sim.beats:
		if row.type != "mob_gate": continue
		for part in sim.beats:
			if part.type in ["gate","repair_bay","final_choice"]: check(absf(float(row.z)-float(part.z)) >= 25,"authored spacing")
	var authored := RunSim.new(); authored.flag_overrides={"mob_stream":true,"gate_preview":true};authored.setup(1,42)
	for row in authored.beats:
		if row.type!="mob_gate":continue
		for part in authored.beats:
			if part.type in ["gate","repair_bay","final_choice"]:check(absf(float(row.z)-float(part.z))>=25,"all authored family separations")
	var snapshots: Array=[]
	for repeat_run in 2:
		var replay := RunSim.new();replay.flag_overrides={"mob_stream":true,"gate_preview":true};replay.setup(1,73)
		var bot = load("res://tests/bots/hook_bot.gd").new(73,0.15)
		var text := ""
		for frame in 7200:
			bot.control(replay);replay.step(1.0/60)
			for e in replay.events:text+=JSON.stringify(e)
			replay.events.clear()
			check(replay.mob.n<=replay.mob.live_cap(),"cohort cap upheld")
			if replay.state in ["won","lost"]:break
		snapshots.append(text.md5_text())
	check(snapshots[0]==snapshots[1],"Hook cohorts/choices deterministic replay")
	print("HOOK2 PROJECTION: ",checks," checks; ",failures.size()," failures")
	for f in failures:printerr(f)
	FileAccess.open("res://results/hook2_projection_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
