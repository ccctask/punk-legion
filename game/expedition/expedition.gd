extends Node3D

signal closed
const SalvageArt := preload("res://assets/salvage/kit.gd")
const Mission := preload("res://net/solo_mission.gd")
const Unit := preload("res://battle/unit.tscn")
const Sim := Mission.Sim
const Endpoints := preload("res://client/endpoints.gd")
const Session := preload("res://net/solo.gd")
@export var overhead_names := true
@export var use_network_motion := false
const MOTION_DELAY := 0.180
const MOTION_MAX_GAP := 0.600
const MOTION_CAPACITY := 8
var _motion_generation := 0
var _motion_context: StringName = &""
@onready var lobby_http: HTTPRequest = $HTTP
var endpoint := ""
var token := ""
var lobby := {}
var selected: Array = []
var selected_role:=""
var squad: Array = []
var solo_draft_initialized := false
const SOLO_UNIT_LIMIT := 12
const SOLO_POINT_LIMIT := 24
var views := {}
var actors := {}
var active := {}
var targets := {}
var goal := ""
var busy := false
var key := ""
var stamp := ""
var claim_key := ""
var finishing := false
var result_notice := ""
var attached := false
var party_mode := false
var leave_for_solo := false
var start_in_party := false
var solo_rules := ""
var lobby_poll := 0.0
var solo_session: Session
var party_session: Session
var net: Node
var last_presence: Array = []
var last_seat_leader := ""
var previous_receipt := {}
var shown_report := ""
var reading_solo := false
var solo_poll := 0.0
var solo_read_confirmed := false
var solo_connection_failed := false
var solo_expired := false
var solo_read_failures := 0
var solo_read_delay := 10.0
var solo_refresh_requested := false

func configure_sessions(solo: Session, party: Session) -> bool:
	if is_inside_tree() or lobby_closing:
		print("Expedition session configuration rejected: page is already active or closing")
		return false
	if not is_instance_valid(solo) or not is_instance_valid(party) or solo==party:
		print("Expedition session configuration rejected: distinct valid sessions are required")
		return false
	solo_session=solo
	party_session=party
	return true

func _sessions_valid() -> bool:
	return is_instance_valid(solo_session) and is_instance_valid(party_session) and solo_session!=party_session

func _usable() -> bool:
	return not lobby_closing and _sessions_valid() and is_instance_valid(net)

func _ready() -> void:
	visibility_changed.connect(_motion_visibility_changed)
	%Back.pressed.connect(_back)
	if not _sessions_valid():
		set_process(false)
		set_process_unhandled_input(false)
		for control in [%PartyPanel,%QuickSalvage,%PartyMode,%Start,%Reload,%Claim,%Squad,%SoloQuote,%PreviousReport]:
			control.hide()
		%LobbyReadStatus.text="探索暂不可用，请返回基地重试。"
		%LobbyReadBanner.show()
		print("Expedition configuration requires distinct valid solo and party sessions")
		return
	solo_rules=%Rules.text
	net = solo_session
	net.changed.connect(_sync)
	%PreviousReport.pressed.connect(func(): %Debrief.present(previous_receipt,false,false,"",_reward_summary(previous_receipt)))
	%ShowReport.pressed.connect(_open_battle_report)
	%Debrief.again.connect(_continue_party)
	%Debrief.leave.connect(func(): %Leave.pressed.emit())
	%PartyMode.pressed.connect(_party_toggle)
	%PartyPanel.request.connect(func(path:String, _fields:Dictionary):
		if path in ["/v1/party/match","/v1/party/cancel_match"]:
			%LobbyStatus.text="")
	%PartyPanel.request.connect(_request)
	%PartyPanel.enter.connect(_enter_party)
	%Start.pressed.connect(_start)
	%Reload.pressed.connect(_fetch)
	%Reload.hide()
	%Reload.text="重新连接"
	%QuickSalvage.redeem.connect(func(body:Dictionary): _request("/v1/expedition/quick-salvage",body))
	%Claim.pressed.connect(func():
		if claim_key.is_empty():
			claim_key = Crypto.new().generate_random_bytes(12).hex_encode()
		_request("/v1/expedition/claim-first",{"key":claim_key}))
	%Leave.pressed.connect(func():
		if not _usable():return
		if party_mode and not net.receipt.is_empty():
			if busy:
				return
			finishing = true
			result_notice = "正在确认收工…"
			_sync()
			_request("/v1/party/finish",{"round":active.id})
		else:_close())
	%Stay.pressed.connect(func():_continue_party())
	%Reconnect.pressed.connect(_join)
	%All.pressed.connect(_all)
	%RoleSelect.chosen.connect(_all)
	%RoleSelect.get_node("CustomGroups").recalled.connect(func(ids: Array[String]):
		selected_role = "custom"
		selected.assign(ids)
		_selection_changed())
	%Route.pressed.connect(func(): _send("route",goal))
	%Alt.pressed.connect(func():
		if _usable() and net.can_command("route"): _swap_goal())
	%Collect.pressed.connect(func(): _send("collect",goal))
	%Repair.pressed.connect(func(): _send("repair"))
	%Retreat.pressed.connect(func(): _send("retreat"))
	%AssemblyRetreat.pressed.connect(func(): _send("retreat"))
	%Map.ordered.connect(func(pos: Vector2): _field_tap("move","",pos))
	$Camera.position = Vector3(-21,17,-4)
	$Camera.look_at(Vector3(-30,0,-18))
	$Camera.make_current()
	if start_in_party:
		_party_toggle()
	elif not endpoint.is_empty():
		_fetch()

func _back() -> void:
	if lobby_closing:return
	# Local departure does not claim that the server cancelled a search lease.
	if not _usable() or not party_mode or not lobby_read_confirmed:
		_close()
	elif not %PartyPanel.match_key.is_empty():
		search_exit="base"
		%PartyPanel.cancel_search()
	else:
		_close()

func _close() -> void:
	if lobby_closing:return
	_release()
	closed.emit()

func _release() -> void:
	if lobby_closing:return
	_clear_network_motion()
	lobby_closing=true
	pending_button={}
	set_process(false)
	set_process_unhandled_input(false)
	http_generation+=1
	if is_instance_valid(lobby_http):
		if http_callback.is_valid() and lobby_http.request_completed.is_connected(http_callback):
			lobby_http.request_completed.disconnect(http_callback)
	http_callback=Callable()
	if is_instance_valid(lobby_http):
		# Cancelling local IO does not undo a POST already committed by the authority.
		lobby_http.cancel_request()
	busy=false
	reading_lobby=false
	reading_solo=false
	renewing_match=false
	quick_request=false
	if is_instance_valid(net):
		if net.changed.is_connected(_sync):net.changed.disconnect(_sync)
		net.disconnect_mission()

