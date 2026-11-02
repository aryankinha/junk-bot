class_name HookBot extends RefCounted
# Same command-delay model as MobBot, but choices use the live, truthful cohort projection.
var aim: AimBot
var delay := 0.0
var commands: Array = []
var applied := 0.0
var next_decision := 0.0
var lane := 0
var row_id := -1
var picks := {"mult":0,"add":0,"power":0,"speed":0,"trap":0}
var stationary := false
func _init(seed_arg := 1, reaction := 0.15, stay := false) -> void:
	aim = AimBot.new(seed_arg,0.0)
	delay=reaction;stationary=stay

static func choose(sim,gate: Dictionary) -> int:
	var best := 0;var score := -INF
	for i in gate.panels.size():
		var preview: Dictionary=sim.hook.preview(sim,gate,gate.panels[i])
		var value: float=float(preview.output)+float(preview.get("converted",0))*0.8
		if gate.panels[i].t=="speed":value+=float(preview.input)*0.1
		if value>score:score=value;best=i
	return best

func control(sim: RunSim) -> void:
	if stationary:
		sim.target_x=0;sim.tap_special();return
	aim.control(sim)
	if sim.hook!=null and sim.mob!=null and sim.state=="running":
		var row: Dictionary={}
		for g in sim.mob.gates:
			if float(g.z)>sim.z+1.5 and float(g.z)<sim.z+60:row=g;break
		var part: Dictionary=sim.next_gate()
		var priority: bool=not part.is_empty() and float(part.z)-sim.z<25 and float(part.z)>sim.z-1
		for enemy in sim.enemies:
			if enemy.warning or float(enemy.charge_left)>0:priority=true
		if not row.is_empty() and not priority:
			if int(row.ord)!=row_id or sim.t>=next_decision:
				lane=choose(sim,row);row_id=int(row.ord);next_decision=sim.t+0.25
				picks[str(row.panels[lane].t)]+=1
			var lead: float=(float(row.z)-sim.z)/27 if row.get("moving",false) else 0.0
			sim.target_x=clampf(sim.mob.panel_center(row,lane,sim.t+lead,sim.flags.tuning),-3,3)
	if delay>0:
		commands.append([sim.t,sim.target_x])
		while not commands.is_empty() and float(commands[0][0])<=sim.t-delay:applied=float(commands.pop_front()[1])
		sim.target_x=applied
