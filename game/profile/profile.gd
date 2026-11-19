extends MarginContainer

const TASKS := ["expedition", "guard", "aid", "repair"]
const NAMES := ["探索", "驻防", "援助", "维修"]
var token := ""
var robots: Array = []
var busy := false
var endpoint := ""
var active_route := ""
var retry_history := false
var repair_refresh_at := 0
var opening_guard := ""
var dossier_navigation: Array = []
var dossier_http: HTTPRequest
var dossier_session: Dictionary = {}
var dossier_needs_refresh := false
var dossier_retries := 0
var dossier_retry_at := -1
var guard_http: HTTPRequest
var guard_retry_at := -1
var guard_retries := 0
var account_id := ""
var auto_reading := false
var read_failed := false
var read_lease := -1
var auto_routes: Array[String] = []
var auto_identity: Array = []
const OwnedWorkshop := preload("res://owned/workshop.tscn")
const Endpoints := preload("res://client/endpoints.gd")

func _ready() -> void:
	$PageRefresh.configure(_page_active, _can_auto_read, 10.0)
	$PageRefresh.read_due.connect(_auto_read)
	%Endpoint.text = Endpoints.profile_url()
	if not Endpoints.valid_url(%Endpoint.text):
		%Message.text=Endpoints.issue("profile")
	%Endpoint.text_changed.connect(func(value: String): Endpoints.remember("profile",value.strip_edges().trim_suffix("/")))
	%History.request.connect(_send)
	%Recovery.request.connect(_send)
	%Recovery.queue_requested.connect(_enter_repair_bay)
	%Owned.pressed.connect(_owned_workshop)
	%Register.pressed.connect(_authenticate.bind(true))
	%Login.pressed.connect(_authenticate.bind(false))
	%Back.pressed.connect(func():
		_cancel_dossier()
		_cancel_guard()
		get_tree().change_scene_to_file("res://beta/entry.tscn" if get_tree().has_meta("base_first_path") else "res://client/range.tscn"), CONNECT_DEFERRED)
	%Refresh.pressed.connect(_refresh_profile)
	%Base.pressed.connect(_enter_base)
	%Friends.pressed.connect(_enter_friends)
	%Rename.pressed.connect(func(): _operate("rename", {"name": %RobotName.text}))
	%Assign.pressed.connect(func(): _operate("assign", {"task": TASKS[%Kind.selected]}))
	%Finish.pressed.connect(_finish.bind("completed"))
	%Cancel.pressed.connect(_finish.bind("cancelled"))
	%Robots.item_selected.connect(func(_index):
		_cancel_auto_read()
		_cancel_guard()
		_display()
		if %History.opened: %History.refresh())
	%HTTP.request_completed.connect(_response)
	%Inventory.bind_account("", "")
	%Inventory.request.connect(_send)
	%Inventory.depart.connect(_depart)
	for label in NAMES:
		%Kind.add_item(label)
	_display()
	if get_tree().has_meta("base_first_path"):
		var navigation:Array=get_tree().get_meta("base_first_profile_action",[])
		var guard_link:bool=navigation.size()==2 and navigation[0]=="raid_guard_recovery"
		if get_tree().has_meta("base_first_profile_action"):
			get_tree().remove_meta("base_first_profile_action")
		if not guard_link and navigation.size()==2:
			dossier_navigation=navigation
		var login:=preload("res://beta/session.gd").load_for(Endpoints.profile_url())
		if not login.get("token","").is_empty():
			endpoint=Endpoints.profile_url()
			token=login.token
			account_id=login.owner
			%Account.text=login.name
			%Account.get_parent().hide()
			%Endpoint.hide()
			%Back.text="返回私人基地"
			%Inventory.bind_account(endpoint,account_id)
			if guard_link:
				_guide_garage(navigation[0],navigation[1])
			else:
				_send("/v1/profile",{},true)
		elif guard_link:
			%Message.text="会话已失效，请重新登录"

