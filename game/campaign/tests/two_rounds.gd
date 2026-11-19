extends "res://campaign/tests/campaign_base.gd"

func _select_actual() -> void:
	for i in panel.robots.size():
		if panel.robots[i].id==robot:
			_select(panel,"%Robots",i)
			return
	_fail("档案实体失踪 "+robot)

func _explore() -> void:
	await _base()
	await _click_button(base,"%Explore",base)
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	var rows:=0
	for button in exp_screen.get_node("%Squad").get_children():
		button.button_pressed=button.get_meta("robot","")==robot
		rows+=int(button.button_pressed)
	if rows!=1:
		_fail("没有可派遣的同一机体 "+robot);return
	await _mission()
	var result:Dictionary=exp_screen.net.receipt
	_note("CAMPAIGN_ROUND "+str(round_count+1)+" robot "+robot+" "+JSON.stringify(result))
	await _snap("round"+str(round_count+1))
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	await _return_to_profile()
	_select_actual()

func _history(index:int) -> void:
	var history:Node=panel.get_node("%History")
	await _click_button(history,"Open",panel)
	if int(history.totals.battles)!=index:
		_fail("累计参战次数不符");return
	await _snap("m10-career-"+str(index),history.get_node("Summary"))

func _run() -> void:
	_setup_capture()
	await _login(false)
	await _base()
	await _click_button(base,"%EconomyToggle",base)
	var econ:Node=base.get_node("%Economy")
	var timeout:=Time.get_ticks_msec()+370000
	while econ.state.lines.structure.pending<1 and Time.get_ticks_msec()<timeout:
		await create_timer(2).timeout
		await _click_button(econ,"%Refresh",base)
	var before:Dictionary=econ.state.lines.structure.duplicate()
	if before.pending<1 or before.stock!=2:
		_fail("实际产出或起始仓不符 "+str(before));return
	await _snap("production-before")
	await _click_button(econ,"%Claim",base)
	var after:Dictionary=econ.state.lines.structure
	if after.stock!=before.stock+before.pending:
		_fail("收取产出后的库存不符");return
	_note("CLAIMED "+str(before.stock)+" + "+str(before.pending)+" = "+str(after.stock))
	await _snap("production-after")
	await _return_to_profile()
	await _open_shop()
	robot=await _make("炉火远征一号")
	await _snap("m09-build")
	_note("MANUFACTURED "+robot)
	await _leave_shop()
	await _explore()
	await _history(1)
	var recovery:Node=panel.get_node("%Recovery")
	await _click_button(recovery,"Open",panel)
	if recovery.data.state!="damaged":
		_fail("首场未留下可核对的战损");return
	await _click_button(recovery,"Details/Actions/Repair",panel)
	await _snap("m13-repair",recovery.get_node("Details/Summary"))
	var due:=Time.get_ticks_msec()+45000
	while recovery.data.state!="ready" and Time.get_ticks_msec()<due:
		await create_timer(.3).timeout
	if recovery.data.state!="ready":
		_fail("实际工坊维修未完成");return
	_note("WORKSHOP_REPAIRED "+robot+" "+str(recovery.data.recent))
	await _open_shop()
	_select(shop,"%Mode",1)
	for i in shop.data.robots.size():
		if shop.data.robots[i].id==robot:_select(shop,"%Robot",i)
	_select(shop,"%Slot",2)
	var drill:=""
	for item:Dictionary in shop.data.available:
		if item.definition=="drill":drill=item.id
	var options:OptionButton=shop.get_node("%Item")
	for i in options.item_count:
		if options.get_item_metadata(i)==drill:options.select(i)
	if drill.is_empty() or options.get_selected_metadata()!=drill:
		_fail("回收场带回的钻头不能实装");return
	await _click_button(shop,"%Install",shop)
	if shop.data.robots[shop.get_node("%Robot").selected].slots.weapon.id!=drill:
		_fail("实物换装失败");return
	await _snap("m09-refit")
	_note("REFITTED "+robot+" drill "+drill)
	await _leave_shop()
	var saved:=robot
	await _login(false)
	robot=saved
	_select_actual()
	round_count=1
	await _explore()
	await _history(2)
	_note("PRIVATE_CAMPAIGN_PASS "+robot)
	quit(0)
