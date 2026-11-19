extends PanelContainer
const Endpoints:=preload("res://client/endpoints.gd")

signal closed
signal preview(robot:Dictionary,style:String)
const STYLES := {"base":"基础黄铜","mint":"薄荷珐琅"}
const STATES := {"created":"待支付","paid":"已支付，待发货","delivered":"已发货","cancelled":"已取消","failed":"支付失败","refunded":"已退款"}
const RESULTS := {"success":"模拟成功并发货","paid":"模拟已扣款、暂缓发货","retry":"查询支付结果并补发","cancel":"模拟取消","fail":"模拟支付失败","refund":"模拟退款"}
var endpoint := ""
var token := ""
var account := ""
var data := {}
var pending := {}
var busy := false
var latest := ""
var auto_reading := false
var read_failed := false
var request_is_read := false
var read_lease := -1
var issued_identity: Array = []

func _ready() -> void:
	$PageRefresh.configure(func(): return is_visible_in_tree() and not token.is_empty(), func(): return not busy and pending.is_empty(), 10.0)
	$PageRefresh.read_due.connect(_auto_read)
	for id:String in RESULTS:
		%Result.add_item(RESULTS[id])
	%Buy.pressed.connect(_buy)
	%Commit.pressed.connect(_pay)
	%Equip.pressed.connect(_equip)
	%Reload.pressed.connect(_send)
	%Back.pressed.connect(func(): closed.emit())
	%Product.item_selected.connect(func(_i): _paint_choice("mint" if data.catalog[%Product.selected].sku=="paint_mint" else str(data.robots[%Robots.selected].paint)); _show())
	%Styles.item_selected.connect(func(_i): _show())
	%Robots.item_selected.connect(func(_i): _paint_choice(data.robots[%Robots.selected].paint); _show())
	%Orders.item_selected.connect(func(_i): _show())
	$HTTP.request_completed.connect(_reply)
	var cfg:=ConfigFile.new()
	if cfg.load(_file())==OK:
		pending=cfg.get_value("shop","pending",{})
	_send()

func _file() -> String:
	return "user://shop_"+(endpoint+account).sha256_text()+".cfg"

func _begin(route:String,body:Dictionary) -> void:
	_cancel_auto_read()
	if busy or not pending.is_empty():
		return
	pending={"route":route,"body":body}
	var cfg:=ConfigFile.new()
	cfg.set_value("shop","pending",pending)
	if cfg.save(_file())!=OK:
		pending.clear()
		%Message.text="无法保存订单操作，请检查本地存储。"
		return
	_send()

func _buy() -> void:
	_begin("/order",{"sku":data.catalog[%Product.selected].sku,"key":Crypto.new().generate_random_bytes(16).hex_encode()})

func _pay() -> void:
	_begin("/simulate",{"order":data.orders[%Orders.selected].id,"result":RESULTS.keys()[%Result.selected]})

func _equip() -> void:
	_begin("/equip",{"robot":data.robots[%Robots.selected].id,"paint":STYLES.keys()[%Styles.selected]})

func _auto_read() -> void:
	if busy or not pending.is_empty():
		$PageRefresh.defer()
		return
	auto_reading=true
	read_lease=$PageRefresh.current_lease()
	_send(true)

func _cancel_auto_read() -> void:
	if not auto_reading:return
	_retire_http()
	busy=false
	auto_reading=false
	$PageRefresh.defer(read_lease)
	read_lease=-1

func _send(read_only:=false) -> void:
	if busy:return
	if read_only and not pending.is_empty():
		$PageRefresh.defer(read_lease)
		return
	issued_identity=[endpoint,token,account]
	busy=true
	request_is_read=read_only or pending.is_empty()
	_show()
	var path:=endpoint+"/v1/store"+("" if request_is_read else str(pending.route))
	var result:Error=$HTTP.request(path,Endpoints.headers(token),
		HTTPClient.METHOD_GET if request_is_read else HTTPClient.METHOD_POST,"" if request_is_read else JSON.stringify(pending.body))
	if result!=OK:
		_retire_http()
		busy=false
		if request_is_read:
			read_failed=true
			$PageRefresh.settled(false,false,read_lease)
			read_lease=-1
		auto_reading=false
		%Message.text="连接中断，正在恢复商店连接。" if pending.is_empty() else "本次操作结果待确认，可恢复原操作。"
		_show()

