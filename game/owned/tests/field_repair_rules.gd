extends SceneTree

const Mission:=preload("res://net/solo_mission.gd")
const Sim:=preload("res://battle/simulation.gd")
var failures:=0

func expect(yes:bool,what:String) -> void:
	if not yes:
		printerr(what)
		failures+=1

func _initialize() -> void:
	var units:=Sim.Catalog.sample_squad(3)
	units[0].slots.utility="1/repair_arm"
	units[1].slots.utility="2/repair_arm"
	var squad:={"units":units,"inventory":Sim.Catalog.sample_inventory(3)}
	var m:=Mission.new()
	expect(m.create("repair-test",squad,2000000000),"creation")
	var sim=m.sim
	var a:Sim.Fighter=sim.units["0:1/hull"]
	var b:Sim.Fighter=sim.units["0:2/hull"]
	var target:Sim.Fighter=sim.units["0:3/hull"]
	var foe:Sim.Fighter=sim.units["1:1/hull"]
	a.pos=Vector2.ZERO
	b.pos=Vector2.ZERO
	target.pos=Vector2(6,0)
	foe.pos=Vector2.ZERO
	foe.hp-=4
	sim._service_ally(a)
	expect(a.service_charges==4 and foe.hp==foe.stats.max_hp-4,"enemy/self and full health")
	target.hp-=3.25
	sim._service_ally(a)
	expect(a.service_charges==4 and target.hp==66.75,"range")
	target.pos=Vector2(5,0)
	sim._service_ally(a)
	expect(target.hp==66.75 and a.service_charges==4,"minor scratch waits")
	sim.elapsed=6.1
	sim._service_ally(a)
	sim._service_ally(b)
	expect(target.hp==70 and a.service_charges==3 and b.service_charges==4,"two techs contest actual missing hp")
	var d=m.combat_reports(squad,0)
	expect(d["1/hull"][0].kind=="field_repair_output" and d["1/hull"][0].amount==3.25 and d["3/hull"][0].actor=="1/hull","paired attribution")
	b.hp=0
	target.hp=30
	sim._service_ally(a)
	expect(target.hp==30,"cooldown")
	var checkpoint=m.checkpoint()
	var copy:=Mission.new()
	expect(copy.restore(checkpoint) and copy.sim.units[a.id].service_charges==3,"checkpoint")
	for i in 4:
		sim.elapsed+=6
		sim._service_ally(a)
	expect(a.service_charges==0 and target.hp==60,"finite energy")
	var ids:Array[String]=[target.id]
	expect(sim.repair(ids)==10 and sim.timeline.back().actor=="","commander owns the independent squad skill")
	target.hp=0
	sim._service_ally(b)
	expect(target.hp==0,"no revival")
	var pressure:=Mission.new()
	pressure.create("priority-test",squad,2000000000)
	var mechanic:Sim.Fighter=pressure.sim.units[a.id]
	var vulnerable:Sim.Fighter=pressure.sim.units[target.id]
	var scratched:Sim.Fighter=pressure.sim.units[b.id]
	mechanic.pos=Vector2.ZERO
	vulnerable.pos=Vector2.ZERO
	scratched.pos=Vector2.ZERO
	vulnerable.hp-=8
	pressure.sim._service_ally(mechanic)
	expect(vulnerable.hp==70 and mechanic.service_charges==3,"exact eight immediately")
	pressure.sim.elapsed=7
	vulnerable.hp=67
	vulnerable.last_damage=6.9
	scratched.hp=65
	scratched.last_damage=6.9
	pressure.sim._service_ally(mechanic)
	expect(mechanic.service_charges==3,"small recent injuries wait")
	vulnerable.hp=14
	scratched.hp=55
	pressure.sim._service_ally(mechanic)
	expect(vulnerable.hp==24 and scratched.hp==55,"critical picked first")
	pressure.sim.elapsed=16
	vulnerable.hp=55
	scratched.hp=61
	scratched.last_damage=15.9
	pressure.sim._service_ally(mechanic)
	expect(scratched.hp==70 and vulnerable.hp==55,"active fire before older damage")
	if failures==0:print("FIELD_REPAIR_RULES_PASS eligibility, exact clamp, race, source identity, range, cooldown, charges and checkpoint.")
	quit(1 if failures else 0)
