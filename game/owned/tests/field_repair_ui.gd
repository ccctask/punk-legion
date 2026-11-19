extends "res://campaign/tests/campaign_base.gd"

var role:=OS.get_environment("REPAIR_ROLE")
var support:=""
var veteran:=""
var module_id:=""
var proof_shot:=false

func _pick_robot(id:String) -> void:
	for i in shop.data.robots.size():
		if shop.data.robots[i].id==id:
			_select(shop,"%Robot",i)
			return
	_fail("机体丢失")

func _fit(item:String) -> void:
	_select(shop,"%Mode",1)
	_pick_robot(support)
	_select(shop,"%Slot",3)
	var options:OptionButton=shop.get_node("%Item")
	for i in options.item_count:
		if options.get_item_metadata(i)==item:
			options.select(i)
			await _click_button(shop,"%Install",shop)
			var chosen:Dictionary=shop.data.robots[shop.get_node("%Robot").selected]
			if chosen.slots.get("utility",{}).get("id","")!=item:_fail("功能槽实物不符")
			return
	_fail("未找到可安装/拆卸的实物 "+item)

func _lobby() -> void:
	var lobby:Node=exp_screen.get_node("%PartyPanel")
	var path:=OS.get_environment("REPAIR_INVITE")
	if role=="leader":
		await _click_button(lobby,"%Create",exp_screen)
		var f:=FileAccess.open(path,FileAccess.WRITE)
		f.store_string(lobby.data.roomscope.code)
		f.close()
	else:
		var end:=Time.get_ticks_msec()+40000
		while not FileAccess.file_exists(path) and Time.get_ticks_msec()<end:await create_timer(.2).timeout
		var c:=FileAccess.get_file_as_string(path)
		lobby.get_node("%Code").text=c
		await _click_button(lobby,"%Join",exp_screen)
	await _click_button(lobby,"%Ready",exp_screen)
	if role=="leader":
		var end:=Time.get_ticks_msec()+40000
		while lobby.get_node("%Launch").disabled and Time.get_ticks_msec()<end:await create_timer(.25).timeout
		await _click_button(lobby,"%Launch",exp_screen)

func _run() -> void:
	_setup_capture()
	await _login(true)
	veteran=robot
	panel.get_node("%RobotName").text="蜂蜜维修车" if role=="guest" else "铜铃领航"
	await _press("Rename")
	if role!="leader":
		var inv:Node=panel.get_node("%Inventory")
		await _click_button(inv,"%LoadStock",panel)
		await _click_button(inv,"%RepairPart",panel)
		for item:Dictionary in inv.stock.parts:
			if item.definition=="repair_arm":module_id=item.id
		if module_id.is_empty():_fail("未制造维修臂");return
		await _open_shop()
		support=veteran
		if role=="solo":
			shop.get_node("%Name").text="工程标准型"
			await _click_button(shop,"%Save",shop)
			support=await _make("蜂蜜维修车")
		await _fit(module_id)
		await _fit("")
		await _fit(module_id)
		await _snap(role+"-workshop")
		await _leave_shop()
	await _base()
	await _go("Solo" if role=="solo" else "Party")
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	if role=="solo":
		for c in exp_screen.get_node("%Squad").get_children():c.button_pressed=true
		await _click_button(exp_screen,"%Start",exp_screen)
	else:
		await _lobby()
	var receipt:=await _play()
	if receipt.get("outcome")!="win":_fail(role+"未胜利 "+str(receipt));return
	if role!="leader" and not proof_shot:_fail(role+"实战未观察到维修");return
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	await _return_to_profile()
	var history:Node=panel.get_node("%History")
	for i in panel.robots.size():
		var id:String=panel.robots[i].id
		_select(panel,"%Robots",i)
		await _click_button(history,"Open",panel)
		await _snap(role+"-"+id,history.get_node("Summary"))
		_note("SERVICE "+id+" "+history.get_node("Summary").text.replace("\n"," / "))
	_note("MODULE_REPAIR_UI_PASS "+role+" "+veteran+" "+support+" "+module_id+" "+receipt.id)
	quit(0)

func _play() -> Dictionary:
	var end:=Time.get_ticks_msec()+310000
	var stage:=-1
	while Time.get_ticks_msec()<end:
		await create_timer(.15).timeout
		if not exp_screen.net.receipt.is_empty():break
		var state:Dictionary=exp_screen.net.state
		if state.is_empty() or not str(state.outcome).is_empty():continue
		if stage!=state.stage:
			stage=state.stage
			exp_screen.get_node("%Route").pressed.emit()
		for id in exp_screen.selected:
			var unit:Dictionary=state.units[id]
			if not proof_shot and float(unit.get("service",-10))>=0:
				proof_shot=true
				await _snap(role+"-live")
			if stage in [0,2,4] and unit.pos.distance_to(exp_screen.Mission.LOCATIONS[exp_screen.goal])<3.2:
				exp_screen.get_node("%Collect").pressed.emit()
				break
	return exp_screen.net.receipt.duplicate(true)
