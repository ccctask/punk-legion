extends Node3D

signal closed
const Endpoints:=preload("res://client/endpoints.gd")
const Sim:=preload("res://battle/simulation.gd")
const Unit:=preload("res://battle/unit.tscn")
const Turret:=preload("res://assets/base_art/turret.tscn")
const Mount:=preload("res://camp/turret_mount.gd")
const RESOURCE_NAMES:={"structure":"结构材料","components":"通用零件"}
const LOW_SUPPLY_NOTICE:="开战时私仓能源不足，本次未扣费。"
var node_id:="brass-yard"
var endpoint: String
var token: String
var grant: String
var camp := {}
var admission := {}
var initial_admission := {}
var busy := false
var attached := false
var last_role := ""
var checks := {}
var selected: Array[String]=[]
var actors := {}
var views := {}
var towers := {}
var auto_select := true
var claim_request := {}
var claiming := false
const BUILD_REASONS := {"not_camp_owner":"仅营主可建设。","camp_busy":"攻防进行中，结束后可建设。","extractor_built":"本任期已建采集站。","insufficient_stock":"私人库存不足。","stale_ownership":"归属已变化，请重新查看报价。","key_conflict":"请求编号冲突，请重新查看报价。"}
var quoted_revision := -1
var build_request := {}
var building := false
var build_receipt := ""
var fetching_overview:=false
var overview_error:=false
var poll := 0.0
var net: Node
var app_paused:=false
var refresh_requested:=false
var auth_failed:=false
var closing:=false
var read_failures:=0

func _ready() -> void:
	net=get_node("/root/Camp")
	net.changed.connect(_sync)
	$Camera.make_current()
	_site(node_id)
	%Back.pressed.connect(_close)
	%Extractor.pressed.connect(_open_quote)
	%CancelBuild.pressed.connect(func():
		%Quote.hide()
		%Lobby.show())
	%ConfirmBuild.pressed.connect(_confirm_build)
	%All.pressed.connect(_all)
	%RoleSelect.chosen.connect(_all)
	%RoleSelect.get_node("CustomGroups").recalled.connect(func(ids: Array[String]):
		auto_select = false
		selected.assign(ids))
	%Core.pressed.connect(_core)
	%Focus.pressed.connect(_focus)
	%Repair.pressed.connect(func():
		if _can_command():net.command("repair",selected))
	%Retreat.pressed.connect(func():
		if _can_command() and not last_role.begins_with("aid_"):net.command("retreat",[]))
	%Reconnect.pressed.connect(func():
		if not %Reconnect.disabled:_join())
	%Retry.pressed.connect(func(): _request("/v1/camp"))
	%Retry.text="重新连接"
	%Station.pressed.connect(func():
		if not %Station.disabled:
			_request("/v1/camp/garrison",{"robots":_checked(false),"turrets":_checked(true)}))
	%Claim.pressed.connect(_claim)
	%Start.pressed.connect(func():
		if %Start.disabled:return
		if camp.get("admission") is Dictionary:
			admission=camp.admission
			_join()
		else:
			_request("/v1/camp/reserve",{"grant":grant,"robots":_checked(false)}))
	$HTTP.request_completed.connect(_response)
	if initial_admission.is_empty():
		%Info.text="正在读取营地归属与机体名单…"
		_request("/v1/camp")
	else:
		admission=initial_admission
		%Back.text="返回好友"
		_join()

func _exit_tree() -> void:
	closing=true
	$HTTP.cancel_request()
	if attached:
		net.disconnect_mission()

func _close() -> void:
	if closing:return
	closing=true
	$HTTP.cancel_request()
	closed.emit()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true

func _page_active() -> bool:
	return not closing and not app_paused and is_visible_in_tree()

