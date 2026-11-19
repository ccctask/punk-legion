extends SceneTree

const Sim = preload("res://battle/simulation.gd")
const Mission = preload("res://net/solo_mission.gd")
const DT = 0.05
const GROUPS = ["J1", "J2", "J3", "R1", "W1"]
var failure: Dictionary = {}
var output_path: String

func require(ok: bool, assertion: String, evidence: Variant = null, kind := "product_failure") -> bool:
	if not ok and failure.is_empty():
		failure = {"classification":kind,"assertion":assertion,"evidence":evidence}
	return ok

func setup(jam: bool, moving := false, injured := true):
	var left: Array = Sim.Catalog.sample_squad(3)
	var right: Array = Sim.Catalog.sample_squad(2)
	if jam:
		left[0].slots.utility="1/jammer"
		left[1].slots.utility="2/jammer"
	right[0].slots.utility="1/repair_arm"
	var sim = Sim.new()
	if not require(sim.create(left,Sim.Catalog.sample_inventory(3),right,Sim.Catalog.sample_inventory(2)),"legal Sim constructor",sim.last_error,"fixture_failure"):return null
	sim.relay_objective=false
	sim.field=Sim.Field.new(Rect2i(-12,-12,25,25),[])
	var positions: Array = [Vector2(-7,0),Vector2(-7,0),Vector2(3,0),Vector2(0,0),Vector2(0,1)] if moving else [Vector2(0,0),Vector2(-1,0),Vector2(5,0),Vector2(2,0),Vector2(6.8,0)]
	var ids: Array = ["0:1/hull","0:2/hull","0:3/hull","1:1/hull","1:2/hull"]
	for i in ids.size():
		var u = sim.units[ids[i]]
		u.pos=positions[i]
		if i!=3:u.stats.damage=0
		if i in [2,4]:u.stats.move_speed=0
	if injured:sim.units["1:2/hull"].hp-=20
	return sim

func snapshot(sim) -> Dictionary:
	var rows: Dictionary={}
	for id in sim.units:
		var u=sim.units[id]
		var data: Dictionary={}
		for key in ["hp","cooldown","last_shot","last_service","lock_target","lock_ready_at","service_charges","jam_charges","last_jam","protected_until","weapon_not_before","repair_not_before","weapon_delayed","repair_delayed"]:data[key]=u.get(key)
		data.pos=[u.pos.x,u.pos.y]
		data.movement_goal=[u.movement_goal.x,u.movement_goal.y]
		rows[id]=data
	return {"at":sim.elapsed,"units":rows,"event_count":sim.timeline.size()}

func pulses(sim) -> Array:
	return sim.timeline.filter(func(e):return e.event=="jam_applied" and e.target=="1:1/hull")

func move(sim, ids: Array[String], target: Vector2, side: int) -> void:
	sim.command_move(ids,target,side)

