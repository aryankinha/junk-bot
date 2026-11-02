extends SceneTree
var failures: Array = []
var checks := 0
func check(value: bool, why: String) -> void:
	checks+=1
	if not value:failures.append(why)
func _initialize() -> void:
	GameData.load_all()
	var sim:=RunSim.new();sim.flag_overrides={"mob_stream":true,"gate_preview":true,"material_tiers":true};sim.setup(1,75)
	var mob: MobSim=sim.mob
	mob.n=0;mob.cap_scale=0.04
	for cohort_id in 5:
		sim.hook.new_cohort(mob,"cannon",7)
		for j in 2:mob.add_drone(MobSim.Kind.BOLT,0,sim.z+2,0,36,7,0,2,1,"cannon")
	var retained:=0.0
	for i in mob.n:retained+=mob.dmg[i]
	check(is_equal_approx(retained+sim.hook.converted_damage,70),"incoming launch payload retained or credited once")
	check(mob.n<=8,"material launch cap respected")
	for i in mob.n:check(mob.wgt[i]<=5,"merge has true weight bound")
	var gate: Dictionary={"type":"mob_gate","z":20.0,"panels":[{"t":"mult","v":100}],"ord":0}
	mob.register_gates([gate])
	var preview: Dictionary=sim.hook.preview(sim,gate,gate.panels[0])
	var cid: int=mob.cohort[0]
	var before:=0.0
	for i in mob.n:
		if mob.cohort[i]==cid:before+=mob.dmg[i]
	var old_credit:float=sim.hook.converted_damage
	sim.hook.apply_gate(sim,mob,0,gate,0)
	var after:=0.0
	for i in mob.n:
		if mob.cohort[i]==cid:after+=mob.dmg[i]
	check(is_equal_approx(after / 7, float(preview.output)),"capped preview reports retained flying units, with separate forge credit")
	check(is_equal_approx(before*100,after+sim.hook.converted_damage-old_credit),"multiplier cap direct payload conserved without double credit")
	check(sim.hook.ledger.converted>0 and absf(sim.hook.ledger.requested-sim.hook.ledger.retained-sim.hook.ledger.converted)<0.001,"allocation ledger balances")
	var fresh:=RunSim.new();fresh.flag_overrides={"material_tiers":true};fresh.setup(1,76)
	check(fresh.hook.quality("cannon")==1,"every run begins Scrap")
	fresh.hook.credit("cannon",29,29,"test");check(fresh.hook.quality("cannon")==1,"below Fixed threshold")
	fresh.hook.credit("cannon",1,1,"test");check(fresh.hook.quality("cannon")==2,"Fixed threshold")
	fresh.hook.credit("cannon",50,50,"test");check(fresh.hook.quality("cannon")==3,"Iron threshold")
	fresh.hook.on_event(fresh,"player_hit",{})
	fresh.hook.credit("cannon",80,80,"test");check(fresh.hook.quality("cannon")==3,"damage pauses credit application without taking a tier away")
	fresh.t=2;fresh.hook.tick(fresh,2);check(fresh.hook.quality("cannon")==4,"paused credit retained and reaches Metal")
	check(fresh.hook.progress("cannon")==1,"Metal is full; no new meter")
	fresh.hook.credit("cannon",100000,100000,"test");check(fresh.hook.ascensionbonus("cannon")<=0.15 and fresh.hook.quality("cannon")==4,"ascend bonus capped and no reset")
	var shrink:=RunSim.new();shrink.flag_overrides={"mob_stream":true,"material_tiers":true};shrink.setup(1,77)
	shrink.mob.n=0;shrink.mob.cap_scale=0.08
	for i in 16:
		shrink.hook.new_cohort(shrink.mob,"cannon",7)
		shrink.mob.add_drone(MobSim.Kind.BOLT,0,2,0,36,35,0,2,5,"cannon")
	shrink.mob.cap_scale=0.04;shrink.mob.enforce_cap()
	var physical:=0.0
	for i in shrink.mob.n:physical+=shrink.mob.dmg[i]
	check(shrink.mob.n==8 and is_equal_approx(physical+shrink.hook.converted_damage,560),"governor shrink accounts existing payload exactly")
	var before_single:=physical;var credit_single:float=shrink.hook.converted_damage
	shrink.mob._multiply(0,10,42)
	physical=0
	for i in shrink.mob.n:physical+=shrink.mob.dmg[i]
	check(is_equal_approx(physical+shrink.hook.converted_damage-credit_single,before_single+350),"material-only legacy multiplication also bounds and accounts overflow")
	print("HOOK3 MATERIAL: ",checks," checks; ",failures.size()," failures")
	for f in failures:printerr(f)
	FileAccess.open("res://results/hook3_material_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
