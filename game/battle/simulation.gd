extends RefCounted

const Field := preload("res://battle/field.gd")
const PathMotion := preload("res://battle/path_motion.gd")
const Rules := preload("res://loadout/rules.gd")
const Catalog := preload("res://loadout/catalog.gd")
const CAPTURE_SECONDS := 16.0
const TIME_LIMIT := 180.0
const REPAIR_PER_UNIT := 15.0
const REPAIR_CHARGES := 2
const UNSET := Vector2i(999, 999)

class Fighter:
	var id: String
	var side: int
	var slot: int
	var orders: Dictionary
	var action := "idle"
	var profile: Dictionary
	var stats: Dictionary
	var pos: Vector2
	var hp: float
	var last_heading := Vector2.RIGHT
	var walking := false
	var travel_speed := 0.0
	var travel_direction := Vector2.ZERO
	var cooldown := 0.0
	var lock_time := 0.25
	var lock_target := ""
	var lock_ready_at := 0.0
	var target_id := ""
	var movement_goal: Vector2i = UNSET
	var route_goal: Vector2i = UNSET
	var route_requested_goal: Vector2i = UNSET
	var next_auto_replan_at := 0.0
	var path := PackedVector2Array()
	var route_index := 0
	var last_shot := -10.0
	var impact_point := Vector2.ZERO
	var blast_due := -1.0
	var kills := 0
	var assists := 0
	var damage := 0.0
	var service_charges := 0
	var last_service := -10.0
	var jam_charges:=0
	var last_jam:=-10.0
	var protected_until:=0.0
	var weapon_not_before:=0.0
	var repair_not_before:=0.0
	var npc_repair_due:=-1.0
	var npc_pending:=false
	var weapon_delayed:=false
	var repair_delayed:=false
	var last_damage := 0.0
	var received_repair := 0.0
	var supporters := {}

var field := Field.new()
var relay_objective := true
var units: Dictionary[String, Fighter] = {}
var has_jammer:=false
var blast_checkpoint_due := false
var score: Array[float] = [0.0, 0.0]
var elapsed := 0.0
var time_limit := TIME_LIMIT
var repair_charges := REPAIR_CHARGES
var result := {}
var timeline: Array[Dictionary] = []
var budgets: Array[int] = [0, 0]
var last_error := ""
# Derived only during a synchronous step; never checkpointed or shared across maps.
var _walk_regions := {}
var _walk_segments: Array = []
var _safe_turning := false
var _light_inertia := false
var light_inertia: bool:
	get:return _light_inertia
var safe_turning: bool:
	get:return _safe_turning

func configure_safe_turning(enabled: bool) -> bool:
	if elapsed!=0.0 or not result.is_empty() or (not enabled and _light_inertia):return false
	_safe_turning=enabled
	return true

func configure_light_inertia(enabled: bool) -> bool:
	if elapsed!=0.0 or not result.is_empty() or (enabled and not _safe_turning):return false
	_light_inertia=enabled
	return true

func stop_motion(unit: Fighter) -> void:
	if not _light_inertia:return
	unit.travel_speed=0.0
	unit.travel_direction=Vector2.ZERO
	unit.walking=false

func stop_motion_all() -> void:
	if not _light_inertia:return
	for unit in units.values():stop_motion(unit)

func create_fixture(heavy: bool, enemy_count: int = 6) -> bool:
	var count := 6 if heavy else 12
	return create_training(Catalog.sample_squad(count, heavy), Catalog.sample_inventory(count),enemy_count)

func create_training(allies:Array,inventory:Dictionary,enemy_count:=6)->bool:
	if not create(allies,inventory,Catalog.sample_squad(enemy_count,true),Catalog.sample_inventory(enemy_count)):
		return false
	for id in alive_ids(1):
		units[id].lock_time=0.0
	return true

func create(allies: Array, inventory: Dictionary, enemies: Array, enemy_inventory: Dictionary, allow_empty_defense := false, ally_point_limit := Rules.MAX_POINTS, ally_unit_limit := Rules.MAX_UNITS) -> bool:
	var teams: Array[Dictionary] = [
		Rules.validate_squad(allies, inventory, ally_point_limit, ally_unit_limit), ({"ok":true,"points":0,"roster":[]} if allow_empty_defense and enemies.is_empty() else Rules.validate_squad(enemies, enemy_inventory))]
	for team in teams:
		if not team.ok:
			last_error = team.detail
			return false
	units.clear()
	_safe_turning=false
	_light_inertia=false
	has_jammer=false
	blast_checkpoint_due=false
	timeline.clear()
	result.clear()
	last_error = ""
	elapsed = 0.0
	repair_charges = REPAIR_CHARGES
	score = [0.0, 0.0]
	for side in 2:
		budgets[side] = teams[side].points
		for slot in teams[side].roster.size():
			var entry: Dictionary = teams[side].roster[slot]
			var u := Fighter.new()
			u.side = side
			u.slot = slot
			u.id = "%d:%s" % [side, entry.entity_id]
			u.profile = entry
			if entry.parts.get("head") == "visor":
				u.lock_time = 0.05
			u.orders=default_orders(entry.parts)
			u.stats = entry.combat
			if entry.parts.get("utility")=="repair_arm":
				u.service_charges=Catalog.PARTS.repair_arm.repair_charges
			elif entry.parts.get("utility")=="jammer":
				has_jammer=true
				u.jam_charges=Catalog.PARTS.jammer.jam_charges
			u.hp = u.stats.max_hp
			u.pos = Vector2((-10.0 - 1.5 * floorf(float(slot) / 4.0)) * (1.0 if side == 0 else -1.0), (slot % 4) * 2.0 - 3.0)
			u.last_heading = Vector2.RIGHT if side == 0 else Vector2.LEFT
			units[u.id] = u
	_record("deployment", "", "", budgets[0])
	return true

