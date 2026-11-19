extends "res://expedition/tests/solo_ui.gd"

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
	scene.get_node("%PartyMode").pressed.emit()
	await _until(scene,"busy")
	var lobby: Node = scene.get_node("%PartyPanel")
	video_dir=OS.get_environment("PARTY_FRAMES")
	if not video_dir.is_empty() and DisplayServer.get_name()!="headless":
		video_epoch=Time.get_ticks_msec()
		RenderingServer.frame_post_draw.connect(_capture_frame)
	var wait_started:=Time.get_ticks_msec()
	var first_wait:=-1
	var friend_peak:=0
	var enemy_peak:=0
	var leader:=OS.get_environment("PARTY_ROLE")=="0"
	var code_file:=OS.get_environment("PARTY_INVITE")
	if leader:
		lobby.get_node("%Create").pressed.emit()
		await _until(scene,"busy")
		var f:=FileAccess.open(code_file,FileAccess.WRITE)
		f.store_string(lobby.data.roomscope.code)
		f.close()
	else:
		var deadline:=Time.get_ticks_msec()+20000
		while not FileAccess.file_exists(code_file) and Time.get_ticks_msec()<deadline:
			await create_timer(.1).timeout
		await _until(scene,"busy")
		lobby.get_node("%Code").text=FileAccess.get_file_as_string(code_file)
		lobby.get_node("%Join").pressed.emit()
		await _until(scene,"busy")
	lobby.get_node("%Ready").pressed.emit()
	await _until(scene,"busy")
	if leader:
		var deadline:=Time.get_ticks_msec()+30000
		while Time.get_ticks_msec()<deadline:
			await create_timer(.1).timeout
			if not scene.busy and lobby.data.roomscope.members.size()==OS.get_environment("PARTY_SIZE").to_int() and not lobby.get_node("%Launch").disabled:
				lobby.get_node("%Launch").pressed.emit()
				break
	var t := Time.get_ticks_msec()
	var last := -1
	var reconnect := false
	var captured := false
	var expected := OS.get_environment("SOLO_EXPECT")
	var second:=OS.get_environment("PARTY_SECOND_ROBOT")
	var round_no:=1
	var hull:=OS.get_environment("SOLO_ROBOT")
	var pinged:=false
	var observed:=false
	while Time.get_ticks_msec()-t < (620000 if not second.is_empty() else 310000):
		await create_timer(0.18).timeout
		if not scene.net.receipt.is_empty():
			var r: Dictionary=scene.net.receipt
			print("PARTY_UI_RESULT wait_ms=",first_wait," friend_peak=",friend_peak," enemy_peak=",enemy_peak," wall=", (Time.get_ticks_msec()-t)/1000.0," seconds=",r.seconds," fighting=",scene.net.state.get("fighting",0)," marching=",scene.net.state.get("marching",0)," outcome=",r.outcome," part=",r.part)
			if not video_dir.is_empty():await create_timer(1).timeout
			_check(r.outcome==expected and str(scene.get_node("%Goal").text).contains("秒"),"终局回执")
			if not second.is_empty():
				_check(observed,"收到队长短时建议")
				print("ROUND_RECEIPT ",round_no," ",scene.active.id," ",r.id," ",hull)
				if round_no==1:
					round_no=2
					scene.get_node("%Stay").pressed.emit()
					await _until(scene,"busy")
					_check(lobby.data.roomscope.code==FileAccess.get_file_as_string(code_file),"原队邀请码保留")
					for button in lobby.get_node("%Select").get_children():
						button.button_pressed=button.text.contains(second.left(6))
					_check(lobby.selected==[second],"第二局换成另一台本人机体")
					hull=second
					lobby.get_node("%Ready").pressed.emit()
					await _until(scene,"busy")
					if leader:
						var wait:=Time.get_ticks_msec()+30000
						while Time.get_ticks_msec()<wait and (scene.busy or lobby.get_node("%Launch").disabled):
							await create_timer(.12).timeout
						lobby.get_node("%Launch").pressed.emit()
					last=-1
					pinged=false
					observed=false
					continue
				scene.get_node("%Leave").pressed.emit()
				await create_timer(.5).timeout
			quit(1 if failed else 0)
			return
		if scene.net.state.is_empty():
			continue
		var s: Dictionary=scene.net.state
		if not second.is_empty():
			if not s.get("suggestion",{}).is_empty():observed=true
			if leader and not pinged and s.elapsed>2:
				scene.get_node("%Mark").button_pressed=true
				scene.get_node("%Map").ordered.emit(Vector2(12,-12))
				pinged=true
		if first_wait<0:first_wait=Time.get_ticks_msec()-wait_started
		var friends:=0
		var enemies:=0
		for fighter in s.units.values():
			if fighter.hp>0:
				if fighter.side==0: friends+=1
				else: enemies+=1
		friend_peak=maxi(friend_peak,friends)
		enemy_peak=maxi(enemy_peak,enemies)
		if not str(s.outcome).is_empty():
			continue
		if expected=="retreat":
			scene.get_node("%Retreat").pressed.emit()
			continue
		var id := "0:"+hull
		if s.units[id].hp < s.units[id].max_hp*0.68 and s.repairs>0:
			scene.get_node("%Repair").pressed.emit()
		if s.stage!=last:
			last=s.stage
			print("PARTY_STAGE ",last," elapsed=",s.elapsed)
			if s.stage==0 and OS.get_environment("SOLO_BRANCH")=="fuel":
				scene.get_node("%Alt").pressed.emit()
			else:
				scene.get_node("%Route").pressed.emit()
		var goal: String=scene.goal
		if s.stage in [0,2,4] and s.units[id].pos.distance_to(scene.Mission.LOCATIONS[goal])<3.2:
			scene.get_node("%Collect").pressed.emit()
		if not leader and not reconnect and s.elapsed>4 and OS.get_environment("PARTY_PERF_STEADY")!="1":
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



