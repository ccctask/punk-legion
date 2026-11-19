extends "res://qa/support.gd"

const Sim := preload("res://battle/simulation.gd")
const Field := Sim.Field
const Mission := preload("res://net/solo_mission.gd")
const SoloSession := preload("res://net/solo.gd")
const Motion := preload("res://battle/path_motion.gd")

class CountedField extends "res://battle/field.gd":
	var queries := 0
	func _init(area: Rect2i, obstacles: Array[Rect2i]) -> void:
		super(area,obstacles)
	func walk_region(at: Vector2, exclusions: Array) -> Dictionary:
		queries+=1
		return super.walk_region(at,exclusions)

class ObservedSim extends "res://battle/simulation.gd":
	var accepted: Array = []
	var query_trace: Array = []
	# Same finite super-call observation as the existing AUTO_REPLAN probe.
	func _walk_region(unit: Fighter, target: Fighter = null) -> Dictionary:
		var count: int=field.get("queries")
		var due: float=unit.next_auto_replan_at
		var cached:=_walk_regions.has(unit.id)
		var answer: Dictionary=super._walk_region(unit,target)
		query_trace.append({"id":unit.id,"elapsed":elapsed,"deadline_before":due,"deadline_after":unit.next_auto_replan_at,
			"query_delta":int(field.get("queries"))-count,"cached":cached,"pending":answer.is_empty()})
		return answer
	func _turn(unit: Fighter, direction: Vector2, seconds: float) -> void:
		if _walk_segments.is_empty() or _walk_segments[-1].id!=unit.id:
			super._turn(unit,direction,seconds)
			return
		var bodies: Array = []
		for other in units.values():
			if other!=unit and other.hp>0:bodies.append({"pos":other.pos,"radius":_radius(other)})
		var row: Dictionary={"segment":_walk_segments[-1].duplicate(),"direction":direction,"unit":unit.id,
			"time":seconds,"speed":unit.travel_speed,"travel_direction":unit.travel_direction,"aim_before":unit.last_heading,
			"bodies":bodies,"earlier":_walk_segments.slice(0,_walk_segments.size()-1).duplicate(true)}
		accepted.append(row)
		super._turn(unit,direction,seconds)
		row.aim_after=unit.last_heading

func deployment(count: int = 1, heavy: bool = false) -> Dictionary:
	return {"units":Sim.Catalog.sample_squad(count,heavy),"inventory":Sim.Catalog.sample_inventory(count)}

func model(count: int = 1, enabled: bool = true, obstacles: Array[Rect2i] = [], inertia: bool = false) -> ObservedSim:
	var sim := ObservedSim.new()
	var source := deployment(count)
	assert_true(sim.create(source.units,source.inventory,[],{},true))
	sim.relay_objective=false
	sim.field=CountedField.new(Rect2i(-12,-12,25,25),obstacles)
	assert_true(sim.configure_safe_turning(enabled))
	assert_true(sim.configure_light_inertia(inertia))
	for unit in sim.units.values():unit.pos=Vector2(-8+(unit.slot%4)*2.5,-8+floori(unit.slot/4.0)*2.5)
	return sim

func decision_state(sim: Sim) -> Dictionary:
	var result := {}
	for id: String in sim.units:
		var u: Sim.Fighter=sim.units[id]
		result[id]={"pos":u.pos,"goal":u.movement_goal,"route":u.route_goal,"requested":u.route_requested_goal,
			"deadline":u.next_auto_replan_at,"path":u.path.duplicate(),"index":u.route_index,"heading":u.last_heading,"hp":u.hp,
			"travel_speed":u.travel_speed,"travel_direction":u.travel_direction,"walking":u.walking}
	return result

func assert_swept_segments(sim: ObservedSim, first: int) -> void:
	for i in range(first,sim.accepted.size()):
		var row: Dictionary=sim.accepted[i]
		var segment: Dictionary=row.segment
		assert_true(sim.field.map_segment_clear(segment.from,segment.to,float(segment.radius)))
		for body: Dictionary in row.bodies:
			var radius:=float(segment.radius)+float(body.radius)-2*Field.GEOMETRY_EPS
			assert_gte(Field.point_segment_distance_squared(body.pos,segment.from,segment.to),radius*radius,"Each accepted sweep clears the other live body's actual position at that decision")
		for earlier: Dictionary in row.earlier:
			if earlier.id==segment.id:continue
			var radius:=float(segment.radius)+float(earlier.radius)-2*Field.GEOMETRY_EPS
			assert_gte(Field.segment_distance_squared(segment.from,segment.to,earlier.from,earlier.to),radius*radius,"Each accepted sweep clears earlier accepted other-unit sweeps in the same tick")

func test_static_geometry_uses_full_radius_and_copied_map() -> void:
	var obstacles: Array[Rect2i]=[Rect2i(0,0,2,2)]
	var field := Field.new(Rect2i(-6,-6,13,13),obstacles)
	obstacles.append(Rect2i(-4,-4,2,2))
	assert_true(field.map_segment_clear(Vector2(-4,-4),Vector2(-4,-4),.6),"Caller mutation does not change a Field")
	assert_false(field.map_segment_clear(Vector2(-1,0),Vector2(-1,0),.6))
	assert_true(field.map_segment_clear(Vector2(-1,0),Vector2(-1,0),.48))
	assert_false(Field.segment_clear(Vector2(-1,0),Vector2(-1,0),field.static_capsule_exclusions(.6)))
	assert_false(field.map_segment_clear(Vector2(-6,-3),Vector2(-6,-3),.6),"Outer border consumes the whole radius")
	assert_false(field.map_segment_clear(Vector2(-3,0),Vector2(3,0),.6))
	assert_false(field.map_segment_clear(Vector2(NAN,0),Vector2.ZERO,.6))
	var chosen:=field.nearest_body_cell(Vector2(-1,0),.6)
	assert_true(field.bounds.has_point(chosen))
	assert_true(field.map_segment_clear(Vector2(chosen),Vector2(chosen),.6))
	assert_eq(chosen,field.nearest_body_cell(Vector2(-1,0),.6))

