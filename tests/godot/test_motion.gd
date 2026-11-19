extends "res://qa/support.gd"

const Track := preload("res://battle/motion_track.gd")
const Field := preload("res://battle/field.gd")
const Sim := preload("res://battle/simulation.gd")
const UnitScene := preload("res://battle/unit.tscn")
const Session := preload("res://net/solo.gd")

func allowed(_a: Vector2, _b: Vector2) -> bool:
	return true

func denied(_a: Vector2, _b: Vector2) -> bool:
	return false

func track(capacity: int = 8) -> Track:
	var item := Track.new()
	add_child_autofree(item)
	assert_true(item.configure(.18,.6,capacity,allowed))
	item.reset(&"one",0,Vector2.ZERO,Vector2.RIGHT,true,0)
	return item

func test_configuration_rejects_invalid_and_defaults_off() -> void:
	var item := Track.new()
	add_child_autofree(item)
	assert_false(item.enabled)
	assert_true(item.sample(0).is_empty())
	assert_false(item.configure(NAN,.6,8,allowed))
	assert_false(item.configure(.18,.18,8,allowed))
	assert_false(item.configure(.18,.6,1,allowed))
	assert_false(item.configure(.18,.6,8,Callable()))
	assert_false(item.enabled)

func synthetic(fps: int) -> Dictionary:
	# Synthetic scheduling exercises values, not an actual renderer FPS claim.
	var item := track()
	var next_packet := 1
	var previous := Vector2.ZERO
	var greatest_error := 0.0
	var at := Vector2.ZERO
	for frame in range(1,fps*2+1):
		var now := float(frame)/fps
		while float(next_packet)*.15<=now+.000001:
			var server_time := float(next_packet)*.15
			item.push(&"one",server_time,Vector2(server_time*3,0),Vector2.RIGHT,true,int(server_time*1000000))
			next_packet+=1
		var pose: Dictionary=item.sample(int(now*1000000))
		at=pose.pos
		assert_gte(at.x,previous.x,"Cursor never reverses")
		if now>.5:greatest_error=maxf(greatest_error,absf(at.x-3*(now-1.0/fps-.18)))
		previous=at
	return {"pos":at,"error":greatest_error}

func test_synthetic_30_60_cadence_is_uniform() -> void:
	var slow := synthetic(30)
	var fast := synthetic(60)
	assert_lt(float(slow.error),.0001)
	assert_lt(float(fast.error),.0001)
	assert_lt(slow.pos.distance_to(fast.pos),.051,"Only first-sample anchoring differs by one synthetic frame")

func test_shortest_heading_and_zero_vector() -> void:
	var item := track()
	item.reset(&"one",0,Vector2.ZERO,Vector2.from_angle(deg_to_rad(179)),true,0)
	item.sample(0)
	item.push(&"one",.3,Vector2(3,0),Vector2.from_angle(deg_to_rad(-179)),true,300000)
	var pose: Dictionary=item.sample(330000)
	assert_gt(absf(pose.heading.angle()),deg_to_rad(178))
	item.reset(&"one",1,Vector2.ZERO,Vector2.ZERO,false,1000000)
	assert_true(item.sample(1000000).heading.is_finite())

func test_duplicate_late_and_correction_are_distinct() -> void:
	var item := track()
	item.sample(0)
	assert_true(item.push(&"one",.15,Vector2.ONE,Vector2.RIGHT,true,150000))
	var returned: Dictionary=item.sample(150000)
	var original: Dictionary=returned.duplicate()
	returned.pos=Vector2(999,999)
	returned.heading=Vector2.LEFT
	returned.walking=false
	assert_eq(item.sample(150000),original,"Mutating a returned pose cannot rewrite history")
	var observation: Dictionary=item.observation()
	observation.context="caller"
	observation.queue_size=999
	assert_eq(item.observation().context,"one")
	assert_eq(item.observation().queue_size,2)
	var before: Dictionary=item.observation()
	assert_false(item.push(&"one",.15,Vector2.ONE,Vector2.RIGHT,true,160000))
	assert_false(item.push(&"one",.1,Vector2.ZERO,Vector2.RIGHT,true,170000))
	assert_eq(item.observation().resets,before.resets)
	assert_true(item.push(&"one",.15,Vector2(2,0),Vector2.LEFT,false,180000))
	assert_eq(item.sample(180000).pos,Vector2(2,0))
	assert_eq(item.observation().resets,int(before.resets)+1)
	assert_false(item.push(&"other",.3,Vector2.ZERO,Vector2.ZERO,false,300000))

