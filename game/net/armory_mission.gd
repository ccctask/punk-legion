extends "res://net/solo_mission.gd"

const POINTS := {"armory_cache":Vector2(8,0),"armory_breaker":Vector2(1,-6),"armory_exit":Vector2(-8,0)}
const GUARDS := [Vector2(5,-1),Vector2(5,1),Vector2(6,0)]
const OBSTACLES: Array[Rect2i] = [Rect2i(-2,-6,2,3),Rect2i(-2,4,2,3)]
const LIMIT := 300.0
var breaker := false

func create(id: String, squad: Dictionary, expiry: int) -> bool:
	mission = id
	deployment = squad
	expires = expiry
	sim.relay_objective = false
	sim.field = Sim.Field.new(AREA,OBSTACLES)
	if not sim.create(squad.units,squad.inventory,Sim.Catalog.sample_squad(GUARDS.size()),Sim.Catalog.sample_inventory(GUARDS.size())):
		return false
	sim.apply_orders(0,squad.get("orders",{}))
	enemy_ids = sim.alive_ids(1)
	for u in sim.units.values():
		if u.side == 0:
			u.pos = Vector2(-8-floori(u.slot/4.0),u.slot%4)
		else:
			u.pos = GUARDS[u.slot]
			u.stats.move_speed = 0.0
			u.lock_time = 0
			u.hp = 22
			u.stats.max_hp = u.hp
			u.stats.damage = 2.4
	return true

func objectives() -> Array:
	if stage == 1:
		return ["armory_exit"]
	return ["armory_cache"] if breaker else ["armory_cache","armory_breaker"]

func objective_revision() -> int:
	return stage*10 + int(breaker)*4 + sim.alive_ids(1).size()

func enemy_name(slot: int) -> String:
	return "库门哨机 %d" % (slot+1)

func step(delta: float) -> void:
	if not outcome.is_empty():
		return
	sim.step(minf(delta,LIMIT-sim.elapsed))
	if sim.alive_ids(0).is_empty():
		outcome = "defeat"
	elif sim.elapsed >= LIMIT:
		outcome = "expired"

func terminal_cause(result: String) -> String:
	if result == "expired" and sim.elapsed >= LIMIT:
		return "time_limit"
	return super.terminal_cause(result)

func order(seq: int, action: String, ids: Array, target: String, pos: Vector2) -> bool:
	last_move_rejection = ""
	if action not in ["route","collect"]:
		return super.order(seq,action,ids,target,pos)
	if target not in objectives():
		return false
	var destination: Vector2 = POINTS[target]
	if action == "route":
		return super.order(seq,"move",ids,"",destination)
	if not outcome.is_empty() or seq <= sequence or ids.is_empty() or ids.size() > 12:
		return false
	var selected := {}
	var near := false
	for id in ids:
		if typeof(id) != TYPE_STRING or selected.has(id) or not sim.units.has(id):
			return false
		var unit := sim.units[id]
		if unit.side != 0 or unit.hp <= 0:
			return false
		selected[id] = true
		near = near or unit.pos.distance_to(destination) <= 3.0
	sequence = seq
	last_notice = ""
	if not near:
		last_notice = "请先抵达目标三米内"
	elif target == "armory_breaker":
		breaker = true
		commanded = true
		for i in 2:
			sim.units[enemy_ids[i]].weapon_not_before = LIMIT + 1
		last_notice = "断电成功，前排两台库门哨机已停火"
	elif stage == 0 and not sim.alive_ids(1).is_empty():
		last_notice = "箱区还有守卫，请先清除"
	elif stage == 0:
		commanded = true
		collected.append("armory_cache")
		stage = 1
	else:
		commanded = true
		outcome = "win"
	return true

func view() -> Dictionary:
	var frame := super.view()
	frame.location = "old_armory"
	frame.activity = "old_armory"
	frame.points = POINTS
	frame.armory = {"guards":sim.alive_ids(1).size(),"breaker":breaker}
	return frame

func checkpoint() -> Dictionary:
	var saved := super.checkpoint()
	saved.location = "old_armory"
	saved.breaker = breaker
	return saved

func restore(saved: Dictionary) -> bool:
	if not saved.get("breaker") is bool or not super.restore(saved):
		return false
	breaker = saved.breaker
	return true