func paired(jam: bool, moving: bool) -> Dictionary:
	var sim=setup(jam,moving)
	if sim==null:return {}
	var tech=sim.units["1:1/hull"]
	var trace: Array=[]
	var first_weapon: Variant=null
	var first_repair: Variant=null
	var next_weapon: Variant=null
	var next_repair: Variant=null
	var moved_at: Variant=null
	var arrived: Variant=null
	var relock: Variant=null
	var hit: Dictionary={}
	var withdrew=false
	var initial=snapshot(sim)
	for tick in 190:
		var before=snapshot(sim)
		var shot: float=tech.last_shot
		var repair: float=tech.last_service
		sim.step(DT)
		var after=snapshot(sim)
		if tech.last_shot!=shot:
			if first_weapon==null:first_weapon=tech.last_shot
			elif next_weapon==null:next_weapon=tech.last_shot
		if tech.last_service!=repair:
			if first_repair==null:first_repair=tech.last_service
			elif next_repair==null:next_repair=tech.last_service
		if jam and hit.is_empty() and not pulses(sim).is_empty():hit={"before":before,"after":after,"event":pulses(sim)[0].duplicate(true)}
		trace.append({"before":before,"after":after})
		if moving and moved_at==null and first_weapon!=null and first_repair!=null:
			moved_at=sim.elapsed
			move(sim,["1:1/hull"],Vector2(-1,0),1)
			move(sim,["0:1/hull"],Vector2(-4,0),0)
			move(sim,["0:2/hull"],Vector2(-4,0),0)
		if moving and moved_at!=null:
			if not withdrew and sim.elapsed>=float(moved_at)+3*DT-0.000001:
				move(sim,["0:1/hull"],Vector2(-9,0),0)
				move(sim,["0:2/hull"],Vector2(-9,0),0)
				withdrew=true
			if arrived==null and tech.movement_goal==Sim.UNSET:arrived=sim.elapsed
			if arrived!=null and relock==null and not tech.lock_target.is_empty():relock=tech.lock_ready_at
		if (not moving and first_weapon!=null and first_repair!=null) or (moving and next_weapon!=null and next_repair!=null):break
	return {"initial":initial,"trace":trace,"hit":hit,"first_weapon":first_weapon,"first_repair":first_repair,"next_weapon":next_weapon,"next_repair":next_repair,"move_started":moved_at,"arrived":arrived,"lock_ready":relock,"pulses":pulses(sim).duplicate(true),"remaining_jam":sim.units["0:1/hull"].jam_charges+sim.units["0:2/hull"].jam_charges,"final":snapshot(sim),"events":sim.timeline.duplicate(true)}

func pair_group(moving: bool) -> Dictionary:
	var base=paired(false,moving)
	var jam=paired(true,moving)
	var e={"baseline":base,"jammed":jam,"tick":DT}
	if not failure.is_empty():return e
	var keys: Array=["next_weapon","next_repair"] if moving else ["first_weapon","first_repair"]
	for branch in [base,jam]:
		for key in keys:
			if not require(branch[key]!=null,"actions observed",e,"fixture_failure"):return e
	if not require(not jam.hit.is_empty(),"natural first pulse",e,"fixture_failure"):return e
	if not require(absf(jam.hit.after.units["1:1/hull"].protected_until-jam.hit.event.time-float(Sim.Catalog.PARTS.jammer.jam_protection))<=0.000001,"original protection deadline exact",e):return e
	if moving:
		if not require(jam.first_weapon==base.first_weapon and jam.first_repair==base.first_repair,"both branches established same real prior actions",e,"fixture_failure"):return e
		var weapon_due: float=jam.first_weapon+float(Sim.Catalog.PARTS.cannon.attack_interval)
		var repair_due: float=jam.first_repair+float(Sim.Catalog.PARTS.repair_arm.repair_interval)
		e.independent_due={"weapon":weapon_due,"repair":repair_due}
		var h: Dictionary=jam.hit
		if not require(absf(h.before.units["1:1/hull"].last_shot-jam.first_weapon)<0.000001 and absf(h.before.units["1:1/hull"].last_service-jam.first_repair)<0.000001 and h.before.at+h.before.units["1:1/hull"].cooldown>h.event.time,"own pre-hit pending from real actions",e,"fixture_failure"):return e
		if not require(h.before.units["1:1/hull"].movement_goal!=[999,999] and h.after.units["1:1/hull"].pos!=h.before.units["1:1/hull"].pos,"hit while movement progresses",e,"fixture_failure"):return e
		if not require(h.event.time<minf(weapon_due,repair_due) and jam.arrived!=null and jam.lock_ready!=null and jam.arrived<weapon_due and jam.lock_ready<weapon_due,"pending and relock before original due",e,"fixture_failure"):return e
		if not require(absf(base.next_weapon-weapon_due)<=DT+0.000001 and absf(base.next_repair-repair_due)<=DT+0.000001,"baseline original deadlines",e,"fixture_failure"):return e
		if not require(absf(h.after.units["1:1/hull"].weapon_not_before-weapon_due-1)<=0.000001 and absf(h.after.units["1:1/hull"].repair_not_before-repair_due-1)<=0.000001,"pending deadlines each plus one",e):return e
	else:
		var weapon_due: float=base.trace[0].after.units["1:1/hull"].lock_ready_at
		var repair_due: float=base.trace[0].after.at
		e.independent_due={"weapon":weapon_due,"repair":repair_due}
		if not require(weapon_due>repair_due and jam.hit.after.units["1:1/hull"].lock_ready_at==weapon_due,"natural first lock established",e,"fixture_failure"):return e
		if not require(absf(jam.hit.after.units["1:1/hull"].weapon_not_before-weapon_due-1)<=0.000001 and absf(jam.hit.after.units["1:1/hull"].repair_not_before-repair_due-1)<=0.000001,"natural action deadlines each plus one",e):return e
	if not require(jam.pulses.size()==1 and jam.remaining_jam==7,"shared protection one pulse/charge",e):return e
	for key in keys:
		if not require(absf(jam[key]-base[key]-1)<=DT+0.000001,"actual action delayed once "+key,e):return e
	return e

