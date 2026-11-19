extends Node

const Mission := preload("res://net/solo_mission.gd")
var results:={}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var t:=Time.get_ticks_usec()
	var base=load("res://base/base.tscn").instantiate()
	base.busy=true
	add_child(base)
	var layout:={"width":12,"height":9,"revision":1,"used":5,"supply":6,"roads":[],"buildings":[]}
	for x in 12:layout.roads.append([x,4])
	for row in [["core",1,2,2,2],["foundry",4,2,2,2],["warehouse",8,3,2,1],
			["workshop",1,5,2,2],["repair",5,5,1,2],["turret",8,5,1,1]]:
		layout.buildings.append({"kind":row[0],"x":row[1],"y":row[2],"w":row[3],"h":row[4],"powered":row[0]!="repair"})
	base._draw(layout)
	await _measure("base",t)
	remove_child(base)
	base.free()
	await get_tree().process_frame
	t=Time.get_ticks_usec()
	_make_boss_scene()
	await _measure("boss",t)
	var file:=FileAccess.open("user://art-bench.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	print("ZONE_ART_BENCH ",JSON.stringify(results))
	get_tree().quit()

func _make_boss_scene() -> Node:
	var area=load("res://expedition/expedition.tscn").instantiate()
	area.busy=true
	add_child(area)
	var model:=Mission.new()
	var units:=Mission.Sim.Catalog.sample_squad(3)
	var inventory:=Mission.Sim.Catalog.sample_inventory(3)
	model.create("visual-check",{"units":units,"inventory":inventory,"names":{"1/hull":"黄铜领航","2/hull":"青柠先锋","3/hull":"蓝莓工兵"}},9999999999)
	model.stage=3
	for n in 8:
		var enemy=model.sim.units[model.enemy_ids[n]]
		enemy.hp=enemy.stats.max_hp if n in [5,6,7] else 0.0
	var friends=model.sim.alive_ids(0)
	for i in friends.size():
		model.sim.units[friends[i]].pos=Vector2(-21+i*1.55,-13+i*0.3)
	model.sim.command_focus(friends,model.enemy_ids[5])
	for i in 8:model.step(.05)
	area.active={"id":"visual-check"}
	area.attached=true
	area.get_node("%Lobby").hide()
	for part in ["Map","Bar","Commands"]:area.get_node("%"+part).show()
	area.net.state=model.view()
	area._sync()
	return area

func _measure(tag: String, started: int) -> void:
	await RenderingServer.frame_post_draw
	var first_ms:=(Time.get_ticks_usec()-started)/1000.0
	print("ZONE_BENCH_FIRST ",tag)
	for i in 24:await RenderingServer.frame_post_draw
	var times:Array[float]=[]
	var render_cpu_ms:Array[float]=[]
	var render_gpu_ms:Array[float]=[]
	var viewport_rid:=get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	var prev:=Time.get_ticks_usec()
	for i in 150:
		await RenderingServer.frame_post_draw
		var stamp:=Time.get_ticks_usec()
		times.append((stamp-prev)/1000.0)
		render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		prev=stamp
	await get_tree().process_frame
	times.sort()
	render_cpu_ms.sort()
	render_gpu_ms.sort()
	results[tag]={"viewport":str(get_viewport().get_visible_rect().size),"samples":times.size(),"render_cpu_ms_p50":render_cpu_ms[75],"render_gpu_ms_p50":render_gpu_ms[75],
			"load_to_first_draw_ms":first_ms,"median_ms":times[75],"p95_ms":times[142],
			"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"static_bytes":OS.get_static_memory_usage(),"video_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)}
	print("ZONE_BENCH_CAPTURE ",tag)
	if OS.get_name()=="Android":
		var marker:=FileAccess.open("user://capture-"+tag,FileAccess.WRITE)
		marker.store_string(tag)
		marker.close()
		for i in 200:
			if FileAccess.file_exists("user://captured-"+tag):break
			await get_tree().create_timer(.1).timeout
	else:
		get_viewport().get_texture().get_image().save_png("user://zone-"+tag+".png")