func _authenticate(register: bool) -> void:
	_cancel_auto_read()
	dossier_navigation=[]
	_cancel_dossier()
	_cancel_guard()
	if busy:
		return
	if not Endpoints.valid_url(%Endpoint.text.strip_edges()):
		%Message.text=Endpoints.issue("profile")
		return
	token = ""
	account_id = ""
	Room.set("pending_ticket", "")
	%Inventory.bind_account("", "")
	robots.clear()
	endpoint = %Endpoint.text.strip_edges().trim_suffix("/")
	%Robots.clear()
	_display()
	_send("/v1/accounts" if register else "/v1/sessions", {"name": %Account.text, "password": %Password.text})

func _operate(action: String, fields: Dictionary) -> void:
	if %Robots.selected >= 0:
		_send("/v1/robots/%s/%s" % [robots[%Robots.selected].id, action], fields)

func _finish(outcome: String) -> void:
	if %Robots.selected >= 0:
		_operate("finish", {"assignment": robots[%Robots.selected].assignment, "outcome": outcome})

func _send(route: String, fields: Dictionary, read_only := false, automatic := false) -> void:
	if not automatic:_cancel_auto_read()
	if busy:
		return
	_cancel_dossier()
	_cancel_guard()
	retry_history = false
	if read_only and route=="/v1/profile":
		if token.is_empty() or account_id.is_empty():
			%Message.text="会话已失效，请重新登录"
			return
		dossier_session={"owner":account_id,"token":token,"endpoint":endpoint}
		repair_refresh_at=0
		_read_dossier()
		return
	var headers := Endpoints.headers(token)
	busy = true
	active_route = route
	_display()
	if not auto_reading:%Message.text = "正在联系档案服务…"
	var error: Error = %HTTP.request(endpoint + route, headers, HTTPClient.METHOD_GET if read_only else HTTPClient.METHOD_POST, "" if read_only else JSON.stringify(fields))
	if error != OK:
		_retire_http()
		retry_history = route.ends_with("/history")
		busy = false
		%Message.text = "连接失败 · " + error_string(error)
		if automatic:_finish_auto(false,0)
		elif read_only:
			read_failed=true
			$PageRefresh.settled(false)
		_display()

