extends SceneTree
const Mission = preload("res://net/solo_mission.gd")
func _initialize() -> void:
	var valid := true
	for config in [[1,false],[2,false],[1,true],[2,true]]:
		var count: int=config[0]
		var drill: bool=config[1]
		var m := Mission.new()
		var catalog := Mission.Sim.Catalog
		var squad=catalog.sample_squad(count)
		if drill:
			for entry in squad:
				entry.slots.weapon=str(entry.chassis).get_slice("/",0)+"/drill"
		m.create("test",{"units":squad,"inventory":catalog.sample_inventory(count)},99999999)
		var last := -1
		while m.outcome.is_empty():
			var ids := m.sim.alive_ids(0)
			var goal: String = m.objectives()[-1] if drill else m.objectives()[0]
			if m.stage != last:
				m.order(m.sequence+1,"route",ids,goal,Vector2.ZERO)
				last = m.stage
			if m.stage in [0,2,4] and not ids.is_empty() and m.sim.units[ids[0]].pos.distance_to(Mission.LOCATIONS[goal]) < 3.2:
				m.order(m.sequence+1,"collect",ids,goal,Vector2.ZERO)
			if not ids.is_empty() and m.sim.units[ids[0]].hp < 48 and m.sim.repair_charges > 0:
				m.order(m.sequence+1,"repair",ids,"",Vector2.ZERO)
			m.step(0.05)
		print("MISSION_SIM count=",count," drill=",drill," seconds=",m.sim.elapsed," outcome=",m.outcome," fights=",m.fighting," march=",m.marching)
		valid = valid and m.outcome=="win" and m.sim.elapsed >= 180 and m.sim.elapsed <= 300
		var terminal:=m.settlement()
		valid=valid and terminal.commanded and terminal.reports.size()==squad.size()
		for entry in squad:
			valid=valid and terminal.reports.has(entry.chassis) and terminal.reports[entry.chassis] is Array
	var idle := Mission.new()
	var catalog := Mission.Sim.Catalog
	idle.create("timeout",{"units":catalog.sample_squad(1),"inventory":catalog.sample_inventory(1)},99999999)
	while idle.outcome.is_empty():
		idle.step(0.05)
	valid = valid and idle.outcome == "defeat" and idle.settlement().seconds == 420.0 and not idle.settlement().commanded
	print("MISSION_TIMEOUT ",idle.outcome," seconds=",idle.settlement().seconds)
	quit(0 if valid else 1)
