extends SceneTree
const Camp := preload("res://net/camp_mission.gd")
const Catalog := preload("res://loadout/catalog.gd")

var site:="brass-yard"

func test(size:int,towers:bool,neutral:bool,empty:bool) -> bool:
	var squad := {"units":Catalog.sample_squad(size),"inventory":Catalog.sample_inventory(size)}
	var defenders := {"units":[],"inventory":{}} if empty else squad
	var mounts: Array = squad.units.map(func(u):return u.chassis) if towers else []
	var mission:=Camp.new()
	if not mission.create("deployment",{"node":site,"attacker":squad,"defender":defenders,"neutral":neutral,"turrets":mounts},int(Time.get_unix_time_from_system())+300):
		return false
	var occupied := {}
	for u in mission.sim.units.values():
		var cell:=Vector2i(u.pos)
		if occupied.has(cell) or mission.sim.field.grid.get_id_path(cell,Vector2i.ZERO).is_empty() or u.pos.length()<=mission.sim.Field.RELAY_RADIUS:
			return false
		if (u.stats.move_speed==0)!=(u.side==1 and (neutral or towers)):
			return false
		occupied[cell]=true
	if not empty and not neutral:
		var old:=mission.checkpoint()
		old.erase("deployment_revision")
		var id:String=mission.sim.alive_ids(1).front()
		old.units[id].pos=Vector2(4,1)
		var restored:=Camp.new()
		if not restored.restore(old) or restored.sim.field.grid.is_point_solid(restored.sim.field.cell(restored.sim.units[id].pos)):
			return false
	return mission.sim.units.size()==size+(1 if neutral else (0 if empty else size))

func _initialize() -> void:
	for node:String in ["brass-yard","coil-depot"]:
		site=node
		for size in [1,6,12]:
			for towers in [true,false]:
				if not test(size,towers,false,false) or not test(size,false,true,true) or not test(size,false,false,true):
					quit(1)
					return
	print("CAMP_DEPLOYMENT_PASS full rosters, neutral/empty/12 fixed defenders, distinct walkable outside-objective cells, legacy obstructed checkpoint recovery")
	quit()
