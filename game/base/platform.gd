extends CanvasLayer
const Endpoints:=preload("res://client/endpoints.gd")
const NAMES:={"survey_radar":"测绘雷达","chimney_arm":"烟囱炮臂","rivet_repeater":"铆钉连发器","cannon":"气炮","jammer":"脉冲干扰器","repair_arm":"维修臂","drill":"钻头","boiler":"锅炉","reinforced_boiler":"重型锅炉","eye":"光学眼","visor":"面罩"}
const ERRORS:={"platform_locked":"本次袭击已锁定防守配置","stale_layout":"布局已变化，正在更新平台状态","item_unavailable":"此件已被占用或已移出背包","incompatible_part":"此件接口不适配","parts_full":"背包已满，请先腾出一格","relief_part":"救援配额件仅限救援机使用","unknown_platform":"平台已移除"}
signal closed
var endpoint: String
var token: String
var platform: String
var data: Dictionary={}
var busy:=false
var intent: Dictionary={}
var read_failed := false
var reading := false
var read_lease := -1
var issued_identity: Array = []
var auto_reading := false

func _ready() -> void:
	$PageRefresh.configure(func(): return visible and not token.is_empty(), func(): return not busy and intent.is_empty(), 10.0)
	$PageRefresh.read_due.connect(func():
		auto_reading=true
		read_lease = $PageRefresh.current_lease()
		_send({}))
	%Back.pressed.connect(func():closed.emit())
	%Refresh.pressed.connect(func():_send(intent if not intent.is_empty() else {}))
	%Parts.item_selected.connect(func(_i):_render())
	%Install.pressed.connect(_act.bind("install"))
	%Detach.pressed.connect(_act.bind("detach"))
	%Remove.pressed.connect(_act.bind("remove"))
	$HTTP.request_completed.connect(_received)
	_send({})

func _act(action:String) -> void:
	_cancel_auto_read()
	if busy or data.is_empty():
		return
	var item: String=str(data.parts[%Parts.selected].id) if action=="install" and %Parts.selected>=0 else ""
	if intent.get("action")!=action or intent.get("item")!=item or intent.get("revision")!=data.revision:
		intent={"action":action,"item":item,"revision":int(data.revision),"key":Crypto.new().generate_random_bytes(14).hex_encode()}
	_send(intent)

func _send(body:Dictionary) -> void:
	if busy:
		return
	issued_identity=[endpoint,token,platform]
	busy=true
	reading=body.is_empty()
	_render()
	if $HTTP.request(endpoint+"/v1/base/platforms/"+platform,Endpoints.headers(token),HTTPClient.METHOD_GET if body.is_empty() else HTTPClient.METHOD_POST, "" if body.is_empty() else JSON.stringify(body))!=OK:
		_retire_http()
		busy=false
		if reading:
			read_failed=true
			$PageRefresh.settled(false,false,read_lease)
			read_lease=-1
		auto_reading=false
		_render()
		%Status.text="连接中断，正在恢复连接。"

func _received(result:int,code:int,_headers:PackedStringArray,raw:PackedByteArray) -> void:
	if auto_reading and (not visible or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	if issued_identity!=[endpoint,token,platform]:
		busy=false
		read_failed=true
		$PageRefresh.settled(false,true,read_lease)
		return
	busy=false
	auto_reading=false
	var decoded:Variant=JSON.parse_string(raw.get_string_from_utf8()) if not raw.is_empty() else null
	if reading:
		read_failed=not (result==HTTPRequest.RESULT_SUCCESS and code==200 and decoded is Dictionary and decoded.get("platform") is Dictionary)
		$PageRefresh.settled(not read_failed,code in [401,404,426],read_lease)
		read_lease=-1
		if read_failed:
			_render()
			%Status.text="平台已不可用，请返回基地。" if code==404 else ("账号已失效，请重新登录。" if code==401 else "连接中断，正在恢复连接。")
			return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not decoded is Dictionary:
		_render()
		%Status.text=str(ERRORS.get(decoded.get("error",""),"操作结果尚未确认，可恢复本次操作。")) if decoded is Dictionary else "连接中断，正在恢复连接。"
		return
	if decoded.has("receipt"):
		intent.clear()
		if decoded.receipt.operation=="platform_remove":
			closed.emit()
		else:
			_send({})
		return
	var selected_id:=str(data.parts[%Parts.selected].id) if not data.is_empty() and %Parts.selected>=0 else ""
	data=decoded.platform
	intent.clear()
	%Parts.clear()
	for row in data.parts:
		%Parts.add_item("%s · %s%s" % [NAMES.get(row.definition,row.definition),str(row.id).left(8),"" if row.compatible else " · 不兼容"])
		if str(row.id)==selected_id:%Parts.select(%Parts.item_count-1)
	_render()

func _process(_delta:float) -> void:
	if auto_reading and (not visible or not $PageRefresh.foreground):_cancel_auto_read()

func _render() -> void:
	var selected: Dictionary=data.parts[%Parts.selected] if not data.is_empty() and %Parts.selected>=0 else {}
	var blocked:=(busy and not auto_reading) or read_failed or not intent.is_empty() or data.is_empty() or bool(data.get("locked",false))
	%Install.disabled=blocked or not selected.get("compatible",false)
	%Detach.disabled=blocked or not data.get("mounted") is Dictionary
	%Remove.disabled=blocked
	%Refresh.disabled=busy
	%Refresh.visible=read_failed or not intent.is_empty()
	%Refresh.text="恢复本次操作" if not intent.is_empty() else "重新连接"
	%Back.disabled=busy and not auto_reading
	if data.is_empty():
		return
	var held:Variant=data.mounted
	var label:String=str(NAMES.get(held.definition,held.definition))+" · "+str(held.id).left(8) if held is Dictionary else ("原装哨戒炮（换装后替换）" if data.legacy else "空底座")
	%Mounted.text="当前装配　"+label+("　· 防守快照已锁定" if data.locked else "")
	%Status.text="背包中没有闲置部件；可从玩家档案制作气炮或维修臂。"
	if not selected.is_empty():
		%Status.text=str({"rivet_repeater":"每 0.4 秒发射一枚铆钉，射程 3.5 格，单击 3 点。","cannon":"气炮瞄准进入射程的野生机。","jammer":"此件兼容 AUX。当前野生突入机只会移动撞击核心，没有可延迟的武器或维修动作。","repair_arm":"维修臂为射程内受损的驻防机恢复耐久，最多四次。"} .get(selected.definition,"此件不匹配固定平台的炮架或维修接口。"))

func _cancel_auto_read() -> void:
	if not auto_reading:return
	_retire_http()
	busy=false
	auto_reading=false
	$PageRefresh.defer(read_lease)
	read_lease=-1

func _retire_http() -> void:
	var previous:HTTPRequest=$HTTP
	previous.request_completed.disconnect(_received)
	previous.cancel_request()
	var replacement:=previous.duplicate(0) as HTTPRequest
	remove_child(previous)
	replacement.name="HTTP"
	add_child(replacement)
	replacement.request_completed.connect(_received)
	previous.queue_free()