func mission_fixture(count: int, utility: String):
	var squad: Array=Sim.Catalog.sample_squad(count)
	for i in mini(2,count):squad[i].slots.utility="%d/%s"%[i+1,utility]
	var mission=Mission.new()
	if not require(mission.create("current-action-contract",{"units":squad,"inventory":Sim.Catalog.sample_inventory(count)},2000000000),"Mission constructor",null,"fixture_failure"):return null
	return mission

func idle_and_restore() -> Dictionary:
	var sim=setup(true,false,false)
	if sim==null:return {}
	sim.step(DT)
	var before=snapshot(sim)
	if not require(pulses(sim).size()==1,"idle pulse",before,"fixture_failure"):return before
	var original_protection: float=sim.units["1:1/hull"].protected_until
	if not require(absf(original_protection-pulses(sim)[0].time-float(Sim.Catalog.PARTS.jammer.jam_protection))<=0.000001,"idle original protection exact",before):return before
	move(sim,["0:1/hull"],Vector2(-9,0),0)
	move(sim,["0:2/hull"],Vector2(-9,0),0)
	while sim.elapsed<4.25-0.000001:
		sim.step(DT)
		if not require(sim.units["1:1/hull"].protected_until==original_protection,"idle original protection retained",snapshot(sim)):return before
	if not require(sim.elapsed>sim.units["1:1/hull"].protected_until and pulses(sim).size()==1,"original protection expiry crossed",snapshot(sim),"fixture_failure"):return before
	sim.units["1:2/hull"].hp-=8
	var injury_at: float=sim.elapsed
	sim.step(DT)
	if not require(absf(sim.units["1:1/hull"].last_service-injury_at-DT)<0.000001,"idle repair no banked penalty",snapshot(sim)):return before
	var m=mission_fixture(1,"jammer")
	if m==null:return before
	m.sim.units["0:1/hull"].pos=Vector2(24,-17)
	m.sim.step(DT)
	move(m.sim,["0:1/hull"],Vector2(18,-17),0)
	var checkpoint: Dictionary=m.checkpoint().duplicate(true)
	var checkpoint_target=m.sim.units[m.enemy_ids[0]]
	var checkpoint_protection: float=checkpoint_target.protected_until
	if not require(absf(checkpoint_protection-DT-float(Sim.Catalog.PARTS.jammer.jam_protection))<=0.000001,"checkpoint original protection exact",snapshot(m.sim)):return before
	var save_path: String=output_path.get_base_dir().path_join("current-checkpoint.save")
	if not require(not FileAccess.file_exists(save_path),"new checkpoint path",save_path,"tool_failure"):return before
	var file=FileAccess.open(save_path,FileAccess.WRITE)
	if not require(file!=null,"open current checkpoint for writing",FileAccess.get_open_error(),"tool_failure"):return before
	file.store_var(checkpoint)
	var write_error=file.get_error()
	file.close()
	if not require(write_error==OK,"store_var current checkpoint",write_error,"tool_failure"):return before
	file=FileAccess.open(save_path,FileAccess.READ)
	if not require(file!=null,"open current checkpoint for reading",FileAccess.get_open_error(),"tool_failure"):return before
	var loaded: Variant=file.get_var()
	var read_error=file.get_error()
	file.close()
	if not require(read_error==OK and loaded==checkpoint,"native checkpoint roundtrip",read_error):return before
	var restored=Mission.new()
	if not require(restored.restore(loaded) and restored.checkpoint()==checkpoint,"exact original due/protection/charge/event restore",null):return before
	while m.sim.elapsed<4.15-0.000001:
		m.sim.step(DT)
		restored.sim.step(DT)
		if not require(checkpoint_target.protected_until==checkpoint_protection and restored.sim.units[restored.enemy_ids[0]].protected_until==checkpoint_protection,"checkpoint original protection retained",snapshot(m.sim)):break
		if not require(m.checkpoint()==restored.checkpoint(),"parallel checkpoint advancement",{"original":snapshot(m.sim),"restored":snapshot(restored.sim)}):break
	var target=m.sim.units[m.enemy_ids[0]]
	require(m.sim.elapsed>target.protected_until and m.sim.timeline.filter(func(e):return e.event=="jam_applied").size()==1,"restored protection expiry no pulse replay",snapshot(m.sim))
	return {"idle_initial":before,"idle_final":snapshot(sim),"injury_at":injury_at,"serialization":"FileAccess.store_var/get_var; new current-checkpoint.save","checkpoint_units":checkpoint.units,"checkpoint_timeline":checkpoint.timeline,"parallel_final":snapshot(m.sim),"restored_final":snapshot(restored.sim)}