static func default_orders(parts:Dictionary) -> Dictionary:
	var role:="support" if parts.get("utility")=="repair_arm" else ("front" if parts.get("weapon")=="drill" else "fire")
	return {"role":role,"guard":"","distance":"weapon","priority":"nearest","retreat":0}

func apply_orders(side:int, policies:Dictionary) -> void:
	for u in units.values():
		if u.side==side and policies.has(u.profile.entity_id):
			u.orders.merge(policies[u.profile.entity_id],true)

func _guard(u:Fighter) -> Fighter:
	if str(u.orders.guard).is_empty():
		return null
	var friend:=units.get("%d:%s"%[u.side,u.orders.guard]) as Fighter
	return friend if friend and friend.hp>0 and friend!=u else null

func _separate(u:Fighter, danger:Fighter, radius:float, delta:float) -> bool:
	if u.stats.move_speed<=0 or u.pos.distance_to(danger.pos)>=radius:
		return false
	var away:=u.pos-danger.pos
	if away.length_squared()<0.001:away=Vector2.LEFT if u.side==0 else Vector2.RIGHT
	var goal:=field.open_cell(field.cell(danger.pos+away.normalized()*radius))
	if goal==field.cell(u.pos):return false
	_walk(u,goal,delta,null,true)
	return true

func alive_ids(side: int) -> Array[String]:
	var ids: Array[String] = []
	for u in units.values():
		if u.side == side and u.hp > 0:
			ids.append(u.id)
	return ids

func command_move(ids: Array[String], destination: Vector2, side := 0) -> bool:
	last_error = ""
	if not result.is_empty() or not destination.is_finite() or not field.bounds.has_point(Vector2i(destination.round())):
		last_error = "invalid_move"
		return false
	var seen := {}
	var eligible: Array[Fighter] = []
	for id in ids:
		var u := units.get(id) as Fighter
		if not u or u.side != side or u.hp <= 0 or seen.has(id):
			continue
		seen[id] = true
		if u.stats.move_speed <= 0:
			last_error = "invalid_move"
			return false
		eligible.append(u)
	if eligible.is_empty():
		last_error = "invalid_move"
		return false
	var plan := _plan_group_move(eligible,seen,destination)
	if plan.size() != eligible.size():
		last_error = "movement_no_space"
		return false
	# No Fighter was modified while planning, including on a later member's failure.
	for assignment: Dictionary in plan:
		var u: Fighter = assignment.unit
		u.movement_goal = assignment.goal
		u.target_id = ""
		u.route_goal = assignment.goal
		u.route_requested_goal = assignment.goal
		u.next_auto_replan_at = _next_auto_replan_phase(u)
		u.path = assignment.path
		u.route_index = 0
		if _light_inertia:_project_motion(u)
	return true

func _radius(u: Fighter) -> float:
	return float(u.stats.get("body_radius",0.6))

func _ordered_units() -> Array[Fighter]:
	var ordered: Array[Fighter] = []
	ordered.assign(units.values())
	ordered.sort_custom(func(a: Fighter,b: Fighter) -> bool:
		if a.side != b.side:return a.side < b.side
		if a.slot != b.slot:return a.slot < b.slot
		return a.id < b.id)
	return ordered

func _exclusions(u: Fighter, ignored: Dictionary = {}, reserve_goals := false, escape := false, target: Fighter = null, swept := false) -> Array:
	var shapes: Array = field.static_capsule_exclusions(_radius(u)) if _safe_turning else []
	for other in units.values():
		if other == u or other == target or other.hp <= 0 or ignored.has(other.id):
			continue
		var radius := _radius(u)+_radius(other)
		var floor_distance := minf(radius,u.pos.distance_to(other.pos)) if escape else radius
		shapes.append({"from":other.pos,"to":other.pos,"radius":floor_distance})
		if reserve_goals and other.movement_goal != UNSET:
			var goal := Vector2(other.movement_goal)
			var goal_distance := minf(radius,u.pos.distance_to(goal)) if escape else radius
			shapes.append({"from":goal,"to":goal,"radius":goal_distance})
	if swept:
		for segment: Dictionary in _walk_segments:
			if segment.id == u.id:
				continue
			var radius := _radius(u)+float(segment.radius)
			var floor_distance := minf(radius,sqrt(Field.point_segment_distance_squared(u.pos,segment.from,segment.to))) if escape else radius
			shapes.append({"from":segment.from,"to":segment.to,"radius":floor_distance})
	return shapes

