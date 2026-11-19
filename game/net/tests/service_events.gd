extends SceneTree

const Exercise := preload("res://net/exercise.gd")

func _initialize() -> void:
	var ex := Exercise.new()
	ex.ready = {1:true,2:true}
	var snapshots := {}
	for seat in [1,2]:
		var id := "owned_%d" % seat
		var slots := {}
		for key: String in {"head":"eye","core":"boiler","weapon":"cannon"}:
			slots[key] = {"id":id+key,"definition":{"head":"eye","core":"boiler","weapon":"cannon"}[key]}
		snapshots[str(seat)] = {"id":id,"version":1,"name":id,"slots":slots}
	if not ex.start(snapshots,"known_battle"):
		quit(1)
		return
	var first = ex.sim.units["0:owned_1"]
	var second = ex.sim.units["0:owned_2"]
	var foe = ex.sim.units[ex.sim.alive_ids(1)[0]]
	var selected: Array[String] = [first.id]
	var ok := ex.sim.repair(selected) == 0 and ex.sim.repair_charges == 2
	first.hp -= 8
	ok = ok and ex.sim.repair(selected) == 8
	foe.hp = 12
	ex.sim._hit(first,foe)
	ex.sim._hit(second,foe)
	ex.sim.retreat()
	var reports := ex.service_reports()
	var expected := [["deployment","field_repair_received","assist","result"],["deployment","kill","result"]]
	for seat in [1,2]:
		var kinds := []
		for event in reports[seat].events:
			kinds.append(event.kind)
		ok = ok and kinds == expected[seat-1]
	ok = ok and reports[1].events[1].actor == "squad_skill" and reports[1].events[1].amount == 8
	print("SERVICE_EVENTS_PASS" if ok else "SERVICE_EVENTS_FAIL", " ", reports)
	quit(0 if ok else 1)
