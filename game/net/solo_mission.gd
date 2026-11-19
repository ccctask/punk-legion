extends RefCounted

const Sim := preload("res://battle/simulation.gd")
const Sites := preload("res://expedition/rail_sites.gd")
const AREA := Sites.AREA
const ROCKS: Array[Rect2i] = Sites.ROCKS
const LOCATIONS := Sites.LOCATIONS
const NAMES := Sites.NAMES
const CLOCK_LIMIT := 420.0
var last_move_rejection := ""
var sim := Sim.new()
var mission := ""
var deployment := {}
var stage := 0
var commanded := false
var collected: Array = []
var outcome := "":
	set(value):
		outcome=value
		if not value.is_empty():sim.stop_motion_all()
var sequence := 0
var enemy_ids: Array[String] = []
var expires := 0
var last_notice := ""
var finished_at := 0
var fighting := 0.0
var marching := 0.0
var pulse := 0.0
var rail_layout := false
const PATH_POLICY := "rail-safe-turn-v1"
const INERTIA_POLICY := "rail-light-inertia-v2"
var _safe_turning := false
var _light_inertia := false
var _created := false

func configure_safe_turning(enabled: bool) -> bool:
	if _created or not mission.is_empty() or (not enabled and _light_inertia):return false
	_safe_turning=enabled
	return true

func configure_light_inertia(enabled: bool) -> bool:
	if _created or not mission.is_empty() or (enabled and not _safe_turning):return false
	_light_inertia=enabled
	return true
const ENEMIES := [
	["废轨斥候",Vector2(27,-17),100,0.30],["储能哨兵",Vector2(29,-4),110,0.42],
	["巡查炮臂",Vector2(-27,16),117,0.40],["巡查维修车",Vector2(-29,19),105,0.25],
	["线圈守卫",Vector2(26,17),124,0.38],["熔炉首领",Vector2(-23,-18),245,0.49],
	["首领护卫",Vector2(-25,-16),135,0.40],["冷却维修车",Vector2(-21,-17),118,0.28],
]

func create(id: String, squad: Dictionary, expiry: int) -> bool:
	_created=true
	mission = id
	deployment = squad
	expires = expiry
	sim.relay_objective = false
	rail_layout = true
	sim.field = Sim.Field.new(AREA,Sites.obstacles())
	if not sim.create(squad.units,squad.inventory,Sim.Catalog.sample_squad(ENEMIES.size()),Sim.Catalog.sample_inventory(ENEMIES.size())):
		return false
	if not sim.configure_safe_turning(_safe_turning):return false
	if not sim.configure_light_inertia(_light_inertia):return false
	sim.apply_orders(0,squad.get("orders",{}))
	enemy_ids = sim.alive_ids(1)
	for u in sim.units.values():
		if u.side == 0:
			u.pos = Vector2(-30 + u.slot%4,-18 + floori(u.slot/4.0))
		else:
			var spec: Array = ENEMIES[u.slot]
			u.lock_time = 0.0
			u.pos = Vector2(sim.field.open_cell(sim.field.cell(spec[1])))
			u.stats.max_hp = float(spec[2]) * (1 + 0.9 * mini(3,squad.units.size()-1))
			u.stats.damage = float(spec[3])
			u.stats.drill_multiplier = 1.0 if u.slot in [3,7] else 0.43
			u.stats.move_speed = 1.8
			u.hp = u.stats.max_hp if u.slot < 2 else 0.0
			if _safe_turning and not sim.field.map_segment_clear(u.pos,u.pos,sim._radius(u)):
				var cell:=sim.field.nearest_body_cell(spec[1],sim._radius(u))
				if not sim.field.bounds.has_point(cell):return false
				u.pos=Vector2(cell)
	return true

func objectives() -> Array:
	return [["scrap","fuel"],["guard"],["coil"],["boss"],["exit"]][stage]

func objective_revision() -> int:
	return stage

func _spawn(index: int) -> void:
	var u := sim.units[enemy_ids[index]]
	u.hp = u.stats.max_hp