func _plan_group_move(eligible: Array[Fighter], group: Dictionary, destination: Vector2) -> Array:
	var maximum_radius := 0.0
	for u in eligible:
		maximum_radius = maxf(maximum_radius,_radius(u))
	var spacing := maxi(1,ceili(2.0*maximum_radius))
	var columns := ceili(sqrt(float(eligible.size())))
	var rows := ceili(float(eligible.size())/columns)
	var plan: Array = []
	for ordinal in eligible.size():
		var u := eligible[ordinal]
		var offset := Vector2(roundf((ordinal%columns-(columns-1)*0.5)*spacing),roundf((floorf(float(ordinal)/columns)-(rows-1)*0.5)*spacing))
		var ideal := Vector2(field.cell(destination))+offset
		var exclusions := _exclusions(u,group,true,true)
		var endpoint_exclusions := _exclusions(u,group,true)
		for assignment: Dictionary in plan:
			var point := Vector2(assignment.goal)
			var radius := _radius(u)+_radius(assignment.unit)
			exclusions.append({"from":point,"to":point,"radius":minf(radius,u.pos.distance_to(point))})
			endpoint_exclusions.append({"from":point,"to":point,"radius":radius})
		var region := field.walk_region(u.pos,exclusions)
		var candidates: Array = region.parents.keys()
		var placed := false
		var best := Vector2i.ZERO
		var best_ideal := INF
		var best_request := INF
		var source_path := PackedVector2Array()
		for candidate: Vector2i in candidates:
			var ideal_distance := Vector2(candidate).distance_squared_to(ideal)
			var request_distance := Vector2(candidate).distance_squared_to(destination)
			var better := not placed
			if placed:
				if ideal_distance != best_ideal:
					better = ideal_distance < best_ideal
				elif request_distance != best_request:
					better = request_distance < best_request
				else:
					better = candidate.x < best.x if candidate.x != best.x else candidate.y < best.y
			if not better:
				continue
			if not Field.segment_clear(Vector2(candidate),Vector2(candidate),endpoint_exclusions):
				continue
			# Only the source has an additional actual-pos-to-center geometry check.
			if candidate == region.source:
				var candidate_path := field.region_path(region,candidate)
				if candidate_path.is_empty():
					continue
				source_path = candidate_path
			best = candidate
			best_ideal = ideal_distance
			best_request = request_distance
			placed = true
		if not placed:
			return []
		# Other parents have a complete BFS chain; reconstruct only the winner.
		var path := source_path if best == region.source else field.region_path(region,best)
		if _safe_turning:
			path=field.rounded_path(path,_radius(u),region.exclusions)
			if path.is_empty():return []
		plan.append({"unit":u,"goal":best,"path":path})
	return plan

func command_focus(ids: Array[String], enemy_id: String, side := 0) -> void:
	var enemy := units.get(enemy_id) as Fighter
	if not result.is_empty() or not enemy or enemy.side == side or enemy.hp <= 0:
		return
	for id in ids:
		var u := units.get(id) as Fighter
		if u and u.side == side and u.hp > 0:
			u.target_id = enemy_id
			u.movement_goal = UNSET
			u.route_goal = UNSET
			u.route_requested_goal = UNSET
			u.path = PackedVector2Array()
			u.route_index = 0
			u.next_auto_replan_at = 0.0
			stop_motion(u)

func repair(ids: Array[String], side := 0) -> float:
	if not result.is_empty() or repair_charges <= 0:
		return 0.0
	var amount := 0.0
	var seen := {}
	for id in ids:
		var u := units.get(id) as Fighter
		if not u or u.side != side or u.hp <= 0 or seen.has(id):
			continue
		seen[id] = true
		var effective := minf(REPAIR_PER_UNIT, u.stats.max_hp - u.hp)
		if effective > 0:
			u.hp += effective
			u.received_repair += effective
			amount += effective
			_record("field_repair", "", id, effective)
	if amount > 0:
		repair_charges -= 1
	return amount

func _repair_target(tech:Fighter) -> Fighter:
	var spec:Dictionary=Catalog.PARTS.repair_arm
	var recipient:Fighter
	var highest_missing:=0.0
	var highest_priority:=-1
	for ally in units.values():
		if ally==tech or ally.side!=tech.side or ally.hp<=0 or tech.pos.distance_to(ally.pos)>float(spec.repair_range):
			continue
		var missing:float=float(ally.stats.max_hp)-ally.hp
		if missing<=0:
			continue
		var critical:bool=ally.hp<=ally.stats.max_hp*spec.repair_critical_ratio
		var recently_hit:bool=elapsed-ally.last_damage<spec.repair_quiet
		if missing+0.000001<spec.repair_trigger and not critical and recently_hit:
			continue
		var priority:=2 if critical else int(recently_hit)
		if priority>highest_priority or (priority==highest_priority and missing>highest_missing):
			highest_priority=priority
			highest_missing=missing
			recipient=ally
	return recipient