func _apply_response(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray, guard_id:String="") -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		retry_history = active_route.ends_with("/history")
		%Message.text = "服务未响应。正在恢复档案连接。"
		_display()
		return
	var payload: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not payload is Dictionary:
		%Message.text = "档案服务返回格式异常"
	elif status == 200:
		if payload.has("recovery"):
			_apply_profile(payload.profile)
			if not guard_id.is_empty():
				if payload.recovery.get("robot")!=guard_id or not _select_guard(guard_id):
					_guard_unavailable(guard_id)
					return
			%Recovery.receive(payload.recovery,payload.has("receipt"))
			%Message.text = "检修档案已同步"
			if not guard_id.is_empty():
				if payload.recovery.state=="retired":
					%Message.text="该驻防机已回收 · #"+guard_id.left(8)
				$Scroll.ensure_control_visible.call_deferred(%Recovery.get_node("Details/Summary"))
			_display()
			return
		if active_route.ends_with("/history"):
			var valid:bool=payload.get("history") is Dictionary and %History.receive(payload.history)
			retry_history=not valid
			%Message.text = "累计战绩已同步" if valid else "累计战绩返回异常，请重新查看"
			_display()
			return
		if payload.has("inventory"):
			%Message.text = "仓库已同步"
			%Inventory.receive(payload, active_route != "/v1/inventory")
			_display()
			return
		if payload.has("token"):
			if not payload.token is String or payload.token.is_empty() or not payload.get("account") is Dictionary or not payload.account.get("id") is String or payload.account.id.is_empty():
				%Message.text="登录回复尚未确认，请重新登录。"
				_display()
				return
			token = payload.token
			account_id = str(payload.account.id)
			read_failed=false
			dossier_needs_refresh=false
			read_lease=-1
			$PageRefresh.configure(_page_active, _can_auto_read, 10.0)
			%Password.clear()
			%Inventory.bind_account(endpoint, str(payload.account.id))
		_apply_profile(payload)
		%Message.text = "档案已同步 · %s" % payload.account.name
	else:
		var reason: String = str(payload.get("error", status))
		%Message.text = {"invalid_account":"账号限 3–32 位字母、数字、短横线或下划线", "invalid_password":"密码限 8–128 个字符", "invalid_credentials":"账号或密码有误", "account_exists":"账号已存在", "invalid_robot_name":"机体名限 1–24 个可见字符", "session_expired":"会话已失效，请重新登录", "robot_busy":"机体已有任务，正在更新状态", "assignment_changed":"任务已变更，正在更新状态"}.get(reason, reason)
		if not guard_id.is_empty() and status==404:
			_guard_unavailable(guard_id)
			return
		if status == 426:
			%Message.text = "当前内测版本已过期，请向负责人领取新版 APK 并覆盖安装。"
		elif status == 401:
			token = ""
			account_id = ""
			robots.clear()
			%Robots.clear()
			%Inventory.bind_account("", "")
		elif active_route.begins_with("/v1/inventory/") and status in [400,403,404,409]:
			%Inventory.reject()
		elif "/recovery/" in active_route and status in [400,403,404,409]:
			%Recovery.clear_intent()
			if active_route.ends_with("/repair") and status==409 and reason in ["insufficient_stock","repair_queue_full","unit_unavailable","repair_not_needed"]:
				%Recovery.data.erase("repair_stock")
				_send(active_route.get_base_dir(),{},true)
				return
			if active_route.ends_with("/recycle") and status==409:
				_send(active_route.get_base_dir(),{},true)
				return
			%Message.text = {"relief_not_needed":"现有机体和能源可出征", "relief_cooldown":"救援配额冷却中，十分钟后可再申请", "finish_active_tasks":"请先完成现有任务", "use_workshop_repair":"现有材料足够，请先入列维修", "use_workshop_build":"现有材料足够，请先制造机体", "keep_last_robot":"需保留至少一台机体", "repair_queue_full":"维修队列已满", "unit_unavailable":"机体当前不可用","insufficient_stock":"库存材料不足","recycle_preview_changed":"机体已变化，正在更新回收预览"}.get(reason,reason)
	_display()

func _cancel_dossier() -> void:
	dossier_needs_refresh=false
	dossier_retry_at=-1
	dossier_retries=0
	dossier_session={}
	if is_instance_valid(dossier_http):
		var request:=dossier_http
		dossier_http=null
		request.cancel_request()
		request.queue_free()
		busy=false

func _current_dossier() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and $Scroll.is_visible_in_tree() and dossier_session.get("owner")==account_id and dossier_session.get("token")==token and dossier_session.get("endpoint")==endpoint

func _read_dossier() -> void:
	if not _current_dossier():
		_cancel_dossier()
		return
	dossier_retry_at=-1
	busy=true
	active_route="/v1/profile"
	var request:=HTTPRequest.new()
	dossier_http=request
	request.timeout=%HTTP.timeout
	request.accept_gzip=%HTTP.accept_gzip
	add_child(request)
	request.request_completed.connect(_dossier_reply.bind(request))
	_display()
	if not auto_reading:%Message.text="正在读取指挥官档案…"
	if request.request(endpoint+"/v1/profile",Endpoints.headers(token))!=OK:
		_dossier_reply(HTTPRequest.RESULT_CANT_CONNECT,0,[],PackedByteArray(),request)

