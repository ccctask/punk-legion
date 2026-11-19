extends RefCounted

const Simulation := preload("res://battle/simulation.gd")
var last_move_rejection := ""
var sim := Simulation.new()
var id := ""
var tick := 0
var ready := {}
var seq := {}
var owners := {}
var owned := {}
var finished_at := 0

func start(snapshots: Dictionary = {}, battle_id := "") -> bool:
	if not id.is_empty() or not ready.has(1) or not ready.has(2):
		return false
	if snapshots.is_empty():
		if not sim.create_fixture(false):
			return false
	elif not _create_owned(snapshots):
		return false
	id = battle_id if not battle_id.is_empty() else Crypto.new().generate_random_bytes(12).hex_encode()
	for u in sim.units.values():
		owners[u.id] = (1 + u.slot % 2) if u.side == 0 else 0
	return true

func _create_owned(snapshots: Dictionary) -> bool:
	var catalog = Simulation.Catalog
	var squad: Array = catalog.sample_squad(12)
	var inventory: Dictionary = catalog.sample_inventory(12)
	var extra_points := 0
	for key: String in snapshots:
		var seat := int(key)
		var data: Dictionary = snapshots[key]
		var slots := {}
		inventory[data.id] = data.get("chassis","crawler")
		for slot: String in data.slots:
			var part: Dictionary = data.slots[slot]
			slots[slot] = part.id
			inventory[part.id] = part.definition
		var request := {"version":int(data.version),"chassis":data.id,"slots":slots}
		var check := Simulation.Rules.validate_unit(request,inventory)
		if not check.ok or seat not in [1,2]:
			return false
		squad[seat - 1] = request
		extra_points += int(check.totals.points) - 2
		owned[seat] = {"robot":data.id,"name":data.name,"paint":data.get("paint","base"),"hull_number":data.get("hull_number","")}
	squad.resize(12 - ceili(extra_points / 2.0))
	if not sim.create_training(squad,inventory):return false
	var policies:={}
	for data:Dictionary in snapshots.values():policies[data.id]=data.get("orders",{})
	sim.apply_orders(0,policies)
	return true

func service_reports() -> Dictionary:
	var reports := {}
	for seat in owned:
		var robot: String = owned[seat].robot
		var unit := "0:" + robot
		var events := [{"at":0,"kind":"deployment","actor":robot,"target":"","amount":0}]
		for event in sim.timeline:
			var kind := ""
			var actor: String = robot if event.actor == unit else str(event.actor)
			var target: String = robot if event.target == unit else str(event.target)
			var amount := float(event.amount)
			if event.event == "disabled" and event.actor == unit:
				kind = "kill"
				amount = 1
			elif event.event == "disabled" and event.target == unit:
				kind = "disabled"
			elif event.event == "assist" and event.actor == unit:
				kind = "assist"
			elif event.event=="jam_applied" and (event.actor==unit or event.target==unit):
				kind="jam_applied" if event.actor==unit else "jam_received"
				actor=str(event.actor).get_slice(":",1)
				target=str(event.target) if str(event.target).ends_with("/hull") else str(event.target).get_slice(":",1)
			elif event.event == "module_repair" and (event.actor==unit or event.target==unit):
				kind="field_repair_output" if event.actor==unit else "field_repair_received"
				actor=str(event.actor).get_slice(":",1)
				target=str(event.target).get_slice(":",1)
			elif event.event == "field_repair" and event.target == unit:
				kind = "field_repair_received"
				actor = "squad_skill"
			if not kind.is_empty():
				events.append({"at":event.time,"kind":kind,"actor":actor,"target":target,"amount":amount})
		var outcome: String = {0:"win",1:"loss",-1:"draw"}[sim.result.winner]
		var fighter = sim.units[unit]
		var loss := float(fighter.stats.max_hp) - float(fighter.hp)
		if loss > 0:
			events.append({"at":sim.elapsed,"kind":"condition","actor":"combat","target":robot,"amount":loss})
		events.append({"at":sim.elapsed,"kind":"result","actor":robot,"target":outcome,"amount":0})
		reports[seat] = {"robot":robot,"events":events}
	return reports

func step(delta: float) -> void:
	if id.is_empty() or not sim.result.is_empty():
		return
	sim.step(delta)
	tick += 1

func order(seat: int, battle: String, sequence: int, action: String, selection: Array, dest: Vector2, enemy: String) -> bool:
	last_move_rejection = ""
	if battle != id or id.is_empty() or not sim.result.is_empty() or sequence <= int(seq.get(seat, 0)):
		return false
	if seat not in [1, 2] or selection.is_empty() or selection.size() > 6:
		return false
	var ids: Array[String] = []
	for unit in selection:
		if typeof(unit) != TYPE_STRING or owners.get(unit, 0) != seat or unit in ids or sim.units[unit].hp <= 0:
			return false
		ids.append(unit)
	match action:
		"move":
			if not dest.is_finite() or not Simulation.Field.BOUNDS.has_point(Vector2i(dest.round())):
				return false
			if not sim.command_move(ids, dest):
				last_move_rejection = "no_space" if sim.last_error == "movement_no_space" else ""
				return false
		"focus":
			if not sim.units.has(enemy) or owners[enemy] != 0 or sim.units[enemy].hp <= 0:
				return false
			sim.command_focus(ids, enemy)
		"repair":
			sim.repair(ids)
		_:
			return false
	seq[seat] = sequence
	return true

func snapshot(full: bool) -> Dictionary:
	var state := {"id":id, "tick":tick, "ready":ready.duplicate(), "seq":seq.duplicate()}
	if id.is_empty():
		return state
	var rows := {}
	var roster := {}
	for u in sim.units.values():
		rows[u.id] = [u.pos, u.hp, u.last_heading, u.walking, u.last_shot, u.impact_point, u.target_id, u.movement_goal,u.last_service,u.protected_until,u.last_jam]
		if full:
			roster[u.id] = [owners[u.id], u.slot, u.profile.parts, u.stats.max_hp]
			var entry: Dictionary = owned.get(owners[u.id],{})
			roster[u.id].append(entry.get("name","") if entry.get("robot","") == u.profile.entity_id else "")
			roster[u.id].append(entry.get("paint","base") if entry.get("robot","") == u.profile.entity_id else "base")
			roster[u.id].append(u.orders.role)
			roster[u.id].append(u.profile.get("chassis","crawler"))
			roster[u.id].append(entry.get("hull_number","") if entry.get("robot","")==u.profile.entity_id else "")
	state.merge({"units":rows, "elapsed":sim.elapsed, "score":sim.score.duplicate(), "repairs":sim.repair_charges})
	if full:
		state.roster = roster
		state.result = sim.result.duplicate(true)
	return state
