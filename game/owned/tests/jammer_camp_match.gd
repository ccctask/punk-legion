extends SceneTree
const Camp:=preload("res://net/camp_mission.gd")
const Catalog:=preload("res://loadout/catalog.gd")

func squad(jam:bool,medic:bool) -> Dictionary:
	var units:=Catalog.sample_squad(2)
	if jam:units[1].slots.utility="2/jammer"
	if medic:units[0].slots.utility="1/repair_arm"
	return {"units":units,"inventory":Catalog.sample_inventory(2),"names":{"1/hull":"领航","2/hull":"后卫"}}

func _initialize() -> void:
	var a1:="0:1/hull"
	var a2:="0:2/hull"
	var d1:="1:1/hull"
	var d2:="1:2/hull"
	for delay in range(0,20):
		var m:=Camp.new()
		var fixture:={"attacker":squad(true,false),"defender":squad(false,true),"neutral":false,"turrets":[]}
		if not m.create("jam-combat-%02d"%delay,fixture,int(Time.get_unix_time_from_system())+600):quit(1);return
		m.command("attacker",1,"focus",[a1],d2,Vector2.ZERO)
		m.command("attacker",2,"move",[a2],"",Vector2(-10,-3))
		m.command("defender",1,"move",[d1],"",Vector2(3,-2))
		m.command("defender",2,"move",[d2],"",Vector2(3,-1))
		var compare:Camp
		for t in 1400:
			if t==20*delay:
				m.command("attacker",3,"focus",[a2],d1,Vector2.ZERO)
			if t==40:
				m.command("defender",3,"focus",[d1,d2],a1,Vector2.ZERO)
			var before:=m.checkpoint()
			var n:=m.sim.timeline.size()
			m.step(.05)
			for event in m.sim.timeline.slice(n):
				if event.event!="jam_applied" or event.target!=d1 or not event.repair_pending or not event.weapon_pending:continue
				var copy:=Camp.new()
				var previous:=Camp.new()
				assert(copy.restore(m.checkpoint()) and previous.restore(before))
				var target=copy.sim.units[d1]
				var deadline:=[target.weapon_not_before,target.repair_not_before,target.protected_until]
				for _i in 2:
					var repeated:=Camp.new()
					assert(repeated.restore(copy.checkpoint()))
					assert([repeated.sim.units[d1].weapon_not_before,repeated.sim.units[d1].repair_not_before,repeated.sim.units[d1].protected_until]==deadline)
				previous.sim.units[a2].jam_charges=0
				var result:={}
				for _i in 155:
					previous.step(.05)
					copy.step(.05)
					for pair in [["control",previous],["jammed",copy]]:
						var unit=pair[1].sim.units[d1]
						for entry in [["weapon",unit.last_shot],["repair",unit.last_service]]:
							if entry[1]>=event.time-.000001 and not result.has(pair[0]+entry[0]):
								result[pair[0]+entry[0]]=entry[1]
				if result.size()!=4:continue
				var expected:=true
				for action in ["weapon","repair"]:
					expected=expected and absf(result["jammed"+action]-result["control"+action]-1)<=.051
				if not expected:continue
				print("CAMP_DUAL_MATCH ",JSON.stringify({"match":m.mission,"join_delay":delay,"step":.05,
					"event":event,"raw_deadlines_after_2_restores":deadline,"actual":result,"checkpoint_events":copy.sim.timeline.filter(func(e):return e.event=="jam_applied" and is_equal_approx(e.time,event.time)).size()}))
				quit(0)
				return
			if not m.outcome.is_empty():break
	printerr("No pending dual action in normal camp match")
	quit(1)
