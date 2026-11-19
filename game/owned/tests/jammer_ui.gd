extends "res://owned/tests/field_repair_ui.gd"

func _run() -> void:
	_setup_capture()
	await _login(true)
	support=robot
	var inventory:Node=panel.get_node("%Inventory")
	await _click_button(inventory,"%LoadStock",panel)
	await _click_button(inventory,"%Jammer",panel)
	for item:Dictionary in inventory.stock.parts:
		if item.definition=="jammer":module_id=item.id
	if module_id.is_empty():_fail("干扰器制造失败");return
	await _open_shop()
	await _fit(module_id)
	await _snap("jammer-mounted")
	await _leave_shop()
	await _base()
	await _go("Solo")
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	await _click_button(exp_screen,"%Start",exp_screen)
	var sent:=false
	var rejoined:=false
	var until:=-1.0
	var target:=""
	var end:=Time.get_ticks_msec()+95000
	while Time.get_ticks_msec()<end:
		await create_timer(.12).timeout
		if not exp_screen.net.receipt.is_empty():break
		var state:Dictionary=exp_screen.net.state
		if state.is_empty() or not str(state.outcome).is_empty():continue
		if not sent:
			sent=true
			exp_screen.get_node("%Route").pressed.emit()
		for id in state.units:
			var row:Dictionary=state.units[id]
			if until<0 and float(row.get("protected_until",0))>float(state.elapsed):
				until=float(row.protected_until)
				target=id
				await _snap("jammer-pulse")
				exp_screen.net.disconnect_mission()
				await create_timer(.4).timeout
				exp_screen.get_node("%Reconnect").pressed.emit()
				break
		if until>0 and not exp_screen.net.state.is_empty() and not rejoined:
			var data:Dictionary=exp_screen.net.state
			if absf(float(data.units[target].get("protected_until",0))-until)>.001:_fail("重连改变保护截止");return
			rejoined=true
			print("JAMMER_REJOIN ",target," until ",until)
			await _snap("jammer-rejoined")
		if rejoined and state.elapsed>until+.3:exp_screen.get_node("%Retreat").pressed.emit()
	var receipt:Dictionary=exp_screen.net.receipt
	if receipt.is_empty() or not rejoined:_fail("未在真实房间观察到干扰后回收回执");return
	var ident:=str(receipt.id)
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	await _return_to_profile()
	var history:Node=panel.get_node("%History")
	await _click_button(history,"Open",panel)
	if int(history.totals.battles)<1:_fail("机体累计参战未入账");return
	await _snap("jammer-career",history.get_node("Summary"))
	print("JAMMER_UI_PASS ",robot," ",module_id," ",ident)
	quit(0)
