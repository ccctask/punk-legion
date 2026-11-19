extends SceneTree

const Mission:=preload("res://net/camp_mission.gd")
const View:=preload("res://battle/unit.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var squad:=Mission.Sim.Catalog.sample_squad(2)
	var inventory:=Mission.Sim.Catalog.sample_inventory(2)
	var rid:String=squad[0].chassis
	var opposing:String=squad[1].chassis
	var attackers:={"units":[squad[0]],"inventory":inventory,"names":{rid:"糖罐"}}
	var defenders:={"units":[squad[1]],"inventory":inventory,"names":{opposing:"铜匠"}}
	var results:=[]
	for paint:String in ["base","mint"]:
		attackers.paints={rid:paint}
		var m:=Mission.new()
		if not m.create("paint_fixture",{"attacker":attackers,"defender":defenders,"neutral":false,"turrets":[]},int(Time.get_unix_time_from_system())+3600):
			quit(1)
			return
		var view:=View.instantiate()
		root.add_child(view)
		view.setup(m.sim.units["0:"+rid])
		var muzzle:Node3D=view.robot.find_child("SOCKET_Cannon_MuzzleFX",true,false)
		var armor:MeshInstance3D=view.robot.find_child("SM_Runtime_ROOT_Chassis_0",true,false)
		if not muzzle or not armor:
			push_error("模型缺少炮口或装甲节点")
			quit(1)
			return
		var at:=muzzle.global_transform
		var bounds:=armor.get_aabb()
		view.set_paint(paint)
		if muzzle.global_transform!=at or armor.get_aabb()!=bounds or (armor.material_override!=null)!=(paint=="mint"):
			quit(1)
			return
		m.command("attacker",1,"focus",["0:"+rid],"1:"+opposing,Vector2.ZERO)
		m.command("defender",1,"focus",["1:"+opposing],"0:"+rid,Vector2.ZERO)
		var shots:=[]
		var last:=-1.0
		while m.outcome.is_empty():
			m.step(0.05)
			var u=m.sim.units["0:"+rid]
			if u.last_shot!=last:
				shots.append([u.last_shot,u.impact_point,u.pos])
				last=u.last_shot
		var report:=m.settlement()
		report.erase("finished_at")
		results.append([m.sim.units["0:"+rid].stats,shots,report])
		view.queue_free()
	if results[0]!=results[1] or results[0][1].size()<2:
		push_error("涂装改变了数值或交战结果")
		quit(1)
		return
	print("PAINT_AB_PASS same chassis/slots, muzzle transform, mesh bounds, stats, shot trace positions x",results[0][1].size(),", reports, winner ",results[0][2].winner)
	quit()
