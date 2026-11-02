extends SceneTree
var checks:=0
var failures:Array=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _initialize()->void:
	GameData.load_all()
	var sim:=RunSim.new();sim.flag_overrides={"mob_stream":true,"horde_scaling":true,"gate_preview":true};sim.setup(1,81)
	sim.enemies.clear();sim.hook.spawn_flow(sim,40)
	check(sim.enemies.size()>=5 and sim.enemies.size()<=48,"flow uses bounded existing enemy entities")
	var first_count:int=sim.enemies.size();var first_hp:float=sim.enemies[0].hp
	sim.mob.n=0;sim.hook.new_cohort(sim.mob,"blaster",1)
	sim.mob.add_drone(MobSim.Kind.BOLT,0,2,0,36,40,0,2,40,"blaster")
	sim.enemies.clear();sim.hook.spawn_flow(sim,70)
	check(sim.enemies.size()>first_count,"pack count scales with canonical stream power")
	check(sim.enemies[0].hp>=first_hp,"wave health snapshot scales to weapon output")
	sim.density_limit=0.6;sim.spawn_pack("scrapper",100,80)
	check(sim.enemies.size()<=28,"density governor respected")
	var shield:Dictionary={"hook_shielded":true}
	check(sim.hook.resistance(shield,100,"projectile")==45,"shield resists ordinary bolts")
	check(sim.hook.resistance(shield,100,"rocket")==100 and sim.hook.resistance(shield,100,"cone")==100,"bombs and torch bypass shield")
	var snapshots:Array=[]
	for repeat_run in 2:
		var s:=RunSim.new();s.flag_overrides={"mob_stream":true,"gate_preview":true,"material_tiers":true,"horde_scaling":true};s.setup(1,82)
		var bot=load("res://tests/bots/hook_bot.gd").new(82,0.15)
		var trace:=""
		for frame in 7200:
			bot.control(s);s.step(1.0/60)
			for e in s.events:trace+=JSON.stringify(e)
			s.events.clear()
			check(s.enemies.size()<=48 and s.mob.n<=s.mob.live_cap(),"full sim caps")
			if s.state in ["won","lost"]:break
		snapshots.append(trace.md5_text())
	check(snapshots[0]==snapshots[1],"power scaling and spawns deterministic with same governor schedule")
	print("HOOK4 HORDE: ",checks," checks; ",failures.size()," failures")
	for f in failures:printerr(f)
	FileAccess.open("res://results/hook4_horde_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