func _service_ally(tech:Fighter) -> void:
	var spec:Dictionary=Catalog.PARTS.repair_arm
	if tech.hp<=0 or tech.service_charges<=0 or elapsed-tech.last_service+0.000001<float(spec.repair_interval) or elapsed+0.000001<tech.repair_not_before:return
	var recipient:=_repair_target(tech)
	if not recipient:return
	var effective:=minf(spec.repair_amount,float(recipient.stats.max_hp)-recipient.hp)
	recipient.hp+=effective
	recipient.received_repair+=effective
	tech.service_charges-=1
	tech.last_service=elapsed
	tech.repair_delayed=false
	_record("module_repair",tech.id,recipient.id,effective)

func _jam(source:Fighter,delta:float) -> void:
	var spec:Dictionary=Catalog.PARTS.jammer
	if source.hp<=0 or source.jam_charges<=0 or elapsed-source.last_jam<float(spec.jam_interval):return
	var target:Fighter
	var best:=INF
	for enemy in units.values():
		if enemy.side==source.side or enemy.hp<=0 or elapsed<enemy.protected_until:continue
		var distance:=source.pos.distance_to(enemy.pos)
		if distance<=float(spec.jam_range) and distance<best and field.can_see(source.pos,enemy.pos):
			best=distance
			target=enemy
	if not target:return
	var weapon_due:=elapsed+maxf(0,target.cooldown-delta)
	var armed:=weapon_due>elapsed
	if target.movement_goal==UNSET:
		var opponent:=units.get(target.target_id) as Fighter
		if not opponent or opponent.hp<=0:opponent=_nearest(target)
		if opponent and target.pos.distance_to(opponent.pos)<=target.stats.range_m+float(opponent.stats.get("body_radius",0.6))-0.6 and field.can_see(target.pos,opponent.pos):
			armed=true
			var lock_due := target.lock_ready_at if target.lock_target==opponent.id else elapsed-delta+target.lock_time
			weapon_due=maxf(weapon_due,lock_due)
	var repair_due:=maxf(elapsed,target.npc_repair_due)
	var needs_service:=target.service_charges>0 and _repair_target(target)!=null
	if needs_service:
		repair_due=maxf(repair_due,target.last_service+float(Catalog.PARTS.repair_arm.repair_interval))
	if not armed or not target.weapon_delayed:
		target.weapon_not_before=maxf(target.weapon_not_before,weapon_due+float(spec.jam_delay))
		target.weapon_delayed=armed
	if not (needs_service or target.npc_repair_due>=0) or not target.repair_delayed:
		target.repair_not_before=maxf(target.repair_not_before,repair_due+float(spec.jam_delay))
		target.repair_delayed=needs_service or target.npc_repair_due>=0
	target.protected_until=elapsed+float(spec.jam_protection)
	source.last_jam=elapsed
	source.jam_charges-=1
	_record("jam_applied",source.id,target.id,float(spec.jam_protection))
	timeline.back().merge({"weapon_pending":armed,"repair_pending":needs_service or target.npc_repair_due>=0,
		"original_weapon_due":weapon_due,"original_repair_due":repair_due,
		"weapon_not_before":target.weapon_not_before,"repair_not_before":target.repair_not_before,"protected_until":target.protected_until})

func retreat() -> void:
	if result.is_empty() and not units.is_empty():
		_finish("retreat", 1)

