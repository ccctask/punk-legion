extends SceneTree

const Mission:=preload("res://net/solo_mission.gd")

func _initialize() -> void:
	var trial:=Mission.new()
	var catalog=Mission.Sim.Catalog
	var squad:Array=catalog.sample_squad(2)
	squad[1].slots.utility="2/repair_arm"
	trial.create("matched-trial",{"units":squad,"inventory":catalog.sample_inventory(2)},2000000000)
	var last:=-1
	var minimum_hp:=[70.0,70.0]
	while trial.outcome.is_empty():
		var allies:=trial.sim.alive_ids(0)
		var goal:String=trial.objectives()[0]
		if last!=trial.stage:
			trial.order(trial.sequence+1,"route",allies,goal,Vector2.ZERO)
			last=trial.stage
		if trial.stage in [0,2,4] and not allies.is_empty() and trial.sim.units[allies[0]].pos.distance_to(Mission.LOCATIONS[goal])<3.2:
			trial.order(trial.sequence+1,"collect",allies,goal,Vector2.ZERO)
		trial.step(.05)
		for i in 2:
			minimum_hp[i]=minf(minimum_hp[i],trial.sim.units["0:%d/hull"%(i+1)].hp)
	var entries=trial.combat_reports(trial.deployment,0)["2/hull"].filter(func(e):return e.kind=="field_repair_output")
	var total:=0.0
	for event in entries:total+=event.amount
	var survivors:=trial.sim.alive_ids(0)
	var ending:=[]
	for id in survivors:ending.append(trial.sim.units[id].hp)
	print("MATCHED_TRIAL ",JSON.stringify({"events":entries,"total":total,"survivors":survivors.size(),"outcome":trial.outcome,"minimum_hp":minimum_hp,"ending_hp":ending,"seconds":trial.sim.elapsed}))
	quit(0 if entries.size()>0 and trial.outcome=="win" else 1)