func test_open_ninety_and_continuous_turn_geometry_is_bounded() -> void:
	var field := Field.new(Rect2i(-12,-12,25,25),[])
	var raw := PackedVector2Array([Vector2(-6,-6),Vector2(4,-6),Vector2(4,4),Vector2(-4,4)])
	var original:=raw.duplicate()
	var path:=field.rounded_path(raw,.6,field.static_capsule_exclusions(.6))
	assert_gt(path.size(),raw.size())
	assert_lte(path.size(),1024)
	assert_eq(raw,original)
	assert_eq(path[0],raw[0])
	assert_eq(path[-1],raw[-1])
	var turning:=0
	for i in range(1,path.size()):
		assert_true(field.map_segment_clear(path[i-1],path[i],.6))
		if i>1:
			var angle:=absf((path[i-1]-path[i-2]).angle_to(path[i]-path[i-1]))
			assert_lte(angle,deg_to_rad(15)+.00001)
			if angle>.00001:turning+=1
	assert_gte(turning,3)
	path[0]=Vector2.ZERO
	assert_eq(raw,original,"Output mutation does not rewrite the input path")

func test_unsafe_corner_falls_back_but_unsafe_original_is_rejected() -> void:
	var obstacles: Array[Rect2i]=[Rect2i(0,0,2,2)]
	var field := Field.new(Rect2i(-8,-8,17,17),obstacles)
	var raw:=PackedVector2Array([Vector2(-.98,3),Vector2(-.98,-.98),Vector2(3,-.98)])
	assert_eq(field.rounded_path(raw,.475,field.static_capsule_exclusions(.475)),raw,"A curve cutting inside the real radius retains the safe original corner")
	assert_true(field.rounded_path(PackedVector2Array([Vector2(-1,0),Vector2(-1,-3)]),.6,[]).is_empty())
	var oversized:=PackedVector2Array()
	for i in 1025:oversized.append(Vector2(float(i)/1000, -4))
	assert_true(field.rounded_path(oversized,.6,[]).is_empty(),"Never truncate an over-limit route and lose its final goal")

func test_authoritative_steps_turn_gradually_and_keep_exact_goal() -> void:
	var sim:=model()
	var id: String=sim.alive_ids(0)[0]
	var unit: Sim.Fighter=sim.units[id]
	assert_true(sim.command_move([id],Vector2(6,6)))
	var started:=Time.get_ticks_usec()
	for _step in 230:
		sim.step(.05)
		if unit.movement_goal==Sim.UNSET:break
	assert_eq(unit.movement_goal,Sim.UNSET)
	assert_lt(unit.pos.distance_to(Vector2(6,6)),.005)
	var changes:=0
	for i in sim.accepted.size():
		var segment: Dictionary=sim.accepted[i].segment
		assert_true(sim.field.map_segment_clear(segment.from,segment.to,sim._radius(unit)))
		if i>0:
			var angle:=absf(sim.accepted[i-1].direction.angle_to(sim.accepted[i].direction))
			assert_lt(angle,deg_to_rad(60))
			if angle>.0001:changes+=1
	assert_gte(changes,3)
	print("AUTHORITY_MOTION steps=",sim.accepted.size()," elapsed_us=",Time.get_ticks_usec()-started," queries=",sim.field.get("queries"))

func test_later_member_planning_failure_is_atomic() -> void:
	var walls: Array[Rect2i]=[Rect2i(3,4,1,1),Rect2i(5,4,1,1),Rect2i(4,3,1,1),Rect2i(4,5,1,1)]
	var sim:=model(2,true,walls)
	var ids:=sim.alive_ids(0)
	sim.units[ids[0]].pos=Vector2(-4,-4)
	# Deliberately impossible setup: exercises rejection, not a legal Mission birth.
	sim.units[ids[1]].pos=Vector2(4,4)
	var first: Array[Sim.Fighter]=[sim.units[ids[0]]]
	assert_eq(sim._plan_group_move(first,{ids[0]:true},Vector2(-4,4)).size(),1)
	var before:=decision_state(sim)
	assert_false(sim.command_move(ids,Vector2(-4,4)))
	assert_eq(sim.last_error,"movement_no_space")
	assert_eq(decision_state(sim),before)

func test_dynamic_body_reroute_and_twelve_unit_congestion_remain_safe() -> void:
	var sim:=model(2)
	var ids:=sim.alive_ids(0)
	var moving: Sim.Fighter=sim.units[ids[0]]
	var blocker: Sim.Fighter=sim.units[ids[1]]
	moving.pos=Vector2(-4,0)
	blocker.pos=Vector2.ZERO
	assert_true(sim.command_move([ids[0]],Vector2(4,0)))
	for _step in 140:
		var previous:=sim.accepted.size()
		sim.step(.05)
		assert_swept_segments(sim,previous)
		assert_gte(moving.pos.distance_to(blocker.pos),sim._radius(moving)+sim._radius(blocker)-Field.GEOMETRY_EPS)
		if moving.movement_goal==Sim.UNSET:break
	assert_eq(moving.movement_goal,Sim.UNSET)
	var crowded:=model(12)
	var accepted:=crowded.command_move(crowded.alive_ids(0),Vector2(5,5))
	assert_true(accepted)
	for _step in 40:
		var previous:=crowded.accepted.size()
		crowded.step(.05)
		assert_swept_segments(crowded,previous)
		var live:=crowded.alive_ids(0)
		for i in live.size():
			for j in range(i+1,live.size()):
				var a: Sim.Fighter=crowded.units[live[i]]
				var b: Sim.Fighter=crowded.units[live[j]]
				assert_gte(a.pos.distance_to(b.pos),crowded._radius(a)+crowded._radius(b)-.00001)
	print("AUTHORITY_CONGESTION queries=",crowded.field.get("queries")," accepted_segments=",crowded.accepted.size())