func _exit_tree() -> void:
	_release()

func _fetch() -> void:
	if not _usable():return
	if party_mode:
		if not _lobby_foreground() or busy or lobby_read_state=="expired":return
		lobby_read_failures=0
		lobby_poll=0
		lobby_read_state="initial" if %PartyPanel.data.is_empty() else "retrying"
		_set_lobby_read(false,"正在读取队伍…")
	else:
		if not _preparation_foreground() or solo_expired:return
		if busy:
			solo_refresh_requested=true
			return
		solo_refresh_requested=false
		solo_poll=0.0
	_request("/v1/party" if party_mode else "/v1/expedition",{})

func _preparation_foreground() -> bool:
	return not attached and not lobby_closing and not app_paused and is_visible_in_tree() and %Lobby.is_visible_in_tree() and not %Debrief.visible

func _solo_read_failed(code:int) -> void:
	solo_read_confirmed=false
	solo_connection_failed=code!=401
	solo_expired=code==401
	solo_read_failures+=1
	solo_poll=0.0
	solo_read_delay=minf(20.0,5.0*pow(2.0,mini(solo_read_failures-1,2)))
	%Reload.visible=solo_connection_failed
	%LobbyStatus.text="登录已过期，请回基地重新登录。" if solo_expired else "连接暂时中断，正在核对原任务和机体。"
	_update_solo_quote()

var quick_request:=false
var reading_lobby:=false
var renewing_match := false
var search_exit := ""
var app_paused := false
var pending_button:={}
var lobby_read_state := "initial"
var lobby_read_failures := 0
var lobby_read_confirmed := false
var lobby_read_retry_delay := 1.5
var lobby_suspended := false
var lobby_closing := false
var http_generation := 0
var http_callback := Callable()
var post_result_uncertain := false

func _lobby_foreground() -> bool:
	return party_mode and not attached and not lobby_closing and not app_paused and is_visible_in_tree() and %PartyPanel.is_visible_in_tree() and not %Debrief.visible

func _set_lobby_read(confirmed: bool, message: String) -> void:
	lobby_read_confirmed=confirmed
	%PartyPanel.set_read_available(confirmed)
	%LobbyReadStatus.text=message
	%LobbyReadBanner.visible=party_mode and not attached and %Lobby.visible and not %Debrief.visible
	%Reload.visible=party_mode and lobby_read_state in ["retrying","failed"] and lobby_read_failures>0
	if not confirmed and %PartyPanel.data.is_empty():
		%PartyPanel.get_node("%Room").text="正在读取队伍" if lobby_read_state=="initial" else "尚未确认队伍状态"

func _intent_context() -> Dictionary:
	var data:Dictionary=%PartyPanel.data
	return {"owner":str(data.get("self","")),"room":str(data.get("roomscope",{}).get("id",""))}

func _discard_intent(intent: Dictionary) -> void:
	if not intent.is_empty() and intent.get("path","") not in ["/v1/party/cancel_match","/v1/party/match"]:
		if intent.get("path","")=="/v1/party/leave":leave_for_solo=false
		%LobbyStatus.text="队伍状态未确认，刚才的操作未发送。恢复后请重新点击。"

func _cancel_lobby_get() -> void:
	if not busy or not (reading_lobby or reading_solo):return
	_retire_lobby_http()
	busy=false
	reading_lobby=false
	reading_solo=false
	if not lobby_closing:
		var reload_button: BaseButton=get_node_or_null("%Reload")
		if is_instance_valid(reload_button) and reload_button.is_inside_tree():reload_button.disabled=false

func _retire_lobby_http() -> void:
	http_generation+=1
	if is_instance_valid(lobby_http):
		if http_callback.is_valid() and lobby_http.request_completed.is_connected(http_callback):
			lobby_http.request_completed.disconnect(http_callback)
		lobby_http.cancel_request()
		# A retired emitter cannot deliver a queued completion to the next read.
		var old:=lobby_http
		var replacement:=old.duplicate(0) as HTTPRequest
		remove_child(old)
		replacement.name="HTTP"
		add_child(replacement)
		lobby_http=replacement
		old.queue_free()

func _suspend_lobby_read() -> void:
	lobby_suspended=true
	_discard_intent(pending_button)
	if pending_button.get("path","") not in ["/v1/party/cancel_match","/v1/party/match"]:pending_button={}
	_cancel_lobby_get()
	lobby_poll=0
	if lobby_read_state!="expired":lobby_read_state="suspended"
	_set_lobby_read(false,"返回页面后将重新确认队伍状态。" if lobby_read_state!="expired" else "登录已过期，请回基地重新登录。")

func _read_failed(code: int, reason: String, queued: Dictionary) -> void:
	_discard_intent(queued)
	lobby_poll=0
	lobby_read_failures+=1
	if code==401 or reason=="session_expired":
		lobby_read_state="expired"
		_set_lobby_read(false,"登录已过期，请回基地重新登录。")
	elif code>=400 and code<500:
		lobby_read_state="failed"
		_set_lobby_read(false,"无法读取当前队伍，可重新连接或返回基地。")
	elif lobby_read_failures<=2:
		lobby_read_state="retrying"
		lobby_read_retry_delay=1.5 if lobby_read_failures==1 else 3.0
		_set_lobby_read(false,"队伍读取暂未成功，正在自动重试（%d/2）…" % lobby_read_failures)
	else:
		lobby_read_state="retrying"
		lobby_read_retry_delay=minf(20.0,5.0*pow(2.0,mini(lobby_read_failures-3,2)))
		_set_lobby_read(false,"连接暂时中断，正在自动恢复队伍状态。")

func _valid_party_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("party") is Dictionary:return false
	var party:Dictionary=data.party
	if not (party.get("roomscope") is Dictionary and party.get("robots") is Array and party.get("last") is Dictionary and party.get("departure_quote") is Dictionary and party.get("self") is String and party.get("drill_recipe") is Dictionary):return false
	for key_name: String in ["mastered","wins","required"]:
		if not party.drill_recipe.has(key_name):return false
	if party.departure_quote.get("source","") not in ["energy","voucher","unavailable"] or not party.departure_quote.has("energy"):return false
	for robot: Variant in party.robots:
		if not robot is Dictionary:return false
		for key_name: String in ["id","name","points","ready"]:
			if not robot.has(key_name):return false
	var scope:Dictionary=party.roomscope
	if not scope.is_empty():
		for key_name: String in ["id","leader","code","members"]:
			if not scope.has(key_name):return false
		if not scope.members is Array:return false
		for member: Variant in scope.members:
			if not member is Dictionary:return false
			for key_name: String in ["owner","name","robots","ready","points"]:
				if not member.has(key_name):return false
	var route:=_api_path("/v1/party")
	if route in ["/v1/pump","/v1/factory"]:
		if not party.get("event") is Dictionary:return false
		for key_name: String in (["id","active","reward_available","expected_components"] if route=="/v1/pump" else ["unlocked","south_unlocked","reward_available"]):
			if not party.event.has(key_name):return false
	return true