func test_capacity_gap_and_context_reset() -> void:
	var item := track(3)
	for i in range(1,10):item.push(&"one",i*.05,Vector2(i,0),Vector2.RIGHT,true,i*50000)
	assert_lte(int(item.observation().queue_size),3)
	assert_gt(int(item.observation().resets),1)
	item.push(&"one",2,Vector2(20,0),Vector2.RIGHT,true,2000000)
	assert_eq(item.observation().reason,&"receive_gap")
	item.reset(&"two",0,Vector2(7,0),Vector2.LEFT,false,2100000)
	assert_eq(item.sample(2100000).pos,Vector2(7,0))
	assert_eq(item.observation().context,"two")
	item.clear()
	assert_true(item.sample(2200000).is_empty())

func test_continuous_frames_do_not_hide_receive_starvation() -> void:
	var item := track()
	for now in range(0,1000001,16000):
		var pose: Dictionary=item.sample(now)
		if now>600000:
			assert_false(pose.walking)
			assert_eq(pose.reason,&"receive_starved")
	assert_eq(item.observation().queue_size,1)

func test_full_segment_geometry_and_invalid_inputs() -> void:
	var area := Rect2i(-10,-10,21,21)
	var obstacles: Array[Rect2i]=[Rect2i(0,0,2,2)]
	assert_true(Field.segment_has_static_clearance(Vector2(-4,-2),Vector2(4,-2),.4,area,obstacles))
	assert_false(Field.segment_has_static_clearance(Vector2(-4,0),Vector2(4,0),.4,area,obstacles),"Clear endpoints cannot authorize crossing a whole blocker")
	assert_false(Field.segment_has_static_clearance(Vector2(-4,-.7),Vector2(4,-.7),.4,area,obstacles),"Radius matters beside an edge")
	assert_false(Field.segment_has_static_clearance(Vector2(0,0),Vector2(4,0),.4,area,obstacles))
	assert_false(Field.segment_has_static_clearance(Vector2(-10.4,-4),Vector2(-8,-4),.4,area,obstacles))
	assert_false(Field.segment_has_static_clearance(Vector2(NAN,0),Vector2.ZERO,.4,area,obstacles))
	assert_false(Field.segment_has_static_clearance(Vector2.ZERO,Vector2.ONE,-1,area,obstacles))

func test_guard_fallback_does_not_replay_and_preserves_real_arrival() -> void:
	var item := track()
	var obstacles: Array[Rect2i]=[Rect2i(0,0,2,2)]
	var guard: Callable=Field.segment_has_static_clearance.bind(.4,Rect2i(-10,-10,21,21),obstacles)
	var a := Vector2(-1,0)
	var b := Vector2(0,-1)
	assert_true(guard.call(a,a))
	assert_true(guard.call(b,b))
	assert_false(guard.call(a,b),"Two individually safe authority points cannot authorize cutting a blocker corner")
	item.configure(.18,.6,8,guard)
	item.reset(&"one",0,a,Vector2.RIGHT,true,0)
	item.sample(0)
	item.push(&"one",.15,b,Vector2.RIGHT,true,150000)
	var pose: Dictionary=item.sample(200000)
	assert_eq(pose.kind,&"authority_snap")
	assert_eq(pose.pos,b)
	for now in range(210000,740001,10000):
		pose=item.sample(now)
		assert_eq(pose.pos,b)
		assert_true(pose.walking,"Fresh fallback does not oscillate Idle/Move")
	pose=item.sample(760000)
	assert_false(pose.walking,"Original 150ms arrival, not 200ms display snap, determines freshness")
	assert_eq(pose.reason,&"receive_starved")
	assert_eq(item.observation().snaps,1)

