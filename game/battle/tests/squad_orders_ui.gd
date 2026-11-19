extends "res://owned/tests/field_repair_ui.gd"

func _choose(button:OptionButton,value:Variant) -> void:
	for i in button.item_count:
		if button.get_item_metadata(i)==value:
			button.select(i)
			button.item_selected.emit(i)
			return
	_fail("未找到策略选项 "+str(value))

func _touch(button:Button) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.position=button.get_global_rect().get_center()
	event.pressed=true
	Input.parse_input_event(event)
	await create_timer(.2).timeout
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await create_timer(.35).timeout

func _controls() -> void:
	var until:=Time.get_ticks_msec()+18000
	while exp_screen.net.state.get("units",{}).is_empty() and Time.get_ticks_msec()<until:await create_timer(.15).timeout
	var state:Dictionary=exp_screen.net.state
	if state.is_empty():_fail("未收到权威战斗");return
	await _touch(exp_screen.get_node("%RoleSelect/Support"))
	if exp_screen.selected!=["0:"+veteran]:_fail(role+"支援分组不等于自己 "+str(exp_screen.selected));return
	await _snap(role+"-group")
	await _touch(exp_screen.get_node("%RoleSelect/Front"))
	if not exp_screen.selected.is_empty():_fail("空前排组越权或自动改成全队");return
	await _touch(exp_screen.get_node("%All"))
	if exp_screen.selected.size()!=(2 if role=="solo" else 1):_fail("全选跨席位");return
	if state.units["0:"+veteran].role!="support":_fail("房间职责丢失");return
	exp_screen.get_node("%Route").pressed.emit()
	await create_timer(1).timeout
	if role!="solo":
		exp_screen.net.disconnect_mission()
		await create_timer(.5).timeout
		exp_screen.get_node("%Reconnect").pressed.emit()
		until=Time.get_ticks_msec()+15000
		while (exp_screen.net.state.is_empty() or exp_screen.net.peer==null or exp_screen.net.peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED) and Time.get_ticks_msec()<until:await create_timer(.1).timeout
		await _touch(exp_screen.get_node("%RoleSelect/Support"))
		if exp_screen.selected!=["0:"+veteran]:_fail("重连后职责或归属失效");return

func _run() -> void:
	_setup_capture()
	await _login(true)
	veteran=robot
	await _open_shop()
	var partner:=""
	if role=="solo":
		shop.get_node("%Name").text="后备通用"
		await _click_button(shop,"%Save",shop)
		partner=await _make("油漆工")
	_select(shop,"%Mode",1)
	_pick_robot(veteran)
	var editor:Node=shop.get_node("%Orders")
	await _click_button(editor,"Toggle",shop)
	_choose(editor.get_node("Body/Role"),"support")
	_choose(editor.get_node("Body/Distance"),"standoff")
	_choose(editor.get_node("Body/Priority"),"weakest")
	_choose(editor.get_node("Body/Retreat"),25)
	if partner!="":_choose(editor.get_node("Body/Guard"),partner)
	await _click_button(editor,"Body/Save",shop)
	if shop.data.robots[shop.get_node("%Robot").selected].orders.role!="support":_fail("职责未保存");return
	await _snap(role+"-settings",editor.get_node("Body/Save"))
	await _leave_shop()
	await _base()
	await _go("Solo" if role=="solo" else "Party")
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	if role=="solo":
		for button in exp_screen.get_node("%Squad").get_children():button.button_pressed=true
		await _click_button(exp_screen,"%Start",exp_screen)
	else:await _lobby()
	await _controls()
	print("SQUAD_ORDERS_LIVE_PASS ",role," ",veteran," guard ",partner)
	exp_screen.get_node("%Retreat").pressed.emit()
	await create_timer(1).timeout
	quit(0)