func test_auto_replan_wait_is_sim_time_bounded_and_drill_uses_actual_range() -> void:
	var sim:=model()
	var unit: Sim.Fighter=sim.units[sim.alive_ids(0)[0]]
	unit.movement_goal=Vector2i(6,6)
	unit.next_auto_replan_at=.5
	for _step in 4:sim.step(.1)
	assert_eq(sim.field.get("queries"),0)
	assert_eq(unit.movement_goal,Vector2i(6,6))
	sim.step(.1)
	assert_eq(sim.field.get("queries"),1)
	assert_gt(unit.next_auto_replan_at,sim.elapsed)
	var phased:=model(12)
	var deadlines := {}
	for actor in phased._ordered_units():
		assert_false(phased._walk_region(actor).is_empty())
		deadlines[actor.next_auto_replan_at]=true
		actor.movement_goal=Vector2i(4+(actor.slot%4)*2,3+floori(actor.slot/4.0)*2)
	assert_eq(deadlines.size(),10,"Twelve actual bodies retain the ten distinct .5sim phases")
	var baseline_queries: int=phased.field.get("queries")
	phased.query_trace.clear()
	var samples: Array = []
	for tick in 12:
		var first_trace:=phased.query_trace.size()
		var began:=Time.get_ticks_usec()
		phased.step(.05)
		var duration:=Time.get_ticks_usec()-began
		var by_unit := {}
		for i in range(first_trace,phased.query_trace.size()):
			var row: Dictionary=phased.query_trace[i]
			by_unit[row.id]=int(by_unit.get(row.id,0))+int(row.query_delta)
			assert_lte(int(by_unit[row.id]),1,"At most one actual query per body in a tick")
			if not row.cached and float(row.elapsed)+.000001<float(row.deadline_before):
				assert_eq(row.query_delta,0)
				assert_eq(row.deadline_after,row.deadline_before,"Waiting does not renew its own deadline")
				assert_true(row.pending)
			if int(row.query_delta)>0:assert_gt(float(row.deadline_after),float(row.elapsed))
		samples.append({"tick":tick,"elapsed":phased.elapsed,"step_us":duration,"queries":by_unit})
	assert_gt(int(phased.field.get("queries")),baseline_queries,"Due phases give real future opportunities")
	print("AUTHORITY_PHASES ",JSON.stringify({"initial_queries":baseline_queries,"total_queries":phased.field.get("queries"),"samples":samples,"trace":phased.query_trace}))
	var source:=deployment(1,true)
	var combat:=Sim.new()
	assert_true(combat.create(source.units,source.inventory,Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1)))
	combat.relay_objective=false
	combat.field=Field.new(Rect2i(-12,-12,25,25),[])
	assert_true(combat.configure_safe_turning(true))
	var attacker: Sim.Fighter=combat.units[combat.alive_ids(0)[0]]
	var target: Sim.Fighter=combat.units[combat.alive_ids(1)[0]]
	attacker.pos=Vector2(-5,0)
	target.pos=Vector2(2,0)
	target.stats.move_speed=0.0
	target.stats.damage=0.0
	combat.command_focus([attacker.id],target.id)
	var hit:=false
	for _step in 140:
		combat.step(.05)
		if attacker.last_shot>=0:
			hit=true
			assert_lte(attacker.pos.distance_to(target.pos),float(attacker.stats.range_m)+float(target.stats.body_radius)-.6+.00001)
			break
	assert_true(hit,"A drill actually reaches valid range; a safe route endpoint is not a hit")

func test_same_version_midturn_checkpoint_is_deterministic_and_strict() -> void:
	var mission:=Mission.new()
	assert_true(mission.configure_safe_turning(true))
	assert_true(mission.create("fresh-turn",deployment(),123456789))
	assert_false(mission.configure_safe_turning(false))
	var id: String=mission.sim.alive_ids(0)[0]
	assert_true(mission.sim.command_move([id],Vector2(-8,-22)))
	var on_turn:=false
	for _step in 230:
		mission.step(.05)
		var heading: Vector2=mission.sim.units[id].last_heading
		if absf(heading.x)>.05 and absf(heading.y)>.05:
			on_turn=true
			break
	assert_true(on_turn)
	var saved: Dictionary=mission.checkpoint().duplicate(true)
	assert_eq(saved.path_policy,Mission.PATH_POLICY)
	var copy:=Mission.new()
	copy.configure_safe_turning(true)
	assert_true(copy.restore(saved))
	for _step in 20:
		mission.step(.05)
		copy.step(.05)
		assert_eq(decision_state(mission.sim),decision_state(copy.sim))
	for fault: String in ["missing","unknown","geometry","index","goal"]:
		var invalid: Dictionary=saved.duplicate(true)
		match fault:
			"missing":invalid.erase("path_policy")
			"unknown":invalid.path_policy="other"
			"geometry":invalid.units[id].pos=Vector2(-13,-18)
			"index":invalid.units[id].route_index=999999
			"goal":invalid.units[id].route_goal=Vector2i(0,0)
		var rejected:=Mission.new()
		rejected.configure_safe_turning(true)
		assert_false(rejected.restore(invalid),fault)
	var unconfigured:=Mission.new()
	assert_false(unconfigured.restore(saved),"Enabled marker cannot enter an off consumer")
	# Actual Mission route/collect lifecycle, using only this newly created scene.
	assert_true(mission.order(1,"collect",[id],"scrap",Vector2.ZERO))
	assert_eq(mission.last_notice,"请先抵达节点四米内")
	assert_false("scrap" in mission.collected)
	assert_true(mission.order(2,"route",[id],"scrap",Vector2.ZERO))
	var arrived:=false
	for _step in 1400:
		mission.step(.05)
		if mission.sim.units[id].pos.distance_to(Mission.LOCATIONS.scrap)<=4.0:
			arrived=true
			break
	assert_true(arrived,"Normal authority route and steps reach the unchanged collection radius")
	assert_true(mission.order(3,"collect",[id],"scrap",Vector2.ZERO))
	var guard: Sim.Fighter=mission.sim.units[mission.enemy_ids[0]]
	if guard.hp>0:
		assert_eq(mission.last_notice,"节点还在守卫火力下，先集火守卫")
		# Explicit current-memory defeated-guard fixture; no natural kill credit.
		guard.hp=0
		print("AUTHORITY_COLLECT fixture=current-version already-defeated scrap guard; natural battle not asserted")
		assert_true(mission.order(4,"collect",[id],"scrap",Vector2.ZERO))
	assert_true("scrap" in mission.collected)
	assert_eq(mission.stage,1)