func step(delta: float) -> void:
	if _light_inertia and not is_finite(delta):
		stop_motion_all()
		return
	if not result.is_empty() or units.is_empty() or delta <= 0:
		return
	_walk_regions.clear()
	_walk_segments.clear()
	elapsed += delta
	if has_jammer:
		for source in units.values():
			if source.jam_charges>0:_jam(source,delta)
	var alive := [0, 0]
	var holding := [0, 0]
	# Damage is applied after decisions so simultaneous last shots both count.
	var volleys: Array = []
	for u in _ordered_units():
		u.walking = false
		u.action="idle"
		# A target stays locked only while this fighter can actually aim at it.
		var previous_lock:String = u.lock_target
		u.lock_target = ""
		if u.hp <= 0:
			continue
		u.cooldown = maxf(0, u.cooldown - delta)
		if u.movement_goal != UNSET:
			u.action="move"
			if _walk(u, u.movement_goal, delta):
				u.movement_goal = UNSET
			continue
		var target := units.get(u.target_id) as Fighter
		var manual:bool=target!=null and target.hp>0
		if not manual:
			u.target_id = ""
			target = _nearest(u)
			if target and int(u.orders.retreat)>0 and u.hp*100<=float(u.stats.max_hp)*float(u.orders.retreat):
				if _separate(u,target,maxf(6.0,minf(8.0,float(target.stats.range_m)+1.5)),delta):
					u.action="retreat"
					continue
				if u.stats.move_speed>0 and u.pos.distance_to(target.pos)>float(u.stats.range_m):
					u.action="hold"
					continue
			var friend:=_guard(u)
			if friend and u.stats.move_speed>0 and u.pos.distance_to(friend.pos)>4.0:
				u.action="guard"
				_walk(u,field.cell(friend.pos),delta,null,true)
				continue
			if target and u.orders.distance=="standoff" and _separate(u,target,float(u.stats.range_m)*0.78,delta):
				u.action="standoff"
				continue
		if target:
			u.action="focus" if manual else "engage"
			var reach:float=u.stats.range_m + float(target.stats.get("body_radius",0.6)) - 0.6
			if not manual and u.orders.distance=="close" and u.stats.move_speed>0:reach=minf(reach,1.8)
			if u.pos.distance_to(target.pos) <= reach and field.can_see(u.pos, target.pos):
				if u.profile.parts.get("armor") == "rivet_shield":
					_turn(u,target.pos-u.pos,delta)
				u.lock_target = target.id
				if previous_lock != target.id:
					u.lock_ready_at = elapsed - delta + u.lock_time
				if u.cooldown <= 0.000001 and elapsed+0.000001>=maxf(u.weapon_not_before,u.lock_ready_at):
					u.cooldown = u.stats.attack_interval
					u.last_shot = elapsed
					u.weapon_delayed=false
					u.impact_point = target.pos
					if u.profile.parts.get("armor") != "rivet_shield" and target.pos != u.pos:
						u.last_heading = (target.pos-u.pos).normalized()
					if u.profile.parts.weapon == "chimney_arm":
						u.blast_due = elapsed + float(Catalog.PARTS["chimney_arm"].blast_delay)
						blast_checkpoint_due = true
					else:
						volleys.append([u, target, false])
			else:
				_approach(u,target,delta,reach)
		elif relay_objective and u.side == 1 and u.pos.length() > Field.RELAY_RADIUS - 0.3:
			_walk(u, Vector2i(u.slot % 3 - 1, floori(float(u.slot % 6) / 3.0)), delta,null,true)
	# All derived movement data is released before damage/service/terminal handling.
	if _light_inertia:
		for u in units.values():
			if not u.walking or u.hp<=0:stop_motion(u)
	_walk_regions.clear()
	_walk_segments.clear()
	for launcher in units.values():
		if launcher.blast_due < 0 or launcher.blast_due > elapsed + 0.000001:
			continue
		launcher.blast_due = -1.0
		blast_checkpoint_due = true
		for enemy in units.values():
			if enemy.side != launcher.side and enemy.hp > 0 and enemy.pos.distance_to(launcher.impact_point) <= float(Catalog.PARTS["chimney_arm"].blast_radius):
				volleys.append([launcher,enemy,true])
	for shot in volleys:
		_hit(shot[0], shot[1], shot[2])
	for tech in units.values():
		if tech.hp>0 and tech.service_charges>0:
			_service_ally(tech)
	if not relay_objective:
		return
	for u in units.values():
		if u.hp > 0:
			alive[u.side] += 1
			if u.pos.length() <= Field.RELAY_RADIUS:
				holding[u.side] += 1
	for side in 2:
		if holding[side] > 0 and holding[1 - side] == 0:
			score[side] = minf(CAPTURE_SECONDS, score[side] + delta)
	if alive[0] == 0 or alive[1] == 0:
		_finish("eliminated", -1 if alive[0] == alive[1] else (0 if alive[0] else 1))
	elif maxf(score[0], score[1]) >= CAPTURE_SECONDS:
		_finish("relay", 0 if score[0] > score[1] else 1)
	elif elapsed >= time_limit:
		_finish("timeout", -1 if is_equal_approx(score[0], score[1]) else (0 if score[0] > score[1] else 1))

func _nearest(u: Fighter) -> Fighter:
	var best:Fighter
	var best_rating:=INF
	var best_dist:=INF
	var limit:=maxf(7.0,float(u.stats.range_m))
	var protected_id:="%d:%s"%[u.side,u.orders.guard]
	for other in units.values():
		if other.side==u.side or other.hp<=0:continue
		var distance:=u.pos.distance_to(other.pos)
		if distance>=limit:continue
		var rating:=0.0
		if u.orders.priority=="weakest":
			rating=other.hp/float(other.stats.max_hp)
		elif u.orders.priority=="threat":
			var attacking:bool=other.target_id==u.id or other.target_id==protected_id
			rating=(-1000.0 if attacking else 0.0)-float(other.stats.damage)/float(other.stats.attack_interval)
		if rating<best_rating or (is_equal_approx(rating,best_rating) and distance<best_dist):
			best_rating=rating
			best_dist=distance
			best=other
	return best

