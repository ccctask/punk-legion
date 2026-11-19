extends SceneTree
const Sim:=preload("res://battle/simulation.gd")

func _initialize() -> void:
	for hull:String in ["crawler","biped"]:
		var s:=Sim.new()
		var inventory:Dictionary=Sim.Catalog.sample_inventory(1)
		inventory["1/hull"]=hull
		if not s.create(Sim.Catalog.sample_squad(1),inventory,Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1)):
			push_error(s.last_error);quit(1);return
		var unit:Sim.Fighter=s.units["0:1/hull"]
		var ids:Array[String]=[unit.id]
		s.command_move(ids,Vector2(-10,6))
		var travelled:=0.0
		for tick in 20:
			var before:=unit.pos
			s.step(0.05)
			travelled+=before.distance_to(unit.pos)
		var speed:=4.6 if hull=="biped" else 3.6
		if absf(travelled-speed)>.02 or s.budgets[0]!=(3 if hull=="biped" else 2):
			push_error("movement/budget mismatch "+str(travelled));quit(1);return
		print("CHASSIS_SIM ",hull," 1s=",travelled," hp=",unit.hp," points=",s.budgets[0])
	quit(0)

