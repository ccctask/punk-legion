extends "res://net/solo_mission.gd"

const ASSEMBLY_SECONDS := 30
var assembly_deadline := 0.0
var battle_started := false
var participating := {}
var last_assembly_second := -1
var owners := {}
var commander_sequence := {}
var seat_names := {}
var issued_orders := {}
var absent_until := {}
var departures := {}
var locks := {}
var leader := ""
var join_order: Array[String] = []
var suggestion := {}
var next_suggestion := 0.0

func suggest(owner: String, kind: String, target: String, point: Vector2) -> bool:
	if not battle_started or owner!=leader or departures.has(owner) or not outcome.is_empty() or sim.elapsed<next_suggestion:
		return false
	if kind=="focus":
		if not sim.units.has(target) or sim.units[target].side!=1 or sim.units[target].hp<=0:
			return false
		point=sim.units[target].pos
	elif kind=="move":
		if not point.is_finite() or not AREA.has_point(Vector2i(point.round())) or not target.is_empty():
			return false
	else:
		return false
	suggestion={"kind":kind,"target":target,"position":point,"until":sim.elapsed+6.0}
	next_suggestion=sim.elapsed+2.5
	return true

func create_party(id: String, assignments: Dictionary, expiry: int, authenticated_at := -1.0) -> bool:
	var arrival := Time.get_unix_time_from_system() if authenticated_at < 0 else authenticated_at
	assembly_deadline = arrival + ASSEMBLY_SECONDS
	var combined := {"units":[],"inventory":{},"names":{},"paints":{},"hull_numbers":{},"orders":{}}
	for owner: String in assignments:
		var squad: Dictionary = assignments[owner]
		combined.units.append_array(squad.units)
		combined.inventory.merge(squad.inventory)
		combined.names.merge(squad.get("names",{}))
		combined.orders.merge(squad.get("orders",{}))
		combined.paints.merge(squad.get("paints",{}))
		combined.hull_numbers.merge(squad.get("hull_numbers",{}))
		commander_sequence[owner] = 0
		absent_until[owner] = int(Time.get_unix_time_from_system()) + 30
		for unit in squad.units:
			owners["0:"+str(unit.chassis)] = owner
	return create(id,combined,expiry)

func arrived(online: Array) -> int:
	var count := 0
	for owner: String in online:
		if commander_sequence.has(owner) and not departures.has(owner):
			count += 1
	return count

func assembly_remaining(now: float) -> int:
	return maxi(0, ceili(assembly_deadline - now)) if not battle_started and outcome.is_empty() else 0

func assembly_total() -> int:
	var total := commander_sequence.size()
	for receipt: Dictionary in departures.values():
		if receipt.outcome == "retreat" and not receipt.participated:
			total -= 1
	return total

func resolve_assembly(now: float, online: Array) -> bool:
	if battle_started or not outcome.is_empty():
		return false
	var present := arrived(online)
	if (present == 0 or present != assembly_total()) and now < assembly_deadline:
		return false
	for owner: String in commander_sequence:
		if owner not in online and not departures.has(owner):
			leave_member(owner,"expired")
	if present > 0:
		for owner: String in commander_sequence:
			if owner in online and not departures.has(owner):
				participating[owner] = true
		battle_started = true
	else:
		outcome = "expired"
	return true

func step(delta: float) -> void:
	if battle_started:
		super.step(delta)

func member_outcome(owner: String, cause: String) -> Dictionary:
	var played := participating.has(owner)
	var all := settlement()
	var records := {}
	for id: String in all.reports:
		if owners.get("0:"+id) == owner:
			records[id] = all.reports[id] if played else []
	var record := {"outcome":cause,"participated":played,"commanded":played and issued_orders.get(owner,false),"seconds":all.seconds if played else 0,"nodes":all.nodes.duplicate() if played else [],"reports":records}
	if not cause.is_empty():
		record.cause = terminal_cause(cause) if played else "not_deployed"
	return record

