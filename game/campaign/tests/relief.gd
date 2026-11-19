extends "res://campaign/tests/campaign_base.gd"

func _retreat() -> void:
	await _base()
	await _click_button(base,"%Explore",base)
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	for candidate in exp_screen.get_node("%Squad").get_children():
		candidate.button_pressed=candidate.get_meta("robot","")==robot
	await _click_button(exp_screen,"%Start",exp_screen)
	var deadline:=Time.get_ticks_msec()+15000
	while exp_screen.net.state.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame
	if exp_screen.net.state.is_empty():_fail("未连接实际探索房间");return
	_note("ENERGY_ENTRY "+str(exp_screen.net.state.id)+" robot "+robot)
	await _click_button(exp_screen,"%Retreat",exp_screen)
	while exp_screen.net.receipt.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame
	if exp_screen.net.receipt.get("outcome")!="retreat":_fail("撤离未收到回执");return
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	await _return_to_profile()

func _run() -> void:
	_setup_capture()
	await _login(true)
	await _open_shop()
	for design_number in 2:
		_select(shop,"%Mode",0)
		_select(shop,"%Head",design_number)
		shop.get_node("%Name").text="救援试验"+str(design_number)
		await _click_button(shop,"%Save",shop)
		for i in 2:await _make("后备"+str(design_number)+"-"+str(i))
	await _leave_shop()
	await _retreat()
	var inv:Node=panel.get_node("%Inventory")
	await _click_button(inv,"%LoadStock",panel)
	for material in ["structure","components","energy"]:
		if inv.stock.stock[material].amount!=0:_fail("尚未枯竭 "+str(inv.stock.stock));return
	await _snap("m13-empty",inv.get_node("%Stock"))
	_note("EMPTY "+str(inv.stock.stock))
	var service:Node=panel.get_node("%Recovery")
	await _click_button(service,"Open",panel)
	await _click_button(service,"Details/Actions/Relief",panel)
	if not service.data.voucher:_fail("救援券未到账");return
	await _snap("m13-relief",service.get_node("Details/Summary"))
	var first:Dictionary=service.data.duplicate(true)
	await _click_button(service,"Details/Actions/Relief",panel)
	if not panel.get_node("%Message").text.contains("救援") and not panel.get_node("%Message").text.contains("relief_cooldown"):
		_fail("第二次救援缺少提示 "+panel.get_node("%Message").text);return
	if service.data.relief_at!=first.relief_at:_fail("重复申请改变额度");return
	_note("RELIEF_RETRY "+panel.get_node("%Message").text)
	await _retreat()
	await _click_button(service,"Open",panel)
	if service.data.voucher:_fail("出击未核销救援凭证");return
	_note("RELIEF_CAMPAIGN_PASS "+robot+" single voucher consumed "+str(service.data.relief_at))
	quit(0)