func _post_uncertain() -> void:
	post_result_uncertain=true
	%LobbyStatus.text="操作结果待核对，将读取队伍状态，不会自动重发。"
	lobby_read_state="retrying"
	lobby_read_retry_delay=0.0
	lobby_poll=0
	_set_lobby_read(false,"正在核对已发送操作的队伍状态…")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
		_clear_network_motion()
		if is_node_ready() and party_mode and not attached:_suspend_lobby_read()
		elif is_node_ready() and reading_solo:
			_cancel_lobby_get()
			solo_refresh_requested=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		_clear_network_motion()
		solo_refresh_requested=true
		if is_node_ready() and party_mode and not attached:lobby_suspended=true

func _api_path(path: String) -> String:
	return path

func _request(path: String, data: Dictionary) -> void:
	if not _usable():return
	if not party_mode and solo_expired:return
	if path=="/v1/expedition" and not _preparation_foreground():
		solo_refresh_requested=true
		return
	if party_mode and lobby_read_state=="expired":return
	var ordinary_action:=path.begins_with("/v1/party/") and path not in ["/v1/party/cancel_match","/v1/party/match","/v1/party/again","/v1/party/finish"]
	if ordinary_action and (not lobby_read_confirmed or not _lobby_foreground()):
		%LobbyStatus.text="请先确认最新队伍状态，再提交操作。"
		return
	if busy:
		if reading_solo and path!="/v1/expedition":
			_cancel_lobby_get()
		else:
			if path=="/v1/party/cancel_match" and (reading_lobby or renewing_match):
				pending_button={"path":path,"body":data.duplicate(true)}
			elif reading_lobby and path.begins_with("/v1/party/") and pending_button.is_empty():
				pending_button={"path":path,"body":data.duplicate(true),"context":_intent_context()}
			return
	if ordinary_action and not %PartyPanel.action_available(path):
		%LobbyStatus.text="当前队伍状态不允许此操作，请重新确认。"
		return
	var service := "party" if party_mode else "solo"
	var starts_activity := path in ["/v1/expedition/start", "/v1/party/create", "/v1/party/join", "/v1/party/ready", "/v1/party/start"]
	if starts_activity and Endpoints.transport(service,endpoint).is_empty():
		%LobbyStatus.text=Endpoints.issue(service)
		return
	busy = true
	renewing_match=path=="/v1/party/match"
	quick_request=path=="/v1/expedition/quick-salvage"
	%QuickSalvage.set_waiting(true)
	%Start.disabled = true
	%Reload.disabled = true
	var headers := Endpoints.headers(token)
	var reading := path in ["/v1/party","/v1/expedition"]
	reading_lobby=path=="/v1/party"
	reading_solo=path=="/v1/expedition"
	http_generation+=1
	http_callback=_response.bind(http_generation)
	$HTTP.request_completed.connect(http_callback,CONNECT_ONE_SHOT)
	if ordinary_action:
		post_result_uncertain=false
		%LobbyStatus.text=""
	var err: Error = $HTTP.request(endpoint+_api_path(path),headers,HTTPClient.METHOD_GET if reading else HTTPClient.METHOD_POST,"" if reading else JSON.stringify(data))
	if err != OK:
		_retire_lobby_http()
		busy = false
		var failed_read:=reading_lobby
		var failed_solo:=reading_solo
		reading_lobby=false
		reading_solo=false
		renewing_match=false
		_update_solo_quote()
		%QuickSalvage.set_waiting(false)
		if quick_request:
			%QuickSalvage.failed("",true)
			quick_request=false
		if failed_read:
			_read_failed(0,"",pending_button)
			pending_button={}
		elif failed_solo:
			_solo_read_failed(0)
		elif finishing:
			_finish_failed("未能连接档案服务")
		else:
			%LobbyStatus.text = "请求未确认，请检查连接后恢复原操作。"
		%Reload.disabled = false

