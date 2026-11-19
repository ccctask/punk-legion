extends "res://owned/tests/field_repair_ui.gd"

func _mark(event:String) -> void:
	print("FIRST_COOP ",role," ",event," ",(Time.get_ticks_msec()-clock)/1000.0)

func _run() -> void:
	_setup_capture()
	await _login(true)
	veteran=robot
	await _base()
	await _go("Go")
	panel.get_node("%RobotName").text="薄荷铆钉" if role=="leader" else "牛奶汽锤"
	await _press("Rename")
	_mark("named")
	if role=="leader":
		var inv:Node=panel.get_node("%Inventory")
		await _click_button(inv,"%LoadStock",panel)
		await _click_button(inv,"%RepairPart",panel)
		for item:Dictionary in inv.stock.parts:
			if item.definition=="repair_arm":module_id=item.id
		support=veteran
		await _open_shop()
		await _fit(module_id)
		await _snap("first-fit")
		await _leave_shop()
		_mark("fitted")
	await _base()
	await _go("Party")
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	await _lobby()
	_mark("lobby_ready")
	var award:=await _play()
	if award.get("outcome")!="win" or award.get("nodes",[]).is_empty():_fail("首场合作未产出带回物资");return
	_mark("credited")
	print("FIRST_COOP_AWARD ",role," ",veteran," ",JSON.stringify(award))
	if role=="leader":await _snap("first-receipt")
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	var guide:Node=base.get_node("%Guide")
	var until:=Time.get_ticks_msec()+12000
	while not guide.get_node("Content/Daily").text.contains(str(award.id).left(8)) and Time.get_ticks_msec()<until:
		guide.refresh()
		await create_timer(.2).timeout
	var message:String=guide.get_node("Content/Daily").text
	if not message.contains("可收工") or not message.contains(str(award.id).left(8)):_fail("日常与实收回执不符 "+message);return
	_mark("may_finish")
	if role=="leader":
		await _snap("first-daily",guide.get_node("Content/Daily"))
		await _go("Recovery")
		await _wait(panel)
		var service:Node=panel.get_node("%Recovery")
		var end:=Time.get_ticks_msec()+5000
		while not service.get_node("Details").visible and Time.get_ticks_msec()<end:await create_timer(.1).timeout
		if service.data.get("state")!="damaged":_fail("日常后未引至实战战损机");return
		await _click_button(service,"Details/Actions/Repair",panel)
		await _snap("optional-repair",service.get_node("Details/Summary"))
		end=Time.get_ticks_msec()+42000
		while service.data.get("state")!="ready" and Time.get_ticks_msec()<end:await create_timer(.25).timeout
		if service.data.get("state")!="ready":_fail("工坊未修完");return
		_mark("repair_done")
		await _base()
		await _snap("return-base",base.get_node("%Guide/Content/Daily"))
		_mark("home")
	print("FIRST_COOP_PASS ",role," ",award.id," ",message)
	quit(0)