func step(delta: float) -> void:
	if not outcome.is_empty():
		return
	for pair in [[3,2],[7,5]]:
		var medic:=sim.units[enemy_ids[pair[0]]]
		var ally:=sim.units[enemy_ids[pair[1]]]
		medic.npc_repair_due=sim.elapsed+maxf(0,3.0-pulse) if medic.hp>0 and ally.hp>0 and ally.hp<ally.stats.max_hp and medic.pos.distance_to(ally.pos)<8 else -1.0
	sim.step(delta)
	var hot := false
	var moving := false
	for u in sim.units.values():
		hot = hot or (u.last_shot >= 0 and sim.elapsed-u.last_shot <= 1.15)
		moving = moving or (u.side == 0 and u.walking)
	if hot:
		fighting += delta
	elif moving:
		marching += delta
	if hot and stage in [1,3]:
		for id in sim.alive_ids(1):
			var guard := sim.units[id]
			for ally in sim.alive_ids(0):
				var attacker := sim.units[ally]
				if sim.elapsed-attacker.last_shot < 1.2 and guard.pos.distance_to(attacker.pos)<12:
					guard.target_id = ally
					break
	pulse += delta
	var scheduled:=pulse>=3
	if scheduled:pulse=0
	for pair in [[3,2],[7,5]]:
		var medic:=sim.units[enemy_ids[pair[0]]]
		var armor:=sim.units[enemy_ids[pair[1]]]
		if scheduled:medic.npc_pending=true
		if not medic.npc_pending:continue
		if medic.hp<=0 or armor.hp<=0 or armor.hp>=armor.stats.max_hp or medic.pos.distance_to(armor.pos)>=8:
			medic.npc_pending=false
		elif sim.elapsed>=medic.repair_not_before:
			armor.hp=minf(armor.stats.max_hp,armor.hp+4)
			medic.repair_delayed=false
			medic.npc_pending=false
	if sim.alive_ids(0).is_empty() or sim.elapsed >= CLOCK_LIMIT:
		outcome = "defeat"
	elif stage == 1 and sim.units[enemy_ids[2]].hp <= 0 and sim.units[enemy_ids[3]].hp <= 0:
		stage = 2
		_spawn(4)
	elif stage == 3 and sim.units[enemy_ids[5]].hp <= 0 and sim.units[enemy_ids[6]].hp <= 0 and sim.units[enemy_ids[7]].hp <= 0:
		stage = 4

func order(seq: int, action: String, ids: Array, target: String, pos: Vector2) -> bool:
	last_move_rejection = ""
	if not outcome.is_empty() or seq <= sequence or ids.size() > 12:
		return false
	var valid: Array[String] = []
	for id in ids:
		if typeof(id) != TYPE_STRING or not sim.units.has(id) or sim.units[id].side != 0 or sim.units[id].hp <= 0 or id in valid:
			return false
		valid.append(id)
	if valid.is_empty() and action != "retreat":
		return false
	var next_notice := ""
	match action:
		"move":
			if not pos.is_finite() or not AREA.has_point(Vector2i(pos.round())):
				return false
			if not sim.command_move(valid,pos):
				last_move_rejection = "no_space" if sim.last_error == "movement_no_space" else ""
				return false
		"focus":
			if target not in enemy_ids or sim.units[target].hp <= 0:
				return false
			sim.command_focus(valid,target)
		"repair":
			if sim.repair(valid) <= 0:
				next_notice = "暂无可修复损伤或维修次数已用尽"
		"route":
			if target not in objectives():
				return false
			if stage in [1,3]:
				for index in ([3,2] if stage == 1 else [7,6,5]):
					if sim.units[enemy_ids[index]].hp > 0:
						sim.command_focus(valid,enemy_ids[index])
						break
			else:
				if not sim.command_move(valid,LOCATIONS[target]):
					last_move_rejection = "no_space" if sim.last_error == "movement_no_space" else ""
					return false
		"collect":
			if target not in objectives() or stage in [1,3]:
				return false
			var near := false
			for id in valid:
				if sim.units[id].pos.distance_to(LOCATIONS[target]) <= 4.0:
					near = true
			if not near:
				next_notice = "请先抵达节点四米内"
			elif stage == 4:
				outcome = "win"
			elif sim.units[enemy_ids[{"scrap":0,"fuel":1,"coil":4}[target]]].hp > 0:
				next_notice = "节点还在守卫火力下，先集火守卫"
			else:
				collected.append(target)
				stage += 1
				for index in ([2,3] if stage == 1 else [5,6,7]):
					_spawn(index)
		"retreat":
			outcome = "retreat"
		_:
			return false
	if action != "retreat" and next_notice.is_empty():
		commanded=true
	last_notice = next_notice
	sequence = seq
	return true

