extends "res://profile/tests/profile_ui.gd"

var video_dir := ""
var video_epoch := 0
var last_frame := -1

func _capture_frame() -> void:
	var frame := floori((Time.get_ticks_msec()-video_epoch)*6.0/1000.0)
	if frame <= last_frame:
		return
	var picture := root.get_texture().get_image()
	while last_frame < frame:
		last_frame += 1
		picture.save_jpg(video_dir.path_join("%06d.jpg" % last_frame),0.85)

func _until(node: Node, property: String, timeout_ms := 10000) -> void:
	var end := Time.get_ticks_msec()+timeout_ms
	while node.get(property) and Time.get_ticks_msec()<end:
		await process_frame

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text=OS.get_environment("SOLO_LOGIN")
	panel.get_node("%Password").text=OS.get_environment("SOLO_PASSWORD")
	await _press("Login")
	if failed:
		quit(1)
		return
	panel.get_node("%Base").pressed.emit()
	var base := panel.get_node("PrivateBase")
	await _until(base,"busy")
	base.get_node("%Explore").pressed.emit()
	var scene := panel.get_node("Expedition")
	await _until(scene,"busy")
	video_dir = OS.get_environment("SOLO_FRAMES")
	if not video_dir.is_empty() and DisplayServer.get_name() != "headless":
		video_epoch = Time.get_ticks_msec()
		RenderingServer.frame_post_draw.connect(_capture_frame)
	for button in scene.get_node("%Squad").get_children():
		button.button_pressed = button.get_meta("robot","")==OS.get_environment("SOLO_ROBOT")
	scene.get_node("%Start").pressed.emit()
	var t := Time.get_ticks_msec()
	var last := -1
	var reconnect := false
	var captured := false
	var expected := OS.get_environment("SOLO_EXPECT")
	while Time.get_ticks_msec()-t < 310000:
		await create_timer(0.18).timeout
		if not scene.net.receipt.is_empty():
			var r: Dictionary=scene.net.receipt
			print("SOLO_UI_RESULT wall=", (Time.get_ticks_msec()-t)/1000.0," seconds=",r.seconds," fighting=",scene.net.state.get("fighting",0)," marching=",scene.net.state.get("marching",0)," outcome=",r.outcome," part=",r.part)
			_check(r.outcome==expected and str(scene.get_node("%Goal").text).contains("秒"),"终局回执")
			quit(1 if failed else 0)
			return
		if scene.net.state.is_empty():
			continue
		var s: Dictionary=scene.net.state
		if not str(s.outcome).is_empty():
			continue
		if expected=="retreat":
			scene.get_node("%Retreat").pressed.emit()
			continue
		var id := "0:"+OS.get_environment("SOLO_ROBOT")
		if s.units[id].hp < s.units[id].max_hp*0.68 and s.repairs>0:
			scene.get_node("%Repair").pressed.emit()
		if s.stage!=last:
			last=s.stage
			if s.stage==0 and OS.get_environment("SOLO_BRANCH")=="fuel":
				scene.get_node("%Alt").pressed.emit()
			else:
				scene.get_node("%Route").pressed.emit()
		var goal: String=scene.goal
		if s.stage in [0,2,4] and s.units[id].pos.distance_to(scene.Mission.LOCATIONS[goal])<3.2:
			scene.get_node("%Collect").pressed.emit()
		if not reconnect and s.elapsed>4:
			reconnect=true
			scene.net.disconnect_mission()
			await create_timer(0.7).timeout
			scene.get_node("%Reconnect").pressed.emit()
			continue
		if not captured and s.stage==3 and not OS.get_environment("SOLO_CAPTURE").is_empty() and DisplayServer.get_name()!="headless":
			var boss: Dictionary=s.units["1:6/hull"]
			if s.units[id].pos.distance_to(boss.pos)<8:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("SOLO_CAPTURE"))
				captured=true
	push_error("探索 UI 超时："+str(scene.get_node("%Hint").text))
	quit(1)