func _response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray, generation: int) -> void:
	if generation!=http_generation or lobby_closing:return
	var was_read:=reading_lobby
	var was_solo_read:=reading_solo
	busy = false
	var was_quick:=quick_request
	quick_request=false
	%QuickSalvage.set_waiting(false)
	reading_lobby=false
	reading_solo=false
	var queued:=pending_button
	pending_button={}
	var was_match:=renewing_match
	renewing_match=false
	%Reload.disabled = false
	_update_solo_quote()
	var response := JSON.new()
	var data: Variant = response.data if response.parse(bytes.get_string_from_utf8()) == OK else null
	if was_solo_read and not _preparation_foreground():
		solo_refresh_requested=true
		return
	if not party_mode and (code==401 or (data is Dictionary and data.get("error","")=="session_expired")):
		_solo_read_failed(401)
		return
	if was_solo_read and (result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary or not data.get("expedition") is Dictionary):
		_solo_read_failed(code if code!=200 else 0)
		return
	if party_mode and not finishing and (code==401 or (data is Dictionary and data.get("error","")=="session_expired")):
		_read_failed(401,"session_expired",queued)
		return
	if party_mode and not attached and not finishing and not _lobby_foreground():
		_discard_intent(queued)
		if queued.get("path","") in ["/v1/party/cancel_match","/v1/party/match"]:pending_button=queued
		if not was_read and not was_match:
			post_result_uncertain=true
			%LobbyStatus.text="操作已发送，返回页面后将核对队伍状态；不会自动重发。"
		_suspend_lobby_read()
		return
	if queued.get("path","") in ["/v1/party/cancel_match","/v1/party/match"]:
		_request(queued.path,queued.body)
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		if was_read:
			_read_failed(0,"",queued)
			return
		if was_quick:
			%QuickSalvage.failed("",true)
			return
		if finishing:
			_finish_failed("档案服务未响应")
			return
		leave_for_solo=false
		if party_mode and not was_match:
			_post_uncertain()
		else:
			_solo_read_failed(0)
		return
	if was_read and (code!=200 or not _valid_party_snapshot(data)):
		_read_failed(code if code!=200 else 0,str(data.get("error","")) if data is Dictionary else "",queued)
		return
	if finishing:
		if code == 200 and data is Dictionary and data.get("finished_round") == active.id:
			finishing = false
			_close()
		else:
			var reason := str(data.get("error","")) if data is Dictionary else ""
			var detail := str({"continuation_unavailable":"未找到本人已结算的这场探索","session_expired":"登录已过期","storage_unavailable":"档案存储暂不可用（503）"}.get(reason,"档案服务回复异常（%d）" % code))
			_finish_failed(detail)
		return
	if not data is Dictionary or code != 200:
		if was_match and code>=400 and code<500:
			%PartyPanel.match_key=""
			_fetch()
		if was_quick:
			var uncertain:=code>=500 or not data is Dictionary
			%QuickSalvage.failed(str(data.get("error","")) if data is Dictionary else "",uncertain)
			if not uncertain:
				_fetch()
			return
		if party_mode and not was_match and (code>=500 or not data is Dictionary):
			_post_uncertain()
			return
		leave_for_solo=false
		var reason := str(data.get("error",code)) if data is Dictionary else str(code)
		%LobbyStatus.text = {"requires_south_land":"先完成封闭工厂护送，开放南地后可出击。","pump_closed":"本轮泵站已关闭，请返回地图查看下次开放。","wrong_activity":"请先结束当前活动","unknown_code":"邀请码无效或房间已出发","requires_east_land":"需先本人通关锈轨，开放基地东侧土地","friends_required":"合作护送需要双方已是好友","party_full":"队伍已满","team_budget":"编队超过本场的台数或指挥点预算","not_ready":"所有队员需要先准备","changed_fit":"机体配置已变化，请重新准备","already_in_party":"请先离开当前队伍","unit_unavailable":"机体正在执行任务、受损或装配不完整", "point_limit":"超过 24 指挥点", "insufficient_stock":"入场能源不足", "expedition_active":"已有未完成任务，正在核对原场","parts_full":"请先在工坊实装部件，腾出一个仓位再领取。"}.get(reason,reason)
		return
	if data.has("party"):
		if not _valid_party_snapshot(data):
			if party_mode:_read_failed(0,"",queued)
			return
		lobby_read_state="ready"
		lobby_read_failures=0
		lobby_poll=0
		_set_lobby_read(true,"队伍状态已同步。")
		if was_read and post_result_uncertain:
			post_result_uncertain=false
			%LobbyStatus.text="队伍状态已更新，请核对刚才操作结果。"
		var previously_searching:bool=not %PartyPanel.match_key.is_empty()
		var was_cancelled:bool=%PartyPanel.cancel_requested
		%PartyPanel.refresh(data.party)
		if not search_exit.is_empty() and not data.party.get("matching",false):
			var destination:=search_exit
			search_exit=""
			if data.party.roomscope.is_empty():
				if destination=="base": _close()
				else: _party_toggle()
				return
		_party_details(data.party)
		_set_previous(data.party.last)
		if not queued.is_empty() and not attached:
			if queued.get("context",{})==_intent_context():_request(queued.path,queued.body)
			else:_discard_intent(queued)
			return
		if leave_for_solo and data.party.roomscope.is_empty():
			leave_for_solo=false
			_party_toggle()
			return
		if not %PartyPanel.match_key.is_empty():
			if was_match:%LobbyStatus.text=""
		elif previously_searching:
			if not data.party.roomscope.is_empty():
				%LobbyStatus.text="已找到锈轨队友，请分别选机并准备。"
			else:
				%LobbyStatus.text="已取消寻找。" if was_cancelled else "本次寻找已结束，可重新寻找队友。"
		elif not data.party.last.is_empty() and data.party.roomscope.is_empty() and (not was_read or %LobbyStatus.text.is_empty()):
			%LobbyStatus.text = _personal_summary(data.party.last)
		return
	_solo_lobby(data)

func _solo_lobby(data:Dictionary) -> void:
	solo_read_confirmed=true
	solo_connection_failed=false
	solo_read_failures=0
	solo_read_delay=10.0
	solo_poll=0.0
	%Reload.hide()
	lobby = data.expedition
	_set_previous(lobby.last)
	%QuickSalvage.refresh(lobby,data.get("receipt",{}))
	%Claim.visible = lobby.get("pending_drill",false)
	active = lobby.active if lobby.active is Dictionary else {}
	%Pity.text = "%s\n首胜获得钻头部件 · 加固锅炉掉落保底 %d/3" % [_recipe_progress(lobby.drill_recipe), int(lobby.pity)]
	_refresh_solo_squad()
	%LobbyStatus.text = _summary(lobby.last) if not lobby.last.is_empty() else "选择自有机体出击，最多 12 台／24 点。"
	if data.get("receipt",{}).get("operation","") == "expedition_claim":
		%LobbyStatus.text = "首胜钻头已存入仓库。"
	elif data.get("receipt",{}).get("operation","")=="expedition_start" and not active.is_empty():
		if _preparation_foreground():_join()
		else:solo_refresh_requested=true

func _set_previous(receipt:Dictionary) -> void:
	previous_receipt=receipt
	%PreviousReport.visible=receipt.has("debrief")

func _open_battle_report() -> void:
	if not _usable():return
	%Debrief.present(net.receipt,true,%Stay.visible,%Leave.text,_reward_summary(net.receipt))
	%Debrief.update_actions(result_notice,finishing)

func _party_details(data: Dictionary) -> void:
	%Pity.text = _recipe_progress(data.drill_recipe)

func _personal_summary(r:Dictionary) -> String:
	var reason:=preload("res://expedition/personal_debrief.gd").assembly_exit(r)
	if not reason.is_empty():
		var payment: String="救援凭证 ×%d" % int(r.debrief.vouchers_used) if r.debrief.vouchers_used else "能源 ×%d" % int(r.debrief.resources.energy.cost)
		return reason+" · 出发扣除"+payment
	return _summary(r)

func _summary(r: Dictionary) -> String:
	var text := "%s · %d 秒" % [{"win":"撤离成功","defeat":"探索失利","retreat":"主动撤退","expired":"任务过期"}.get(r.outcome,r.outcome),int(r.seconds)]
	var rewards:=_reward_summary(r)
	return text if rewards.is_empty() else text+"\n"+rewards