func test_four_chassis_and_new_npc_births_have_full_static_clearance() -> void:
	assert_eq(Sim.Catalog.HULLS.size(),4,"Reject an empty or incomplete chassis matrix")
	var legacy:=Mission.new()
	assert_true(legacy.create("reference-new",deployment(),123456789))
	for chassis: String in Sim.Catalog.HULLS:
		var source:=deployment()
		source.units[0].chassis="1/"+("hull" if chassis=="crawler" else chassis)
		var mission:=Mission.new()
		mission.configure_safe_turning(true)
		assert_true(mission.create("fresh-"+chassis,source,123456789),chassis)
		for unit in mission.sim.units.values():
			assert_true(mission.sim.field.map_segment_clear(unit.pos,unit.pos,mission.sim._radius(unit)),unit.id)
			if unit.side==1:
				var original: Sim.Fighter=legacy.sim.units[unit.id]
				if mission.sim.field.map_segment_clear(original.pos,original.pos,mission.sim._radius(unit)):
					assert_eq(unit.pos,original.pos,"Already legal birth remains authored")
		var ally: Sim.Fighter=mission.sim.units[mission.sim.alive_ids(0)[0]]
		assert_eq(ally.pos,Vector2(-30,-18),"Do not rewrite the friendly formation")

func test_factories_and_nonstandard_consumers_remain_explicit() -> void:
	var session:=SoloSession.new()
	add_child_autofree(session)
	for location: String in ["","rustrail","old_armory","unknown"]:
		var mission=session._new_solo_mission(location)
		assert_true(mission.create("factory-"+location,deployment(),123456789))
		assert_eq(mission.sim.safe_turning,location in ["","rustrail"])
		assert_false(mission.configure_safe_turning(true),"Created standard/derived Mission cannot change policy")
	for path: String in ["res://net/party_mission.gd","res://net/pump_mission.gd","res://net/factory_mission.gd"]:
		var mission=load(path).new()
		assert_true(mission.create_party("fresh-party",{"one":deployment()},123456789,0.0))
		assert_false(mission.sim.safe_turning,path)
		assert_false(mission.checkpoint().has("path_policy"))
		assert_false(mission.configure_safe_turning(true),"Created derived activity cannot inherit a policy mutation")
	var camp=load("res://net/camp_mission.gd").new()
	assert_false(camp.sim.safe_turning)
	var exercise=load("res://net/exercise.gd").new()
	exercise.ready={1:true,2:true}
	assert_true(exercise.start())
	assert_false(exercise.sim.safe_turning)
	var standard=session._new_solo_mission()
	assert_true(standard.create("factory-current",deployment(),123456789))
	session.directory=ProjectSettings.globalize_path("user://authority-motion-checkpoints")
	assert_eq(DirAccess.make_dir_recursive_absolute(session.directory),OK)
	assert_true(session._save(standard))
	var restored=session._load(standard.mission)
	assert_not_null(restored)
	if restored!=null:assert_true(restored.sim.safe_turning)
	# Current-version off instance supplies a missing-marker negative; no old data is imported.
	var wrong_instance:=Mission.new()
	wrong_instance.create("factory-missing-marker",deployment(),123456789)
	assert_true(session._save(wrong_instance))
	assert_null(session._load(wrong_instance.mission),"No new policy is applied to a current-version checkpoint missing its marker")

func inertial_mission(id: String) -> Mission:
	var mission:=Mission.new()
	assert_true(mission.configure_safe_turning(true))
	assert_true(mission.configure_light_inertia(true))
	assert_true(mission.create(id,deployment(),2000000000))
	return mission

func assert_stopped(unit: Sim.Fighter) -> void:
	assert_eq(unit.travel_speed,0.0)
	assert_eq(unit.travel_direction,Vector2.ZERO)
	assert_false(unit.walking)

