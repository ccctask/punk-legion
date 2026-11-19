extends CanvasLayer

signal destination(target:String)
signal power_observed(powered:bool)

const Endpoints:=preload("res://client/endpoints.gd")
const RESOURCES:= {"structure":"结构","components":"零件","energy":"能源"}
const POWER_REASON:= {"paused":"请在基地切换该站供能。","out_of_range":"请将站房移入核心或配电柱的供区。","budget":"请暂停其他设施，腾出 1 点电力。"}
var station_id:=""
var token:=""
var endpoint:=""
var due_ms:=-1
var watching:=false
var busy:=false
var leaving:=false
var app_paused:=false
var refresh_requested:=false
var auth_failed:=false
var read_failures:=0

func _ready() -> void:
	%Explore.pressed.connect(_leave.bind("explore"))
	%World.pressed.connect(_leave.bind("world"))
	%Back.pressed.connect(_leave.bind("base"))
	%Guard.pressed.connect(_leave.bind("guard"))
	%Refresh.pressed.connect(_read)
	%Refresh.hide()
	%Refresh.text="重新连接"
	$HTTP.request_completed.connect(_received)
	set_process(false)

func _leave(target:String) -> void:
	if leaving:return
	leaving=true
	set_process(false)
	$HTTP.cancel_request()
	destination.emit(target)

func _process(_delta:float) -> void:
	if not _page_active() or auth_failed or busy:return
	if refresh_requested or (due_ms>=0 and Time.get_ticks_msec()>=due_ms):
		_read()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true
		if is_node_ready() and watching and not leaving:set_process(true)

func _page_active() -> bool:
	return not leaving and not app_paused and visible and %Back.is_visible_in_tree()

func _read_failed(message:String) -> void:
	%Status.text=message
	%Refresh.visible=not auth_failed
	read_failures+=1
	due_ms=-1 if auth_failed else Time.get_ticks_msec()+mini(20000,5000*(1<<mini(read_failures-1,2)))
	set_process(not auth_failed)

func _exit_tree() -> void:
	leaving=true
	$HTTP.cancel_request()

func _read() -> void:
	if busy or leaving:return
	if not _page_active():
		refresh_requested=true
		return
	if auth_failed:return
	refresh_requested=false
	watching=true
	due_ms=-1
	set_process(false)
	busy=true
	%Guard.hide()
	%Refresh.disabled=true
	%Status.text="正在读取雷达信号…"
	if $HTTP.request(endpoint+"/v1/base/radar/"+station_id,Endpoints.headers(token))!=OK:
		var old:HTTPRequest=$HTTP
		old.request_completed.disconnect(_received)
		old.cancel_request()
		var next:=old.duplicate(0) as HTTPRequest
		remove_child(old)
		next.name="HTTP"
		add_child(next)
		next.request_completed.connect(_received)
		old.queue_free()
		_received(-1,0,PackedStringArray(),PackedByteArray())

func _received(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
	if leaving:return
	busy=false
	%Refresh.disabled=false
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		if code==401:
			auth_failed=true
			_read_failed("登录已失效，请返回基地重新登录。")
			%Explore.disabled=true
			%World.disabled=true
		elif code==404:
			auth_failed=true
			_read_failed("这座雷达站已不可用，请返回基地。")
			%Explore.disabled=true
			%World.disabled=true
		else:
			_read_failed("连接暂时中断，正在恢复雷达信号。")
		return
	var data:Variant=JSON.parse_string(body.get_string_from_utf8())
	var radar:Variant=data.get("radar") if data is Dictionary else null
	if not radar is Dictionary or radar.get("station_id")!=station_id or not (radar.get("server_now") is float or radar.get("server_now") is int) or not radar.has("next_refresh"):
		_read_failed("未能确认雷达信号，正在重新连接。")
		return
	var message:=_message(radar)
	if message.is_empty():
		_read_failed("未能确认雷达信号，正在重新连接。")
		return
	%Explore.disabled=false
	%World.disabled=false
	%Status.text=message
	%Refresh.hide()
	read_failures=0
	%Guard.visible=radar.stage in ["pending","warning","live"]
	power_observed.emit(radar.stage!="unpowered")
	var delay:=30
	if int(radar.next_refresh)>0:
		delay=clampi(int(radar.next_refresh)-int(radar.server_now),1,30)
	due_ms=Time.get_ticks_msec()+delay*1000
	set_process(true)

func _message(radar:Dictionary) -> String:
	match radar.get("stage"):
		"unpowered":return "雷达停电 · 扫描已停止\n"+str(POWER_REASON.get(radar.get("power_reason",""),"请查看基地供电。"))
		"quiet":return "暂无来袭信号"
		"resting":return "基地休整中，下一次来袭尚未安排。"
		"pending":return "已到预计预警时刻，等待正式警报。"
		"live":return "守备进行中，可查看当前战况。"
		"signal":
			var minutes:=int(radar.get("minutes",0))
			return "侦测到活动 · 预计 %d 分钟后发出正式警报" % minutes if minutes in range(1,91) else ""
		"warning":
			var path:Variant=radar.get("approach_path")
			var loot:Variant=radar.get("loot_preview")
			if not path is Array or path.size()<2 or not loot is Dictionary or not loot.get("exposed") is Dictionary or not loot.has("max_loot") or not radar.has("budget"):return ""
			var start:Variant=path[0]
			var step:Variant=path[1]
			if not start is Array or not step is Array or start.size()!=2 or step.size()!=2:return ""
			var dx:=int(step[0])-int(start[0])
			var dy:=int(step[1])-int(start[1])
			var direction:="西" if dx>0 else "东" if dx<0 else "北" if dy>0 else "南"
			var amounts:=PackedStringArray()
			for resource:String in RESOURCES:
				amounts.append("%s %d" % [RESOURCES[resource],int(loot.exposed.get(resource,0))])
			return "正式警报 · 从%s侧进入\n威胁预算 %d 点\n超出保险：%s\n失守最多损失 %d 份" % [direction,int(radar.budget),"、".join(amounts),int(loot.max_loot)]
	return ""
