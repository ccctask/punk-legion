extends "res://expedition/tests/zone_art_bench.gd"

const WARMUP:=24
const COUNT:=90

func _run() -> void:
	var area:=_make_boss_scene()
	var viewport:=get_viewport()
	var rid:=viewport.get_viewport_rid()
	# The first/last identical setup brackets heat, compositor, and host drift.
	# The first four runs isolate timing probes, the following runs isolate 3D cost.
	var cases:=[
		["reference",1.0,true,false,false,true],
		["timing_probe",1.0,true,true,false,true],
		["adb_probe",1.0,true,false,false,true],
		["companions",1.0,true,false,false,true],
		["scale_75",0.75,true,false,false,true],
		["no_msaa",1.0,false,false,false,true],
		["scale_75_no_msaa",0.75,false,false,false,true],
		["without_shadows",1.0,true,false,false,false],
		["hud_only",1.0,true,false,true,true],
		["reference_repeat",1.0,true,false,false,true]]
	if ProjectSettings.get_setting("diagnostics/quick_cost",false):
		cases=[cases[0],cases[8],cases[9]]
	var output:={}
	for c in cases:
		var label:String=c[0]
		viewport.scaling_3d_scale=c[1]
		viewport.msaa_3d=Viewport.MSAA_2X if c[2] else Viewport.MSAA_DISABLED
		RenderingServer.viewport_set_measure_render_time(rid,c[3])
		viewport.disable_3d=c[4]
		area.get_node("Sun").shadow_enabled=c[5]
		print("COST_WARM ",label)
		# Outside the sample; lets the host launch/stop the controlled load.
		await get_tree().create_timer(1.5).timeout
		for i in WARMUP:await RenderingServer.frame_post_draw
		var frames:=PackedFloat32Array()
		frames.resize(COUNT)
		var prev:=Time.get_ticks_usec()
		for i in COUNT:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			frames[i]=(now-prev)*.001
			prev=now
			if c[3]:
				RenderingServer.viewport_get_measured_render_time_cpu(rid)
				RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var sorted:=frames.duplicate()
		sorted.sort()
		output[label]={"p50":sorted[COUNT/2],"p95":sorted[int(COUNT*.95)],"frames":Array(frames),
			"draw":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"scale":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d}
		print("COST_FINISH ",label)
		# The host retrieves the most recent 128 presented buffers once, after measurement.
		await get_tree().create_timer(2.0).timeout
	var file:=FileAccess.open("user://boss-cost.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	file.close()
	print("COST_DONE")
	get_tree().quit()