func assert_macro_motion(sim: ObservedSim, first: int, delta: float) -> void:
	var totals := {}
	for i in range(first,sim.accepted.size()):
		var row: Dictionary=sim.accepted[i]
		if not totals.has(row.unit):totals[row.unit]={"time":0.0,"distance":0.0}
		totals[row.unit].time+=float(row.time)
		totals[row.unit].distance+=row.segment.from.distance_to(row.segment.to)
		assert_gte(float(row.time),0.0)
		assert_lte(float(row.speed),float(sim.units[row.unit].stats.move_speed))
	for id: String in totals:
		assert_lte(float(totals[id].time),delta+.000001)
		assert_lte(float(totals[id].distance),float(sim.units[id].stats.move_speed)*delta+.00002)
		var unit: Sim.Fighter=sim.units[id]
		if unit.travel_speed>0:
			var last: Dictionary=sim.accepted.filter(func(row):return row.unit==id)[-1]
			assert_almost_eq(unit.travel_speed,float(last.speed),.000001)
			assert_gt(unit.travel_direction.dot(last.direction),.99999,"Use final travel tangent, not macro displacement or aiming")
	assert_swept_segments(sim,first)

func test_inertia_math_exact_phases_prefix_times_and_hard_reverse() -> void:
	for maximum: float in [1.8,3.6,5.4]:
		var acceleration_rate:=maximum/.25
		var braking_rate:=maximum/.20
		var distance:=10.0
		var result:=Motion.advance_segment(0,maximum,0,distance,20,acceleration_rate,braking_rate)
		assert_true(result.valid,"Current NPC/crawler/wheel speed family")
		if not result.valid:continue
		assert_true(result.reached)
		assert_eq(result.distance,distance)
		assert_eq(result.speed,0.0)
		assert_eq(result.phases.size(),3)
		assert_almost_eq(result.time,.25+.20+(distance-maximum*(.25+.20)/2)/maximum,.0000001)
		for phase: Dictionary in result.phases:
			assert_true(is_finite(float(phase.time)))
			assert_gte(float(phase.speed),0.0)
			assert_lte(float(phase.speed),maximum+.000001)
			assert_lte(float(phase.speed)+float(phase.rate)*float(phase.time),maximum+.000001)
	var whole:=Motion.advance_segment(0,3.6,0,10,20,14.4,18)
	assert_true(whole.valid)
	if not whole.valid:return
	assert_true(whole.reached)
	assert_eq(whole.distance,10.0)
	assert_eq(whole.speed,0.0)
	assert_eq(whole.phases.size(),3)
	assert_almost_eq(whole.time,.25+.20+(10-.45-.36)/3.6,.0000001)
	var first:=Motion.advance_segment(0,3.6,0,10,.1,14.4,18)
	var next:=Motion.advance_segment(first.speed,3.6,0,10-first.distance,.3,14.4,18)
	var combined:=Motion.advance_segment(0,3.6,0,10,.4,14.4,18)
	assert_true(first.valid and next.valid and combined.valid)
	assert_almost_eq(first.distance+next.distance,combined.distance,.0000001)
	assert_almost_eq(next.speed,combined.speed,.0000001)
	var short:=Motion.advance_segment(0,3.6,0,.01,1,14.4,18)
	assert_true(short.valid and short.reached)
	assert_almost_eq(short.time,.05,.000001)
	assert_eq(short.speed,0.0)
	var acceleration:=Motion.advance_segment(0,3.6,3.6,10,.1,14.4,18)
	assert_almost_eq(Motion.time_for_distance(acceleration.phases,.018),.05,.000001)
	assert_gt(absf(Motion.time_for_distance(acceleration.phases,.018)-float(acceleration.time)*.25),.01)
	var braking:=Motion.advance_segment(3.6,3.6,0,.36,.1,14.4,18)
	assert_true(braking.valid)
	assert_almost_eq(Motion.time_for_distance(braking.phases,.1575),.05,.000001)
	assert_gt(absf(Motion.time_for_distance(braking.phases,.1575)-float(braking.time)*.1575/float(braking.distance)),.005)
	var reverse:=Motion.profile(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ZERO]),Vector2.ZERO,3.6,18)
	assert_true(reverse.valid)
	assert_eq(reverse.nodes[1],0.0)
	assert_gt(reverse.limits[0],0.0)
	assert_gt(reverse.limits[1],0.0)
	var turn:=Motion.advance_segment(0,reverse.limits[0],0,1,2,14.4,18)
	assert_true(turn.valid and turn.reached)
	assert_true(Motion.advance_segment(0,reverse.limits[1],0,1,2-turn.time,14.4,18).reached)
	var after_reverse:=Motion.profile(PackedVector2Array([Vector2(.9,0),Vector2.ZERO]),Vector2.LEFT,3.6,18,TAU,PackedVector2Array([Vector2.ZERO,Vector2(1,0)]))
	assert_true(after_reverse.valid)
	assert_gt(float(after_reverse.start_limit),0.0,"A passed zero-speed vertex cannot freeze its outgoing edge")
	assert_false(Motion.advance_segment(NAN,3.6,0,1,1,14.4,18).valid)
	assert_false(Motion.advance_segment(4,3.6,0,1,1,14.4,18).valid)
	assert_lt(Motion.time_for_distance(acceleration.phases,99),0.0)
	var prefix:=PackedVector2Array([Vector2(-1,0),Vector2.ZERO])
	var near:=Motion.profile(PackedVector2Array([Vector2(.9,0),Vector2(1,0)]),Vector2.RIGHT,3.6,18,TAU,prefix)
	var nearer:=Motion.profile(PackedVector2Array([Vector2(.95,0),Vector2(1,0)]),Vector2.RIGHT,3.6,18,TAU,prefix)
	assert_true(near.valid and nearer.valid)
	assert_eq(near.limits,nearer.limits,"Remaining half-edge length cannot change original edge cap")
	assert_gt(float(near.start_limit),float(nearer.start_limit),"Braking still uses actual remaining distance")
	var next_point:=Vector2(.08,.01)
	var quarter:=Motion.profile(PackedVector2Array([next_point*.25,next_point,Vector2(.15,.04),Vector2(.2,.1)]),next_point.normalized(),3.6,18,TAU,prefix)
	var three_quarters:=Motion.profile(PackedVector2Array([next_point*.75,next_point,Vector2(.15,.04),Vector2(.2,.1)]),next_point.normalized(),3.6,18,TAU,prefix)
	assert_true(quarter.valid and three_quarters.valid)
	assert_eq(quarter.limits,three_quarters.limits)
	assert_eq(quarter.nodes.slice(1),three_quarters.nodes.slice(1),"Future corner envelopes remain phase independent")

