extends "res://net/solo_mission.gd"

const ROLES := ["attacker","defender"]
const HOLD := 16.0
const ROUND_SECONDS := 180.0
const RECONNECT_SECONDS := 30
const LANES := [-3,3,-1,1]
const EMPLACEMENTS := [Vector2i(3,-1),Vector2i(3,1),Vector2i(3,-2),Vector2i(3,2),
	Vector2i(2,-3),Vector2i(2,3),Vector2i(3,-3),Vector2i(3,3),Vector2i(1,-3),
	Vector2i(1,3),Vector2i(4,-2),Vector2i(3,4)]
var progress := [0.0,0.0]
var orders := [0,0]
var aid_orders := {}
var principals := {}
var control := {}
var charges := [2,2]
var reason := ""
var lost_attack_at := 0.0
var round_deadline := 0.0

func create(id: String, squads: Dictionary, expiry: int) -> bool:
	mission=id
	deployment=squads
	expires=expiry
	round_deadline=Time.get_unix_time_from_system()+ROUND_SECONDS
	var a: Dictionary=squads.attacker
	var d: Dictionary=squads.defender
	var enemies: Array=d.units
	var stock: Dictionary=d.inventory
	if squads.neutral:
		enemies=Sim.Catalog.sample_squad(1)
		stock=Sim.Catalog.sample_inventory(1)
	if not sim.create(a.units,a.inventory,enemies,stock,true):
		return false
	var harbor:bool=squads.get("node","brass-yard")=="coil-depot"
	if harbor:
		var barriers:Array[Rect2i]=[]
		for r in Sim.Field.BLOCKS:barriers.append(Rect2i(r.position.x,1-r.end.y,r.size.x,r.size.y))
		sim.field=Sim.Field.new(Sim.Field.BOUNDS,barriers)
	sim.apply_orders(0,a.get("orders",{}))
	sim.apply_orders(1,d.get("orders",{}))
	principals={"attacker":0,"defender":1}
	var occupied := {}
	for unit in sim.units.values():
		var fixed: bool=unit.side==1 and (squads.neutral or unit.profile.entity_id in squads.turrets)
		var column: int=floori(unit.slot/4.0)
		var x: int=-7-column if unit.side==0 else 6+column
		var cell := Vector2i(x,LANES[unit.slot%4])
		if fixed:
			cell=EMPLACEMENTS[unit.slot]
			unit.stats.move_speed=0.0
			unit.lock_time=0.0
		if harbor:cell.y=-cell.y
		if occupied.has(cell) or not sim.field.bounds.has_point(cell) or sim.field.grid.is_point_solid(cell):
			return false
		if sim.field.grid.get_id_path(cell,Vector2i.ZERO).is_empty():
			return false
		occupied[cell]=true
		unit.pos=Vector2(cell)
		var rid: String=unit.profile.entity_id
		var role: String=ROLES[unit.side]
		if squads.get("aid_owners",{}).has(rid):
			role="aid_"+str(squads.aid_owners[rid])
			principals[role]=unit.side
			aid_orders[role]=0
		control[unit.id]=role
		if unit.side==1 and squads.neutral:
			unit.hp=18
			unit.stats.max_hp=18
			unit.stats.damage=1
	sim.relay_objective=false
	return true

func finish(winner: String, why: String) -> void:
	if outcome.is_empty():
		outcome=winner
		reason=why
		finished_at=mini(int(Time.get_unix_time_from_system()),expires)

func lose_attacker(stamp: float) -> void:
	if outcome.is_empty() and lost_attack_at==0:
		lost_attack_at=stamp+RECONNECT_SECONDS

func recover_clock(saved_at: float, stamp: float) -> void:
	if not outcome.is_empty():
		return
	lose_attacker(saved_at)
	var until:=minf(stamp,minf(lost_attack_at,minf(round_deadline,expires)))
	sim.elapsed=minf(ROUND_SECONDS,sim.elapsed+maxf(0.0,until-saved_at))
	resolve_deadlines(stamp)

func timeout_winner() -> String:
	return "attacker" if lost_attack_at==0 and progress[0]>progress[1] else "defender"

func authenticate(role: String, stamp: float) -> void:
	resolve_deadlines(stamp)
	if role=="attacker" and outcome.is_empty():
		lost_attack_at=0

func resolve_deadlines(stamp: float) -> void:
	if not outcome.is_empty():
		return
	var match_deadline:=minf(round_deadline,expires)
	if lost_attack_at>0 and stamp>=lost_attack_at and lost_attack_at<=match_deadline:
		finish("defender","disconnected")
	elif stamp>=match_deadline or sim.elapsed>=ROUND_SECONDS:
		finish(timeout_winner(),"timeout")

func step(delta: float) -> void:
	resolve_deadlines(Time.get_unix_time_from_system())
	if not outcome.is_empty():
		return
	sim.step(delta)
	var on_core: Array[int]=[0,0]
	for unit in sim.units.values():
		if unit.hp>0 and unit.pos.length()<=Sim.Field.RELAY_RADIUS:
			on_core[unit.side]+=1
	for i in 2:
		if on_core[i]>0 and on_core[1-i]==0 and (i==1 or lost_attack_at==0):
			progress[i]=minf(HOLD,float(progress[i])+delta)
	if sim.alive_ids(0).is_empty():
		finish("defender","eliminated")
	elif lost_attack_at==0 and progress[0]>=HOLD:
		finish("attacker","core")
	elif progress[1]>=HOLD:
		finish("defender","core")
	elif sim.elapsed>=ROUND_SECONDS:
		finish(timeout_winner(),"timeout")

