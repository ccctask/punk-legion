extends SceneTree
const Contest:=preload("res://net/camp_mission.gd")
const Sim:=preload("res://battle/simulation.gd")

func _initialize() -> void:
	var a: Dictionary={"units":Sim.Catalog.sample_squad(1),"inventory":Sim.Catalog.sample_inventory(1),"names":{}}
	var rid: String=a.units[0].chassis
	var end:=int(Time.get_unix_time_from_system())+180
	var source:={"attacker":a,"defender":a,"neutral":false,"turrets":[rid]}
	var m:=Contest.new()
	assert(m.create("combat_fixture",source,end))
	assert(not m.command("attacker",1,"move",["1:"+rid],"",Vector2.ZERO))
	assert(not m.command("defender",1,"move",["1:"+rid],"",Vector2.ZERO))
	assert(m.command("defender",1,"focus",["1:"+rid],"0:"+rid,Vector2.ZERO))
	assert(not m.command("defender",1,"focus",["1:"+rid],"0:"+rid,Vector2.ZERO))
	m.sim.elapsed=179.99
	m.progress=[6,6]
	m.sim.units["1:"+rid].pos=Vector2(10,4)
	m.step(0.05)
	assert(m.outcome=="defender" and m.reason=="timeout")
	var other:=Contest.new()
	assert(other.restore(m.checkpoint()))
	assert(other.outcome=="defender" and other.orders[1]==1)
	var gone:=Contest.new()
	assert(gone.create("left_battle",source,end))
	gone.lost_attack_at=int(Time.get_unix_time_from_system())-1
	gone.step(0.05)
	assert(gone.outcome=="defender" and gone.reason=="disconnected")
	print("CAMP_RULES_PASS tower no movement, ownership, replay, timeout tie, checkpoint, lost attacker")
	quit()
