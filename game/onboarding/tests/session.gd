extends "res://profile/tests/profile_ui.gd"

var clock := 0
var frame_number := -1
var robot := ""
var base:Node
var exp_screen:Node
var folder := ""
var round_count := 0

func _note(message:String) -> void:
	print("M17 ",(Time.get_ticks_msec()-clock)/1000.0,"s ",message)

func _record() -> void:
	var n:=floori((Time.get_ticks_msec()-clock)/500.0)
	if n<=frame_number:
		return
	var image:=root.get_texture().get_image()
	while frame_number<n:
		frame_number+=1
		image.save_jpg(folder.path_join("%06d.jpg" % frame_number),0.75)

func _wait(node:Node) -> void:
	var end:=Time.get_ticks_msec()+10000
	while node.busy and Time.get_ticks_msec()<end:
		await process_frame
	if node.busy:
		_fail("等待界面 "+str(node.name))

func _fail(message:String) -> void:
	push_error(message)
	quit(1)

func _login(register:bool) -> void:
	await _panel()
	panel.get_node("%Account").text=account
	panel.get_node("%Password").text=password
	await _press("Register" if register else "Login")
	robot=panel.robots[0].id

func _base() -> void:
	panel.get_node("%Base").pressed.emit()
	base=panel.get_node("PrivateBase")
	await _wait(base)
	var until:=Time.get_ticks_msec()+10000
	while not base.get_node("%Guide").loaded and Time.get_ticks_msec()<until:
		await process_frame
	if not base.get_node("%Guide").loaded:
		_fail("首玩入口未能读取")
	_note("基地下一步 "+str(base.get_node("%Guide").current))

func _return_to_profile() -> void:
	base.get_node("%Back").pressed.emit()
	await process_frame
	await _press("Refresh")

func _go(path:String) -> void:
	base.get_node("%Guide").get_node("Content/"+path).pressed.emit()
	await process_frame

func _mission() -> void:
	await _wait(exp_screen)
	exp_screen.get_node("%Start").pressed.emit()
	var start:=Time.get_ticks_msec()
	var stage:=-1
	while Time.get_ticks_msec()-start<330000:
		await create_timer(0.2).timeout
		if not exp_screen.net.receipt.is_empty():
			var result:Dictionary=exp_screen.net.receipt
			_note("回收结算 "+str(result.outcome)+" 战斗 "+str(result.seconds)+" 秒，回执 "+str(result.id))
			if result.outcome!="win":
				_fail("回收未胜利")
			return
		if exp_screen.net.state.is_empty():
			continue
		var field:Dictionary=exp_screen.net.state
		if not str(field.outcome).is_empty():
			continue
		var id:="0:"+robot
		if not field.units.has(id):
			_fail("实战机体不符")
			return
		if field.units[id].hp<field.units[id].max_hp*0.68 and field.repairs>0:
			exp_screen.get_node("%Repair").pressed.emit()
		if stage!=field.stage:
			stage=field.stage
			exp_screen.get_node("%Alt" if stage==0 and round_count%2==1 else "%Route").pressed.emit()
		if stage in [0,2,4] and field.units[id].pos.distance_to(exp_screen.Mission.LOCATIONS[exp_screen.goal])<3.2:
			exp_screen.get_node("%Collect").pressed.emit()
	_fail("实际指挥流程超时："+str(exp_screen.get_node("%LobbyStatus").text))

func _run() -> void:
	clock=Time.get_ticks_msec()
	folder=OS.get_environment("M17_FRAMES")
	if not folder.is_empty():
		RenderingServer.frame_post_draw.connect(_record)
	account="guide_"+Crypto.new().generate_random_bytes(6).hex_encode()
	await _login(true)
	await _base()
	await _go("Go")
	panel.get_node("%RobotName").text="蜂蜜汽笛"
	await _press("Rename")
	await _base()
	await _go("Party")
	exp_screen=panel.get_node("Expedition")
	await _wait(exp_screen)
	exp_screen.get_node("%PartyPanel").get_node("%Create").pressed.emit()
	await _wait(exp_screen)
	exp_screen.get_node("%PartyMode").pressed.emit()
	await _wait(exp_screen)
	if exp_screen.party_mode:
		_fail("等待好友时未能切回独行")
		return
	_note("已从邀请队友切换独行")
	# The basic objective ends at the first successful extraction. The second run
	# tries the other resource branch with the newly fitted drill.
	while round_count<2:
		await _mission()
		round_count+=1
		exp_screen.get_node("%Leave").pressed.emit()
		await process_frame
		await _wait(base)
		await _return_to_profile()
		if round_count==1:
			# Return to startup as the previous view and token are discarded.
			await _login(false)
			await _base()
			await _go("Go")
			await _go("Go")
			var shop:=panel.get_node("Workshop")
			await _wait(shop)
			var pick:OptionButton=shop.get_node("%Item")
			if pick.item_count<2:
				_fail("首胜部件不可实装")
				return
			pick.select(1)
			shop.get_node("%Install").pressed.emit()
			await _wait(shop)
			shop.get_node("%Back").pressed.emit()
			await process_frame
			await _wait(panel)
			_note("结算后重登、首胜钻头实装后重登")
			await _login(false)
		await _base()
		var g:=base.get_node("%Guide")
		if not str(g.get_node("Content/Daily").text).contains("1/1"):
			_fail("日常收据未显示完成")
			return
		if round_count==1:
			_note("基地已显示今日 1/1，可收工")
		if not str(g.damaged).is_empty():
			await _go("Recovery")
			await _wait(panel)
			var recovery:=panel.get_node("%Recovery")
			recovery.get_node("Details/Actions/Repair").pressed.emit()
			await _wait(panel)
			var until:=Time.get_ticks_msec()+40000
			while recovery.data.get("state")!="ready" and Time.get_ticks_msec()<until:
				await create_timer(0.25).timeout
			if recovery.data.get("state")!="ready":
				_fail("维修未恢复")
				return
			_note("真实机体维修完成")
			await _base()
		if round_count==2:
			_note("M17_SESSION_PASS 今日目标已完成，额外试用首胜部件、改走能源支路")
			quit()
			return
		await _go("Solo")
		exp_screen=panel.get_node("Expedition")
	_fail("可选支路未完成")
