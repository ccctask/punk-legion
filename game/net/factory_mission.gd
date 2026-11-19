extends "res://net/party_mission.gd"

const POINTS := {"start":[-24,0], "checkpoint":[0,0], "gate":[24,0]}
const ESCORT_RADIUS := 4.5
const BLOCK_RADIUS := 6.0
const CART_SPEED := 1.4
const TIME_LIMIT := 300.0
var cart_x := -24.0
var reason := "waiting_escort"
var escorts := {}

func create(id: String, squad: Dictionary, expiry: int) -> bool:
	mission = id
	deployment = squad
	expires = expiry
	sim.relay_objective = false
	var clear_track: Array[Rect2i] = []
	sim.field = Sim.Field.new(AREA, clear_track)
	if not sim.create(squad.units, squad.inventory, Sim.Catalog.sample_squad(2), Sim.Catalog.sample_inventory(2), false, 24, 12):
		return false
	sim.apply_orders(0, squad.get("orders", {}))
	enemy_ids = sim.alive_ids(1)
	for unit in sim.units.values():
		if unit.side == 0:
			unit.pos = Vector2(-29 + unit.slot % 3, 5 + floori(unit.slot / 3.0))
		else:
			unit.pos = Vector2(-8 if unit.slot == 0 else 12, 1)
			unit.stats.move_speed = 0.0
			unit.stats.damage = 0.6
			unit.stats.max_hp = 78.0 if unit.slot == 0 else 104.0
			unit.hp = unit.stats.max_hp
	return true

func enemy_name(slot: int) -> String:
	return "轨口拦截机" if slot == 0 else "厂门拦截机"

func objectives() -> Array:
	return ["cart", "checkpoint", "gate"]

func party_order(owner: String, number: int, action: String, ids: Array, target: String, pos: Vector2) -> bool:
	last_move_rejection = ""
	if not commander_sequence.has(owner) or action == "collect":
		return false
	if action == "route":
		if target not in objectives():
			return false
		var destination := Vector2(cart_x, 0)
		if target != "cart":
			destination.x = POINTS[target][0]
		if not super.party_order(owner, number, "move", ids, "", destination):
			return false
		for id in ids:
			if target == "cart":
				escorts[id] = true
			else:
				escorts.erase(id)
		return true
	if not super.party_order(owner, number, action, ids, target, pos):
		return false
	if action in ["move", "focus"]:
		for id in ids:
			escorts.erase(id)
	return true

func _near(side: int, radius: float) -> bool:
	for unit in sim.units.values():
		if unit.side == side and unit.hp > 0 and unit.pos.distance_to(Vector2(cart_x, 0)) <= radius:
			return true
	return false

func step(delta: float) -> void:
	if not battle_started or not outcome.is_empty():
		return
	var tick := minf(delta, TIME_LIMIT - sim.elapsed)
	for id: String in escorts:
		var unit := sim.units[id]
		if unit.hp > 0 and unit.movement_goal == Sim.UNSET and unit.pos.distance_to(Vector2(cart_x, 0)) > 2.8:
			var selected: Array[String] = [id]
			if not sim.command_move(selected, Vector2(cart_x, 0)):
				continue
	sim.step(tick)
	for owner: String in participating:
		if departures.has(owner):
			continue
		var alive := false
		for id: String in owners:
			if owners[id] == owner and sim.units[id].hp > 0:
				alive = true
				break
		if not alive:
			leave_member(owner, "defeat")
	if not outcome.is_empty():
		return
	if not _near(0, ESCORT_RADIUS):
		reason = "waiting_escort"
	elif _near(1, BLOCK_RADIUS):
		reason = "blocked"
	else:
		reason = "moving"
		cart_x = minf(24.0, cart_x + CART_SPEED * tick)
		stage = 1 if cart_x >= 0.0 else 0
		if cart_x >= 24.0:
			reason = "arrived"
			outcome = "win"
	if outcome.is_empty() and sim.elapsed >= TIME_LIMIT:
		outcome = "expired"

func leave_member(owner: String, cause: String) -> void:
	var active := outcome.is_empty() and not departures.has(owner)
	super.leave_member(owner, cause)
	if active and departures.size() == commander_sequence.size():
		outcome = cause

func terminal_cause(result: String) -> String:
	if result == "win":
		return "factory_gate"
	if result == "expired" and sim.elapsed >= TIME_LIMIT:
		return "time_limit"
	return super.terminal_cause(result)

func cart_state() -> Dictionary:
	return {"cart":[cart_x,0], "progress":(cart_x + 24.0) / 48.0, "checkpoint":stage >= 1, "reason":reason}

func view() -> Dictionary:
	var frame := super.view()
	frame.activity = "factory_escort"
	frame.factory = cart_state()
	frame.factory.points = POINTS
	return frame

func save_party() -> Dictionary:
	var saved := super.save_party()
	saved.activity = "factory_escort"
	saved.cart_x = cart_x
	saved.reason = reason
	saved.escorts = escorts.duplicate()
	return saved

func restore_party(saved: Dictionary) -> bool:
	if not saved.has_all(["cart_x", "reason", "escorts"]) or not super.restore_party(saved):
		return false
	cart_x = saved.cart_x
	reason = saved.reason
	escorts = saved.escorts
	return true