func _apply_dossier_reply(result:int,status:int,_headers:PackedStringArray,bytes:PackedByteArray,request:HTTPRequest) -> void:
	if request!=dossier_http:return
	dossier_http=null
	request.queue_free()
	busy=false
	if not _current_dossier():
		_cancel_dossier()
		return
	print("DOSSIER_READ result=",result," status=",status," bytes=",bytes.size()," attempt=",dossier_retries+1)
	var reason:=""
	var retry_manually:=false
	if status==401:
		token=""
		account_id=""
		robots.clear()
		%Robots.clear()
		%Inventory.bind_account("","")
		reason="会话已失效，请重新登录"
	elif status==426:
		reason="当前内测版本已过期，请向负责人领取新版 APK 并覆盖安装。"
	elif status in [408,429] or (status>=500 and status<=599) or (result!=HTTPRequest.RESULT_SUCCESS and status<400):
		if dossier_retries<2:
			dossier_retries+=1
			dossier_retry_at=Time.get_ticks_msec()+500*dossier_retries
			%Message.text="档案暂未读到，正在重试 %d/2…" % dossier_retries
			_display()
			return
		retry_manually=true
		reason="档案连接中断，正在恢复连接。"
	elif status!=200:
		reason="档案读取被拒绝（%d）" % status
	else:
		var json:=JSON.new()
		var data:Variant=json.data if json.parse(bytes.get_string_from_utf8())==OK else null
		if _valid_dossier(data):
			_apply_profile(data)
			reason="档案已同步 · %s" % data.account.name
			if not dossier_navigation.is_empty():
				var navigation:=dossier_navigation
				dossier_navigation=[]
				if not str(navigation[0]).is_empty():
					_follow_dossier_link.call_deferred(navigation,token)
		else:
			retry_manually=true
			reason="档案状态尚未确认，正在恢复连接。"
	_cancel_dossier()
	dossier_needs_refresh=retry_manually
	%Message.text=reason
	_display()

func _follow_dossier_link(navigation:Array,session_token:String) -> void:
	if token==session_token and not busy and is_inside_tree() and not is_queued_for_deletion() and $Scroll.is_visible_in_tree():
		_guide_garage(str(navigation[0]),str(navigation[1]))

func _valid_dossier(data:Variant) -> bool:
	if not data is Dictionary or not data.get("account") is Dictionary or data.account.get("id")!=account_id or not data.account.get("name") is String or data.account.name.is_empty():return false
	if not data.get("robots") is Array or data.robots.is_empty() or typeof(data.get("server_now")) not in [TYPE_FLOAT,TYPE_INT]:return false
	var ids:={}
	for row in data.robots:
		if not row is Dictionary or not row.get("id") is String or row.id.is_empty() or ids.has(row.id):return false
		if not row.get("name") is String or row.name.is_empty() or row.get("state") not in %Recovery.STATES:return false
		if not row.has_all(["task","assignment"]) or (row.task!=null and not row.task is String) or (row.assignment!=null and not row.assignment is String):return false
		if row.get("repair_due")!=null and typeof(row.repair_due) not in [TYPE_FLOAT,TYPE_INT]:return false
		ids[row.id]=true
	return true

func _apply_profile(payload:Dictionary) -> void:
	var index:int=%Robots.selected
	var selected_id:=str(robots[index].id) if index>=0 and index<robots.size() else ""
	robots=payload.robots
	%Robots.clear()
	repair_refresh_at=0
	for robot in robots:
		%Robots.add_item(robot.name)
		if robot.get("repair_due")!=null:
			var delay:=maxi(100,int((float(robot.repair_due)-float(payload.server_now))*1000)+100)
			var deadline:=Time.get_ticks_msec()+delay
			if repair_refresh_at==0 or deadline<repair_refresh_at:
				repair_refresh_at=deadline
	if not robots.is_empty():
		%Robots.select(0 if selected_id.is_empty() else robots.find_custom(func(row):return row.id==selected_id))

func _refresh_profile() -> void:
	_cancel_auto_read()
	if not opening_guard.is_empty():
		guard_retries=0
		guard_retry_at=0
		return
	if retry_history and %History.opened:
		%History.refresh()
		return
	if not dossier_needs_refresh and dossier_session.is_empty() and not %Recovery.data.is_empty():
		_send("/v1/robots/%s/recovery" % %Recovery.robot,{},true)
	else:
		_send("/v1/profile",{},true)