func enemy_name(slot: int) -> String:
	return ENEMIES[slot][0]

func view() -> Dictionary:
	var rows := {}
	for u in sim.units.values():
		rows[u.id] = {"pos":u.pos,"hp":u.hp,"max_hp":u.stats.max_hp,"side":u.side,"slot":u.slot,"chassis":u.profile.get("chassis","crawler"),"parts":u.profile.parts,
			"role":u.orders.role,"name":deployment.get("names",{}).get(u.profile.entity_id,"") if u.side == 0 else enemy_name(u.slot),
			"hull_number":deployment.get("hull_numbers",{}).get(u.profile.entity_id,"") if u.side==0 else "",
			"paint":deployment.get("paints",{}).get(u.profile.entity_id,"base") if u.side==0 else "base",
			"heading":u.last_heading,"walking":u.walking,"service":u.last_service,"protected_until":u.protected_until,"last_jam":u.last_jam,"shot":u.last_shot,"impact":u.impact_point}
	return {"id":mission,"stage":stage,"goals":objectives(),"outcome":outcome,"nodes":collected.duplicate(),
		"elapsed":sim.elapsed,"fighting":fighting,"marching":marching,"repairs":sim.repair_charges,"units":rows,"seq":sequence,"notice":last_notice}

func terminal_cause(result: String) -> String:
	match result:
		"win": return "extracted"
		"retreat": return "voluntary_retreat"
		"expired": return "session_expired"
		"defeat": return "time_limit" if not sim.alive_ids(0).is_empty() and sim.elapsed >= CLOCK_LIMIT else "squad_disabled"
	return ""

func settlement() -> Dictionary:
	var record := {"id":mission,"outcome":outcome,"commanded":commanded,"nodes":collected,"reports":combat_reports(deployment,0),"seconds":minf(sim.elapsed,CLOCK_LIMIT)}
	if not outcome.is_empty():
		record.cause = terminal_cause(outcome)
	return record

func combat_reports(squad: Dictionary, side: int, time_limit: float = CLOCK_LIMIT) -> Dictionary:
	var reports := {}
	for unit in squad.units:
		var robot: String = unit.chassis
		var id := "%d:%s" % [side,robot]
		var events := []
		for e in sim.timeline:
			var kind := ""
			var actor: String = e.actor if e.actor != id else robot
			var target: String = e.target if e.target != id else robot
			var amount := float(e.amount)
			if e.event == "disabled" and e.actor == id:
				kind = "kill"
				amount = 1
			elif e.event == "disabled" and e.target == id:
				kind = "disabled"
			elif e.event == "assist" and e.actor == id:
				kind = "assist"
			elif e.event=="jam_applied" and (e.actor==id or e.target==id):
				kind="jam_applied" if e.actor==id else "jam_received"
				actor=str(e.actor).get_slice(":",1)
				target=str(e.target).get_slice(":",1)
				if e.target in enemy_ids and target.ends_with("/hull"):
					target="npc:"+enemy_name(enemy_ids.find(e.target))
			elif e.event == "module_repair" and (e.actor==id or e.target==id):
				kind="field_repair_output" if e.actor==id else "field_repair_received"
				actor=str(e.actor).get_slice(":",1)
				target=str(e.target).get_slice(":",1)
			elif e.event == "field_repair" and e.target == id:
				kind = "field_repair_received"
				actor = "squad_skill"
			if not kind.is_empty():
				events.append({"at":minf(e.time,time_limit),"kind":kind,"actor":actor,"target":target,"amount":amount})
		var fighter := sim.units[id]
		var lost := maxf(0,float(fighter.stats.max_hp) - fighter.hp)
		if lost > 0:
			events.append({"at":minf(sim.elapsed,time_limit),"kind":"condition","actor":"combat","target":robot,"amount":lost})
		reports[robot] = events
	return reports

