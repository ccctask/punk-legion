extends SceneTree

const Mission := preload("res://net/party_mission.gd")
const Catalog := preload("res://loadout/catalog.gd")

func _initialize() -> void:
	var mission:=Mission.new()
	var squads:={}
	var samples:=Catalog.sample_squad(3)
	var inventory:=Catalog.sample_inventory(3)
	for i in 3:
		var chassis:String=samples[i].chassis
		squads[str(i)]={"units":[samples[i]],"inventory":inventory,"names":{chassis:"R"+str(i)}}
	var first:="0:1/hull"
	var second:="0:2/hull"
	var third:="0:3/hull"
	var expiry:=int(Time.get_unix_time_from_system())+1200
	assert(mission.create_party("fixture",squads,expiry))
	assert(mission.resolve_assembly(Time.get_unix_time_from_system(),["0","1","2"]))
	mission.leader="0"
	assert(not mission.suggest("1","move","",Vector2.ZERO))
	assert(mission.suggest("0","move","",Vector2(5,4)))
	assert(mission.personalized("1").suggestion.position==Vector2(5,4) and mission.personalized("1").seq==0)
	assert(not mission.suggest("0","focus",mission.enemy_ids[0],Vector2.ZERO))
	mission.sim.elapsed+=7.0
	assert(mission.personalized("1").suggestion.is_empty() and mission.suggest("0","focus",mission.enemy_ids[0],Vector2.ZERO))
	assert(not mission.party_order("0",1,"move",[second],"",Vector2.ZERO))
	assert(mission.party_order("0",1,"route",[first],"scrap",Vector2.ZERO))
	assert(not mission.party_order("0",1,"route",[first],"scrap",Vector2.ZERO))
	mission.sim.units[first].pos=mission.LOCATIONS.scrap
	mission.sim.units[third].pos=mission.LOCATIONS.scrap
	mission.sim.units[mission.enemy_ids[0]].hp=0
	assert(mission.party_order("0",2,"collect",[first],"scrap",Vector2.ZERO))
	assert(mission.stage==0)
	assert(not mission.party_order("0",3,"collect",[first],"scrap",Vector2.ZERO))
	var resumed:=Mission.new()
	assert(resumed.restore_party(mission.save_party()))
	assert(resumed.personalized("0").seq==2 and resumed.absent_until.has("0"))
	assert(resumed.party_order("2",1,"collect",[third],"scrap",Vector2.ZERO) and resumed.stage==1)
	assert(resumed.party_order("0",3,"retreat",[first],"",Vector2.ZERO))
	assert(not resumed.party_order("0",4,"move",[first],"",Vector2.ZERO))
	resumed.leave_member("1","expired")
	assert(resumed.departures.size()==2 and resumed.outcome.is_empty())
	assert(resumed.party_order("2",2,"route",[third],"guard",Vector2.ZERO))
	resumed.outcome="win"
	var results:=resumed.results()
	assert(results["0"].outcome=="retreat" and results["1"].outcome=="expired" and results["2"].outcome=="win")
	for owner in results:
		assert(results[owner].reports.keys()==[samples[int(owner)].chassis])
		assert(results[owner].commanded==(owner!="1"))
	print("PARTY_RULES_PASS reject cross-owner and replay; two distinct owners unlock; checkpoint restores; leader withdraws; grace expiry; third member continues; reports split")
	quit()
