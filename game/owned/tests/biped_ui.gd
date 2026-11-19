extends "res://campaign/tests/campaign_base.gd"

func _trip(kind:String) -> void:
	await _base()
	await _go("Solo")
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	await _click_button(exp_screen,"%Start",exp_screen)
	var deadline:=Time.get_ticks_msec()+12000
	var key:="0:"+robot
	while not exp_screen.views.has(key) and Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout
	if not exp_screen.views.has(key):
		_fail("出击未绑定命名机体");return
	var row:Dictionary=exp_screen.net.state.units[key]
	var view:Node=exp_screen.views[key].robot
	if row.chassis!=kind or view.chassis!=kind or row.max_hp!=(58 if kind=="biped" else 70):
		_fail("实际战场底盘、模型或耐久错误");return
	var origin:Vector2=row.pos
	exp_screen.get_node("%Route").pressed.emit()
	deadline=Time.get_ticks_msec()+4500
	while origin.distance_to(exp_screen.net.state.units[key].pos)<1.5 and Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
	var travel:float=origin.distance_to(exp_screen.net.state.units[key].pos)
	if travel<1.5:_fail("未收到真实移动");return
	_note("FIELD chassis=%s id=%s hp=%s moved=%.2f" % [kind,robot,row.max_hp,travel])
	await _snap(kind+"-field")
	exp_screen.get_node("%Retreat").pressed.emit()
	deadline=Time.get_ticks_msec()+12000
	while exp_screen.net.receipt.is_empty() and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
	if exp_screen.net.receipt.get("outcome")!="retreat":_fail("撤回未结算");return
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	await _return_to_profile()

func _run() -> void:
	_setup_capture()
	await _login(true)
	var original:=robot
	panel.get_node("%RobotName").text="糖罐巡游"
	await _press("Rename")
	await _trip("crawler")
	await _open_shop()
	_select(shop,"%Mode",1)
	_select(shop,"%HullTarget",1)
	await _snap("conversion",shop.get_node("%ApplyHull"))
	var slots:Dictionary=shop.data.robots[0].slots.duplicate(true)
	await _click_button(shop,"%ApplyHull",shop)
	var unit:Dictionary=shop.data.robots[0]
	if unit.chassis!="biped" or unit.id!=original or unit.slots!=slots or unit.name!="糖罐巡游":
		_fail("改装后 ID、装配、名字或底盘不符");return
	_select(shop,"%Mode",0)
	_select(shop,"%DraftHull",1)
	shop.get_node("%Name").text="巡检双足型"
	await _click_button(shop,"%Save",shop)
	var made:=await _make("新造双足")
	if made==original or shop.data.robots[1].chassis!="biped":_fail("新制造底盘不符");return
	await _leave_shop()
	await _login(false)
	if robot!=original:_fail("重登身份变更");return
	await _trip("biped")
	var history:Node=panel.get_node("%History")
	await _click_button(history,"Open",panel)
	if int(history.totals.battles)!=2:_fail("同一机体累计参战次数不符");return
	await _snap("career",history.get_node("Summary"))
	_note("BIPED_LIVE_PASS "+original)
	quit(0)

