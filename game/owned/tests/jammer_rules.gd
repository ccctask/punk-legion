extends SceneTree

const Sim:=preload("res://battle/simulation.gd")
const Mission:=preload("res://net/solo_mission.gd")
var failed:=false

func check(ok:bool,reason:String) -> void:
	if not ok:
		printerr(reason)
		failed=true

func trial(equipped:bool) -> Array:
	var sim:=Sim.new()
	var left:=Sim.Catalog.sample_squad(2)
	var right:=Sim.Catalog.sample_squad(2)
	if equipped:
		for i in 2:left[i].slots.utility="%d/jammer"%(i+1)
	right[0].slots.utility="1/repair_arm"
	check(sim.create(left,Sim.Catalog.sample_inventory(2),right,Sim.Catalog.sample_inventory(2)),"failed to deploy")
	sim.relay_objective=false
	sim.field=Sim.Field.new(Rect2i(-12,-12,25,25),[])
	var tech:=sim.units["1:1/hull"]
	var buddy:=sim.units["1:2/hull"]
	var a:=sim.units["0:1/hull"]
	var b:=sim.units["0:2/hull"]
	a.pos=Vector2.ZERO;b.pos=Vector2(-1,0)
	tech.pos=Vector2(2,0);buddy.pos=Vector2(6.8,0)
	buddy.stats.move_speed=0
	tech.cooldown=2;tech.last_service=-3
	buddy.hp-=20
	for u in sim.units.values():u.stats.damage=0
	var weapon:=-1.0
	var repair:=-1.0
	for tick in 95:
		sim.step(.05)
		if equipped and tick==0:check(a.jam_charges+b.jam_charges==7,"protected target charged twice")
		if tech.last_shot>=0 and weapon<0:weapon=tech.last_shot
		if tech.last_service>=0 and repair<0:repair=tech.last_service
	var hits:=sim.timeline.filter(func(e):return e.time<=4 and e.event=="jam_applied" and e.target==tech.id)
	if equipped:
		check(hits.size()==1 and hits[0].amount==4,"one effective application across two sources")
	return [weapon,repair]

func _initialize() -> void:
	var base:=trial(false)
	var delayed:=trial(true)
	check(absf(delayed[0]-base[0]-1)<0.051 and absf(delayed[1]-base[1]-1)<0.051,"pending deadlines did not shift once "+str([base,delayed]))
	var m:=Mission.new()
	var squad:=Sim.Catalog.sample_squad(1)
	squad[0].slots.utility="1/jammer"
	check(m.create("jam-checkpoint",{"units":squad,"inventory":Sim.Catalog.sample_inventory(1)},2000000000),"mission")
	var source:=m.sim.units["0:1/hull"]
	var target:=m.sim.units[m.enemy_ids[0]]
	source.pos=Vector2(24,-17)
	target.movement_goal=Vector2i(28,-16)
	target.service_charges=1
	target.last_service=0
	var old:=target.pos
	m.sim.step(.05)
	check(target.pos!=old and target.protected_until>4,"movement interrupted")
	check(absf(target.repair_not_before-1.05)<.001,"idle repair banked an extension")
	var saved:=m.checkpoint()
	var restored:=Mission.new()
	check(restored.restore(saved),"restore")
	var resumed:=restored.sim.units[target.id]
	check(is_equal_approx(resumed.protected_until,target.protected_until) and is_equal_approx(resumed.weapon_not_before,target.weapon_not_before) and is_equal_approx(resumed.repair_not_before,target.repair_not_before),"original deadlines changed")
	check(restored.combat_reports(restored.deployment,0)["1/hull"].filter(func(e):return e.kind=="jam_applied").size()==1,"restored event duplicated")
	print("JAM_RULES ",JSON.stringify({"baseline":base,"delayed":delayed,"moved":target.pos!=old,"protection":resumed.protected_until,"idle_repair":resumed.repair_not_before}))
	quit(int(failed))