func _process(_delta:float) -> void:
	if auto_reading and (not _page_active() or not $PageRefresh.foreground):_cancel_auto_read()
	if not $PageRefresh.foreground or not $Scroll.is_visible_in_tree():return
	if dossier_retry_at>=0:
		if Time.get_ticks_msec()>=dossier_retry_at:_read_dossier()
		return
	if not opening_guard.is_empty():
		if not busy and guard_retry_at>=0 and Time.get_ticks_msec()>=guard_retry_at:
			_read_guard()
		return
	if not busy and not token.is_empty() and repair_refresh_at>0 and Time.get_ticks_msec()>=repair_refresh_at:
		repair_refresh_at=Time.get_ticks_msec()+3000
		_refresh_profile()

func _depart(ticket: String) -> void:
	Room.set("pending_ticket", ticket)
	get_tree().call_deferred("change_scene_to_file", "res://client/range.tscn")

func _enter_friends() -> void:
	_cancel_auto_read()
	_cancel_dossier()
	_cancel_guard()
	var scene:=preload("res://friends/friends.tscn").instantiate()
	scene.endpoint=endpoint
	scene.token=token
	$Scroll.hide()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(scene)
	scene.closed.connect(func():
		scene.queue_free()
		$Scroll.show()
		mouse_filter=Control.MOUSE_FILTER_STOP)

func _enter_repair_bay() -> void:
	_cancel_auto_read()
	_cancel_dossier()
	_cancel_guard()
	var bay := preload("res://base/repair_bay.tscn").instantiate()
	bay.endpoint = endpoint
	bay.token = token
	bay.return_text = "返回档案"
	$Scroll.hide()
	add_child(bay)
	bay.closed.connect(func():
		bay.queue_free()
		$Scroll.show()
		_refresh_profile())

func _enter_base() -> void:
	_cancel_auto_read()
	_cancel_dossier()
	_cancel_guard()
	var scene := preload("res://base/base.tscn").instantiate()
	scene.endpoint = endpoint
	scene.token = token
	scene.account = account_id
	$Scroll.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene)
	scene.garage_requested.connect(func(action:String,robot:String):
		scene.closed.emit()
		call_deferred("_guide_garage",action,robot))
	scene.closed.connect(func():
		scene.queue_free()
		$Scroll.show()
		mouse_filter = Control.MOUSE_FILTER_STOP
	)

# A dedicated read leaves the ordinary HTTP channel (including writes) untouched.
# Each attempt owns its completion callback, even after an immediate request error.
func _cancel_guard() -> void:
	opening_guard=""
	guard_retry_at=-1
	guard_retries=0
	if is_instance_valid(guard_http):
		var request:=guard_http
		guard_http=null
		request.cancel_request()
		request.queue_free()
		busy=false
	%Refresh.text="刷新"

func _read_guard() -> void:
	guard_retry_at=-1
	busy=true
	var request:=HTTPRequest.new()
	request.timeout=%HTTP.timeout
	request.accept_gzip=%HTTP.accept_gzip
	add_child(request)
	guard_http=request
	request.request_completed.connect(_guard_reply.bind(request))
	_display()
	%Message.text="正在读取驻防机况 · #"+opening_guard.left(8)
	var err:=request.request(endpoint+"/v1/robots/"+opening_guard+"/recovery",Endpoints.headers(token))
	if err!=OK:
		_guard_reply(HTTPRequest.RESULT_CANT_CONNECT,0,[],PackedByteArray(),request)

