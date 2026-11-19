extends CanvasLayer
const Endpoints:=preload("res://client/endpoints.gd")

signal closed
const Pin := preload("res://world/pin.tscn")
const Party := preload("res://expedition/expedition.tscn")
const Pump := preload("res://pump/outing.tscn")
const Contest := preload("res://camp/camp.tscn")
const TreasureSite := preload("res://treasure/treasure.tscn")
var endpoint := ""
var token := ""
var world := {}
var selected := ""
var card_node := ""
var pins := {}
var intents := {}
var busy := false
var anchor_ms := 0
var next_refresh := 0
var displayed_second := -1
var in_party := false
var pending_route := ""
var pending_node := ""
var receipts := {}
var sync_message := ""
var app_paused := false
var refresh_requested := false
var connection_failed := false
var auth_failed := false
var read_failures := 0
var closing := false

func _ready() -> void:
	%DefenseAlerts.enter.connect(func(id:String):
		if not busy and not in_party:_enter_contest(id,""))
	visibility_changed.connect(_sync_alerts)
	_sync_alerts()
	%Sync.pressed.connect(refresh)
	%Back.pressed.connect(_close)
	%Sync.hide()
	%Sync.text="重新连接"
	%Action.pressed.connect(_act)
	%WorkshopCard.pressed.connect(func(): card_node=selected; _render())
	%CardBack.pressed.connect(func(): card_node=""; _render())
	%Contest.pressed.connect(_open_contest)
	%PumpCoop.pressed.connect(_open_pump.bind("coop"))
	%Chart.resized.connect(_position_pins)
	$HTTP.request_completed.connect(_response)
	refresh()

func _sync_alerts() -> void:
	if closing or not is_inside_tree() or is_queued_for_deletion():return
	var alerts:=get_node_or_null("%DefenseAlerts")
	if not is_instance_valid(alerts) or not alerts.is_inside_tree() or alerts.is_queued_for_deletion():return
	alerts.set_screen(_page_active(),endpoint,token)
	if _page_active():refresh_requested=true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true
	else:return
	if not closing and is_inside_tree() and not is_queued_for_deletion() and is_node_ready():_sync_alerts()

func _page_active() -> bool:
	if closing or not is_inside_tree() or is_queued_for_deletion() or app_paused or in_party or not visible:return false
	var back:=get_node_or_null("%Back") as Control
	return is_instance_valid(back) and not back.is_queued_for_deletion() and back.is_visible_in_tree()

func _close() -> void:
	if closing:return
	var alerts:=get_node_or_null("%DefenseAlerts")
	if is_instance_valid(alerts) and alerts.is_inside_tree() and not alerts.is_queued_for_deletion():alerts.set_screen(false,endpoint,token)
	closing=true
	var http:=get_node_or_null("HTTP") as HTTPRequest
	if is_instance_valid(http):http.cancel_request()
	closed.emit()

func _exit_tree() -> void:
	closing=true
	var http:=get_node_or_null("HTTP") as HTTPRequest
	if is_instance_valid(http):http.cancel_request()

func _connection_issue(message:String) -> void:
	connection_failed=true
	read_failures+=1
	next_refresh=Time.get_ticks_msec()+mini(20000,5000*(1<<mini(read_failures-1,2)))
	%Sync.visible=not auth_failed
	_feedback(message)

func refresh() -> void:
	if not _page_active() or busy:
		refresh_requested=true
		return
	if auth_failed:return
	refresh_requested=false
	_request("/v1/world",{})

func _request(route: String, body: Dictionary) -> void:
	if busy or closing or auth_failed:
		return
	busy = true
	%DefenseAlerts.set_locked(true)
	pending_route = route
	pending_node = "" if route=="/v1/world" else selected
	%Sync.disabled = true
	%Action.disabled = true
	var headers := Endpoints.headers(token)
	var err: Error = $HTTP.request(endpoint+route,headers,HTTPClient.METHOD_GET if body.is_empty() else HTTPClient.METHOD_POST,"" if body.is_empty() else JSON.stringify(body))
	if err != OK:
		_retire_http()
		busy = false
		%DefenseAlerts.set_locked(false)
		_connection_issue("连接暂时中断，正在恢复连接。")
		%Sync.disabled = false

func _retire_http() -> void:
	var old:HTTPRequest=$HTTP
	old.request_completed.disconnect(_response)
	old.cancel_request()
	var next:=old.duplicate(0) as HTTPRequest
	remove_child(old)
	next.name="HTTP"
	add_child(next)
	next.request_completed.connect(_response)
	old.queue_free()