func test_inertia_macro_acceleration_braking_curve_and_large_delta() -> void:
	var sim:=model(1,true,[],true)
	var unit: Sim.Fighter=sim.units[sim.alive_ids(0)[0]]
	assert_true(sim.command_move([unit.id],Vector2(6,-8)))
	var slowed:=false
	for tick in 110:
		var first:=sim.accepted.size()
		sim.step(.05)
		assert_macro_motion(sim,first,.05)
		if tick<5:assert_almost_eq(unit.travel_speed,3.6*float(tick+1)/5,.000001)
		if unit.pos.x>5.6 and unit.travel_speed>0 and unit.travel_speed<3.6:slowed=true
		assert_lte(unit.pos.x,6.0)
		if unit.movement_goal==Sim.UNSET:break
	assert_true(slowed)
	assert_eq(unit.pos,Vector2(6,-8))
	assert_stopped(unit)
	var big:=model(1,true,[],true)
	var split:=model(1,true,[],true)
	var big_unit: Sim.Fighter=big.units[big.alive_ids(0)[0]]
	var split_unit: Sim.Fighter=split.units[split.alive_ids(0)[0]]
	big.command_move([big_unit.id],Vector2(6,-8))
	split.command_move([split_unit.id],Vector2(6,-8))
	big.step(.4)
	for _i in 8:split.step(.05)
	assert_lt(big_unit.pos.distance_to(split_unit.pos),.00001)
	assert_almost_eq(big_unit.travel_speed,split_unit.travel_speed,.000001)
	assert_macro_motion(big,0,.4)
	var first:=big.accepted.size()
	big.step(10)
	assert_macro_motion(big,first,10)
	assert_eq(big_unit.pos,Vector2(6,-8))
	assert_stopped(big_unit)
	var curved:=model(1,true,[],true)
	var actor: Sim.Fighter=curved.units[curved.alive_ids(0)[0]]
	curved.command_move([actor.id],Vector2(6,6))
	var curve_samples:=0
	for _i in 240:
		var previous:=curved.accepted.size()
		curved.step(.05)
		assert_macro_motion(curved,previous,.05)
		for i in range(previous,curved.accepted.size()):
			var row: Dictionary=curved.accepted[i]
			if absf(row.direction.x)>.05 and absf(row.direction.y)>.05 and float(row.speed)<3.55:curve_samples+=1
		if actor.movement_goal==Sim.UNSET:break
	assert_gte(curve_samples,3)
	assert_eq(actor.pos,Vector2(6,6))
	assert_stopped(actor)
	var close_corner:=model(1,true,[],true)
	var corner_unit: Sim.Fighter=close_corner.units[close_corner.alive_ids(0)[0]]
	assert_true(close_corner.command_move([corner_unit.id],Vector2(6,6)))
	assert_gt(corner_unit.path.size(),3,"Fixture uses the real B rounded path")
	var corner_index:=2
	var waypoint: Vector2=corner_unit.path[corner_index]
	var tangent: Vector2=corner_unit.path[corner_index-1].direction_to(waypoint)
	corner_unit.pos=waypoint-tangent*.002
	corner_unit.route_index=corner_index
	corner_unit.travel_speed=.1
	corner_unit.travel_direction=tangent
	corner_unit.walking=true
	assert_true(close_corner.field.map_segment_clear(corner_unit.pos,waypoint,close_corner._radius(corner_unit)))
	close_corner.step(.05)
	assert_macro_motion(close_corner,0,.05)
	assert_gt(corner_unit.route_index,corner_index,"Consume the nonzero .002m prefix before changing geometric owner")
	assert_gt(corner_unit.travel_speed,0.0,"Continue beyond the corner rather than rejecting a mismatched prefix")
	# One actual fast Catalog hull, not four redundant whole-scene matrices.
	var fast_source:=deployment()
	fast_source.units[0].chassis="1/wheel"
	var fast:=ObservedSim.new()
	assert_true(fast.create(fast_source.units,fast_source.inventory,[],{},true))
	fast.relay_objective=false
	fast.field=CountedField.new(Rect2i(-12,-12,25,25),[])
	fast.configure_safe_turning(true)
	fast.configure_light_inertia(true)
	var wheel: Sim.Fighter=fast.units[fast.alive_ids(0)[0]]
	wheel.pos=Vector2(-8,-8)
	assert_almost_eq(float(wheel.stats.move_speed),5.4,.000001)
	assert_almost_eq(fast._radius(wheel),.48,.000001)
	assert_true(fast.command_move([wheel.id],Vector2(6,-8)))
	var accelerated:=false
	var braked:=false
	for tick in 90:
		var previous:=fast.accepted.size()
		fast.step(.05)
		assert_macro_motion(fast,previous,.05)
		if tick<5:assert_almost_eq(wheel.travel_speed,5.4*float(tick+1)/5,.000001)
		if wheel.travel_speed>5.39:accelerated=true
		if wheel.pos.x>5.4 and wheel.travel_speed>0 and wheel.travel_speed<5.4:braked=true
		if wheel.movement_goal==Sim.UNSET:break
	assert_true(accelerated and braked)
	assert_eq(wheel.pos,Vector2(6,-8))
	assert_stopped(wheel)