func _request(path: String, data: Dictionary={}) -> void:
	if closing or auth_failed:return
	var overview:=path=="/v1/camp"
	if overview and not _page_active():
		refresh_requested=true
		return
	if not overview and (camp.is_empty() or (overview_error and path!="/v1/camp/claim")):return
	if busy:
		if overview or not fetching_overview:return
		# An intentional action takes precedence over a background read; the server rechecks eligibility.
		_retire_http()
	busy=true
	if overview:refresh_requested=false
	fetching_overview=overview
	building=path=="/v1/camp/extractor"
	claiming=path=="/v1/camp/claim"
	%Retry.disabled=true
	if not overview:_update_actions()
	if building:%ConfirmBuild.disabled=true
	path=path.replace("/v1/camp","/v1/camp/"+node_id)
	var err: Error=$HTTP.request(endpoint+path,Endpoints.headers(token),
		HTTPClient.METHOD_GET if data.is_empty() else HTTPClient.METHOD_POST,"" if data.is_empty() else JSON.stringify(data))
	if err!=OK:
		_retire_http()
		busy=false
		if building:
			_build_error("网络中断，尚未收到回执。",false)
		elif claiming:_claim_uncertain()
		else:_read_failed("档案服务暂时无法连接")

func _retire_http() -> void:
	var old:HTTPRequest=$HTTP
	old.request_completed.disconnect(_response)
	old.cancel_request()
	var replacement:=old.duplicate(0) as HTTPRequest
	remove_child(old)
	replacement.name="HTTP"
	add_child(replacement)
	replacement.request_completed.connect(_response)
	old.queue_free()

func _claim() -> void:
	if %Claim.disabled or not %Claim.visible:return
	if claim_request.is_empty():
		claim_request={"key":Crypto.new().generate_random_bytes(16).hex_encode(),"revision":int(camp.revision)}
	%Feedback.text="正在核对领取回执…"
	_request("/v1/camp/claim",claim_request)

func _claim_uncertain() -> void:
	%Feedback.text="领取结果尚未确认，请重查本次领取。"
	_update_actions()

