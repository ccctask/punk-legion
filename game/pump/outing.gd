extends "res://expedition/expedition.gd"

const LABELS:={"valve_a":"西阀","valve_b":"东阀","cache":"物资箱","exit":"撤离口"}
var pump_mode:="solo"
var window_id:=""

func _ready() -> void:
	start_in_party=true
	super()
	$HUD/Lobby/Scroll/Body/Title.text="泵站遗迹 · "+("单人行动" if pump_mode=="solo" else "好友合作")
	%Rules.text="清除守卫，到达并校准西阀和东阀。共用物资箱开启后，每人带自己的机体在出口确认撤离。战斗限时 5 分钟。"
	%PartyPanel.pump_mode=pump_mode
	%PartyMode.hide()
	%Leave.text="返回世界地图"
	%Mark.hide()
	%Back.text="返回世界地图"
	%LobbyStatus.text=""
	var panel:Node=%PartyPanel
	panel.get_node("%Create").text="准备单人行动" if pump_mode=="solo" else "建立好友小队"
	panel.get_node("%Code").visible=pump_mode=="coop"
	panel.get_node("%Join").visible=pump_mode=="coop"

func _join() -> void:
	selected.clear()
	selected_role=""
	_selection_changed()
	super()

func _selection_changed() -> void:
	var caption:="已选 %d 台" % selected.size()
	if selected.size()==1:
		var row:Dictionary=net.state.get("units",{}).get(selected[0],{})
		caption+=" · "+str(row.get("name",""))
	if %Identity.text!=caption:
		%Identity.text=caption

func _api_path(path: String) -> String:
	return path.replace("/v1/party","/v1/pump")

func _request(path: String, data: Dictionary) -> void:
	if path=="/v1/party/create":
		data={"event":window_id,"mode":pump_mode}
	if not endpoint.is_empty():
		super(path,data)

func _party_details(data: Dictionary) -> void:
	var event:Dictionary=data.event
	if not data.roomscope.is_empty():
		$HUD/Lobby/Scroll/Body/Title.text="泵站遗迹 · "+("单人行动" if data.roomscope.mode=="solo" else "好友合作")
	var price: String={"energy":"1 能源","voucher":"1 救援凭证","unavailable":"缺少出发物资"}[data.departure_quote.source]
	%Pity.text="出发每人 %s · 今日首胜额度 %d 通用零件，预计入库 %d。" % [price,event.reward_available,event.expected_components]
	if event.reward_available==0:
		%Pity.text+=" 今日已领，仍可协助好友。"
	var arm:Dictionary=event.get("recovered_arm",{})
	match arm.get("status",""):
		"unearned": %Pity.text+="\n个人首次成功撤离可回收维修臂 · 每人一件，可装在带 AUX 接口的底盘上。"
		"pending": %Pity.text+="\n首通维修臂待领 · 腾出一个背包格后到基地机库领取。"
		"delivered": %Pity.text+="\n已回收首通维修臂 #%s" % str(arm.part_id).left(8)
	var can_start:bool=event.active and event.id==window_id
	var panel:Node=%PartyPanel
	panel.get_node("%Launch").text="开始行动" if data.roomscope.get("mode","")=="solo" else "全队出发"
	panel.get_node("%Create").disabled=not can_start
	panel.get_node("%Join").disabled=not can_start
	if data.roomscope.is_empty():
		panel.get_node("%Room").text="选择机体准备独行" if pump_mode=="solo" else "建立小队或输入好友的邀请码"
	else:
		panel.get_node("%Launch").disabled=panel.get_node("%Launch").disabled or not event.active or data.roomscope.event!=event.id
	if not can_start:
		%Pity.text+=" 本轮已关闭，已出发的场次仍可重连。"

func _swap_goal() -> void:
	for choice: String in net.state.get("goals",[]):
		if choice!=goal:
			goal=choice
			_send("route",goal)
			break

func _objectives(state: Dictionary) -> void:
	$Field.update_progress(state)
	var left:=maxi(0,ceili(300.0-float(state.elapsed)))
	var dest:=str(LABELS.get(goal,"撤离口"))
	var objective:="泵站 %d:%02d · 已校准 %d/2 · %s" % [left/60,left%60,state.calibrated.size(),dest]
	%Route.text="前往"+dest
	%Alt.visible=state.goals.size()>1
	%Alt.text="改去"+("东阀" if goal=="valve_a" else "西阀")
	%Collect.text=["校准"+dest,"开物资箱","确认撤离"][clampi(int(state.stage),0,2)]
	%Repair.text="维修 ×%d" % int(state.repairs)
	%Repair.disabled=state.repairs==0
	%Collect.disabled=not state.outcome.is_empty()
	var message: String=net.message
	var hint:=message if not message.is_empty() else "选中自有机体，接近目标四米内操作 · A 西阀 / B 东阀 / C 箱 / E 出口"
	if message.is_empty() and goal in state.guards:
		var count:=0
		for guard:String in state.guards[goal]:
			if state.units[guard].hp>0:count+=1
		hint="%s · 剩余 %d 名守卫；清除后靠近四米内校准。" % [dest,count] if count else dest+"守卫已清除 · 靠近四米内可校准"
	var suggestion:=_suggestion_hint(state)
	if not suggestion.is_empty():
		hint=suggestion
	var rejection: String = net.movement_feedback()
	if not rejection.is_empty():
		hint = rejection
	if state.get("withdrawn",false) or not str(state.outcome).is_empty():
		hint = "本人已离场 · 等待个人结算"
	if %Hint.text!=hint:
		%Hint.text=hint
	if state.get("withdrawn",false):
		for seat: Dictionary in state.presence:
			if seat.owner==active.owner:
				objective={"win":"本人已成功撤离","retreat":"本人主动撤退","expired":"本人已超时","defeat":"本人已战败"}.get(seat.reason,"本人已离场")+" · 等待队友结算"
	if not str(state.outcome).is_empty():
		objective="本场结束 · 正在核对个人收据"
	if %Goal.text!=objective:
		%Goal.text=objective

func _summary(r: Dictionary) -> String:
	var result: String={"win":"成功撤离","retreat":"主动撤退","defeat":"战败","expired":"过期"}.get(r.outcome,str(r.outcome))
	return "泵站 · 本人%s · %d 秒 · 通用零件入库 %d" % [result,int(r.seconds),int(r.get("changes",{}).get("components",0))]
