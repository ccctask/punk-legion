extends "res://profile/tests/profile_ui.gd"

var mode:=OS.get_environment("CAMP_ACTION")
var started:=0
var frame_dir:=OS.get_environment("CAMP_FRAMES")
var frame:=-1

func _capture() -> void:
	var age:=Time.get_ticks_msec()-started
	if OS.has_environment("CAMP_VIDEO_EPOCH"):
		age=int(Time.get_unix_time_from_system()*1000)-OS.get_environment("CAMP_VIDEO_EPOCH").to_int()
	var n:=floori(age*6.0/1000.0)
	if n<=frame:
		return
	var picture:=root.get_texture().get_image()
	while frame<n:
		frame+=1
		picture.save_jpg(frame_dir.path_join("%06d.jpg"%frame),0.80)

func _http(node: Node) -> void:
	var until:=Time.get_ticks_msec()+9000
	while node.busy and Time.get_ticks_msec()<until:
		await process_frame
	_check(not node.busy,"网络等待超时")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text=OS.get_environment("CAMP_LOGIN")
	panel.get_node("%Password").text=OS.get_environment("CAMP_PASSWORD")
	await _press("Login")
	if failed:
		quit(1)
		return
	panel.get_node("%Base").pressed.emit()
	var base:=panel.get_node("PrivateBase")
	await _http(base)
	base.get_node("%WorldMap").pressed.emit()
	var world:=panel.get_node("WorldMap")
	await _http(world)
	var site:=OS.get_environment("CAMP_NODE")
	world.pins["brass-yard" if site.is_empty() else site].pressed.emit()
	if mode in ["neutral","attacker","absent","offline","takeover"]:
		world.get_node("%Action").pressed.emit()
		await _http(world)
	world.get_node("%Contest").pressed.emit()
	var scene:=panel.get_node("CampContest")
	await _http(scene)
	if mode in ["station","release"]:
		var pair: Array=scene.checks.values()[0]
		pair[0].button_pressed=mode=="station"
		pair[1].button_pressed=mode=="station"
		scene.get_node("%Station").pressed.emit()
		await _http(scene)
		_check(scene.camp.robots[0].guard==(mode=="station") and scene.camp.robots[0].turret==(mode=="station"),"实体驻防或解除")
		print("CAMP_UI_GARRISON_PASS")
		quit(1 if failed else 0)
		return
	var wait:=Time.get_ticks_msec()+30000
	while scene.get_node("%Start").disabled and Time.get_ticks_msec()<wait:
		await create_timer(0.15).timeout
	scene.get_node("%Start").pressed.emit()
	var net: Node=scene.net
	started=Time.get_ticks_msec()
	if not frame_dir.is_empty() and DisplayServer.get_name()!="headless":
		RenderingServer.frame_post_draw.connect(_capture)
	var moved:=false
	var connected:=false
	var reconnect:=false
	var seen:=false
	var mint:=OS.get_environment("CAMP_EXPECT_MINT")
	var checked_role:=false
	var saw_mint:=false
	var repairs:=false
	var last_send:=0
	while Time.get_ticks_msec()-started<80000:
		await create_timer(0.20).timeout
		if not net.receipt.is_empty():
			var r: Dictionary=net.receipt
			print("CAMP_UI_RESULT ",mode," winner=",r.winner," reason=",r.reason," revision=",r.revision," seconds=",r.seconds," owned_frame=",seen)
			_check(seen and (mode not in ["neutral","takeover"] or r.winner=="attacker"),"没有正确占领或看见己方战场")
			_check(mint.is_empty() or saw_mint,"双席画面未确认实装涂装")
			quit(1 if failed else 0)
			return
		if connected and str(net.message).contains("连接中断") and Time.get_ticks_msec()-last_send>1700:
			scene.get_node("%Reconnect").pressed.emit()
			last_send=Time.get_ticks_msec()
			continue
		if net.state.is_empty():
			if connected and Time.get_ticks_msec()-last_send>1700:
				scene.get_node("%Reconnect").pressed.emit()
				last_send=Time.get_ticks_msec()
			continue
		if not connected:
			var screen:=root.get_visible_rect()
			for key in ["All","Core","Repair","Retreat","Reconnect"]:
				_check(screen.encloses(scene.get_node("%"+key).get_global_rect()),"战斗操作必须完全处于屏内 "+key)
		connected=true
		var s: Dictionary=net.state
		if not mint.is_empty() and not saw_mint and scene.views.has("0:"+mint):
			var painted:Node=scene.views["0:"+mint]
			saw_mint=s.units["0:"+mint].paint=="mint" and painted.robot.paint=="mint"
			if saw_mint:print("CAMP_PAINT_PASS ",mode," saw purchased mint attacker ",mint)
		if mode=="takeover":
			_check(not s.units.values().any(func(u):return int(u.side)==1),"已归属且未驻防的营地不能刷新中立机体")
		if not checked_role and OS.get_environment("CAMP_EXPECT_ROLE")=="support":
			scene.get_node("%RoleSelect/Front").pressed.emit()
			_check(scene.selected.is_empty(),"攻守席不应误选空前排组")
			scene.get_node("%RoleSelect/Support").pressed.emit()
			_check(not scene.selected.is_empty() and scene.selected.all(func(i):return s.units[i].owned and s.units[i].role=="support" and s.units[i].hp>0),"职责选择与本方快照不符")
			print("CAMP_ORDERS_ROLE_PASS ",mode," role=support own=",scene.selected)
			checked_role=true
		seen=true
		if mode=="offline" and s.elapsed>2:
			print("CAMP_UI_EXIT_ACTIVE")
			quit(0)
			return
		if not s.outcome.is_empty():
			continue
		if mode=="attacker" and s.elapsed>11:
			scene.get_node("%Retreat").pressed.emit()
			continue
		if mode=="defender":
			if not moved:
				scene.get_node("%Focus").pressed.emit()
				moved=true
		else:
			if not moved:
				scene.get_node("%Core").pressed.emit()
				moved=true
			if mode=="neutral" and s.elapsed>2 and not reconnect:
				reconnect=true
				net.disconnect_mission()
				await create_timer(0.65).timeout
				scene.get_node("%Reconnect").pressed.emit()
				moved=false
				continue
			if s.elapsed>3 and not repairs:
				scene.get_node("%Repair").pressed.emit()
				repairs=true
			if mode=="neutral":
				for id in s.units:
					if s.units[id].side==0 and s.units[id].pos.length()<2.4:
						scene.get_node("%Focus").pressed.emit()
			if mode=="absent" and s.elapsed>9:
				scene.get_node("%Retreat").pressed.emit()
		if s.elapsed>3 and not OS.get_environment("CAMP_CAPTURE").is_empty() and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("CAMP_CAPTURE"))
			OS.unset_environment("CAMP_CAPTURE")
	push_error("营地测试超时 · "+str(scene.get_node("%Feedback").text)+" · "+str(net.message)+" · "+str(net.state.get("elapsed",0)))
	quit(1)