func _next_auto_replan_phase(u: Fighter) -> float:
	# The complete deployment order includes dead fighters, so deaths never move phases.
	var ordinal := _ordered_units().find(u)
	var phase := float(ordinal % 10)*0.05
	return phase+(floorf((elapsed+0.000001-phase)/0.5)+1.0)*0.5

func _walk_region(u: Fighter, target: Fighter = null) -> Dictionary:
	if _walk_regions.has(u.id):
		return _walk_regions[u.id]
	# An empty dictionary means pending, never an already-queried empty region.
	if u.hp <= 0 or elapsed+0.000001 < u.next_auto_replan_at:
		return {}
	_walk_regions[u.id] = field.walk_region(u.pos,_exclusions(u,{},true,true,target,true))
	u.next_auto_replan_at = _next_auto_replan_phase(u)
	return _walk_regions[u.id]

func _nearest_walk_cell(u: Fighter, region: Dictionary, desired: Vector2) -> Vector2i:
	var best := UNSET
	var distance := INF
	var cost := INF
	var exclusions := _exclusions(u,{},true)
	for candidate: Vector2i in region.parents:
		var point := Vector2(candidate)
		var next_distance := point.distance_squared_to(desired)
		var next_cost: float = region.costs[candidate]
		var better := next_distance < distance or (next_distance == distance and (next_cost < cost or (next_cost == cost and (best == UNSET or candidate.x < best.x or (candidate.x == best.x and candidate.y < best.y)))))
		if not better or not Field.segment_clear(point,point,exclusions):
			continue
		best = candidate
		distance = next_distance
		cost = next_cost
	return best

func _approach(u: Fighter, target: Fighter, delta: float, reach: float) -> void:
	var target_cell := field.cell(target.pos)
	# A still-usable approach cache does not need a new whole-region query.
	if not u.path.is_empty() and u.route_index < u.path.size():
		var endpoint := u.path[u.path.size()-1]
		if u.route_goal == target_cell or (endpoint.distance_to(target.pos) <= reach and field.can_see(endpoint,target.pos)):
			_walk(u,u.route_goal,delta,target)
			return
	var region := _walk_region(u,target)
	if region.is_empty():
		return
	var chosen := UNSET
	var best_cost := INF
	var best_distance := INF
	var exclusions := _exclusions(u,{},true)
	for candidate: Vector2i in region.parents:
		var point := Vector2(candidate)
		if point.distance_to(target.pos) > reach:
			continue
		var cost: float = region.costs[candidate]
		var distance := point.distance_squared_to(target.pos)
		var better := cost < best_cost or (cost == best_cost and (distance < best_distance or (distance == best_distance and (chosen == UNSET or candidate.x < chosen.x or (candidate.x == chosen.x and candidate.y < chosen.y)))))
		if not better or not field.can_see(point,target.pos) or not Field.segment_clear(point,point,exclusions):
			continue
		chosen = candidate
		best_cost = cost
		best_distance = distance
	# The pursued body is a planning exception only. Actual steps still clip to it.
	# This permits a short-range unit to approach at fractional (non-grid) distances.
	if chosen == UNSET and region.parents.has(target_cell):
		chosen = target_cell
	if chosen != UNSET:
		_walk(u,chosen,delta,target)

func _at_walk_goal(u: Fighter, goal: Vector2i, precise := false) -> bool:
	var arrived := u.pos == Vector2(goal) if precise else u.pos.distance_to(Vector2(goal)) < 0.005
	return arrived and Field.segment_clear(u.pos,u.pos,_exclusions(u))

func _escape_improves(u: Fighter, start: Vector2, finish: Vector2) -> bool:
	var overlapping := false
	var improves := false
	for other in units.values():
		if other == u or other.hp <= 0:
			continue
		var radius := _radius(u)+_radius(other)
		var before := start.distance_to(other.pos)
		if before >= radius-Field.GEOMETRY_EPS:
			continue
		overlapping = true
		var after := finish.distance_to(other.pos)
		if after < before-Field.GEOMETRY_EPS:
			return false
		improves = improves or after > before+Field.GEOMETRY_EPS
	return not overlapping or improves

func _install_walk_path(u: Fighter, goal: Vector2i, region: Dictionary, requested_goal: Vector2i = UNSET) -> bool:
	if region.is_empty() or region.from != u.pos:
		return false
	var path:=field.region_path(region,goal)
	if _safe_turning:
		path=field.rounded_path(path,_radius(u),region.exclusions)
		if path.is_empty():return false
	u.route_goal = goal
	u.route_requested_goal = goal if requested_goal == UNSET else requested_goal
	u.path = path
	u.route_index = 0
	if _light_inertia:_project_motion(u)
	return true

func _motion_profile(u: Fighter) -> Dictionary:
	return _path_motion_profile(u.pos,u.path,u.route_index,u.travel_direction,float(u.stats.move_speed))