func repair_clamp() -> Dictionary:
	var m=mission_fixture(3,"repair_arm")
	if m==null:return {}
	for id in m.sim.units:
		var u=m.sim.units[id]
		if u.side==1:
			u.pos=Vector2(30,20)
			u.stats.damage=0
			u.stats.move_speed=0
	m.sim.units["0:1/hull"].pos=Vector2(0,0)
	m.sim.units["0:2/hull"].pos=Vector2(0,1)
	var hurt=m.sim.units["0:3/hull"]
	hurt.pos=Vector2(1,0)
	hurt.hp-=3.25
	hurt.last_damage=-10 # Declared quiet-age fixture, never a service/output field.
	var initial=snapshot(m.sim)
	m.sim.step(DT)
	var events: Array=m.sim.timeline.filter(func(e):return e.event=="module_repair")
	var reports: Dictionary=m.combat_reports(m.deployment,0)
	var output: Array=[]
	var received: Array=[]
	for rows in reports.values():
		for event in rows:
			if event.kind=="field_repair_output":output.append(event)
			if event.kind=="field_repair_received":received.append(event)
	var evidence={"initial":initial,"final":snapshot(m.sim),"events":events,"reports":reports}
	if not require(hurt.hp==hurt.stats.max_hp and events.size()==1 and events[0].amount==3.25 and output.size()==1 and received.size()==1,"effective clamp and paired report count",evidence):return evidence
	require(output[0].actor==received[0].actor and output[0].target==received[0].target and output[0].target=="3/hull" and output[0].amount==received[0].amount and output[0].amount==3.25,"paired actual actor/target/effective output",evidence)
	var charges: Array=[m.sim.units["0:1/hull"].service_charges,m.sim.units["0:2/hull"].service_charges]
	charges.sort()
	require(charges==[3,4],"only effective healer consumes charge",evidence)
	return evidence

func weapon_fixture(name: String, distance: float):
	var squad: Array=Sim.Catalog.sample_squad(1)
	squad[0].slots.weapon="1/"+name
	var sim=Sim.new()
	if not require(sim.create(squad,Sim.Catalog.sample_inventory(1),Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1)),"legal weapon fixture",sim.last_error,"fixture_failure"):return null
	sim.relay_objective=false
	sim.field=Sim.Field.new(Rect2i(-12,-12,25,25),[])
	sim.units["0:1/hull"].pos=Vector2.ZERO
	sim.units["1:1/hull"].pos=Vector2(distance,0)
	# Fixed geometry only; actual compared weapon definition remains unchanged.
	for u in sim.units.values():u.stats.move_speed=0
	sim.units["1:1/hull"].stats.damage=0
	return sim