func test_proven_bracket_is_cached_and_instances_are_isolated() -> void:
	var first := track()
	var second := track()
	first.sample(0)
	first.push(&"one",.3,Vector2(3,0),Vector2.RIGHT,true,300000)
	first.sample(310000)
	var count: int=first.observation().guard_checks
	for now in range(311000,400000,1000):first.sample(now)
	assert_eq(first.observation().guard_checks,count)
	assert_eq(second.sample(400000).pos,Vector2.ZERO)
	first.clear()
	assert_true(second.enabled)

func fighter() -> Sim.Fighter:
	var sim := Sim.new()
	assert_true(sim.create_fixture(false,1))
	return sim.units[sim.units.keys()[0]]

func test_unit_heading_attack_death_and_default_interpolation() -> void:
	var view := UnitScene.instantiate()
	add_child_autofree(view)
	var actor := fighter()
	view.setup(actor)
	var original: int=view.physics_interpolation_mode
	assert_false(view.network_motion.enabled)
	actor.last_heading=Vector2.RIGHT
	actor.last_shot=-10
	view.sync(actor,2,false,0)
	assert_almost_eq(view.robot.rotation.y,-PI/2,.00001,"Existing four-argument local behavior")
	view.sync(actor,2,false,0,Vector2.DOWN)
	assert_almost_eq(absf(view.robot.rotation.y),PI,.00001)
	actor.profile.parts.armor="rivet_shield"
	view.sync(actor,2,false,0,Vector2.DOWN)
	assert_almost_eq(view.robot.rotation.y,-PI/2,.00001)
	actor.profile.parts.erase("armor")
	actor.last_shot=1.9
	view.sync(actor,2,false,0,Vector2.DOWN)
	assert_almost_eq(view.robot.rotation.y,-PI/2,.00001)
	assert_true(view.configure_network_motion(.18,.6,8,allowed))
	assert_eq(view.physics_interpolation_mode,Node.PHYSICS_INTERPOLATION_MODE_OFF)
	actor.hp=0
	actor.pos=Vector2(8,9)
	view.sync(actor,2,false,0,Vector2.DOWN)
	assert_eq(view.position,Vector3(8,.12,9))
	assert_false(view.network_motion.enabled)
	assert_eq(view.physics_interpolation_mode,original)

func test_scene_opt_in_is_explicit_and_other_outings_are_off() -> void:
	for path: String in ["res://expedition/expedition.tscn","res://armory/outing.tscn","res://pump/outing.tscn","res://factory/outing.tscn"]:
		var page=load(path).instantiate()
		assert_eq(page.use_network_motion,path=="res://expedition/expedition.tscn",path)
		page.free()