func _reward_summary(r:Dictionary) -> String:
	if not r.get("participated",true):
		return ""
	if r.get("activity","")=="pump_ruin":
		if r.get("outcome","")!="win":
			return ""
		var text:="今日奖励已领 · 本次协助，通用零件入库 0"
		if r.get("first_daily",false):
			var credited:=int(r.changes.get("components",0))
			text="今日首胜 · 通用零件实际入库 %d/%d" % [credited,int(r.reward_available)]
		var arm:Dictionary=r.get("recovered_arm",{})
		if r.get("first_clear",false):
			if arm.get("status")=="delivered":
				text+="\n个人首通回收 · 维修臂 #%s 已入包，可装在带 AUX 接口的底盘上。" % str(arm.part_id).left(8)
			elif arm.get("status")=="pending":
				text+="\n本场结算时背包已满，维修臂已保留。到基地机库查看领取状态。"
		return text
	var lines:=PackedStringArray()
	if r.get("part") is Dictionary:
		var label:String={"drill":"钻头","cannon":"炮臂","reinforced_boiler":"加固锅炉"}.get(r.part.definition,r.part.definition)
		lines.append(("%s%s #%s" % ["首胜回收" if r.first else "回收",label,str(r.part.id).left(8)]))
	if r.get("converted",false):
		lines.append("仓位已满，部件折为材料")
	if r.get("pending_drill",false):
		lines.append("首胜钻头已保留，腾出仓位后回到出击页领取。")
	if r.has("drill_recipe"):
		lines.append(_recipe_progress(r.drill_recipe))
	return "\n".join(lines)

func _recipe_progress(recipe: Dictionary) -> String:
	if recipe.get("unlocked_now",false):
		return "个人通关 %d/%d · 已掌握钻头制造配方" % [recipe.wins, recipe.required]
	if recipe.mastered:
		return "钻头制造配方已掌握"
	return "钻头制造配方 · 个人通关 %d/%d" % [recipe.wins, recipe.required]

func _pick(enabled: bool, id: String) -> void:
	if enabled:
		if not squad.has(id):squad.append(id)
	else:
		squad.erase(id)
	_update_solo_quote()

func _refresh_solo_squad() -> void:
	var rows:Dictionary={}
	for child in %Squad.get_children():
		rows[child.get_meta("robot")]=child
	var available:Array=[]
	for index in lobby.robots.size():
		var robot:Dictionary=lobby.robots[index]
		var id:String=robot.id
		if robot.ready:
			available.append(id)
		var button:CheckButton=rows.get(id)
		if button==null:
			button=CheckButton.new()
			button.set_meta("robot",id)
			button.toggled.connect(_pick.bind(id))
			%Squad.add_child(button)
		rows.erase(id)
		if button.get_index()!=index:%Squad.move_child(button,index)
		var cost:="%d 点" % int(robot.points) if robot.has("points") else "点数待同步"
		button.text="%s · %s · %s · %s" % [robot.name,Sim.Catalog.HULL_LABELS.get(robot.get("chassis","crawler"),"未知底盘"),Sim.Catalog.LABELS.get(robot.weapon,"待装配"),cost]
		button.disabled=not robot.ready or not active.is_empty()
	for obsolete:CheckButton in rows.values():
		%Squad.remove_child(obsolete)
		obsolete.queue_free()
	if not solo_draft_initialized and active.is_empty():
		squad=available.slice(0,2)
		solo_draft_initialized=true
	else:
		squad=squad.filter(func(id):return id in available)
	for button:CheckButton in %Squad.get_children():
		var picked:bool=active.is_empty() and button.get_meta("robot") in squad
		if button.button_pressed!=picked:
			button.set_pressed_no_signal(picked)
	_update_solo_quote()

func _update_solo_quote() -> void:
	if party_mode:return
	if not solo_read_confirmed or solo_expired:
		%Start.disabled=true
		return
	var resume:=not active.is_empty()
	%Start.text="恢复探索" if resume else "出发"
	if resume:
		if not _same_outing():
			%SoloQuote.text="请从基地进入进行中的探索：" + ("旧武器库" if active.get("location","")=="old_armory" else "锈轨回收场")
			%Start.disabled=true
			return
		%SoloQuote.text="已有进行中的独行探索，可恢复原场。"
		%Start.disabled=busy
		return
	var points:=0
	var price_known:=true
	var issues:=PackedStringArray()
	for robot:Dictionary in lobby.get("robots",[]):
		if robot.id in squad:
			if not robot.has("points"):
				price_known=false
				issues.append("机体报价暂不可用，正在重新确认")
				break
			points+=int(robot.points)
	if squad.is_empty():issues.append("请先选择待命机体")
	if squad.size()>SOLO_UNIT_LIMIT:issues.append("超出 %d 台" % (squad.size()-SOLO_UNIT_LIMIT))
	if points>SOLO_POINT_LIMIT:issues.append("超出 %d 指挥点" % (points-SOLO_POINT_LIMIT))
	%SoloQuote.text="已选 %d/%d 台 · %s/%d 指挥点" % [squad.size(),SOLO_UNIT_LIMIT,str(points) if price_known else "?",SOLO_POINT_LIMIT]
	if lobby.get("robots",[]).filter(func(robot):return robot.ready).size()>=3 and squad.size()<3:
		%SoloQuote.text+="\n可手动勾选第三台，核对指挥点后出发。"
	if not issues.is_empty():%SoloQuote.text+=" · "+"，".join(issues)
	%Start.disabled=busy or not issues.is_empty()

func _same_outing() -> bool:
	return active.get("location","")!="old_armory"

func _start() -> void:
	if not _usable():return
	if party_mode or busy or %Start.disabled:return
	if not active.is_empty():
		_join()
	elif not squad.is_empty():
		var signature := JSON.stringify(squad)
		if key.is_empty() or stamp != signature:
			key = Crypto.new().generate_random_bytes(16).hex_encode()
			stamp = signature
		_request("/v1/expedition/start",{"key":key,"robots":squad})
	else:
		%LobbyStatus.text = "请先选择处于待命状态的机体"

func _join() -> void:
	if not _usable():return
	_clear_network_motion()
	shown_report=""
	%ShowReport.hide()
	%Debrief.hide()
	result_notice = ""
	%Leave.disabled = false
	$BattleAudio.reset_audio()
	var service := "party" if party_mode else "solo"
	var address:=Endpoints.transport(service,endpoint)
	if address.is_empty():
		%LobbyStatus.text=Endpoints.issue(service)
		return
	attached = true
	%LobbyReadBanner.hide()
	%Lobby.hide()
	%Bar.show()
	%Map.show()
	%Commands.hide()
	%AssemblyRetreat.hide()
	%Leave.show()
	%Reconnect.hide()
	%Stay.hide()
	%Mark.button_pressed=false
	net.connect_mission(address.host,address.port,active)

func _all(role: String="") -> void:
	if not _usable():return
	if not net.can_command("move"):
		return
	selected_role=role
	selected.clear()
	for id in net.state.get("units",{}):
		var row: Dictionary = net.state.units[id]
		if row.side == 0 and row.hp > 0 and _owned(id) and (role.is_empty() or role==row.get("role",Sim.default_orders(row.parts).role)):
			selected.append(id)
	_selection_changed()

func _selection_changed() -> void:
	pass

