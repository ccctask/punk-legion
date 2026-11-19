extends "res://expedition/expedition.gd"

var mode := "solo"
var unlocked := false

func _ready() -> void:
	start_in_party=true
	super()
	$HUD/Lobby/Scroll/Body/Title.text="封闭工厂 · 检修车护送"
	%Rules.text="靠近检修车伴行，清除轨道附近的拦截机。经过中段检查点，护送到厂门即胜利。限时 5 分钟。"
	%PartyMode.hide()
	%LobbyStatus.text=""
	%FactoryMode.add_item("单人护送")
	%FactoryMode.add_item("与一位好友同行")
	%FactoryMode.item_selected.connect(func(index:int):
		mode="solo" if index==0 else "coop"
		_show_mode())
	_show_mode()

func _api_path(path:String) -> String:
	return path.replace("/v1/party","/v1/factory")

func _request(path:String,data:Dictionary) -> void:
	if path=="/v1/party/create":
		data={"mode":mode}
	if not endpoint.is_empty():
		super(path,data)

func _show_mode() -> void:
	var panel:Node=%PartyPanel
	panel.pump_mode=mode
	panel.get_node("%Match").hide()
	panel.get_node("%Code").visible=mode=="coop"
	panel.get_node("%Join").visible=mode=="coop"
	panel.get_node("%Create").text="准备单人护送" if mode=="solo" else "建立好友护送队"
	panel.get_node("%Create").disabled=not unlocked
	panel.get_node("%Join").disabled=not unlocked
	panel.get_node("%Room").text="独行最多 12 台 / 24 点" if mode=="solo" else "邀请已开放东地的好友 · 每人最多 6 台 / 12 点"

func _party_details(data:Dictionary) -> void:
	var event:Dictionary=data.event
	var scope:Dictionary=data.roomscope
	unlocked=event.unlocked
	%FactoryMode.visible=scope.is_empty()
	if scope.is_empty():
		_show_mode()
	else:
		mode=scope.mode
		%FactoryMode.select(0 if mode=="solo" else 1)
		%PartyPanel.pump_mode=mode
		var panel:Node=%PartyPanel
		if mode=="coop":
			panel.get_node("%Room").text="邀请码 %s · %d/2 人" % [scope.code,scope.members.size()]
		panel.get_node("%Launch").text="开始护送" if mode=="solo" else "全队出发"
	var land:="南地已开放 · 30 格" if event.south_unlocked else "个人首胜开放南地两行 · 30 格"
	var daily:="今日结构材料已领" if int(event.reward_available)==0 else "今日成功可获 1 结构材料（受仓容限制）"
	var cost:String={"energy":"1 能源","voucher":"1 救援凭证","unavailable":"出发物资不足"}[data.departure_quote.source]
	%Pity.text="%s · %s\n%s" % [land,daily,cost+" / 人"]
	if not unlocked:
		%Pity.text="本人通关锈轨、开放东地后可护送。"

func _objectives(state:Dictionary) -> void:
	var f:Dictionary=state.factory
	$Field.apply_state(f)
	goal="cart"
	%Route.text="前往检修车"
	%Alt.show()
	%Alt.text="前往厂门" if f.checkpoint else "前往检查点"
	%Collect.hide()
	%Repair.text="维修 ×%d" % int(state.repairs)
	%Repair.disabled=state.repairs==0
	var reason:String={"waiting_escort":"缺少伴行 · 请靠近车旁","blocked":"轨道受阻 · 清除附近敌机","moving":"护送中","arrived":"已抵达厂门"}.get(f.reason,"")
	var goal_text:="检修车 %d%% · %s · %s" % [roundi(f.progress*100),("已过检查点" if f.checkpoint else "前往检查点"),reason]
	if state.get("withdrawn",false):
		goal_text="本人已离场 · 等待队友完成护送"
	if not str(state.outcome).is_empty():
		goal_text="本场结束 · 正在核对个人收据"
	if %Goal.text!=goal_text: %Goal.text=goal_text
	var hint:=_suggestion_hint(state)
	if hint.is_empty():hint=net.message if not net.message.is_empty() else "车旁留机伴行，其他机体可前出清障"
	var rejection: String = net.movement_feedback()
	if not rejection.is_empty():
		hint = rejection
	if state.get("withdrawn",false) or not str(state.outcome).is_empty():
		hint = "本人已离场 · 等待个人结算"
	if %Hint.text!=hint:%Hint.text=hint

func _swap_goal() -> void:
	_send("route","gate" if net.state.factory.checkpoint else "checkpoint")

func _summary(r:Dictionary) -> String:
	var outcome:String={"win":"检修车已抵达厂门","retreat":"主动撤退","defeat":"护送失利","expired":"任务到期"}.get(r.outcome,r.outcome)
	return "封闭工厂 · %s · %d 秒" % [outcome,int(r.seconds)]

func _reward_summary(r:Dictionary) -> String:
	if r.get("outcome","")!="win":return ""
	var land:="首通 · 南地两行已开放，可接路建厂。\n" if r.get("first_clear",false) else ""
	return land+"结构材料实际入库 %d" % int(r.changes.get("structure",0))