func _guard_reply(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray,request:HTTPRequest) -> void:
	if request!=guard_http:return
	guard_http=null
	request.queue_free()
	busy=false
	var id:=opening_guard
	if (result!=HTTPRequest.RESULT_SUCCESS and (status<400 or status>=500)) or status in [408,429] or (status>=500 and status<=599):
		var reason:="网络未响应" if result!=HTTPRequest.RESULT_SUCCESS else "服务暂不可用（%d）" % status
		if guard_retries<2:
			guard_retries+=1
			guard_retry_at=Time.get_ticks_msec()+500*guard_retries
			%Message.text="%s，正在重试 %d/2 · #%s" % [reason,guard_retries,id.left(8)]
		else:
			_guard_manual(reason)
	elif status!=200:
		_cancel_guard()
		if status==404:
			_guard_unavailable(id)
		elif status==401:
			token=""
			robots.clear()
			%Robots.clear()
			%Inventory.bind_account("","")
			%Message.text="会话已失效，请重新登录"
		else:
			%Message.text="无法读取驻防机况（%d） · #%s" % [status,id.left(8)]
	else:
		var json:=JSON.new()
		var payload:Variant=json.data if json.parse(body.get_string_from_utf8())==OK else null
		if _valid_guard_reply(payload,id):
			_cancel_guard()
			_response(result,status,_headers,body,id)
			return
		_guard_manual("机况回包无效")
	_display()

func _guard_manual(reason:String) -> void:
	guard_retry_at=-1
	%Refresh.text="重试驻防机况"
	%Message.text="%s · #%s，可点重试驻防机况。" % [reason,opening_guard.left(8)]
	$Scroll.ensure_control_visible(%Refresh)

func _valid_guard_reply(body:Variant,id:String) -> bool:
	if not body is Dictionary or not body.get("profile") is Dictionary or not body.get("recovery") is Dictionary:return false
	var profile:Dictionary=body.profile
	var info:Dictionary=body.recovery
	if not profile.get("account") is Dictionary or profile.account.get("id")!=account_id or not profile.get("robots") is Array:return false
	if not profile.has("server_now") or not profile.robots.all(func(row):return row is Dictionary and row.get("id") is String and row.get("name") is String and row.has("task") and row.get("state") in %Recovery.STATES):return false
	if info.get("robot")!=id or info.get("state") not in %Recovery.STATES or not info.has_all(["seconds","voucher"]):return false
	if info.state=="repairing" and info.get("due")==null:return false
	if not info.get("bays") is Dictionary or not info.bays.has_all(["available","used"]):return false
	if not info.get("price") is Dictionary or not info.get("repair_stock") is Dictionary or not info.get("recent") is Array:return false
	return info.recent.all(func(event):return event is Dictionary and event.has_all(["at","kind"]))

func _select_guard(id:String) -> bool:
	var index:=robots.find_custom(func(row):return row.id==id)
	%Robots.select(index)
	_display()
	return index>=0

func _guard_unavailable(id:String) -> void:
	%Robots.select(-1)
	_display()
	%Message.text="当前档案找不到本场驻防机 · #"+id.left(8)
	$Scroll.ensure_control_visible(%Message)

func _guide_garage(action:String,robot:String) -> void:
	_cancel_dossier()
	if action=="raid_guard_recovery":
		_cancel_guard()
		opening_guard=robot
		%Recovery.bind_robot("",false)
		_select_guard(robot)
		guard_retry_at=0
		return
	if action in ["fit","build"]:
		_owned_workshop(action=="fit")
		return
	if action=="name":
		$Scroll.ensure_control_visible(%RobotName)
		%RobotName.grab_focus()
		return
	for index in robots.size():
		if robots[index].id==robot:
			%Robots.select(index)
			_display()
	%Recovery.get_node("Open").pressed.emit()
	$Scroll.ensure_control_visible(%Recovery)

func _owned_workshop(garage:=false) -> void:
	_cancel_auto_read()
	_cancel_dossier()
	_cancel_guard()
	if busy or token.is_empty():
		return
	var panel := OwnedWorkshop.instantiate()
	panel.endpoint = endpoint
	panel.token = token
	panel.account = account_id
	panel.open_garage=garage
	$Scroll.hide()
	add_child(panel)
	panel.closed.connect(func() -> void:
		panel.queue_free()
		$Scroll.show()
		_send("/v1/profile",{},true))