func _send(action: String, target := "", pos := Vector2.ZERO) -> void:
	if not _usable():return
	if not net.can_command(action):
		return
	net.command(action,selected,target,pos)

func _assembling() -> bool:
	return party_mode and net.state.get("assembly", {}).get("phase", "") == "assembling"

func _field_tap(action: String,target: String,pos: Vector2) -> void:
	if not _usable():return
	if not net.can_command(action):
		return
	if %Mark.button_pressed and _can_mark():
		%Mark.button_pressed=false
		net.suggest(action,target,pos)
	else:
		_send(action,target,pos)

func _continue_party() -> void:
	if not _usable():return
	_clear_network_motion()
	%Debrief.hide()
	%ShowReport.hide()
	var previous:=str(active.id)
	attached=false
	net.disconnect_mission()
	for view in views.values():view.queue_free()
	views.clear()
	actors.clear()
	targets.clear()
	selected.clear()
	selected_role=""
	active={}
	%PartyPanel.initialized=false
	%PartyPanel.selected.clear()
	%Bar.hide()
	%Map.hide()
	%Commands.hide()
	%SeatPanel.hide()
	last_presence.clear()
	%Lobby.show()
	%Leave.text="返回基地"
	_request("/v1/party/again",{"round":previous})

func _finish_failed(detail: String) -> void:
	finishing = false
	result_notice = "收工未确认 · %s。可再点「本次收工」。" % detail
	_sync()

func _swap_goal() -> void:
	goal="fuel" if goal=="scrap" else "scrap"
	_send("route",goal)

func _sync() -> void:
	if not _usable():return
	var groups = %RoleSelect.get_node("CustomGroups")
	if not attached or not net.can_command("move"):
		groups.suspend()
	if not attached:
		_clear_network_motion()
		return
	_update_presence()
	%Mark.visible = _can_mark()
	if not %Mark.visible:
		%Mark.button_pressed = false
	if not net.receipt.is_empty():
		_clear_network_motion()
		$BattleAudio.reset_audio()
		%AssemblyRetreat.hide()
		%Leave.show()
		var summary := _personal_summary(net.receipt)
		if not result_notice.is_empty():
			summary += "\n" + result_notice
		if %Goal.text != summary:
			%Goal.text = summary
		%Stay.disabled = finishing
		%Leave.disabled = finishing
		%Hint.text = "奖励与战报已保存。返回基地可维修或换装。"
		%Commands.hide()
		%Reconnect.hide()
		%Stay.visible=party_mode and net.receipt.get("activity","") not in ["pump_ruin","factory_escort"]
		%Leave.text="本次收工" if party_mode else "返回基地"
		%ShowReport.visible=net.receipt.has("debrief")
		if %ShowReport.visible:
			var mission:String=net.receipt.debrief.mission
			if shown_report!=mission:
				shown_report=mission
				_open_battle_report()
			elif %Debrief.visible:
				%Debrief.update_actions(result_notice,finishing)
		return
	if not net.authorized():
		_clear_network_motion()
		%Commands.hide()
		%AssemblyRetreat.hide()
		%Leave.show()
		%Reconnect.visible=net.seat_state!="connecting"
		match net.seat_state:
			"connecting": %Goal.text="正在连接 · 等待服务器确认本场席位"
			"displaced","rejected": %Goal.text=net.message
			_: %Goal.text="已离线 · 可重连原场"
		return
	%Reconnect.hide()
	var state: Dictionary = net.state
	if net.can_command("move"):
		var roster := {}
		for id: String in state.units:
			var u: Dictionary = state.units[id]
			if u.side==0 and u.hp>0 and _owned(id):
				roster[id] = str(u.get("name","")) if not str(u.get("name","")).is_empty() else "机组 %02d"%(int(u.slot)+1)
		groups.bind_roster("expedition/%s/%s" % [state.id,str(active.get("secret","")).sha256_text()],roster)
		if selected_role=="custom":
			var live := selected.filter(func(id): return roster.has(id))
			if live != selected:
				selected = live
				_selection_changed()
	$Field.set_goals(state.goals)
	if goal not in state.goals and not state.goals.is_empty():
		goal = state.goals[0]
	if selected.is_empty() and selected_role.is_empty():
		_all()
	targets = state.units
	var motion_ready := _prepare_network_motion()
	var arrival_usec := Time.get_ticks_usec()
	for id in targets:
		var row: Dictionary = targets[id]
		var created := false
		if not actors.has(id) and row.hp > 0:
			var u := Sim.Fighter.new()
			u.id=id; u.side=row.side; u.slot=row.slot; u.pos=row.pos
			u.profile={"chassis":row.get("chassis","crawler"),"parts":row.parts}; u.stats={"max_hp":row.max_hp}
			actors[id]=u
			var view := Unit.instantiate()
			$Units.add_child(view)
			view.setup(u)
			view.set_paint(str(row.get("paint","base")))
			view.robot.set_hull_number(str(row.get("hull_number","")))
			if row.side==1:
				SalvageArt.dress(view,int(row.slot))
			if overhead_names and not str(row.get("name","")).is_empty():
				var name_tag: Label3D = view.get_node("OwnedName")
				name_tag.text = str(row.name)
				name_tag.modulate = Color.AQUAMARINE if row.side == 0 else (Color.WHEAT if int(row.slot) in [3,7] else Color.LIGHT_SALMON)
				name_tag.show()
			if id == "1:6/hull" and state.get("activity","") not in ["pump_ruin","factory_escort","old_armory"]:
				view.scale = Vector3.ONE*1.7
			views[id] = view
			created=true
		if actors.has(id):
			var u:Sim.Fighter=actors[id]
			u.last_service=float(row.get("service",-10))
			u.protected_until=float(row.get("protected_until",0))
			u.last_jam=float(row.get("last_jam",-10))
			u.hp=row.hp; u.last_heading=row.heading; u.walking=row.walking; u.last_shot=row.shot; u.impact_point=row.impact
			if motion_ready:_feed_network_motion(id,row,arrival_usec)
			elif views[id].network_motion.enabled:views[id].clear_network_motion()
			if row.hp<=0:
				u.pos=row.pos
				u.walking=false
				views[id].clear_network_motion()
			if created:views[id].sync(u,float(state.elapsed),selected.has(id),0.0)
		if row.hp <= 0 and id in selected:
			selected.erase(id)
			_selection_changed()
	%Map.state = state
	%Map.queue_redraw()
	var waiting := _assembling()
	%AssemblyRetreat.visible = waiting and net.can_command("retreat")
	%Leave.visible = not %AssemblyRetreat.visible
	%Commands.visible = net.can_command("move")
	if waiting:
		var assembly: Dictionary = state.assembly
		if state.get("withdrawn", false):
			%Goal.text = "已退出集结 · 等待本场结算"
		else:
			%Goal.text = "队伍集结 · %d/%d 人到场 · 到齐即开战，最多再等 %d 秒" % [assembly.online, assembly.total, assembly.remaining]
		return
	_objectives(state)