func leave_member(owner: String, cause: String) -> void:
	if departures.has(owner) or not outcome.is_empty():
		return
	departures[owner] = member_outcome(owner,cause)
	if owner == leader:
		leader = ""
		suggestion.clear()
		next_suggestion = 0.0
		for member in join_order:
			if not departures.has(member):
				leader = member
				break
	for id: String in owners:
		if owners[id] == owner:
			sim.units[id].hp = 0
	absent_until.erase(owner)
	if departures.size() == commander_sequence.size():
		outcome = "retreat"

func party_order(owner: String, number: int, action: String, ids: Array, target: String, pos: Vector2) -> bool:
	last_move_rejection = ""
	if (not battle_started and action!="retreat") or departures.has(owner) or not outcome.is_empty() or number <= int(commander_sequence.get(owner,0)):
		return false
	for id in ids:
		if not id is String or owners.get(id) != owner:
			return false
	if action == "retreat":
		leave_member(owner,"retreat")
	elif action == "collect" and stage == 0:
		if target not in objectives() or ids.is_empty():
			return false
		var near := false
		for id: String in ids:
			var fighter = sim.units[id]
			if fighter.hp > 0 and fighter.pos.distance_to(LOCATIONS[target]) <= 4:
				near = true
		if not near or sim.units[enemy_ids[0 if target=="scrap" else 1]].hp > 0:
			return false
		if not locks.has(target):
			locks[target] = {}
		var already:bool = locks[target].has(owner)
		locks[target][owner] = true
		var present := 0
		for claimant in locks[target]:
			if not departures.has(claimant):
				present += 1
		if present >= mini(2,commander_sequence.size()-departures.size()):
			if not order(sequence+1,action,ids,target,pos):
				return false
		elif already:
			return false
		else:
			last_notice = "第一把锁已启用，请另一位指挥官到达并协同采集"
	else:
		if not order(sequence+1,action,ids,target,pos):
			return false
	if action != "retreat" and (last_notice.is_empty() or action=="collect" and stage==0):
		issued_orders[owner]=true
	commander_sequence[owner] = number
	return true

func personalized(owner: String, online: Array = []) -> Dictionary:
	var frame := view()
	frame.seq = commander_sequence[owner]
	frame.owners = owners
	var seats: Array[Dictionary] = []
	for commander: String in commander_sequence:
		var reason: String = departures[commander].outcome if departures.has(commander) else ""
		var status := "departed" if departures.has(commander) else ("online" if commander in online else "waiting")
		seats.append({"owner":commander,"name":str(seat_names.get(commander,"")),"status":status,"reason":reason})
	frame.presence = seats
	frame.assembly = {"phase":"ended" if not outcome.is_empty() else ("started" if battle_started else "assembling"),
		"deadline":assembly_deadline,"remaining":assembly_remaining(Time.get_unix_time_from_system()),
		"online":arrived(online),"total":assembly_total()}
	frame.locks = locks
	frame.withdrawn = departures.has(owner)
	frame.leader = leader
	frame.suggestion = suggestion if sim.elapsed<float(suggestion.get("until",0)) else {}
	return frame

func results() -> Dictionary:
	var all := {}
	for owner: String in commander_sequence:
		all[owner] = departures[owner] if departures.has(owner) else member_outcome(owner,outcome)
	return all

func save_party() -> Dictionary:
	return {"assembly_deadline":assembly_deadline,"battle_started":battle_started,"participating":participating,"model":checkpoint(),"owners":owners,"orders":commander_sequence,"issued":issued_orders,"absence":absent_until,"left":departures,"locks":locks,"leader":leader,"join_order":join_order,"suggestion":suggestion,"next_suggestion":next_suggestion}

func restore_party(saved: Dictionary) -> bool:
	if not restore(saved.model):
		return false
	assembly_deadline = saved.assembly_deadline
	battle_started = saved.battle_started
	participating = saved.participating
	owners = saved.owners
	leader = saved.leader
	join_order.assign(saved.join_order)
	suggestion = saved.get("suggestion",{})
	next_suggestion = float(saved.get("next_suggestion",0))
	commander_sequence = saved.orders
	issued_orders = saved.get("issued",{})
	absent_until = saved.absence
	departures = saved.left
	locks = saved.locks
	for owner in commander_sequence:
		if not absent_until.has(owner) and not departures.has(owner):
			absent_until[owner] = int(Time.get_unix_time_from_system())+30
	return true
