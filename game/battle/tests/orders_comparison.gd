extends SceneTree

const Sim:=preload("res://battle/simulation.gd")
const Unit:=preload("res://battle/unit.tscn")
var output:=OS.get_environment("SQUAD_CAPTURE")

func _initialize() -> void:call_deferred("_record")

func _record() -> void:
	var scene:=preload("res://battle/battle.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.hud.get_node("Modal").hide()
	scene.hud.get_node("Commands").hide()
	scene.camera.position=Vector3(2,10,13)
	scene.camera.look_at(Vector3(1.4,0.5,-1))
	scene.camera.size=6.9
	for pass_index in 2:
		var strategy:="nearest" if pass_index==0 else "weakest"
		var sim:=Sim.new()
		sim.relay_objective=false
		sim.field=Sim.Field.new(Rect2i(-16,-16,33,33),[])
		sim.create(Sim.Catalog.sample_squad(1),Sim.Catalog.sample_inventory(1),Sim.Catalog.sample_squad(2),Sim.Catalog.sample_inventory(2))
		var own:=sim.units["0:1/hull"]
		var near:=sim.units["1:1/hull"]
		var weak:=sim.units["1:2/hull"]
		own.pos=Vector2(-1,-2);near.pos=Vector2(1,-2);weak.pos=Vector2(1.8,0.85)
		weak.hp=16
		sim.apply_orders(0,{"1/hull":{"priority":strategy}})
		var views:={}
		for u in sim.units.values():
			if u.side==1:
				u.stats.range_m=0;u.stats.move_speed=0
			var view:=Unit.instantiate()
			scene.get_node("Units").add_child(view)
			view.setup(u)
			var label:Label3D=view.get_node("OwnedName")
			label.show()
			label.text="同一台气炮" if u.side==0 else ("近靶" if u==near else "残血靶")
			views[u.id]=view
		scene.hud.get_node("%Mission").text="优先最近敌机" if pass_index==0 else "优先最低耐久"
		for i in 30:
			if i>=10:sim.step(.05)
			for u in sim.units.values():
				views[u.id].sync(u,sim.elapsed,u.side==0,.05)
			scene.hud.get_node("%Score").text="近靶 %d/70　残血靶 %d/70" % [near.hp,weak.hp]
			scene.hud.get_node("%Timer").text="模拟 %.2f 秒" % sim.elapsed
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output.path_join("%06d.jpg"%(i+pass_index*30)),.85)
			await create_timer(.045).timeout
		print("VISIBLE_ORDERS ",strategy," impact=",own.impact_point," near=",near.hp," weak=",weak.hp)
		if (pass_index==0 and near.hp!=61) or (pass_index==1 and weak.hp!=7):quit(1);return
		for view in views.values():view.queue_free()
		await process_frame
	quit(0)