func _objectives(state: Dictionary) -> void:
	var left := maxi(0,ceili(420.0-float(state.elapsed)))
	if not str(state.outcome).is_empty():
		%Goal.text="本场结束 · 正在核对个人收据"
	elif state.get("withdrawn",false):
		%Goal.text="本人已离场 · 等待本场结算"
	else:
		%Goal.text = "锈轨回收场　%d:%02d　%s" % [left/60,left%60,Mission.NAMES[goal]]
	%Collect.text = "确认撤离" if state.stage == 4 else "采集"
	%Collect.disabled = state.stage in [1,3] or not state.outcome.is_empty()
	%Route.text = "集火目标" if state.stage in [1,3] else "前往"+str(Mission.NAMES[goal])
	%Alt.visible = state.stage == 0
	%Repair.text = "维修 ×%d" % int(state.repairs)
	%Repair.disabled = state.repairs == 0
	%Hint.text = str(net.message) if not str(net.message).is_empty() else "已选 %d 台　点地移动／友机选中／敌机集火　节点四米内可采集" % selected.size()
	for id in state.units:
		var affected:Dictionary=state.units[id]
		var left_protection:=float(affected.get("protected_until",0))-float(state.elapsed)
		if left_protection>0:
			%Hint.text="脉冲干扰 · %s　保护剩余 %.1f 秒" % [str(affected.name) if not str(affected.name).is_empty() else "机体",left_protection]
			break
	var suggestion := _suggestion_hint(state)
	if not suggestion.is_empty():
		%Hint.text=suggestion
	var rejection: String = net.movement_feedback()
	if not rejection.is_empty():
		%Hint.text = rejection
	if state.get("withdrawn",false):
		%Commands.hide()
		%Hint.text="你已撤离，队友可继续探索。结算后可在队伍页查看个人战报。"
	elif not state.outcome.is_empty():
		%Hint.text = "正在核对回收物与战损…"

func _can_mark() -> bool:
	return party_mode and net.can_command("suggest") and net.state.get("presence",[]).size()>1 and net.state.get("leader","")==active.get("owner","")

func _suggestion_hint(state: Dictionary) -> String:
	if %Mark.button_pressed:
		return "点地面或小地图建议移动，点敌机建议集火"
	var ping:Dictionary=state.get("suggestion",{})
	if not ping.is_empty() and state.elapsed<float(ping.until):
		return "队长建议集火："+str(state.units.get(ping.target,{}).get("name","敌机")) if ping.kind=="focus" else "队长建议移动至小地图金色十字"
	return ""

func _update_presence() -> void:
	if not party_mode or not net.receipt.is_empty():
		%SeatPanel.hide()
		return
	%SeatPanel.show()
	var seats: Array = net.state.get("presence", [])
	if seats.is_empty() or not net.authorized():
		last_presence.clear()
		%Seats.text = "席位状态待同步"
		return
	var leader:String = net.state.get("leader","")
	if seats == last_presence and leader == last_seat_leader:
		return
	last_seat_leader = leader
	last_presence = seats.duplicate(true)
	var lines := PackedStringArray()
	for seat: Dictionary in seats:
		var status := "待连接"
		match seat.status:
			"online": status = "在线"
			"departed": status = {"win":"成功撤离","retreat":"已撤退","defeat":"已战败","expired":"已过期"}.get(seat.reason,"已离场")
		var who := "我" if seat.owner == active.get("owner", "") else "队友"
		if seat.owner == leader and seats.size()>1:
			who += "·队长"
		lines.append("%s · %s · %s" % [who, status, seat.name])
	%Seats.text = "\n".join(lines)

func _owned(id: String) -> bool:
	return not party_mode or net.state.get("owners",{}).get(id,"") == active.get("owner","")

func _party_toggle() -> void:
	if not _usable():return
	if party_mode and not %PartyPanel.match_key.is_empty():
		search_exit="solo"
		%PartyPanel.cancel_search()
		return
	if busy:
		return
	if party_mode and not %PartyPanel.data.get("roomscope",{}).is_empty():
		leave_for_solo=true
		_request("/v1/party/leave",{})
		return
	_set_previous({})
	party_mode=not party_mode
	%Rules.text="组队探索 · 全队上限 12 台和 24 点，个人费用在出发时结算。撤离后各自领取回收物并记录战损。" if party_mode else solo_rules
	if net.changed.is_connected(_sync):net.changed.disconnect(_sync)
	net=party_session if party_mode else solo_session
	if not net.changed.is_connected(_sync):net.changed.connect(_sync)
	%PartyPanel.visible=party_mode
	%QuickSalvage.visible=not party_mode
	%Squad.visible=not party_mode
	%SoloQuote.visible=not party_mode
	%Start.visible=not party_mode
	%Pity.text=""
	%Claim.hide()
	%PartyMode.text="返回独行探索" if party_mode else "组队探索 · 寻找队友或邀请好友"
	%LobbyStatus.text="两到三人共同探索，首个节点需两名队员抵达后依次采集。" if party_mode else ""
	%LobbyReadBanner.visible=party_mode
	_fetch()

func _enter_party(admission: Dictionary) -> void:
	if not _usable():return
	if attached: return
	active=admission
	_join()

func _network_motion_applicable() -> bool:
	return use_network_motion and is_instance_valid(net) and net==solo_session and not party_mode and attached and net.seat_state=="active" and not net.state.is_empty() and active.get("id","")==net.state.get("id","") and active.get("location","")=="rustrail"

func _clear_network_motion() -> void:
	_motion_generation+=1
	_motion_context=&""
	for id in views:
		if views[id].network_motion.enabled and actors.has(id) and targets.has(id):
			actors[id].pos=targets[id].pos
			actors[id].walking=false
		views[id].clear_network_motion()

func _motion_visibility_changed() -> void:
	if not is_visible_in_tree():_clear_network_motion()

func _prepare_network_motion() -> bool:
	if not _network_motion_applicable() or app_paused or not is_visible_in_tree() or not net.receipt.is_empty() or not str(net.state.get("outcome","")).is_empty():
		if _motion_context!=&"":_clear_network_motion()
		return false
	var context := StringName("%s/%s/%s/%s" % [net.get_instance_id(),_motion_generation,net.state.id,net.state.stage])
	if _motion_context!=context:
		_clear_network_motion()
		_motion_context=StringName("%s/%s/%s/%s" % [net.get_instance_id(),_motion_generation,net.state.id,net.state.stage])
	return true