func test_inertia_command_projection_atomic_failure_and_blocked_prefix() -> void:
	for goal: Vector2 in [Vector2(6,-4),Vector2(-4,6),Vector2(-8,-4)]:
		var sim:=model(1,true,[],true)
		var unit: Sim.Fighter=sim.units[sim.alive_ids(0)[0]]
		unit.pos=Vector2(-4,-4)
		unit.travel_speed=2
		unit.travel_direction=Vector2.RIGHT
		unit.walking=true
		assert_true(sim.command_move([unit.id],goal))
		assert_almost_eq(unit.travel_speed,2.0 if goal==Vector2(6,-4) else 0.0,.000001)
		if unit.travel_speed==0:assert_stopped(unit)
	var walls: Array[Rect2i]=[Rect2i(3,4,1,1),Rect2i(5,4,1,1),Rect2i(4,3,1,1),Rect2i(4,5,1,1)]
	var failed:=model(2,true,walls,true)
	var ids:=failed.alive_ids(0)
	failed.units[ids[0]].pos=Vector2(-4,-4)
	failed.units[ids[0]].travel_speed=2
	failed.units[ids[0]].travel_direction=Vector2.RIGHT
	failed.units[ids[0]].walking=true
	failed.units[ids[1]].pos=Vector2(4,4)
	var before:=decision_state(failed)
	assert_false(failed.command_move(ids,Vector2(-4,4)))
	assert_eq(decision_state(failed),before)
	var blocked:=model(2,true,[],true)
	ids=blocked.alive_ids(0)
	var mover: Sim.Fighter=blocked.units[ids[0]]
	var body: Sim.Fighter=blocked.units[ids[1]]
	body.pos=Vector2(0,8)
	blocked.command_move([mover.id],Vector2(6,-8))
	blocked.step(.2)
	assert_gt(mover.travel_speed,0.0)
	# Current-memory arrival of a blocker, with nonoverlapping initial bodies.
	body.pos=mover.pos+Vector2(blocked._radius(mover)+blocked._radius(body)+.02,0)
	var first:=blocked.accepted.size()
	blocked.step(.05)
	assert_macro_motion(blocked,first,.05)
	assert_stopped(mover)
	assert_gt(blocked.accepted.size(),first,"The accepted safe prefix uses its actual acceleration time")

func test_inertia_shield_time_idle_death_and_sim_finish_clear_immediately() -> void:
	var sim:=model(1,true,[],true)
	var unit: Sim.Fighter=sim.units[sim.alive_ids(0)[0]]
	unit.profile.parts.armor="rivet_shield"
	unit.last_heading=Vector2.UP
	sim.command_move([unit.id],Vector2(6,-8))
	sim.step(.05)
	assert_eq(sim.accepted.size(),1)
	var row: Dictionary=sim.accepted[0]
	var rate:=deg_to_rad(float(Sim.Catalog.PARTS.rivet_shield.turn_degrees_per_second))
	assert_almost_eq(absf(row.aim_before.angle_to(row.aim_after)),rate*float(row.time),.000001)
	assert_almost_eq(row.time,.05,.000001,"Shield uses actual accelerated time, not travelled/V")
	var speed:=unit.travel_speed
	var direction:=unit.travel_direction
	sim._turn(unit,Vector2.LEFT,.01)
	assert_eq(unit.travel_speed,speed)
	assert_eq(unit.travel_direction,direction,"Aiming does not rewrite the movement vector")
	sim.command_focus([unit.id],"missing")
	assert_eq(unit.travel_speed,speed,"Invalid focus cannot clear valid motion")
	unit.movement_goal=Sim.UNSET
	sim.step(.05)
	assert_stopped(unit)
	var combat:=model(2,true,[],true)
	var ids:=combat.alive_ids(0)
	var victim: Sim.Fighter=combat.units[ids[0]]
	var attacker: Sim.Fighter=combat.units[ids[1]]
	combat.command_move([victim.id],Vector2(6,-8))
	combat.step(.1)
	victim.hp=1
	combat._hit(attacker,victim)
	assert_lte(victim.hp,0.0)
	assert_stopped(victim)
	attacker.travel_speed=1
	attacker.travel_direction=Vector2.RIGHT
	attacker.walking=true
	combat.retreat()
	assert_stopped(attacker)
	var focus:=Sim.new()
	var source:=deployment()
	focus.create(source.units,source.inventory,Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1))
	focus.configure_safe_turning(true)
	focus.configure_light_inertia(true)
	var mover: Sim.Fighter=focus.units[focus.alive_ids(0)[0]]
	mover.travel_speed=1
	mover.travel_direction=Vector2.RIGHT
	mover.walking=true
	focus.command_focus([mover.id],focus.alive_ids(1)[0])
	assert_stopped(mover)
	var drill:=Sim.new()
	source=deployment(1,true)
	assert_true(drill.create(source.units,source.inventory,Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1)))
	drill.relay_objective=false
	drill.field=Field.new(Rect2i(-12,-12,25,25),[])
	drill.configure_safe_turning(true)
	drill.configure_light_inertia(true)
	var tool: Sim.Fighter=drill.units[drill.alive_ids(0)[0]]
	var target: Sim.Fighter=drill.units[drill.alive_ids(1)[0]]
	tool.pos=Vector2(-5,0)
	target.pos=Vector2(2,0)
	target.stats.move_speed=0
	target.stats.damage=0
	drill.command_focus([tool.id],target.id)
	var struck:=false
	for _i in 160:
		drill.step(.05)
		if tool.last_shot>=0:
			struck=true
			assert_lte(tool.pos.distance_to(target.pos),float(tool.stats.range_m)+float(target.stats.body_radius)-.6+.00001)
			assert_stopped(tool)
			break
	assert_true(struck,"C stops in the actual drill range, not at an assumed route endpoint")