func checkpoint() -> Dictionary:
	var units := {}
	for u in sim.units.values():
		var data := {}
		data.lock_target = u.lock_target
		data.lock_ready_at = u.lock_ready_at
		data.blast_due = u.blast_due
		for key in ["pos","hp","last_heading","walking","cooldown","target_id","movement_goal","route_goal","route_requested_goal","next_auto_replan_at","path","route_index","last_shot","impact_point","kills","assists","damage","service_charges","last_service","last_damage","jam_charges","last_jam","protected_until","weapon_not_before","repair_not_before","npc_repair_due","npc_pending","weapon_delayed","repair_delayed","received_repair","supporters"]:
			data[key] = u.get(key)
		if _light_inertia:
			data.travel_speed=u.travel_speed
			data.travel_direction=u.travel_direction
		units[u.id] = data
	var saved := {"mission":mission,"deployment":deployment,"expires":expires,"units":units,"timeline":sim.timeline,
		"commanded":commanded,"elapsed":sim.elapsed,"repairs":sim.repair_charges,"stage":stage,"outcome":outcome,"seq":sequence,"nodes":collected,"finished_at":finished_at,"fighting":fighting,"marching":marching,"pulse":pulse}
	if _safe_turning:saved.path_policy=INERTIA_POLICY if _light_inertia else PATH_POLICY
	return saved

func restore(saved: Dictionary) -> bool:
	if _safe_turning:
		var expected:=INERTIA_POLICY if _light_inertia else PATH_POLICY
		if not saved.get("path_policy") is String or saved.path_policy!=expected:return false
	elif saved.has("path_policy"):
		return false
	if not create(saved.mission,saved.deployment,saved.expires):
		return false
	if not saved.get("units") is Dictionary:
		return false
	if saved.units.size() != sim.units.size():
		return false
	for id in saved.units:
		if not sim.units.has(id):
			return false
		# These are decision state, not optional caches or an old-checkpoint upgrade.
		var row: Variant = saved.units[id]
		if not row is Dictionary or not row.has_all(["route_requested_goal","next_auto_replan_at"]):
			return false
		var requested: Variant = row.route_requested_goal
		var deadline: Variant = row.next_auto_replan_at
		if not requested is Vector2i:
			return false
		if requested != Sim.UNSET and not sim.field.bounds.has_point(requested):
			return false
		if not (deadline is float or deadline is int) or not is_finite(float(deadline)) or float(deadline) < 0.0:
			return false
	if rail_layout and not _rail_checkpoint_geometry_valid(saved.units):
		return false
	if _safe_turning and not _safe_turn_checkpoint_valid(saved.units):return false
	if not _inertia_checkpoint_valid(saved):return false
	for id in saved.units:
		for key in saved.units[id]:
			sim.units[id].set(key,saved.units[id][key])
	sim.timeline.assign(saved.timeline)
	sim.elapsed = saved.elapsed
	sim.repair_charges = saved.repairs
	stage = saved.stage
	outcome = saved.outcome
	finished_at = int(saved.get("finished_at",0))
	fighting = float(saved.get("fighting",0))
	marching = float(saved.get("marching",0))
	pulse = float(saved.get("pulse",0))
	commanded = saved.get("commanded",not saved.nodes.is_empty())
	sequence = saved.seq
	collected = saved.nodes
	return true