static func _path_motion_profile(position: Vector2, path: PackedVector2Array, index: int, direction: Vector2, maximum: float) -> Dictionary:
	var points:=PackedVector2Array([position])
	while index<path.size() and path[index]==position:index+=1
	for i in range(index,path.size()):points.append(path[i])
	var prefix:=path.slice(maxi(0,index-2),index)
	return PathMotion.profile(points,direction,maximum,maximum/.20,TAU,prefix)

func _project_motion(u: Fighter) -> void:
	var index:=u.route_index
	while index<u.path.size() and u.path[index]==u.pos:index+=1
	if index>=u.path.size():
		stop_motion(u)
		return
	var direction: Vector2=(u.path[index]-u.pos).normalized()
	var projected:=u.travel_speed*maxf(0,u.travel_direction.dot(direction))
	u.travel_direction=direction if projected>0 else Vector2.ZERO
	var profile:=_motion_profile(u)
	if not profile.valid:
		stop_motion(u)
		return
	u.travel_speed=minf(projected,minf(float(u.stats.move_speed),float(profile.start_limit)))
	if u.travel_speed==0:stop_motion(u)

func _static_walk_segment(start: Vector2, finish: Vector2) -> bool:
	if not start.is_finite() or not finish.is_finite():
		return false
	for point: Vector2 in [start,finish]:
		var cell := Vector2i(point.round())
		if not field.bounds.has_point(cell) or field.grid.is_point_solid(cell):
			return false
	return field.can_see(start,finish)

func _cached_exact_walk(u: Fighter, desired: Vector2i) -> bool:
	if u.route_requested_goal != desired or u.path.is_empty() or u.route_index < 0 or u.route_index > u.path.size():
		return false
	if not _walk_segment_clear(u,u.pos,u.pos) or u.path[u.path.size()-1] != Vector2(u.route_goal):
		return false
	# A nearby substitute remains usable until arrival. Reconsider it only when due.
	if u.route_index == u.path.size():
		return _at_walk_goal(u,u.route_goal) and (u.route_goal == desired or elapsed+0.000001 < u.next_auto_replan_at)
	return true

func _walk_segment_clear(u: Fighter, start: Vector2, finish: Vector2) -> bool:
	return field.map_segment_clear(start,finish,_radius(u)) if _safe_turning else _static_walk_segment(start,finish)

func _walk(u: Fighter, goal: Vector2i, delta: float, target: Fighter = null, nearby := false) -> bool:
	if u.stats.move_speed <= 0 or delta <= 0:
		return false
	# A pursuit endpoint inside weapon range is not a substitute for actual position.
	var precise := target != null or _light_inertia
	var installed_region := false
	var requested_goal := goal
	if nearby:
		if _cached_exact_walk(u,requested_goal):
			goal = u.route_goal
		else:
			var region := _walk_region(u,target)
			if region.is_empty():
				return false
			goal = _nearest_walk_cell(u,region,Vector2(requested_goal))
			if goal == UNSET:
				return false
			installed_region = _install_walk_path(u,goal,region,requested_goal)
			if not installed_region:
				return false
	if _at_walk_goal(u,goal,precise):
		stop_motion(u)
		return true
	if u.route_goal != goal or u.path.is_empty() or u.route_index < 0 or u.route_index >= u.path.size():
		var region := _walk_region(u,target)
		if region.is_empty():
			return false
		installed_region = _install_walk_path(u,goal,region,requested_goal)
		if not installed_region:
			return false
	var remaining: float = u.stats.move_speed * delta
	var remaining_time:=delta
	var motion_profile := {}
	var profile_index:=0
	var events:=0
	while (remaining_time>0 if _light_inertia else remaining>0) and u.route_index < u.path.size():
		if _light_inertia and events>=6*PathMotion.POINT_LIMIT+8:
			stop_motion(u)
			return false
		var waypoint := u.path[u.route_index]
		var d := u.pos.distance_to(waypoint)
		var precise_end := precise and u.route_index == u.path.size()-1
		if d == 0.0 or (not _light_inertia and d < 0.005 and not precise_end):
			if not _walk_segment_clear(u,u.pos,waypoint):
				if not installed_region:
					var region := _walk_region(u,target)
					if not region.is_empty():
						installed_region = _install_walk_path(u,goal,region,requested_goal)
						if installed_region:
							motion_profile={}
							profile_index=0
							continue
				return false
			u.route_index += 1
			if _light_inertia:events+=1
			continue
		var direction := (waypoint - u.pos) / d
		var movement := minf(d, remaining)
		var advance := {}
		if _light_inertia:
			if motion_profile.is_empty():
				motion_profile=_motion_profile(u)
				profile_index=0
			if not motion_profile.valid:
				stop_motion(u)
				return false
			advance=PathMotion.advance_segment(u.travel_speed,float(motion_profile.limits[profile_index]),float(motion_profile.nodes[profile_index+1]),d,remaining_time,float(u.stats.move_speed)/.25,float(u.stats.move_speed)/.20)
			if not advance.valid:
				stop_motion(u)
				return false
			events+=int(advance.events)
			movement=float(advance.distance)
			if movement<=0:
				stop_motion(u)
				return false
		var start := u.pos
		var proposed := waypoint if (_light_inertia and advance.reached) or (precise_end and movement>=d) else start+direction*movement
		# Only the segment actually consumed this step is statically checked.
		# Dynamic body clipping still includes the target and accepted swept segments.
		var fraction := 0.0
		if _walk_segment_clear(u,start,proposed):
			fraction = Field.safe_fraction(start,proposed,_exclusions(u,{},false,true,null,true))
		var finish := proposed if fraction == 1.0 else start.lerp(proposed,fraction)
		if not _escape_improves(u,start,finish):
			fraction = 0.0
		var travelled := start.distance_to(finish) if fraction > 0 else 0.0
		var advances := travelled > 0.000001 or (precise_end and travelled > 0) or (_light_inertia and travelled>0)
		var used_time: float=travelled/float(u.stats.move_speed)
		if _light_inertia and advances:
			used_time=float(advance.time) if fraction==1.0 else PathMotion.time_for_distance(advance.phases,travelled)
			if not is_finite(used_time) or used_time<0 or used_time>remaining_time+.000001:
				stop_motion(u)
				return false
		if advances:
			u.pos = finish
			if _light_inertia:
				u.travel_speed=float(advance.speed)
				u.travel_direction=direction if u.travel_speed>0 else Vector2.ZERO
				remaining_time=maxf(0,remaining_time-used_time)
			_walk_segments.append({"id":u.id,"from":start,"to":u.pos,"radius":_radius(u)})
			_turn(u,direction,used_time)
			u.walking = u.travel_speed>0 if _light_inertia else true
			remaining -= travelled
			if fraction == 1.0 and movement >= d:
				u.route_index += 1
				if _light_inertia:profile_index+=1
		if fraction < 1.0 or not advances:
			stop_motion(u)
			if _light_inertia:remaining_time=0.0
			# Never join a tree from an earlier source onto an already-walked prefix.
			if not installed_region:
				var region := _walk_region(u,target)
				if not region.is_empty() and region.from == u.pos:
					var replacement := _nearest_walk_cell(u,region,Vector2(requested_goal)) if nearby else goal
					if replacement != UNSET:
						installed_region = _install_walk_path(u,replacement,region,requested_goal)
						if installed_region:
							goal = replacement
							motion_profile={}
							profile_index=0
							continue
			return false
	var arrived:=_at_walk_goal(u,goal,precise)
	if arrived:stop_motion(u)
	return arrived