func _feed_network_motion(id: String, row: Dictionary, arrival_usec: int) -> void:
	var view: Node3D=views[id]
	if float(row.hp)<=0:
		view.clear_network_motion()
		return
	var track: Node=view.network_motion
	if not track.enabled:
		var chassis: String=str(row.get("chassis","crawler"))
		if not Sim.Catalog.CHASSIS.has(chassis):return
		var radius: float=float(Sim.Catalog.CHASSIS[chassis].body_radius)
		var guard: Callable=Sim.Field.segment_has_static_clearance.bind(radius,Mission.Sites.AREA,Mission.Sites.obstacles())
		if not view.configure_network_motion(MOTION_DELAY,MOTION_MAX_GAP,MOTION_CAPACITY,guard):return
		track.reset(_motion_context,float(net.state.elapsed),row.pos,row.heading,bool(row.walking),arrival_usec)
	else:
		track.push(_motion_context,float(net.state.elapsed),row.pos,row.heading,bool(row.walking),arrival_usec)

func _process(delta: float) -> void:
	if not _usable():return
	if not party_mode and not attached:
		if not _preparation_foreground():
			if reading_solo:_cancel_lobby_get()
			solo_refresh_requested=true
		elif not solo_expired:
			solo_poll+=delta
			if not busy and (solo_refresh_requested or solo_poll>=solo_read_delay):_fetch()
	if party_mode and not attached:
		var foreground:=_lobby_foreground()
		if not foreground and not lobby_suspended:_suspend_lobby_read()
		elif foreground and lobby_suspended:
			lobby_suspended=false
			if lobby_read_state!="expired":
				lobby_read_failures=0
				lobby_read_state="retrying"
				lobby_read_retry_delay=0.0
				lobby_poll=0
				_set_lobby_read(false,"正在重新确认队伍状态…")
		%PartyPanel.enforce_read_gate()
		%LobbyReadBanner.visible=foreground
		%Lobby.offset_top=maxf(0.0,%LobbyReadBanner.offset_top+%LobbyReadBanner.size.y+6.0-get_viewport().get_visible_rect().size.y*%Lobby.anchor_top)
		if foreground and not busy and lobby_read_state not in ["failed","expired","suspended"]:
			lobby_poll+=delta
			var searching:bool=lobby_read_state=="ready" and lobby_read_confirmed and not %PartyPanel.match_key.is_empty() and not %PartyPanel.cancel_requested
			var interval:float=3.0 if searching else (lobby_read_retry_delay if lobby_read_state=="retrying" else 1.5)
			if lobby_poll>=interval:
				lobby_poll=0
				if searching:_request("/v1/party/match",{"key":%PartyPanel.match_key})
				else:_request("/v1/party",{})
	else:
		%LobbyReadBanner.hide()
		if not party_mode:%Lobby.offset_top=0.0
	if attached and net.seat_state=="active" and not net.authorized():
		net._lost()
	if not attached or targets.is_empty() or net.state.is_empty():
		return
	var age:=float(net.state.elapsed)
	var motion_ready := _prepare_network_motion()
	var motion_now := Time.get_ticks_usec()
	var center := Vector2.ZERO
	var firing_target := Vector2.ZERO
	var shooters := 0
	var count := 0
	var camera_planes:Array[Plane]=$Camera.get_frustum()
	for id in actors:
		var row: Dictionary = targets[id]
		var u: Sim.Fighter = actors[id]
		var visual_heading := Vector2.ZERO
		if motion_ready:
			_feed_network_motion(id,row,motion_now)
			var pose: Dictionary=views[id].network_motion.sample(motion_now)
			if not pose.is_empty():
				u.pos=pose.pos
				u.walking=pose.walking
				visual_heading=pose.heading
			else:
				u.pos=row.pos
				u.walking=false
		elif _network_motion_applicable():
			u.pos=row.pos
			u.walking=false
		else:
			u.pos = u.pos.lerp(row.pos,minf(delta*16,1))
		if u.hp<=0:
			u.pos=row.pos
			u.walking=false
		var visual:Node3D=views[id]
		if not visual.visible and u.hp<=0:continue
		var in_view:=true
		var center_3d:=Vector3(u.pos.x,1.5,u.pos.y)
		# Extend beyond the screen for the boss mesh, attached equipment and cast shadows.
		for plane:Plane in camera_planes:
			if plane.distance_to(center_3d)>8.0:
				in_view=false
				break
		visual.robot.update_pose_visibility(in_view,delta)
		views[id].sync(u,age,selected.has(id),delta,visual_heading)
		if id in selected and u.hp > 0:
			center += u.pos
			count += 1
			if u.last_shot>=0 and age-u.last_shot<1.2 and u.pos.distance_squared_to(u.impact_point)<144:
				firing_target+=u.impact_point
				shooters+=1
	if not net.authorized() or not str(net.state.outcome).is_empty() or net.state.get("withdrawn",false):
		if not $BattleAudio.session.is_empty():$BattleAudio.reset_audio()
	else:
		$BattleAudio.observe(str(active.get("id","")),age,actors,views,$Camera)
	if count > 0:
		center /= count
		if shooters>0:
			center=center.lerp(firing_target/shooters,0.20)
		var desired:=Vector3(center.x+9,17,center.y+14)
		$Camera.position=$Camera.position.lerp(desired,minf(1,delta*8)) if $Camera.position.distance_squared_to(desired)<36 else desired

func _unhandled_input(e: InputEvent) -> void:
	if not _usable():return
	if not attached or not net.can_command("move") or not e is InputEventMouseButton or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	var best := 22.0
	var pick := ""
	for id in actors:
		if actors[id].hp <= 0:
			continue
		var at: Vector2 = actors[id].pos
		var height:=2.55 if targets[id].side==1 and int(targets[id].slot)==5 else 1.25
		var low:Vector2=$Camera.unproject_position(Vector3(at.x,0.38,at.y))
		var high:Vector2=$Camera.unproject_position(Vector3(at.x,height,at.y))
		var closest:=Geometry2D.get_closest_point_to_segment(e.position,low,high)
		var dist:float=e.position.distance_to(closest)
		if dist < best:
			best = dist
			pick = id
	if not pick.is_empty():
		if actors[pick].side == 0:
			if _owned(pick) and selected != [pick]:
				selected.assign([pick])
				_selection_changed()
		else:
			_field_tap("focus",pick,Vector2.ZERO)
	else:
		var ground: Variant = Plane(Vector3.UP,0).intersects_ray($Camera.project_ray_origin(e.position),$Camera.project_ray_normal(e.position))
		if ground != null:
			_field_tap("move","",Vector2(ground.x,ground.z))
	get_viewport().set_input_as_handled()



