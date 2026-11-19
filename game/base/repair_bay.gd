extends CanvasLayer

signal closed
const Endpoints := preload("res://client/endpoints.gd")
const RepairQuote := preload("res://profile/repair_quote.gd")
var affordable := false
var refresh_after_error := false
var endpoint := ""
var token := ""
var return_text := "返回基地"
var data := {}
var intent := {}
var busy := false
var submitting := false
var received_ms := 0
var next_read := 0
var last_second := -1
var waiting_for_expiry := false
var fresh := false
var app_paused := false
var refresh_requested := false
var auth_failed := false
var closing := false

func _ready() -> void:
	%Back.text = return_text
	%Back.pressed.connect(_close)
	%Refresh.pressed.connect(_read)
	%Refresh.hide()
	%Refresh.text="重新连接"
	%Repair.pressed.connect(_repair)
	%Robot.item_selected.connect(func(_index: int): _update_quote())
	$HTTP.request_completed.connect(_response)
	if not endpoint.is_empty():
		_read()

func _read() -> void:
	if not _page_active() or busy:
		refresh_requested=true
		return
	if not auth_failed:
		refresh_requested=false
		_send("/v1/recovery",{})

func _page_active() -> bool:
	return not closing and not app_paused and visible and %Back.is_visible_in_tree()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true

func _close() -> void:
	if closing:return
	closing=true
	$HTTP.cancel_request()
	closed.emit()

func _exit_tree() -> void:
	closing=true
	$HTTP.cancel_request()

func _repair() -> void:
	if %Repair.disabled:
		return
	var id := str(%Robot.get_selected_metadata())
	if intent.get("robot") != id:
		intent = {"robot":id,"key":Crypto.new().generate_random_bytes(16).hex_encode()}
	_send("/v1/robots/%s/recovery/repair" % id,{"key":intent.key})

func _send(route: String, body: Dictionary) -> void:
	busy = true
	submitting = not body.is_empty()
	_controls()
	var err: Error = $HTTP.request(endpoint+route,Endpoints.headers(token),HTTPClient.METHOD_GET if body.is_empty() else HTTPClient.METHOD_POST,"" if body.is_empty() else JSON.stringify(body))
	if err != OK:
		_retire_http()
		_failed()

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

func _failed() -> void:
	busy = false
	fresh = false
	refresh_after_error = true
	next_read = Time.get_ticks_msec()+5000
	%Status.text = "未能确认工位状态，正在重试。"
	_controls()

func _controls() -> void:
	%Back.disabled = busy and submitting
	%Refresh.visible=refresh_after_error and not auth_failed
	%Refresh.disabled = busy
	%Robot.disabled = not fresh or %Robot.item_count == 0
	%Repair.disabled = busy or not fresh or not affordable or %Robot.selected < 0 or int(data.get("available",0))<=0

func _response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if closing or not is_inside_tree():return
	busy = false
	var payload: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if result!=HTTPRequest.RESULT_SUCCESS or not payload is Dictionary or code>=500:
		_failed()
		return
	if code!=200:
		auth_failed=code==401
		intent.clear()
		fresh=false
		refresh_after_error=true
		%Status.text = {"repair_queue_full":"工位已满，请等候在修机体完工。","repair_not_needed":"机况已变化，请查看最新名单。","insufficient_stock":"送修材料不足。","unit_unavailable":"机体当前不可送修。"}.get(payload.get("error",""),"未能读取或更新维修工位。")
		next_read=0 if auth_failed else Time.get_ticks_msec()+1500
		if auth_failed:%Status.text="登录已过期，请返回基地重新登录。"
		_controls()
		return
	if payload.has("receipt"):
		intent.clear()
		%Status.text = "已送修，完工后机体自动归队。"
		_read()
		return
	var previous_id := str(%Robot.get_selected_metadata()) if %Robot.selected>=0 else ""
	data=payload.recovery
	received_ms=Time.get_ticks_msec()
	next_read=received_ms+4000
	waiting_for_expiry=false
	fresh=true
	if refresh_after_error:
		refresh_after_error=false
		%Status.text=""
	%Robot.clear()
	for unit: Dictionary in data.robots:
		if unit.state!="damaged":
			continue
		var index: int=%Robot.item_count
		%Robot.add_item("%s  ·  %s" % [unit.name,str(unit.id).left(8)])
		%Robot.set_item_metadata(index,unit.id)
		if unit.id==previous_id:
			%Robot.select(index)
	%Capacity.text = "开放工位 %d　空闲 %d　正在维修 %d 台\n%s" % [data.capacity,data.available,data.used,
		"修理站已供电，开放额外工位。" if int(data.powered_stations)>0 else "基础工位开放。为修理站供电可增加一个工位。"]
	%Robot.visible = %Robot.item_count > 0
	_update_quote()
	_update_queue()

func _update_quote() -> void:
	affordable = false
	%Quote.text = "没有待修机体。"
	if %Robot.selected >= 0:
		var id: String = %Robot.get_selected_metadata()
		for unit: Dictionary in data.robots:
			if unit.id == id:
				var quote := RepairQuote.read(unit, data.repair_stock)
				affordable = quote.affordable
				%Quote.text = "所选机体送修 · %d 秒\n%s" % [data.seconds, quote.text]
				break
	_controls()

func _update_queue() -> void:
	var stamp := int(data.server_now) + int((Time.get_ticks_msec()-received_ms)/1000.0)
	last_second=stamp
	var lines := PackedStringArray()
	for unit: Dictionary in data.robots:
		if unit.state=="repairing":
			var left := maxi(0,int(unit.due)-stamp)
			lines.append("%s · %s　%s" % [unit.name,str(unit.id).left(8),("剩余 %d 秒" % left) if left else "正在核对完工"])
			if left==0 and not waiting_for_expiry:
				waiting_for_expiry=true
				next_read=Time.get_ticks_msec()
	%Queue.text="\n".join(lines) if not lines.is_empty() else "目前没有机体在修。"

func _process(_delta: float) -> void:
	if not _page_active() or auth_failed:return
	if not data.is_empty() and int(data.server_now)+int((Time.get_ticks_msec()-received_ms)/1000.0)!=last_second:
		_update_queue()
	if not busy and (refresh_requested or (next_read>0 and Time.get_ticks_msec()>=next_read)):
		_read()