func _response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if closing or not is_inside_tree():return
	busy = false
	%DefenseAlerts.set_locked(false)
	%Sync.disabled = false
	next_refresh = Time.get_ticks_msec()+15000
	if result != HTTPRequest.RESULT_SUCCESS:
		_connection_issue("连接暂时中断，正在恢复连接。")
		return
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary:
		_connection_issue("未能确认地图状态，正在重新连接。")
		return
	if code != 200:
		var reason: String = str(data.get("error",code))
		if code==401:
			auth_failed=true
			%Sync.hide()
		elif code>=500 or code in [408,429]:
			_connection_issue("地图服务暂不可用，正在恢复连接。")
			return
		_feedback({"camp_closed":"营地尚未开放","entry_cutoff":"服务器已停止接收新场次","qualification_expired":"本次资格已过期",
			"session_expired":"账号已在其他窗口登录，请返回档案重新登录","key_conflict":"登记请求不一致，正在核对当前状态","world_configuration_unavailable":"日程尚未发布"}.get(reason,reason))
		if pending_route!="/v1/world" and code in [404,409]:
			refresh()
		return
	if data.has("world"):
		connection_failed=false
		read_failures=0
		%Sync.hide()
		sync_message = ""
		world = data.world
		if world.get("pump_ruin") is Dictionary:
			world.nodes.append(world.pump_ruin)
		if world.get("treasure") is Dictionary and int(world.server_time)<int(world.treasure.closes) and not world.nodes.any(func(n): return n.type=="treasure"):
			world.nodes.append(world.treasure)
		anchor_ms = Time.get_ticks_msec()
		_sync_pins()
		_render()
	if data.has("admission"):
		var a: Dictionary = data.admission
		_feedback("已登记资格 #%s · 日程 v%d\n结算期限 %s" % [str(a.id).left(8),int(a.window_version),_local(int(a.settle_until))],str(a.id))

func _feedback(message:String, grant_id := "") -> void:
	if pending_node.is_empty():
		sync_message = message
	else:
		receipts[pending_node] = {"text":message,"grant":grant_id}
	_render()
	if world.is_empty():
		%Feedback.text = sync_message

func _sync_pins() -> void:
	for id in pins:
		%Chart.remove_child(pins[id])
		pins[id].queue_free()
	pins.clear()
	if not world.nodes.any(func(node): return node.id == selected):
		selected = world.nodes[0].id
	for node in world.nodes:
		var button := Pin.instantiate() as Button
		button.name = str(node.id)
		button.text = str({"party":"探索 · ","treasure":"秘宝 · ","pump_ruin":"遗迹 · "}.get(node.type,"营地 · "))+str(node.name)
		button.self_modulate = Color("#b5efe0") if node.type=="party" else Color("#f2c587")
		button.pressed.connect(select.bind(str(node.id)))
		%Chart.add_child(button)
		pins[node.id] = button
	_position_pins()

func _position_pins() -> void:
	if world.is_empty():
		return
	var placed:Array[Rect2]=[]
	var links:Array[Dictionary]=[]
	for node in world.nodes:
		if not pins.has(node.id):
			continue
		var button: Button = pins[node.id]
		button.size = button.get_combined_minimum_size()
		var anchor:Vector2=Vector2(float(node.x),float(node.y))*%Chart.size
		var preferred:=anchor-button.size/2
		var limit:Vector2=(%Chart.size-button.size).max(Vector2.ZERO)
		var xs:Array[float]=[clampf(preferred.x,0,limit.x)]
		var ys:Array[float]=[clampf(preferred.y,0,limit.y)]
		for area:Rect2 in placed:
			xs.append(clampf(area.position.x-button.size.x-6,0,limit.x))
			xs.append(clampf(area.end.x+6,0,limit.x))
			ys.append(clampf(area.position.y-button.size.y-6,0,limit.y))
			ys.append(clampf(area.end.y+6,0,limit.y))
		var best:=INF
		var pos:=preferred.clamp(Vector2.ZERO,limit)
		for x:float in xs:
			for y:float in ys:
				var trial:=Rect2(Vector2(x,y),button.size)
				if placed.any(func(other:Rect2):return other.grow(2).intersects(trial)):
					continue
				var d:=trial.position.distance_squared_to(preferred)
				if d<best:
					best=d
					pos=trial.position
		button.position=pos
		var bounds:=Rect2(pos,button.size)
		placed.append(bounds)
		if pos.distance_squared_to(preferred)>2:
			links.append({"at":anchor,"edge":anchor.clamp(bounds.position,bounds.end)})
	%Chart.links=links
	%Chart.queue_redraw()

func select(id: String) -> void:
	card_node = ""
	selected = id
	$Backdrop/Layout/Main/Detail/Card/Scroll.scroll_vertical = 0
	_render()

func _node() -> Dictionary:
	for node in world.get("nodes",[]):
		if node.id == selected:
			return node
	return {}

func _server_now() -> int:
	return int(world.get("server_time",0))+floori((Time.get_ticks_msec()-anchor_ms)/1000.0)