func test_host_values_lifecycle_and_no_authority_write() -> void:
	var page=load("res://expedition/expedition.tscn").instantiate()
	var solo := Session.new()
	var party := Session.new()
	add_child_autofree(solo)
	add_child_autofree(party)
	assert_true(page.configure_sessions(solo,party))
	add_child_autofree(page)
	page.set_process(false)
	page.net=solo
	page.attached=true
	solo.seat_state="active"
	solo.state={"id":"fresh","stage":0,"elapsed":0.0,"outcome":""}
	page.active={"id":"fresh","location":"rustrail"}
	assert_true(page._prepare_network_motion())
	var actor := fighter()
	var view := UnitScene.instantiate()
	page.get_node("Units").add_child(view)
	view.setup(actor)
	page.views={"u":view}
	page.actors={"u":actor}
	var row := {"hp":70,"chassis":"crawler","pos":Vector2(-30,-18),"heading":Vector2.RIGHT,"walking":true}
	page.targets={"u":row}
	var before: Dictionary=row.duplicate(true)
	page._feed_network_motion("u",row,0)
	view.network_motion.sample(100000)
	assert_eq(row,before,"No view operation rewrites received authority")
	assert_true(view.network_motion.enabled)
	page._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(view.network_motion.enabled)
	page._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(page._prepare_network_motion())
	page._feed_network_motion("u",row,200000)
	assert_eq(view.network_motion.sample(200000).pos,row.pos)
	var old_context: String=view.network_motion.observation().context
	solo.state.stage=1
	assert_true(page._prepare_network_motion())
	page._feed_network_motion("u",row,220000)
	assert_ne(view.network_motion.observation().context,old_context)
	page.hide()
	assert_false(view.network_motion.enabled)
	page.show()
	assert_true(page._prepare_network_motion())
	page._feed_network_motion("u",row,230000)
	for seat: String in ["connecting","offline","displaced"]:
		solo.seat_state=seat
		assert_false(page._prepare_network_motion(),seat)
		assert_false(view.network_motion.enabled)
		solo.seat_state="active"
		assert_true(page._prepare_network_motion())
		page._feed_network_motion("u",row,240000)
	page.active.id="other"
	assert_false(page._prepare_network_motion())
	assert_false(view.network_motion.enabled)
	page.active.id="fresh"
	assert_true(page._prepare_network_motion())
	page._feed_network_motion("u",row,250000)
	var first_context: String=view.network_motion.observation().context
	# A second legal composition uses new Sessions before entering the tree.
	var second=load("res://expedition/expedition.tscn").instantiate()
	var second_solo := Session.new()
	var second_party := Session.new()
	add_child_autofree(second_solo)
	add_child_autofree(second_party)
	assert_true(second.configure_sessions(second_solo,second_party))
	add_child_autofree(second)
	second.set_process(false)
	second.attached=true
	second_solo.seat_state="active"
	second_solo.state=solo.state.duplicate(true)
	second.active=page.active.duplicate(true)
	# Align the local generation: Session identity must still separate contexts.
	second._motion_generation=page._motion_generation-1
	assert_true(second._prepare_network_motion())
	assert_eq(second._motion_generation,page._motion_generation)
	var second_context: String=String(second._motion_context)
	assert_ne(second_context,first_context)
	assert_false(view.network_motion.push(StringName(second_context),.15,row.pos,row.heading,true,300000))
	second._release()
	# Real reconnect entry cleanup, deliberately rejecting the address before ENet.
	var had_port := OS.has_environment("SOLO_PORT")
	var original_port := OS.get_environment("SOLO_PORT")
	OS.set_environment("SOLO_PORT","0")
	page._join()
	if had_port:OS.set_environment("SOLO_PORT",original_port)
	else:OS.unset_environment("SOLO_PORT")
	assert_false(view.network_motion.enabled)
	assert_null(solo.peer,"Address-rejected entry does not claim a successful network reconnect")
	assert_true(page._prepare_network_motion())
	page._feed_network_motion("u",row,300000)
	assert_ne(view.network_motion.observation().context,first_context)
	solo.receipt={"outcome":"win","seconds":2,"participated":false}
	page._sync()
	assert_false(view.network_motion.enabled)
	assert_eq(page._motion_context,&"")
	assert_eq(view.physics_interpolation_mode,Node.PHYSICS_INTERPOLATION_MODE_INHERIT)
	solo.receipt.clear()
	solo.state.outcome="win"
	assert_false(page._prepare_network_motion())
	solo.state.outcome=""
	page.active.erase("location")
	assert_false(page._prepare_network_motion())
	assert_false(view.network_motion.enabled)
	page.active.location="rustrail"
	page.party_mode=true
	assert_false(page._network_motion_applicable())
	page.party_mode=false
	page.net=party
	assert_false(page._network_motion_applicable())
	page.net=solo
	page._release()
	assert_false(view.network_motion.enabled)
