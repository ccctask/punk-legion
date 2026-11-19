extends "res://profile/tests/profile_ui.gd"

func _await_http(node: Node) -> void:
	var deadline := Time.get_ticks_msec()+9000
	while node.busy and Time.get_ticks_msec()<deadline:
		await process_frame
	_check(not node.busy,"地图请求超时")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text=account
	panel.get_node("%Password").text=password
	await _press("Register")
	if failed:
		quit(1)
		return
	panel.get_node("%Base").pressed.emit()
	var base := panel.get_node("PrivateBase")
	await _await_http(base)
	base.get_node("%WorldMap").pressed.emit()
	var world := panel.get_node("WorldMap")
	await _await_http(world)
	if world.world.is_empty():
		push_error("地图没有加载")
		quit(1)
		return
	world.pending_route="/v1/world"
	world._response(HTTPRequest.RESULT_TIMEOUT,0,PackedStringArray(),PackedByteArray())
	_check(world.get_node("%Feedback").text.contains("无法同步"),"断线反馈")
	world.refresh()
	await _await_http(world)
	_check(world.get_node("%Feedback").text.is_empty(),"同步恢复应清除过期错误")
	var mode := OS.get_environment("WORLD_TEST_MODE")
	world.pins["ice-dock"].pressed.emit()
	_check(not world.get_node("%Action").visible and not world.get_node("%Contest").visible,"预览节点不显示参战操作")
	_check(world.get_node("%Window").text.contains("开放") and world.get_node("%Kind").text.contains("预览"),"未开放玩法的场地保留日程说明")
	world._act()
	_check(not world.busy,"预览场地不应发出资格请求")
	var id := "rustrail" if mode=="party" else "brass-yard"
	world.pins[id].pressed.emit()
	_check(world.get_node("%Action").visible and not world.get_node("%Action").disabled,"节点没有可用入口")
	var anchor: int=world._server_now()
	_check(absf(float(anchor)-Time.get_unix_time_from_system())>86400,"客户端日期明显不同的服务端夹具")
	var original_time: int=world.world.server_time
	var original_anchor: int=world.anchor_ms
	for shift: int in [-86400, 86400]:
		var remote := int(Time.get_unix_time_from_system())+shift
		world.world.server_time=remote
		world.anchor_ms=Time.get_ticks_msec()-2500
		_check(world._server_now()==remote+2,"本地日期偏差一天仍应使用服务端时间")
	world.world.server_time=original_time
	world.anchor_ms=original_anchor
	var capture:=OS.get_environment("WORLD_CAPTURE")
	if mode=="camp":
		_check(world.get_node("%Info").text.contains("可能被其他玩家夺取"),"公共营地风险")
		world.get_node("%Action").pressed.emit()
		await _await_http(world)
		_check(world.get_node("%Feedback").text.contains("登记资格"),"服务端资格回执")
		world._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		await _await_http(world)
		_check(world.get_node("%Action").text.contains("已登记"),"恢复前台后重取服务器")
	if not capture.is_empty() and DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(capture)==OK,"截图失败")
	if mode=="party":
		world.get_node("%Action").pressed.emit()
		await process_frame
		var party := panel.get_node("Expedition")
		await _await_http(party)
		_check(party.party_mode and party.get_node("%PartyPanel").visible,"未进入真正组队大厅")
		party.get_node("%Back").pressed.emit()
		await process_frame
		_check(world.visible,"退出组队大厅应回世界地图")
	if not failed:
		print("WORLD_UI_PASS ",mode)
	quit(1 if failed else 0)