func test_inertia_mission_order_expiry_and_disk_terminal_clear_same_call() -> void:
	var session:=SoloSession.new()
	add_child_autofree(session)
	for cause: String in ["order-retreat","step-defeat","expire","direct-win"]:
		var mission:=inertial_mission("terminal-"+cause)
		var unit: Sim.Fighter=mission.sim.units[mission.sim.alive_ids(0)[0]]
		mission.sim.command_move([unit.id],Vector2(-24,-18))
		mission.step(.05)
		assert_gt(unit.travel_speed,0.0)
		match cause:
			"order-retreat":assert_true(mission.order(1,"retreat",[],"",Vector2.ZERO))
			"step-defeat":
				unit.hp=0
				mission.step(.05)
			"expire":
				mission.expires=0
				assert_true(session._solo_expire(mission))
			"direct-win":mission.outcome="win"
		assert_false(mission.outcome.is_empty())
		for actor in mission.sim.units.values():assert_stopped(actor)
	var active:=inertial_mission("current-terminal-file")
	var actor: Sim.Fighter=active.sim.units[active.sim.alive_ids(0)[0]]
	active.sim.command_move([actor.id],Vector2(-24,-18))
	active.step(.05)
	assert_gt(actor.travel_speed,0.0)
	session.directory=ProjectSettings.globalize_path("user://inertia-terminal-checkpoints")
	assert_eq(DirAccess.make_dir_recursive_absolute(session.directory),OK)
	assert_true(session._save(active))
	var terminal:=FileAccess.open(session.directory.path_join(active.mission+".result.json"),FileAccess.WRITE)
	assert_not_null(terminal)
	if terminal==null:return
	terminal.store_string(JSON.stringify({"result":{"outcome":"expired"},"finished_at":1234}))
	terminal.close()
	var restored=session._load(active.mission)
	assert_not_null(restored)
	if restored!=null:
		assert_eq(restored.outcome,"expired")
		for unit in restored.sim.units.values():assert_stopped(unit)

func test_inertia_three_midphase_restores_and_invalid_decision_state() -> void:
	var acceleration_saved := {}
	var first_id := ""
	for phase: String in ["acceleration","curve","braking"]:
		var mission:=inertial_mission("current-"+phase)
		var id: String=mission.sim.alive_ids(0)[0]
		var goal:=Vector2(-8,-22) if phase=="curve" else Vector2(-24,-18)
		assert_true(mission.sim.command_move([id],goal))
		var found:=false
		for tick in 260:
			mission.step(.05)
			var unit: Sim.Fighter=mission.sim.units[id]
			if phase=="acceleration":found=tick==0 and unit.travel_speed>0
			elif phase=="curve":found=absf(unit.travel_direction.x)>.05 and absf(unit.travel_direction.y)>.05 and unit.travel_speed>0 and unit.travel_speed<float(unit.stats.move_speed)-.05
			else:found=unit.pos.distance_to(goal)<.4 and unit.travel_speed>0 and unit.travel_speed<float(unit.stats.move_speed)
			if found:break
		assert_true(found,phase)
		var before:=decision_state(mission.sim)
		var saved: Dictionary=mission.checkpoint().duplicate(true)
		assert_eq(decision_state(mission.sim),before,"Checkpoint reads never stop or modify motion")
		assert_eq(saved.path_policy,Mission.INERTIA_POLICY)
		var copy:=Mission.new()
		copy.configure_safe_turning(true)
		copy.configure_light_inertia(true)
		assert_true(copy.restore(saved),phase)
		for _i in 20:
			mission.step(.05)
			copy.step(.05)
			assert_eq(decision_state(mission.sim),decision_state(copy.sim),phase)
		if phase=="acceleration":
			acceleration_saved=saved
			first_id=id
	assert_false(acceleration_saved.is_empty())
	if acceleration_saved.is_empty():return
	for fault: String in ["missing","nan","negative","overspeed","zero-direction","long-direction","stopped-direction","backward","dead","terminal","b-policy","moving-idle","missing-walking","walking-type"]:
		var saved: Dictionary=acceleration_saved.duplicate(true)
		var row: Dictionary=saved.units[first_id]
		match fault:
			"missing":row.erase("travel_speed")
			"nan":row.travel_speed=NAN
			"negative":row.travel_speed=-1
			"overspeed":row.travel_speed=100
			"zero-direction":row.travel_direction=Vector2.ZERO
			"long-direction":row.travel_direction*=2
			"stopped-direction":row.travel_speed=0
			"backward":row.travel_direction=-row.travel_direction
			"dead":row.hp=0
			"terminal":saved.outcome="win"
			"b-policy":saved.path_policy=Mission.PATH_POLICY
			"moving-idle":row.walking=false
			"missing-walking":row.erase("walking")
			"walking-type":row.walking=1
		var rejected:=Mission.new()
		rejected.configure_safe_turning(true)
		rejected.configure_light_inertia(true)
		assert_false(rejected.restore(saved),fault)
	var off:=Mission.new()
	var source:=deployment()
	off.create("off-current",source,2000000000)
	var off_saved: Dictionary=off.checkpoint().duplicate(true)
	var off_id: String=off.sim.alive_ids(0)[0]
	off_saved.units[off_id].travel_speed=0
	off_saved.units[off_id].travel_direction=Vector2.ZERO
	assert_false(Mission.new().restore(off_saved),"Off mode cannot accept C-only fields, even zero-valued")