func _turn(unit: Fighter, direction: Vector2, seconds: float) -> void:
	if direction.is_zero_approx():return
	if unit.profile.parts.get("armor") != "rivet_shield":
		unit.last_heading=direction.normalized()
		return
	var limit:=deg_to_rad(float(Catalog.PARTS["rivet_shield"].turn_degrees_per_second))*seconds
	var angle:=unit.last_heading.angle()
	var difference:=fposmod(direction.angle()-angle+PI,TAU)-PI
	unit.last_heading=Vector2.from_angle(angle+clampf(difference,-limit,limit))

func _hit(attacker: Fighter, target: Fighter, area := false) -> void:
	if target.hp <= 0:
		return
	var damage: float = attacker.stats.damage
	if attacker.profile.parts.weapon == "drill":
		damage *= float(target.stats.get("drill_multiplier",1.0))
	if damage > 0.0 and not area and target.profile.parts.get("armor") == "rivet_shield":
		var shield:Dictionary=Catalog.PARTS["rivet_shield"]
		var bearing:=target.pos.direction_to(attacker.pos)
		if target.last_heading.dot(bearing)+0.000001 >= cos(deg_to_rad(float(shield.front_half_angle))):
			var reduced:=damage*float(shield.direct_damage_ratio)
			damage=maxf(1.0,roundf(reduced)) if damage==floorf(damage) else reduced
	var effective := minf(target.hp, damage)
	target.hp -= effective
	target.last_damage=elapsed
	attacker.damage += effective
	target.supporters[attacker.id] = true
	if target.hp <= 0:
		stop_motion(target)
		attacker.kills += 1
		for id: String in target.supporters:
			if id != attacker.id:
				units[id].assists += 1
				_record("assist", id, target.id, 1)
		_record("disabled", attacker.id, target.id, effective)

func _record(kind: String, actor: String, target: String, amount: float) -> void:
	timeline.append({"time": elapsed, "event": kind, "actor": actor, "target": target, "amount": amount})

func _finish(reason: String, winner: int) -> void:
	stop_motion_all()
	_record(reason, "", "", winner)
	var records: Array[Dictionary] = []
	for u in units.values():
		records.append({"id":u.id,"entity_id":u.profile.entity_id,"side":u.side,"kills":u.kills,
			"assists":u.assists,"damage":u.damage,"received_repair":u.received_repair,"hp":u.hp})
	result = {"reason": reason, "winner": winner, "seconds": elapsed, "score": score.duplicate(),
		"units": records, "timeline": timeline.duplicate(true)}