func _display() -> void:
	var locked:bool=(busy and not auto_reading) or read_failed
	var has_session:=not token.is_empty() and not account_id.is_empty()
	var auth_locked:=busy and not auto_reading
	%Owned.disabled = locked
	%Inventory.set_busy(locked)
	%Inventory.get_node("%LoadStock").visible=read_failed and has_session
	%Inventory.get_node("%LoadStock").text="重新连接"
	var selected: int = %Robots.selected
	var available := selected >= 0 and selected < robots.size()
	%Robots.disabled = locked and guard_http==null
	%History.select_robot(str(robots[selected].id) if available else "",locked)
	%Recovery.bind_robot(str(robots[selected].id) if available else "",locked,str(robots[selected].name) if available else "")
	%Inventory.selected_robot = str(robots[selected].id) if available else ""
	%Record.visible = not robots.is_empty()
	%Register.disabled = auth_locked
	%Login.disabled = auth_locked
	%Endpoint.editable = not auth_locked and Endpoints.development()
	if not has_session:
		%Account.get_parent().show()
		if Endpoints.development():%Endpoint.show()
	%Refresh.disabled = busy or token.is_empty()
	%Refresh.visible=has_session and (read_failed or dossier_needs_refresh or not opening_guard.is_empty())
	%Refresh.text="重新连接"
	%Base.disabled = locked or token.is_empty()
	%Friends.disabled = locked or token.is_empty()
	if not available:
		%Identity.text="请选择要查看的机体"
		for control in [%Rename,%Assign,%Finish,%Cancel]:
			control.disabled=true
	if available:
		var robot: Dictionary = robots[selected]
		var kind := TASKS.find(robot.task)
		%Identity.text = "机体编号  %s\n当前任务  %s" % [robot.id, "待命" if kind < 0 else NAMES[kind]]
		var sortie = robot.get("sortie")
		if sortie != null:
			var activity:Dictionary={"waiting":"已领演习券 · 等待队友，可取消并退还能源","active":"已入场 · 等待演习战报",
				"raid_guard":"驻防中 · 本次袭击结算后解锁","mission":"探索中 · 任务结算后解锁"}
			%Identity.text = "机体编号  %s\n%s" % [robot.id,activity.get(sortie,"等待战报")]
		%Cancel.text = "退还入场券" if sortie == "waiting" else "取消任务"
		%Rename.disabled = locked
		%Assign.disabled = locked or kind >= 0
		%Finish.disabled = locked or kind < 0 or sortie != null
		%Cancel.disabled = locked or kind < 0 or (sortie != null and sortie != "waiting")
		if str(robot.get("assignment","")).begins_with("trq:"):
			%Identity.text="机体编号  %s\n秘宝队伍已预留，去大地图上的秘宝队伍可取消或查看匹配。" % robot.id
			%Finish.disabled=true
			%Cancel.disabled=true
		if robot.get("state","ready") != "ready":
			%Identity.text += "\n机况  %s" % %Recovery.STATES[robot.state]
			%Assign.disabled = true
			if robot.state == "repairing":
				%Cancel.disabled = true
				%Finish.disabled = true

func _page_active() -> bool:
	return not token.is_empty() and not account_id.is_empty() and $Scroll.is_visible_in_tree()

func _can_auto_read() -> bool:
	return not busy and not auto_reading and opening_guard.is_empty() and dossier_retry_at<0 and %Inventory.pending.is_empty() and %Recovery.pending.is_empty()

func _auto_read() -> void:
	if not _can_auto_read():
		$PageRefresh.defer()
		return
	read_lease=$PageRefresh.current_lease()
	auto_identity=[endpoint,token,account_id]
	auto_routes.assign(["/v1/inventory","/v1/profile"])
	if %History.opened and not %History.robot.is_empty():
		auto_routes.append("/v1/robots/%s/history" % %History.robot)
	if %Recovery.get_node("Details").is_visible_in_tree() and not %Recovery.robot.is_empty():
		auto_routes.append("/v1/robots/%s/recovery" % %Recovery.robot)
	auto_reading=true
	_auto_next()