func _local(timestamp: int) -> String:
	var bias := int(Time.get_time_zone_from_system().bias)
	var d := Time.get_datetime_dict_from_unix_time(timestamp+bias*60)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [d.year,d.month,d.day,d.hour,d.minute,d.second]

func _span(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds/3600,seconds%3600/60,seconds%60]

func _render() -> void:
	var node := _node()
	if node.is_empty():
		return
	var messages:=PackedStringArray()
	if not sync_message.is_empty():messages.append(sync_message)
	if receipts.has(selected):
		var receipt:Dictionary=receipts[selected]
		var grant:Variant=node.get("admission")
		if not str(receipt.grant).is_empty() and (not grant is Dictionary or str(grant.id)!=str(receipt.grant) or _server_now()>=int(grant.settle_until)):
			receipts.erase(selected)
		else:
			messages.append(str(receipt.text))
	%Feedback.text="\n".join(messages)
	for id in pins:
		pins[id].modulate = Color.WHITE if id==node.id else Color(0.84,0.84,0.84)
	var now := _server_now()
	var zone := int(Time.get_time_zone_from_system().bias)
	%Footer.text = "服务器日程 v%d　·　本地 UTC%s%02d:%02d　·　%s" % [int(world.version),"+" if zone>=0 else "−",absi(zone)/60,absi(zone)%60,_local(now)]
	if world.get("treasure") is Dictionary and now>=int(world.treasure.closes):
		%Footer.text+="　·　下次秘宝 "+_local(int(world.treasure.next))
	%Name.text = node.name
	var card:Variant = node.get("workshop_card")
	%WorkshopCard.visible = card is Dictionary
	if card_node != selected or not card is Dictionary:
		card_node = ""
	var opened := not card_node.is_empty()
	%PublicCard.visible = opened
	$Backdrop/Layout/Main/Detail/Card/Scroll.visible = not opened
	$Backdrop/Layout/Main/Detail/Card/Actions.visible = not opened
	if opened:
		var lines := PackedStringArray(["工坊名片 · %s" % card.name, "持有的公开营地"])
		for holding:Dictionary in card.holdings:
			lines.append("%s · %s" % [holding.name, holding.resource])
		lines.append("铭牌刻名 · %s" % card.inscription if card.inscription is String else "尚未公开铭牌")
		if not sync_message.is_empty(): lines.append(sync_message)
		%CardText.text = "\n".join(lines)
		return
	%Action.disabled = busy or connection_failed or auth_failed
	%Contest.disabled=connection_failed or auth_failed
	%PumpCoop.disabled=connection_failed or auth_failed
	%Action.show()
	%Contest.visible = _supports_contest(node)
	%PumpCoop.visible=node.type=="pump_ruin"
	if node.type=="pump_ruin":
		%Kind.text="限时遗迹 · 合作 PvE"
		%Info.text="清守卫、校准双阀、开箱并各自撤离。今日首胜额度 %d 通用零件，预计入库 %d。" % [node.reward_available,node.expected_components]
		var price: String={"energy":"1 能源","voucher":"1 救援凭证","unavailable":"缺少入场物资"}[node.departure_quote.source]
		%Window.text="每人出发 · %s\n关闭 %s · 下次开放 %s" % [price,_local(node.closes),_local(node.next)]
		%Clock.text="距关闭 "+_span(node.closes-now) if now<node.closes else "已关闭 · 已出发可重连"
		%Action.text="单人 PvE · 准备"
		return
	if node.type=="treasure":
		%Kind.text="限时秘宝 · 玩家对抗"
		%Info.text="可单人或与一位好友组队。宿敌可抢先拾取；每人最多带两件，撤离才入库。机体保留并依战损维修。"
		%Window.text="入场截止　%s\n撤离截止　%s" % [_local(int(node.cutoff)),_local(int(node.closes))]
		%Clock.text=("距入场截止　"+_span(int(node.cutoff)-now)) if now<int(node.cutoff) else "已截止 · 下次开放　"+_local(int(node.next))
		%Action.text="查看争夺区与队伍"
		return
	%Contest.text = "接管营地防守" if node.get("contested",false) and node.get("mine",false) else ("营地产出与驻防" if node.get("mine",false) else "进入营地指挥台")
	if node.type=="party":
		%Kind.text = "组队探索"
		%Info.text = "回收资源　%s\n探索区无法占领。组队成员各自带回所得物资。" % node.resource
		%Window.text = ""
		%Clock.text = "全天开放"
		%Action.text = "进入队伍大厅"
		return
	%Kind.text = "公开资源营地"
	%Info.text = "归属　%s\n资源　%s\n进入争夺需实时参战，已有营地可能被其他玩家夺取。" % [str(node.owner) if node.owner!=null else "未占领",node.resource]
	if node.get("contested",false):
		%Info.text+="\n当前有一场占领战进行中。"
	var window: Dictionary = node.current if node.current is Dictionary and now<int(node.current.closes_at) else node.next
	var state := "closed" if now<int(window.opens_at) or now>=int(window.closes_at) else ("open" if now<int(window.cutoff_at) else "cutoff")
	%Window.text = "开放　%s\n截止　%s\n关闭　%s" % [_local(int(window.opens_at)),_local(int(window.cutoff_at)),_local(int(window.closes_at))]
	if state!="closed" and int(node.next.opens_at)!=int(window.opens_at):
		%Window.text += "\n下次　%s" % _local(int(node.next.opens_at))
	var deadline := int(window.opens_at) if state=="closed" else (int(window.cutoff_at) if state=="open" else int(window.closes_at))
	%Clock.text = "%s　%s" % [{"closed":"距开放","open":"距入场截止","cutoff":"已截止 · 距关闭"}[state],_span(maxi(0,deadline-now))]
	if not _supports_contest(node):
		%Kind.text = "公开营地 · 日程预览"
		%Info.text = "资源　%s\n此营地当前仅展示开放日程。" % node.resource
		%Action.hide()
		return
	var grant: Variant = node.admission
	var granted := grant is Dictionary and now<int(grant.settle_until)
	%Action.text = "查看已登记资格" if granted else ("登记参战资格" if state=="open" else "暂不接收新入场")
	%Action.disabled = busy or connection_failed or auth_failed or (not granted and state!="open")