func command(role: String, number: int, action: String, selected: Array, target: String, pos: Vector2) -> bool:
	last_move_rejection = ""
	resolve_deadlines(Time.get_unix_time_from_system())
	var side:=int(principals.get(role,-1))
	if side<0 or not outcome.is_empty() or (role=="attacker" and lost_attack_at>0) or number<=_sequence_for(role) or selected.size()>12:
		return false
	var ids: Array[String]=[]
	for value in selected:
		var u:=sim.units.get(str(value)) as Sim.Fighter
		if not u or control[u.id]!=role or u.hp<=0 or u.id in ids:
			return false
		ids.append(u.id)
	match action:
		"move":
			if ids.is_empty() or not pos.is_finite() or not Sim.Field.BOUNDS.has_point(Vector2i(pos.round())):
				return false
			for id in ids:
				if sim.units[id].stats.move_speed<=0:
					return false
			if not sim.command_move(ids,pos,side):
				last_move_rejection = "no_space" if sim.last_error == "movement_no_space" else ""
				return false
		"focus":
			if ids.is_empty() or not sim.units.has(target) or sim.units[target].side==side or sim.units[target].hp<=0:
				return false
			sim.command_focus(ids,target,side)
		"repair":
			sim.repair_charges=charges[side]
			if sim.repair(ids,side)<=0:
				return false
			charges[side]=sim.repair_charges
		"retreat":
			if aid_orders.has(role):
				return false
			if side==0:
				finish("defender","retreat")
			else:
				finish("attacker","surrender")
		_:
			return false
	if aid_orders.has(role):
		aid_orders[role]=number
	else:
		orders[side]=number
	return true

func _sequence_for(role: String) -> int:
	return int(aid_orders[role]) if aid_orders.has(role) else int(orders[principals[role]])

func personalized(role: String) -> Dictionary:
	var side:=int(principals[role])
	var rows: Dictionary={}
	for u in sim.units.values():
		var names: Dictionary=deployment[ROLES[u.side]].names
		var turret: bool=u.stats.move_speed<=0
		rows[u.id]={"pos":u.pos,"hp":u.hp,"max_hp":u.stats.max_hp,"side":u.side,"slot":u.slot,"chassis":u.profile.get("chassis","crawler"),"parts":u.profile.parts,
			"role":u.orders.role,"owned":control[u.id]==role,"is_aid":str(control[u.id]).begins_with("aid_"),
			"hull_number":deployment[ROLES[u.side]].get("hull_numbers",{}).get(u.profile.entity_id,""),
			"paint":deployment[ROLES[u.side]].get("paints",{}).get(u.profile.entity_id,"base"),
			"name":str(names.get(u.profile.entity_id,"中立哨塔")),"turret":turret,
			"heading":u.last_heading,"walking":u.walking,"service":u.last_service,"protected_until":u.protected_until,"last_jam":u.last_jam,"shot":u.last_shot,"impact":u.impact_point}
	return {"id":mission,"node":deployment.get("node","brass-yard"),"name":deployment.get("name","黄铜转运场"),"role":role,"side":side,"seq":_sequence_for(role),"notice":"控制中央核心累计16秒，平局守方保有营地",
		"elapsed":sim.elapsed,"progress":progress.duplicate(),"repairs":charges[side],"units":rows,"outcome":outcome,"reason":reason}

func settlement() -> Dictionary:
	var seconds:=minf(sim.elapsed,ROUND_SECONDS)
	var reports:=combat_reports(deployment.attacker,0,seconds)
	reports.merge(combat_reports(deployment.defender,1,seconds))
	return {"id":mission,"reports":reports,"seconds":seconds,"winner":outcome,"reason":reason,"finished_at":finished_at}

func checkpoint() -> Dictionary:
	var saved:=super.checkpoint()
	saved.merge({"deployment_revision":2,"progress":progress,"orders":orders,"aid_orders":aid_orders,"charges":charges,"reason":reason,"lost_attack_at":lost_attack_at,"round_deadline":round_deadline,"saved_at":Time.get_unix_time_from_system()})
	return saved

func restore(saved: Dictionary) -> bool:
	if not saved.has_all(["saved_at","round_deadline"]) or not super.restore(saved):
		return false
	if not saved.has("deployment_revision") and outcome.is_empty():
		_recover_obstructed_units()
	progress=saved.progress
	orders=saved.orders
	aid_orders=saved.get("aid_orders",{})
	charges=saved.charges
	reason=saved.reason
	lost_attack_at=saved.lost_attack_at
	round_deadline=saved.round_deadline
	return true

func _recover_obstructed_units() -> void:
	var occupied := {}
	for u in sim.units.values():
		occupied[sim.field.cell(u.pos)]=true
	for u in sim.units.values():
		var cell := sim.field.cell(u.pos)
		if not sim.field.grid.is_point_solid(cell):
			continue
		var best := INF
		var closest := cell
		for point in sim.field.grid.get_point_data_in_region(sim.field.bounds):
			var candidate: Vector2i=point.id
			var distance := cell.distance_squared_to(candidate)
			if not occupied.has(candidate) and distance<best and not sim.field.grid.is_point_solid(candidate):
				closest=candidate
				best=distance
		occupied[closest]=true
		u.pos=Vector2(closest)
		u.path.clear()
		u.route_index=0
		u.route_goal=Sim.UNSET