func _auto_next() -> void:
	if not auto_reading:return
	if auto_identity!=[endpoint,token,account_id] or not _page_active() or busy or not %Inventory.pending.is_empty() or not %Recovery.pending.is_empty():
		_cancel_auto_read()
		return
	if auto_routes.is_empty():
		_finish_auto(true,200)
		return
	_send(auto_routes.pop_front(),{},true,true)

func _finish_auto(success:bool,status:int) -> void:
	read_failed=not success
	if success and not auto_routes.is_empty() and _page_active():
		_auto_next.call_deferred()
		return
	auto_reading=false
	auto_routes.clear()
	$PageRefresh.settled(success,status in [401,426],read_lease)
	read_lease=-1
	_display()

func _cancel_auto_read() -> void:
	if not auto_reading:return
	auto_reading=false
	auto_routes.clear()
	if is_instance_valid(dossier_http):
		_cancel_dossier()
	elif busy:
		_retire_http()
		busy=false
	$PageRefresh.defer(read_lease)
	read_lease=-1

func _response(result:int,status:int,headers:PackedStringArray,bytes:PackedByteArray,guard_id:String="") -> void:
	if auto_reading and (auto_identity!=[endpoint,token,account_id] or not _page_active() or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	if auto_reading and status==200:
		var decoded:Variant=JSON.parse_string(bytes.get_string_from_utf8())
		var valid:bool=decoded is Dictionary
		if valid and active_route=="/v1/inventory":valid=%Inventory.valid_snapshot(decoded.get("inventory"))
		elif valid and active_route.ends_with("/history"):valid=decoded.get("history") is Dictionary and decoded.history.get("totals") is Dictionary and decoded.history.totals.has_all(["battles","kills","output"])
		elif valid and active_route.ends_with("/recovery"):valid=decoded.get("recovery") is Dictionary and _valid_dossier(decoded.get("profile"))
		if not valid:
			busy=false
			%Message.text="资料暂未取得完整，正在恢复连接。"
			_finish_auto(false,0)
			return
	var automatic:=auto_reading
	var context:=[token,account_id]
	var saved_message:String=%Message.text
	_apply_response(result,status,headers,bytes,guard_id)
	if automatic:
		var payload:Variant=JSON.parse_string(bytes.get_string_from_utf8())
		var valid:bool=result==HTTPRequest.RESULT_SUCCESS and status==200 and payload is Dictionary
		if active_route.ends_with("/history") and retry_history:valid=false
		if valid and context==[token,account_id]:%Message.text=saved_message if not read_failed else ""
		_finish_auto(valid,status)
	elif result==HTTPRequest.RESULT_SUCCESS and status in [200,400,403,404,409]:
		read_failed=false
		$PageRefresh.request_now()

func _dossier_reply(result:int,status:int,headers:PackedStringArray,bytes:PackedByteArray,request:HTTPRequest) -> void:
	if request!=dossier_http:return
	if auto_reading and (auto_identity!=[endpoint,token,account_id] or not _page_active() or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	var automatic:=auto_reading
	var saved_message:String=%Message.text
	_apply_dossier_reply(result,status,headers,bytes,request)
	if dossier_retry_at>=0:return
	var payload:Variant=JSON.parse_string(bytes.get_string_from_utf8())
	var valid:bool=result==HTTPRequest.RESULT_SUCCESS and status==200 and _valid_dossier(payload)
	if automatic:
		if valid:%Message.text=saved_message if not read_failed else ""
		_finish_auto(valid,status)
	else:
		read_failed=not valid
		$PageRefresh.settled(valid,status in [401,426])
		if valid:$PageRefresh.request_now()
		_display()

func _retire_http() -> void:
	var previous:HTTPRequest=%HTTP
	previous.request_completed.disconnect(_response)
	previous.cancel_request()
	var replacement:=previous.duplicate(0) as HTTPRequest
	remove_child(previous)
	replacement.name="HTTP"
	add_child(replacement)
	replacement.owner=self
	replacement.request_completed.connect(_response)
	previous.queue_free()
