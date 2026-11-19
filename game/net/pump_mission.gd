extends "res://net/party_mission.gd"

const POINTS := {"valve_a":Vector2(-24,-16),"valve_b":Vector2(25,14),"cache":Vector2(-17,17),"exit":Vector2(22,-18)}
const TITLES := ["西阀守卫","东阀守卫","西阀护卫","东阀护卫","西阀巡卫","东阀巡卫"]
const TIME_LIMIT := 300.0
var calibrated: Array = []
var cache_taken := false
var guards := {"valve_a":[],"valve_b":[]}

func create(id: String, squad: Dictionary, expiry: int) -> bool:
	mission=id
	deployment=squad
	expires=expiry
	sim.relay_objective=false
	sim.field=Sim.Field.new(AREA,ROCKS)
	# Individual limits are enforced on party admission; the combined cooperative roster may exceed one solo squad.
	if not sim.create(squad.units,squad.inventory,Sim.Catalog.sample_squad(6),Sim.Catalog.sample_inventory(6),false,36,18):
		return false
	sim.apply_orders(0,squad.get("orders",{}))
	enemy_ids=sim.alive_ids(1)
	for u in sim.units.values():
		if u.side==0:
			u.pos=Vector2(-28+u.slot%5,8+floori(u.slot/5.0))
		else:
			var valve: String="valve_a" if u.slot%2==0 else "valve_b"
			u.pos=POINTS[valve]+Vector2(1+floori(u.slot/2.0),-2)
			u.lock_time=0.0
			u.stats.move_speed=0.0
			u.stats.damage=0.36
			u.hp=0.0
	return true

func configure_guards(revive: bool) -> void:
	for valve: String in guards:
		guards[valve]=[]
	var count:=participating.size()
	for id: String in enemy_ids:
		var u=sim.units[id]
		if u.slot>=count*2:
			continue
		var valve: String="valve_a" if u.slot%2==0 else "valve_b"
		guards[valve].append(id)
		u.stats.max_hp=520.0 if u.slot<2 else 360.0
		if revive:
			u.hp=u.stats.max_hp

func resolve_assembly(now: float, online: Array) -> bool:
	var changed:=super.resolve_assembly(now,online)
	if changed and battle_started:
		configure_guards(true)
	return changed

func objectives() -> Array:
	if stage==0:
		var available: Array=[]
		for valve: String in guards:
			if valve not in calibrated:
				available.append(valve)
		return available
	return ["cache"] if stage==1 else ["exit"]

func party_order(owner: String, number: int, action: String, ids: Array, target: String, pos: Vector2) -> bool:
	last_move_rejection = ""
	if action not in ["route","collect"]:
		return super.party_order(owner,number,action,ids,target,pos)
	if not battle_started or not commander_sequence.has(owner) or departures.has(owner) or not outcome.is_empty():
		return false
	if number<=int(commander_sequence[owner]) or target not in objectives() or ids.is_empty():
		return false
	var valid: Array[String]=[]
	var near:=false
	for id in ids:
		if not id is String or owners.get(id)!=owner or id in valid or sim.units[id].hp<=0:
			return false
		valid.append(id)
		near=near or sim.units[id].pos.distance_to(POINTS[target])<=4.0
	var next_notice := ""
	if action=="route":
		if not sim.command_move(valid,POINTS[target]):
			last_move_rejection = "no_space" if sim.last_error == "movement_no_space" else ""
			return false
	elif not near:
		next_notice="请带自己的机体抵达四米内"
	elif target in guards:
		for id: String in guards[target]:
			if sim.units[id].hp>0:
				next_notice="先击败本阀的守卫"
				break
		if next_notice.is_empty():
			calibrated.append(target)
			if calibrated.size()==2:
				stage=1
	elif target=="cache":
		cache_taken=true
		stage=2
	else:
		issued_orders[owner]=true
		leave_member(owner,"win")
	if next_notice.is_empty():
		issued_orders[owner]=true
	last_notice = next_notice
	commander_sequence[owner]=number
	return true

func leave_member(owner: String,cause: String) -> void:
	if departures.has(owner) or not outcome.is_empty():
		return
	super.leave_member(owner,cause)
	if departures.size()==commander_sequence.size():
		outcome=cause
		for result: Dictionary in departures.values():
			if result.outcome=="win":
				outcome="win"
				break

func step(delta: float) -> void:
	if not battle_started or not outcome.is_empty():
		return
	sim.step(minf(delta,maxf(0,TIME_LIMIT-sim.elapsed)))
	for owner: String in participating:
		if departures.has(owner):
			continue
		var alive:=false
		for id: String in owners:
			if owners[id]==owner and sim.units[id].hp>0:
				alive=true
				break
		if not alive:
			leave_member(owner,"defeat")
		elif sim.elapsed>=TIME_LIMIT:
			leave_member(owner,"expired")
			departures[owner].cause="time_limit"

func enemy_name(slot: int) -> String:
	return TITLES[slot]

func view() -> Dictionary:
	var frame:=super.view()
	frame.activity="pump_ruin"
	frame.points=POINTS
	frame.calibrated=calibrated.duplicate()
	frame.cache_taken=cache_taken
	frame.guards=guards.duplicate(true)
	return frame

func save_party() -> Dictionary:
	var saved:=super.save_party()
	saved.activity="pump_ruin"
	saved.calibrated=calibrated.duplicate()
	saved.cache_taken=cache_taken
	return saved

func restore_party(saved: Dictionary) -> bool:
	if not super.restore_party(saved):
		return false
	calibrated=saved.calibrated
	cache_taken=saved.cache_taken
	configure_guards(false)
	return true