func weapons() -> Dictionary:
	var evidence: Dictionary={}
	for name in ["rivet_repeater","cannon"]:
		for distance in [3,4]:
			var sim=weapon_fixture(name,distance)
			if sim==null:return evidence
			var gun=sim.units["0:1/hull"]
			var dummy=sim.units["1:1/hull"]
			var shots: Array=[]
			var original_speed: float=Sim.Rules.validate_squad(Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1)).roster[0].combat.move_speed
			for tick in 40:
				var previous: float=gun.last_shot
				var hp: float=dummy.hp
				sim.step(DT)
				if gun.last_shot!=previous:shots.append({"at":gun.last_shot,"damage":hp-dummy.hp})
			evidence[name+"_"+str(distance)]={"shots":shots,"initial_distance":distance,"final_distance":gun.pos.distance_to(dummy.pos),"original_speeds":[original_speed,original_speed],"fixture_speeds":[gun.stats.move_speed,dummy.stats.move_speed],"final":snapshot(sim),"weapon_stats":gun.stats}
	var r: Array=evidence.rivet_repeater_3.shots
	var c: Array=evidence.cannon_3.shots
	if not require(r.size()>c.size() and c.size()>0,"close repeater frequency",evidence):return evidence
	for shot in r:
		if not require(shot.damage>0 and shot.damage<c[0].damage,"close repeater lower per hit",evidence):return evidence
	require(evidence.rivet_repeater_4.shots.is_empty() and not evidence.cannon_4.shots.is_empty(),"four-meter cannon role",evidence)
	return evidence

func qualify() -> Dictionary:
	var fixtures: Array=[]
	for args in [[false,false,true],[true,false,true],[false,true,true],[true,true,true],[true,false,false]]:
		var sim=setup(args[0],args[1],args[2])
		if sim==null:return {}
		fixtures.append(snapshot(sim))
	for utility in ["jammer","repair_arm"]:
		var m=mission_fixture(1 if utility=="jammer" else 3,utility)
		if m==null:return {}
		fixtures.append(snapshot(m.sim))
	for name in ["rivet_repeater","cannon"]:
		for distance in [3,4]:
			var sim=weapon_fixture(name,distance)
			if sim==null:return {}
			fixtures.append(snapshot(sim))
	return {"prepared":true,"not_behavior_pass":true,"no_step":true,"constructors":fixtures.size(),"initial":fixtures}

func _initialize() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if args.size()<1:
		printerr("output path required")
		quit(2)
		return
	output_path=args[0]
	var report={"passed":false,"model":"godot","step":DT,"groups":[],"remaining":GROUPS.duplicate()}
	if "--fixture-only" in args:
		report.merge(qualify(),true)
		report.scope="constructor qualification only"
	else:
		for name in GROUPS:
			var evidence: Dictionary
			match name:
				"J1":evidence=pair_group(false)
				"J2":evidence=pair_group(true)
				"J3":evidence=idle_and_restore()
				"R1":evidence=repair_clamp()
				"W1":evidence=weapons()
			var item={"name":name,"passed":failure.is_empty(),"evidence":evidence}
			if not failure.is_empty():item.merge(failure,true)
			report.groups.append(item)
			report.remaining.erase(name)
			if not failure.is_empty():break
		report.passed=report.groups.size()==5 and failure.is_empty()
	if not failure.is_empty():report.first_error=failure
	var file=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null:
		printerr("cannot write report ",FileAccess.get_open_error())
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	var error=file.get_error()
	file.close()
	print("ACTION_CONTRACT ",JSON.stringify({"passed":report.passed,"prepared":report.get("prepared",false),"groups":report.groups.size()}))
	quit(0 if error==OK and failure.is_empty() and (report.passed or report.get("prepared",false)) else 1)