func _reply(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
	if auto_reading and (not is_visible_in_tree() or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	if issued_identity!=[endpoint,token,account]:
		busy=false
		read_failed=true
		$PageRefresh.settled(false,true,read_lease)
		return
	busy=false
	var background:=auto_reading
	var recovered:=read_failed
	auto_reading=false
	var payload:Variant=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	if request_is_read:
		read_failed=not (result==HTTPRequest.RESULT_SUCCESS and status==200 and payload is Dictionary and payload.get("store") is Dictionary)
		$PageRefresh.settled(not read_failed,status in [401,426],read_lease)
		read_lease=-1
		if read_failed:
			%Message.text="账号已失效，请返回档案重新登录。" if status==401 else "商店连接暂不可用，正在恢复连接。"
			_show()
			return
	if result!=HTTPRequest.RESULT_SUCCESS or not payload is Dictionary or status>=500:
		%Message.text="连接中断，正在恢复商店连接。" if pending.is_empty() else "操作结果尚未确认，恢复会沿用原订单。"
		_show()
		return
	if not pending.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_file()))
		pending.clear()
	if status!=200:
		%Message.text={"product_limit":"商品持有或待付数量已达上限","paint_not_owned":"请先购买此涂装","test_payments_disabled":"此环境未启用模拟支付","session_expired":"请重新登录档案"}.get(payload.get("error",""),"本次操作未完成，正在更新订单。")
		$PageRefresh.request_now()
		_show()
		return
	var product:int=maxi(0,%Product.selected)
	var unit:=str(data.robots[%Robots.selected].id) if not data.is_empty() and %Robots.selected>=0 else ""
	var old_style:=str(STYLES.keys()[%Styles.selected]) if %Styles.selected>=0 else ""
	var previously_owned:Array=data.get("styles",[])
	var selected_order:=str(data.orders[%Orders.selected].id) if not data.is_empty() and %Orders.selected>=0 else latest
	var order_id:=str(payload.get("order",selected_order))
	data=payload.store
	%Product.clear()
	for entry:Dictionary in data.catalog:%Product.add_item(str(entry.name))
	%Product.select(product)
	%Robots.clear()
	for robot:Dictionary in data.robots:
		%Robots.add_item(str(robot.name)+" · "+str(STYLES.get(robot.paint,"基础黄铜")))
		if robot.id==unit:%Robots.select(%Robots.item_count-1)
	%Styles.clear()
	for key:String in STYLES:%Styles.add_item(str(STYLES[key])+(" · 已拥有" if key in data.styles else " · 可预览"))
	if %Robots.selected>=0 and (old_style.is_empty() or old_style in previously_owned and old_style not in data.styles):
		old_style=str(data.robots[%Robots.selected].paint)
	_paint_choice(old_style)
	%Orders.clear()
	for order:Dictionary in data.orders:
		%Orders.add_item("%s · %s · %s" % [str(order.id).left(8),"薄荷珐琅" if order.sku=="paint_mint" else "方案栏",STATES[order.state]])
		if order.id==order_id:%Orders.select(%Orders.item_count-1)
	latest=order_id
	if not background or recovered:
		%Message.text=""
	_show()

func _process(_delta:float) -> void:
	if auto_reading and (not is_visible_in_tree() or not $PageRefresh.foreground):_cancel_auto_read()

func _paint_choice(id:String) -> void:
	%Styles.select(maxi(0,STYLES.keys().find(id)))

func _show() -> void:
	if not is_node_ready():return
	var locked:=(busy and not auto_reading) or read_failed or not pending.is_empty() or data.is_empty()
	for button in [%Buy,%Equip,%Commit]:button.disabled=locked
	%Reload.disabled=busy
	%Reload.visible=read_failed or not pending.is_empty()
	%Reload.text="恢复本次操作" if not pending.is_empty() else "重新连接"
	%Back.disabled=busy and not auto_reading
	if data.is_empty():return
	var product:Dictionary=data.catalog[%Product.selected]
	%Capacity.text="常用方案 %d 格，含免费 6 格，加购上限 2 格。" % int(data.capacity)
	%Info.text="%s · %d 模拟点。%s。已拥有 %d，可再购买 %d。" % [product.name,product.price,product.purpose,product.owned,product.remaining]
	%Buy.disabled=locked or not data.test_payment or int(product.remaining)==0
	var style:String=STYLES.keys()[%Styles.selected]
	%Equip.disabled=locked or %Robots.selected<0 or style not in data.styles
	preview.emit(data.robots[%Robots.selected] if %Robots.selected>=0 else {},style)
	%Commit.disabled=locked or not data.test_payment or %Orders.selected<0
	%Events.text="暂无订单"
	if %Orders.selected>=0:
		var states:=PackedStringArray()
		for event:Dictionary in data.orders[%Orders.selected].events:
			states.append(STATES[event.state])
		%Events.text=" → ".join(states)

func _retire_http() -> void:
	var previous:HTTPRequest=$HTTP
	previous.request_completed.disconnect(_reply)
	previous.cancel_request()
	var replacement:=previous.duplicate(0) as HTTPRequest
	remove_child(previous)
	replacement.name="HTTP"
	add_child(replacement)
	replacement.request_completed.connect(_reply)
	previous.queue_free()