func _supports_contest(node: Dictionary) -> bool:
	return node.get("type")=="camp" and node.get("contest_available",node.get("id")=="brass-yard")

func _open_contest() -> void:
	if not _supports_contest(_node()):
		return
	var node:=_node()
	_enter_contest(str(node.id),str(node.admission.id) if node.admission is Dictionary else "")

func _enter_contest(id:String,admission_id:String) -> void:
	var scene:=Contest.instantiate()
	scene.endpoint=endpoint
	scene.token=token
	scene.node_id=id
	scene.grant=admission_id
	hide()
	in_party=true
	get_parent().add_child(scene)
	scene.closed.connect(func():
		scene.queue_free()
		show()
		in_party=false
		refresh()
	)

func _open_pump(mode: String) -> void:
	var node:=_node()
	if node.get("type")!="pump_ruin" or in_party:return
	var scene:=Pump.instantiate()
	scene.endpoint=endpoint
	scene.token=token
	scene.pump_mode=mode
	scene.window_id=str(node.id)
	scene.configure_sessions(get_node("/root/Solo"),get_node("/root/Party"))
	hide()
	in_party=true
	get_parent().add_child(scene)
	scene.closed.connect(func():
		scene.queue_free()
		show()
		in_party=false
		refresh()
	)

func _act() -> void:
	var node := _node()
	if busy or node.is_empty():
		return
	if node.type=="pump_ruin":
		_open_pump("solo")
		return
	if node.type=="treasure":
		var scene:=TreasureSite.instantiate()
		scene.endpoint=endpoint
		scene.token=token
		in_party=true
		hide()
		get_parent().add_child(scene)
		scene.closed.connect(func():
			scene.queue_free()
			show()
			in_party=false
			refresh()
		)
		return
	if node.type=="party":
		var scene := Party.instantiate()
		scene.endpoint=endpoint
		scene.token=token
		scene.start_in_party=true
		scene.configure_sessions(get_node("/root/Solo"),get_node("/root/Party"))
		in_party=true
		hide()
		get_parent().add_child(scene)
		scene.closed.connect(func():
			scene.queue_free()
			show()
			in_party=false
			refresh()
		)
		return
	if not _supports_contest(node):
		return
	if node.admission is Dictionary and _server_now()<int(node.admission.settle_until):
		_request("/v1/world/admissions/"+str(node.admission.id),{})
		return
	var window: Dictionary = node.current if node.current is Dictionary and _server_now()<int(node.current.closes_at) else node.next
	var marker := "%s-%d-%d-%s" % [str(node.id),int(world.version),int(window.opens_at),str(node.get("completed_grant",""))]
	if not intents.has(marker):
		intents[marker]=Crypto.new().generate_random_bytes(16).hex_encode()
	_request("/v1/world/admit",{"node":node.id,"key":intents[marker]})

func _process(_delta: float) -> void:
	if not _page_active() or auth_failed:
		return
	if not busy and (refresh_requested or Time.get_ticks_msec()>=next_refresh):
		refresh()
	if not world.is_empty() and _server_now()!=displayed_second:
		displayed_second=_server_now()
		if world.get("treasure") is Dictionary and displayed_second>=int(world.treasure.closes) and pins.has(world.treasure.id):
			world.nodes=world.nodes.filter(func(n):return n.type!="treasure")
			_sync_pins()
		_render()