func _inertia_checkpoint_valid(saved: Dictionary) -> bool:
	for id: String in saved.units:
		var row: Dictionary=saved.units[id]
		if not _light_inertia:
			if row.has("travel_speed") or row.has("travel_direction"):return false
			continue
		if not row.has_all(["travel_speed","travel_direction","walking"]) or not row.walking is bool:return false
		var speed: Variant=row.travel_speed
		var direction: Variant=row.travel_direction
		var maximum: float=float(sim.units[id].stats.move_speed)
		if not (speed is float or speed is int) or not is_finite(float(speed)) or float(speed)<0 or float(speed)>maximum:return false
		if row.walking!=(float(speed)>0):return false
		if not direction is Vector2 or not direction.is_finite():return false
		if float(speed)==0:
			if direction!=Vector2.ZERO:return false
			continue
		if maximum<=0 or float(row.hp)<=0 or not str(saved.outcome).is_empty() or absf(direction.length_squared()-1)>.00001:return false
		var path: PackedVector2Array=row.path
		var index: int=row.route_index
		while index<path.size() and path[index]==row.pos:index+=1
		if index>=path.size():return false
		var aligned: bool=direction.dot(row.pos.direction_to(path[index]))>=1-.00001
		if not aligned and index>1 and row.pos==path[index-1]:
			aligned=direction.dot(path[index-2].direction_to(path[index-1]))>=1-.00001
		if not aligned:return false
		var profile:=Sim._path_motion_profile(row.pos,path,index,direction,maximum)
		if not profile.valid or float(speed)*float(speed)>float(profile.start_limit)*float(profile.start_limit)+2*(maximum/.20)*Sim.PathMotion.POSITION_EPS:return false
	return true

func _safe_turn_checkpoint_valid(saved_units: Dictionary) -> bool:
	for id: String in saved_units:
		var row: Dictionary=saved_units[id]
		var radius: float=sim._radius(sim.units[id])
		if not sim.field.map_segment_clear(row.pos,row.pos,radius):return false
		for key: String in ["movement_goal","route_goal"]:
			if row[key]!=Sim.UNSET and not sim.field.map_segment_clear(Vector2(row[key]),Vector2(row[key]),radius):return false
		var path: PackedVector2Array=row.path
		if path.size()>Sim.Field.TURN_PATH_LIMIT:return false
		if path.is_empty():
			if int(row.route_index)!=0:return false
			continue
		if row.route_goal==Sim.UNSET or path[-1]!=Vector2(row.route_goal):return false
		for point: Vector2 in path:
			if not sim.field.map_segment_clear(point,point,radius):return false
		var index: int=row.route_index
		if index<path.size():
			if not sim.field.map_segment_clear(row.pos,path[index],radius):return false
			for i in range(index+1,path.size()):
				if not sim.field.map_segment_clear(path[i-1],path[i],radius):return false
	return true

func _rail_checkpoint_geometry_valid(saved_units: Dictionary) -> bool:
	# Validate all rows before applying any saved field. Do not repair old layouts.
	for id in saved_units:
		var row: Variant = saved_units[id]
		if not row is Dictionary or not row.has_all(["pos","movement_goal","route_goal","path","route_index"]):
			return false
		var pos: Variant = row.pos
		if not pos is Vector2 or not pos.is_finite() or not _rail_open_cell(Vector2i(pos.round())):
			return false
		for key: String in ["movement_goal","route_goal"]:
			var goal: Variant = row[key]
			if not goal is Vector2i:
				return false
			if goal != Sim.UNSET and not _rail_open_cell(goal):
				return false
		var path: Variant = row.path
		if not path is PackedVector2Array:
			return false
		for point: Vector2 in path:
			if not point.is_finite() or not _rail_open_cell(Vector2i(point.round())):
				return false
		var index: Variant = row.route_index
		if not index is int or index < 0 or index > path.size():
			return false
	return true

func _rail_open_cell(cell: Vector2i) -> bool:
	# Field.cell clamps: check the original rounded cell instead of hiding overflow.
	return sim.field.bounds.has_point(cell) and not sim.field.grid.is_point_solid(cell)




