extends VBoxContainer

signal enter(node_id:String)
const Endpoints:=preload("res://client/endpoints.gd")
var endpoint := ""
var token := ""
var screen_visible := false
var background := false
var locked := false
var delay := 3.0
var active:HTTPRequest
var buttons := {}
var restart_queued := false
var closing := false

func _ready() -> void:
	$Poll.timeout.connect(_read)
	_queue_restart()

func set_screen(shown:bool,url:String,bearer:String) -> void:
	if shown==screen_visible and url==endpoint and bearer==token:return
	screen_visible=shown
	endpoint=url
	token=bearer
	_queue_restart()

func _notification(what:int) -> void:
	var paused:bool
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		paused=false
	else:return
	if background==paused:return
	background=paused
	_queue_restart()

func _stop_read() -> void:
	var poll:=get_node_or_null("Poll") as Timer
	if is_instance_valid(poll):poll.stop()
	if is_instance_valid(active):
		active.cancel_request()
		active.queue_free()
	active=null

func _queue_restart() -> void:
	_stop_read()
	if closing or not is_inside_tree() or is_queued_for_deletion():return
	if restart_queued:return
	restart_queued=true
	_restart.call_deferred()

func _restart() -> void:
	restart_queued=false
	if not _live():return
	_show_rows([])
	delay=3.0
	_read()

func _live() -> bool:
	return not closing and is_inside_tree() and is_node_ready() and not is_queued_for_deletion()

func _exit_tree() -> void:
	closing=true
	restart_queued=false
	_stop_read()

func _read() -> void:
	if not _live() or restart_queued or active or not screen_visible or background or endpoint.is_empty() or token.is_empty():return
	var http:=HTTPRequest.new()
	http.timeout=3
	add_child(http)
	active=http
	http.request_completed.connect(_done.bind(http),CONNECT_ONE_SHOT)
	if http.request(endpoint+"/v1/camp/defense-alerts",Endpoints.headers(token))!=OK:
		_done(-1,0,[],PackedByteArray(),http)

func _done(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray,http:HTTPRequest) -> void:
	if not _live() or http!=active:return
	active=null
	http.queue_free()
	if not screen_visible or background or restart_queued:return
	var data:Variant=JSON.parse_string(body.get_string_from_utf8()) if result==HTTPRequest.RESULT_SUCCESS and status==200 and not body.is_empty() else null
	if data is Dictionary and data.get("alerts") is Array and typeof(data.get("poll_after")) in [TYPE_FLOAT,TYPE_INT]:
		var rows:Array=data.alerts
		if rows.all(func(r):return r is Dictionary and r.get("node") is String and r.get("name") is String and r.get("battle") is String):
			_show_rows(rows)
			delay=3.0
			$Poll.start(clampf(float(data.poll_after),1,60))
			return
	_show_rows([])
	if status in [401,403,426]:return
	delay=minf(30,delay*2)
	$Poll.start(delay)

func _show_rows(rows:Array) -> void:
	var retained:={}
	for row:Dictionary in rows:
		var id:String=row.node
		retained[id]=true
		if not buttons.has(id):
			var button:=Button.new()
			button.name=id.validate_node_name()
			button.pressed.connect(func():
				if not locked and buttons.get(id)==button and screen_visible and not background:enter.emit(id))
			add_child(button)
			buttons[id]=button
		buttons[id].text="%s遇袭 · 回防" % row.name
		buttons[id].disabled=locked
	for id:String in buttons.keys():
		if retained.has(id):continue
		var retired:Button=buttons[id]
		buttons.erase(id)
		retired.hide()
		retired.disabled=true
		retired.mouse_filter=Control.MOUSE_FILTER_IGNORE
		retired.queue_free()
	visible=not buttons.is_empty()

func set_locked(value:bool) -> void:
	locked=value
	for button:Button in buttons.values():button.disabled=value