func _response(status: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if closing or not is_inside_tree():return
	busy=false
	poll=0.0
	var parser:=JSON.new()
	var data:Variant=parser.data if not bytes.is_empty() and parser.parse(bytes.get_string_from_utf8())==OK else null
	if code==401:
		auth_failed=true
	if status!=HTTPRequest.RESULT_SUCCESS or not data is Dictionary or code!=200 or (fetching_overview and not data.get("camp") is Dictionary):
		var reason: String=str(data.get("error","网络异常")) if data is Dictionary else "网络异常"
		if claiming:
			if status==HTTPRequest.RESULT_SUCCESS and code>=400 and code<500 and code not in [408,429] and data is Dictionary and data.get("error") is String:
				claim_request={}
				%Feedback.text={"nothing_to_claim":"当地暂无产出","storage_full":"该资源的私人仓库已满","not_camp_owner":"营地已不归你管理","stale_ownership":"归属任期已变更","key_conflict":"请求编号冲突","session_expired":"登录已过期"}.get(reason,reason)+" · 领取未完成"
				overview_error=true
				_update_actions()
				_request("/v1/camp")
			else:_claim_uncertain()
			return
		if building:
			_build_error(BUILD_REASONS.get(reason,"未收到建造回执，请重试。"),code>=400 and code<500)
			return
		_read_failed({"network_unavailable":"档案服务暂时不可用","service_unavailable":"档案服务暂时不可用","session_expired":"登录已过期，请返回基地重新登录",
			"camp_contested":"另一支队伍已先进入战场","unit_unavailable":"所选机体正在执行其他任务或需要维修",
			"point_limit":"编队超过指挥点上限","aid_budget":"包含援军后的编队已超额，请调整勾选","camp_not_editable":"攻防进行中不能调整驻军","storage_full":"私人仓库已满",
			"entry_cutoff":"本场已过入场截止","window_fight_complete":"本时段这份资格已完成对局","unit_limit":"所选机体数量不符合出战限制"}.get(reason,reason))
		if reason=="aid_budget" and not fetching_overview:
			_request("/v1/camp")
		return
	if claiming:
		var receipt:Variant=data.get("receipt")
		var resource:String=camp.get("resource","")
		if not receipt is Dictionary or receipt.get("operation")!="camp_claim" or receipt.get("node")!=node_id or not receipt.get("id") is String or receipt.id.is_empty() or not receipt.get("changes") is Dictionary or typeof(receipt.changes.get(resource)) not in [TYPE_INT,TYPE_FLOAT] or int(receipt.changes[resource])<=0:
			_claim_uncertain()
			return
	if overview_error and data.has("camp"):
		if fetching_overview and %Feedback.text.ends_with("将自动重试。"):%Feedback.text=""
		overview_error=false
	if data.has("admission"):
		admission=data.admission
		_join()
		return
	if data.get("camp") is Dictionary:
		read_failures=0
		if camp.get("revision")!=data.camp.revision and not build_receipt.is_empty():
			if %Feedback.text==build_receipt:%Feedback.text=""
			build_receipt=""
		camp=data.camp
		_site(node_id)
		_lobby()
	if building and data.has("receipt"):
		var receipt:Dictionary=data.receipt
		var resource:String=camp.resource
		build_receipt="已建设采集站 · 私仓扣除%s ×%d · 本地任期 v%d" % [RESOURCE_NAMES[resource],-int(receipt.changes[resource]),int(receipt.revision)]
		build_request={}
		_update_actions()
		%Feedback.text=build_receipt
		%Reply.text=build_receipt
		_render_quote()
	elif claiming:
		var resource:String=camp.resource
		claim_request={}
		%Feedback.text="已领取%s ×%d" % [RESOURCE_NAMES[resource],int(data.receipt.changes[resource])]
		_update_actions()

func _read_failed(message:String) -> void:
	if fetching_overview:
		read_failures+=1
		overview_error=true
		%Info.text="营地资料未更新，暂时无法操作。"
		%Feedback.text=message+"。将自动重试。"
	else:
		%Feedback.text=message
	_update_actions()
	_render_quote()

func _update_actions() -> void:
	var ready:=not camp.is_empty() and not overview_error and not auth_failed
	%Retry.visible=overview_error and not auth_failed
	%Retry.disabled=busy
	%Scroll.visible=ready
	%Budget.visible=ready
	%Station.visible=ready and bool(camp.get("mine",false))
	var preview:Dictionary=camp.get("claim_preview",{})
	var pending:=not claim_request.is_empty()
	%Claim.visible=%Station.visible or pending
	%Claim.text="重查本次领取" if pending else "领取营地产出"
	var writing:=busy and not fetching_overview
	%Claim.disabled=auth_failed or writing or (not pending and (not ready or not camp.get("mine",false) or int(preview.get("collectible",0))<=0))
	%ClaimQuote.visible=%Station.visible
	if %ClaimQuote.visible:
		if preview.is_empty():
			%ClaimQuote.text="领取预估暂不可用，正在重新确认营地。"
		else:
			var resource:String=RESOURCE_NAMES[camp.resource]
			var reason:="" if int(preview.collectible)>0 else ("当地暂无产出" if int(camp.stock)==0 else "该资源私仓已满")
			%ClaimQuote.text="%s · 可入库 %d　私仓余位 %d　原地保留 %d" % [resource,int(preview.collectible),int(preview.private_free),int(preview.remaining)]
			if not reason.is_empty():%ClaimQuote.text+=" · "+reason
	%Extractor.visible=ready and camp.get("extractor") is Dictionary and (bool(camp.mine) or not build_request.is_empty())
	if %Extractor.visible:
		%Extractor.text="重查建造回执" if not build_request.is_empty() else ("采集站 · 已建" if camp.extractor.built else "建设采集站")
		%Extractor.disabled=busy and not fetching_overview
	var seat:=camp.get("admission") is Dictionary
	%Start.visible=ready and (seat or not bool(camp.get("mine",false)))
	%Supply.visible=ready and (not camp.mine or seat)
	if not ready:return
	var within_budget:=_update_budget()
	%Station.disabled=writing or camp.active or not within_budget
	var supply:Dictionary=camp.get("attack_supply",{})
	var paid:bool=supply.get("paid",false)
	var affordable:bool=supply.get("affordable",false)
	if %Feedback.text==LOW_SUPPLY_NOTICE and (paid or affordable or camp.mine):
		%Feedback.text=""
	if camp.mine:
		%Supply.text="接管防守免费"
	elif supply.is_empty():
		%Supply.text="正在读取进攻补给报价"
	elif paid:
		%Supply.text="已付 %d 能源 · 私仓余 %d · 接回免费　#%s" % [supply.cost,supply.energy,str(supply.receipt_id).left(8)]
	else:
		%Supply.text="首次开战 %d 能源 · 私仓有 %d" % [supply.cost,supply.energy]
		if not affordable: %Supply.text+=" · 补给不足，救援凭证不可替代"
	%Start.text="实时进攻"
	if seat:
		%Start.text="接管防守" if camp.mine else ("接回原场次" if paid else "进入预约场次")
	%Start.disabled=writing or (not camp.mine and not paid and not affordable) or (not seat and (grant.is_empty() or camp.active or not within_budget or _checked(false).is_empty()))

func _update_budget() -> bool:
	if not camp.has("budget"):
		%Budget.text="等待服务器确认编队额度"
		return false
	var budget:Dictionary=camp.budget
	var count:=0
	var points:=0
	for robot:Dictionary in camp.robots:
		if checks.has(robot.id) and checks[robot.id][0].button_pressed:
			count+=1
			points+=int(robot.points)
	var units_total:=count+int(budget.aid_units)
	var points_total:=points+int(budget.aid_points)
	var excess:=PackedStringArray()
	if units_total>int(budget.max_units):
		excess.append("超出 %d 台" % (units_total-int(budget.max_units)))
	if points_total>int(budget.max_points):
		excess.append("超出 %d 指挥点" % (points_total-int(budget.max_points)))
	var caption:="本人 %d 台 · %d 点　援军 %d 台 · %d 点" % [count,points,budget.aid_units,budget.aid_points]
	caption+="\n合计 %d/%d 台 · %d/%d 指挥点" % [units_total,budget.max_units,points_total,budget.max_points]
	if not excess.is_empty():
		caption+="　"+"，".join(excess)
	%Budget.text=caption
	return excess.is_empty()

func _open_quote() -> void:
	%Lobby.hide()
	quoted_revision=int(camp.revision)
	%Quote.show()
	%Reply.text="上一笔建造结果待核对，请重试原请求。" if not build_request.is_empty() else build_receipt
	_render_quote()

func _render_quote() -> void:
	if not %Quote.visible or not camp.get("extractor") is Dictionary:return
	var quote:Dictionary=camp.extractor
	var resource:String=camp.resource
	%QuoteTitle.text="%s · 采集站" % camp.name
	%QuoteBody.text="私人仓库建造费：%s ×%d\n基础每 %d 分钟 1 份，建后每 %d 分钟 1 份。\n当地产物：%s，最多 %d 份。失守后设施和当地库存清空。" % [RESOURCE_NAMES[resource],int(quote.cost[resource]),int(quote.base_seconds)/60,int(quote.built_seconds)/60,RESOURCE_NAMES[resource],int(camp.capacity)]
	var pending:=not build_request.is_empty()
	var stale:=quoted_revision!=int(camp.revision)
	%ConfirmBuild.text="重试原请求" if pending else "确认建造"
	%ConfirmBuild.visible=pending or not quote.built
	%ConfirmBuild.disabled=auth_failed or overview_error or (busy and not fetching_overview) or (not pending and (stale or not quote.can_build))
	if stale and not pending:
		%Reply.text=BUILD_REASONS.stale_ownership
	elif not pending and %Reply.text.is_empty():
		%Reply.text=BUILD_REASONS.get(quote.reason,"")

func _confirm_build() -> void:
	if build_request.is_empty():
		if not camp.extractor.can_build or quoted_revision!=int(camp.revision):return
		build_request={"revision":quoted_revision,"key":Crypto.new().generate_random_bytes(16).hex_encode()}
	%Reply.text="正在核对建造回执…"
	_request("/v1/camp/extractor",build_request)

func _build_error(message:String,definite:bool) -> void:
	if definite:build_request={}
	%Reply.text=message
	%Feedback.text=message
	_update_actions()
	_render_quote()
	if definite:_request("/v1/camp")

func _pick_robot(enabled: bool, id: String) -> void:
	var fixed:CheckBox=checks[id][1]
	fixed.disabled=not enabled or not fixed.get_meta("can_mount",false)
	if fixed.disabled:
		fixed.set_pressed_no_signal(false)
	_update_actions()

func _checked(turrets: bool) -> Array:
	var ids: Array=[]
	for id in checks:
		if checks[id][0].button_pressed and (not turrets or checks[id][1].button_pressed):
			ids.append(id)
	return ids

func _site(id:String) -> void:
	$Switchyard.visible=id=="brass-yard"
	$CoilQuay.visible=id=="coil-depot"
	var built:bool=camp.get("extractor",{}).get("built",false)
	$OreExtractor.visible=built and id=="brass-yard"
	$CoilExtractor.visible=built and id=="coil-depot"
	%Title.text=camp.get("name","线圈港" if id=="coil-depot" else "黄铜转运场")

func _lobby() -> void:
	var present:Dictionary={}
	for robot in camp.robots:
		present[robot.id]=true
		var fresh:=not checks.has(robot.id)
		if fresh:
			var line:=HBoxContainer.new()
			%Roster.add_child(line)
			var pick:=CheckBox.new()
			var fixed:=CheckBox.new()
			var cost:=Label.new()
			pick.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			pick.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			line.add_child(pick)
			line.add_child(cost)
			line.add_child(fixed)
			checks[robot.id]=[pick,fixed,cost]
			pick.toggled.connect(_pick_robot.bind(robot.id))
		var pick:CheckBox=checks[robot.id][0]
		var fixed:CheckBox=checks[robot.id][1]
		pick.text=robot.name+(" · 驻军" if robot.guard else ("" if robot.ready else " · 不可派遣"))
		pick.tooltip_text=pick.text
		checks[robot.id][2].text="%d 点" % int(robot.points) if robot.has("points") else ""
		pick.disabled=not robot.ready and not robot.guard
		if fresh or pick.disabled:
			pick.set_pressed_no_signal(not pick.disabled and (robot.guard or (not camp.mine and robot.ready)))
		fixed.text="架设固定炮塔" if robot.weapon=="cannon" else "该武器仅可机动驻防"
		fixed.set_meta("can_mount",camp.mine and robot.weapon=="cannon")
		fixed.disabled=not fixed.get_meta("can_mount") or not pick.button_pressed
		fixed.visible=camp.mine
		if fresh or fixed.disabled:
			fixed.set_pressed_no_signal(not fixed.disabled and robot.turret)
	for id in checks.keys():
		if not present.has(id):
			var line:Control=checks[id][0].get_parent()
			%Roster.remove_child(line)
			line.queue_free()
			checks.erase(id)
	%Info.text=("营地归你管理 · 待领%s %d / %d" % [RESOURCE_NAMES[camp.get("resource","structure")],int(camp.stock),int(camp.capacity)] if camp.mine else "进攻需实时入场，实际投入的机体将被锁定。")+"\n中央核心累计独占16秒获胜。"
	if camp.mine:
		%Info.text+="\n每 %d 分钟产 1 份。勾选并保存即驻防，取消勾选后保存可撤防。" % (int(camp.seconds_per_unit)/60)
	_update_actions()
	_render_quote()
	if not camp.last.is_empty() and %Feedback.text.is_empty():
		%Feedback.text="上场%s · 归属版本 v%d" % [_reason(str(camp.last.reason)),int(camp.last.revision)]

func _join() -> void:
	if not _page_active():
		refresh_requested=true
		return
	var address:=Endpoints.transport("camp",endpoint)
	if address.is_empty():
		%Feedback.text=Endpoints.issue("camp")
		return
	attached=true
	%Lobby.hide()
	%Quote.hide()
	%Fight.show()
	net.connect_mission(address.host,address.port,admission)

func _reason(value: String) -> String:
	return {"core":"占领核心","retreat":"攻方撤退","surrender":"守方撤退","eliminated":"攻方战力耗尽","expired":"席位到期","disconnected":"攻方离线逾时","timeout":"时间到"}.get(value,value)

func _can_command() -> bool:
	return attached and net.seat_state=="active" and net.receipt.is_empty() and not net.state.is_empty() and net.state.id==admission.id and str(net.state.outcome).is_empty() and net.peer!=null and net.peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED

func _command_buttons(enabled:bool) -> void:
	for button:Button in [%All,%Core,%Focus,%Repair,%Retreat]:
		button.disabled=not enabled
	for child in %RoleSelect.get_children():
		if child is Button:
			child.disabled=not enabled

func _offline_text() -> String:
	if last_role=="attacker":
		return "主攻方已离线 · 占点暂停。30 秒内重连原场，无需再次支付能源。"
	if last_role=="defender":
		return "守方已离线 · 驻军继续防守。可重连原场接管。"
	if last_role.begins_with("aid_"):
		return "援军已离线 · 战斗继续。可重连原场指挥本席机体。"
	return "已离线 · 可重连原场查询席位或战报。"

func _sync() -> void:
	var groups = %RoleSelect.get_node("CustomGroups")
	if not _can_command():
		groups.suspend()
	if not attached:
		return
	_command_buttons(_can_command())
	%Reconnect.disabled=true
	if not net.receipt.is_empty():
		var r: Dictionary=net.receipt
		%Status.text="战报已入账 · %s · %s · 归属版本 v%d" % ["攻方获胜" if r.winner=="attacker" else "守方保有营地",_reason(r.reason),int(r.revision)]
		return
	var s:Dictionary=net.state
	match net.seat_state:
		"connecting":
			%Status.text="援军入场免费 · 等待服务器确认席位。" if not initial_admission.is_empty() else "连接中 · 等待服务器确认原场席位或返回战报。"
			return
		"displaced":
			%Status.text="指挥权已转至另一窗口，本窗口已停止发令。"
			%Reconnect.disabled=false
			return
		"rejected":
			if net.message.ends_with("insufficient_attack_energy") and initial_admission.is_empty():
				attached=false
				net.disconnect_mission()
				admission={}
				%Fight.hide()
				%Lobby.show()
				overview_error=true
				%Feedback.text=LOW_SUPPLY_NOTICE
				_update_actions()
				_request("/v1/camp")
				return
			%Status.text=net.message
			%Reconnect.disabled=false
			return
	if net.seat_state!="active" or s.is_empty() or net.peer==null or net.peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:
		%Status.text=_offline_text()
		%Reconnect.disabled=false
		return
	last_role=s.role
	if _can_command():
		var roster := {}
		for id: String in s.units:
			var u: Dictionary = s.units[id]
			if u.owned and u.hp>0 and not u.turret:
				roster[id] = str(u.get("name","")) if not str(u.get("name","")).is_empty() else "机组 %02d"%(int(u.slot)+1)
		groups.bind_roster("camp/%s/%s" % [s.id,str(admission.get("secret","")).sha256_text()],roster)
	for id in selected.duplicate():
		if not s.units.has(id) or not s.units[id].owned or s.units[id].hp<=0:selected.erase(id)
	var side:=int(s.side)
	%Retreat.visible=not str(s.role).begins_with("aid_")
	var command_title: String="进攻" if side==0 else "防守"
	if str(s.role).begins_with("aid_"):
		command_title="援军协攻" if side==0 else "援军协防"
	_site(s.get("node",node_id))
	%Title.text="%s　·　%s指挥" % [s.get("name",%Title.text),command_title]
	%Status.text="核心　攻 %.1f / 16　守 %.1f / 16　·　%ds　·　维修 %d" % [s.progress[0],s.progress[1],int(s.elapsed),int(s.repairs)]
	%Status.text+=_equipment_status(s)
	var rejection: String = net.movement_feedback()
	if not rejection.is_empty():
		%Status.text = rejection
	if not s.outcome.is_empty():
		%Status.text+="　·　"+_reason(s.reason)
	for id in s.units:
		var row: Dictionary=s.units[id]
		if not actors.has(id):
			var u:=Sim.Fighter.new()
			u.id=id
			u.side=int(row.side)
			u.slot=int(row.slot)
			u.pos=row.pos
			u.stats={"max_hp":row.max_hp}
			u.profile={"chassis":row.get("chassis","crawler"),"parts":row.parts}
			actors[id]=u
			var view:=Unit.instantiate()
			$Units.add_child(view)
			view.setup(u)
			view.set_paint(str(row.get("paint","base")))
			view.robot.set_hull_number(str(row.get("hull_number","")))
			if row.turret:
				var tower:=Turret.instantiate()
				view.add_child(tower)
				if row.get("paint","base")=="mint":
					for mesh in tower.find_children("*","MeshInstance3D",true,false):
						mesh.material_override=preload("res://store/mint.tres")
				tower.set_hull_number(str(row.get("hull_number","")))
				towers[id]=tower
				view.get_node("Robot").hide()
			var tag: Label3D=view.get_node("OwnedName")
			tag.text=row.name+(" · 固定炮塔" if row.turret else (" · 援军" if row.is_aid else ""))
			if row.is_aid:
				tag.position.y+=0.7+0.25*(int(row.slot)%2)
			tag.show()
			views[id]=view
	if auto_select:
		_all()

func _equipment_status(frame:Dictionary) -> String:
	if selected.size()!=1 or not frame.units.has(selected[0]):
		return ""
	var unit:Dictionary=frame.units[selected[0]]
	var tool:String=preload("res://loadout/catalog.gd").LABELS.get(unit.parts.get("weapon",""),"空槽")
	return "　·　%s方 %s %s" % ["攻" if int(unit.side)==0 else "守","薄荷珐琅" if unit.get("paint")=="mint" else "基础黄铜",tool]

func _all(role: String="") -> void:
	if not _can_command():return
	selected.clear()
	if net.state.is_empty():
		return
	for id in net.state.units:
		var row:Dictionary=net.state.units[id]
		if row.owned and row.hp>0 and (role.is_empty() or role==row.get("role",Sim.default_orders(row.parts).role)):
			selected.append(id)
	auto_select=false

func _core() -> void:
	if not _can_command():return
	var mobile:=selected.filter(func(id): return not net.state.units[id].turret)
	net.command("move",mobile,"",Vector2.ZERO)

func _focus() -> void:
	if not _can_command() or selected.is_empty():
		return
	var from: Vector2=net.state.units[selected[0]].pos
	var side:=int(net.state.side)
	var nearest: String=""
	var distance:=INF
	for id in net.state.units:
		var row: Dictionary=net.state.units[id]
		var d:=from.distance_to(row.pos)
		if int(row.side)!=side and row.hp>0 and d<distance:
			nearest=id
			distance=d
	if not nearest.is_empty():
		net.command("focus",selected,nearest)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not _can_command() or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:
		return
	var hit: Variant=Plane(Vector3.UP).intersects_ray($Camera.project_ray_origin(event.position),$Camera.project_ray_normal(event.position))
	if not hit is Vector3:
		return
	var at:=Vector2(hit.x,hit.z)
	var side:=int(net.state.side)
	for id in net.state.units:
		var row: Dictionary=net.state.units[id]
		if row.hp>0 and at.distance_to(row.pos)<1.1:
			if row.owned:
				selected.assign([id])
			elif int(row.side)!=side:
				net.command("focus",selected,id)
			return
	net.command("move",selected.filter(func(id): return not net.state.units[id].turret),"",at)

func _process(delta: float) -> void:
	if not _page_active() or auth_failed:return
	if not attached:
		if not initial_admission.is_empty():
			if refresh_requested and not busy:
				refresh_requested=false
				_join()
			return
		poll+=delta
		var delay:float=3.0 if not overview_error else minf(20.0,5.0*pow(2.0,mini(maxi(read_failures-1,0),2)))
		if (refresh_requested or poll>=delay) and not busy:
			poll=0
			_request("/v1/camp")
		return
	# Some locally initiated transport closes do not emit server_disconnected.
	if net.seat_state=="active" and (net.peer==null or net.peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED):
		if %Reconnect.disabled and net.receipt.is_empty():_sync()
		return
	if net.seat_state!="active" or net.state.is_empty():
		return
	for id in actors:
		var u: Sim.Fighter=actors[id]
		var row: Dictionary=net.state.units[id]
		u.pos=u.pos.lerp(row.pos,minf(delta*16,1))
		u.hp=row.hp
		u.last_heading=row.heading
		u.walking=row.walking
		u.last_service=float(row.get("service",-10))
		u.protected_until=float(row.get("protected_until",0))
		u.last_jam=float(row.get("last_jam",-10))
		u.last_shot=row.shot
		u.impact_point=row.impact
		views[id].sync(u,float(net.state.elapsed),selected.has(id),delta)
		if towers.has(id) and u.hp>0:
			var trace: MeshInstance3D=views[id].get_node("Shot")
			var tower: Node3D=towers[id]
			Mount.aim(tower,u.last_heading)
			if trace.visible:
				Mount.trace_to(tower,trace,u.impact_point)

