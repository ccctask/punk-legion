extends CanvasLayer

signal closed
const Endpoints := preload("res://client/endpoints.gd")
const OUTCOMES := {"win":"胜利","loss":"战败","defeat":"战败","draw":"平局","retreat":"撤退","expired":"到期"}
var endpoint := ""
var token := ""
var state := {}
var request: HTTPRequest
var craft_keys := {}
var read_failed := false
var read_lease := -1
var auto_reading := false
var issued_identity: Array = []

func _ready() -> void:
	$PageRefresh.configure(func(): return visible and not token.is_empty(), func(): return request==null, 15.0)
	$PageRefresh.read_due.connect(func():
		auto_reading=true
		read_lease=$PageRefresh.current_lease()
		_read(_page(),_shelf()))
	%Back.pressed.connect(func(): closed.emit())
	%Refresh.pressed.connect(func(): _read(_page(), _shelf()))
	%Prev.pressed.connect(func(): _read(_page()-1, _shelf()))
	%Next.pressed.connect(func(): _read(_page()+1, _shelf()))
	%Older.pressed.connect(func(): _read(_page(), _shelf()-1))
	%Newer.pressed.connect(func(): _read(_page(), _shelf()+1))
	%Eligible.item_selected.connect(func(_i): _controls())
	%Collection.item_selected.connect(func(_i): _controls())
	%Craft.pressed.connect(_craft)
	%Display.pressed.connect(_display)
	%CardPublic.pressed.connect(func():
		if not %CardPublic.disabled:
			_send("public","/public",{"plaque":state.displayed,"public":not state.card_public}))
	_read(0,0)

func _page() -> int:
	return int(state.get("page",0))

func _shelf() -> int:
	return int(state.get("collection_page",0))

func _read(page:int, shelf:int) -> void:
	_send("read","?page=%d&collection_page=%d" % [page,shelf],{})

func _row(picker:OptionButton) -> Dictionary:
	return picker.get_item_metadata(picker.selected) if picker.selected >= 0 else {}

func _identity(row:Dictionary) -> String:
	return "%s/%s" % [row.get("robot",""),row.get("battle","")]

func _title(row:Dictionary) -> String:
	return "%s · 战役 #%s · %s" % [row.name,str(row.battle).left(8),OUTCOMES.get(row.outcome,row.outcome)]

func _populate(picker:OptionButton, rows:Array, empty:String) -> void:
	var previous := _identity(_row(picker))
	picker.clear()
	for row:Dictionary in rows:
		var i:=picker.item_count
		picker.add_item(_title(row) + " · 机体 #" + str(row.robot).left(8))
		picker.set_item_metadata(i,row)
		if _identity(row)==previous: picker.select(i)
	if rows.is_empty():
		picker.add_item(empty)
		picker.set_item_metadata(0,{})

func _craft() -> void:
	var row:=_row(%Eligible)
	if row.is_empty() or %Craft.disabled:return
	var identity:=_identity(row)
	if not craft_keys.has(identity): craft_keys[identity]=Crypto.new().generate_random_bytes(16).hex_encode()
	_send("craft","/craft",{"robot":row.robot,"battle":row.battle,"key":craft_keys[identity]})

func _display() -> void:
	if not %Display.disabled: _send("display","/display",{"plaque":_row(%Collection).id})

func _send(action:String, suffix:String, data:Dictionary) -> void:
	if request!=null:
		if auto_reading:_cancel_auto_read()
		else:return
	issued_identity=[endpoint,token]
	request=HTTPRequest.new()
	request.timeout=7
	add_child(request)
	request.request_completed.connect(_done.bind(request,action),CONNECT_ONE_SHOT)
	_controls()
	var err:=request.request(endpoint+"/v1/base/plaques"+suffix,Endpoints.headers(token),
		HTTPClient.METHOD_GET if data.is_empty() else HTTPClient.METHOD_POST,
		"" if data.is_empty() else JSON.stringify(data))
	if err!=OK:_done(-1,0,[],PackedByteArray(),request,action)

func _done(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray,http:HTTPRequest,action:String) -> void:
	if http!=request:return
	if auto_reading and (not visible or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	request=null
	http.queue_free()
	auto_reading=false
	if issued_identity!=[endpoint,token]:
		read_failed=true
		$PageRefresh.settled(false,true,read_lease)
		_controls()
		return
	var reply:Variant=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	var recovered_read:=read_failed
	if action=="read":
		var valid_read:bool=result==HTTPRequest.RESULT_SUCCESS and status==200 and reply is Dictionary and reply.get("plaques") is Dictionary
		read_failed=not valid_read
		$PageRefresh.settled(valid_read,status in [401,426],read_lease)
		read_lease=-1
	if result!=HTTPRequest.RESULT_SUCCESS or not reply is Dictionary or status>=500:
		read_failed=action=="read"
		%Feedback.text="连接中断，正在恢复连接。" if action=="read" else "本次操作结果尚未确认，请恢复本次操作核对。"
	elif status!=200:
		var code:String=reply.get("error","")
		%Feedback.text={"insufficient_stock":"私仓材料不足","already_commissioned":"该记录已制作铭牌","unknown_record":"这条参战记录已不可用","unknown_plaque":"这块铭牌已不可用","display_changed":"当前陈列已改变，请重新核对"}.get(code,"请求未完成 · %s" % status)
		if action!="read":_read(_page(),_shelf())
	elif reply.get("plaques") is Dictionary:
		if recovered_read and action=="read":%Feedback.text=""
		read_failed=false
		state=reply.plaques
		_populate(%Eligible,state.eligible,"没有可委托的已结算记录")
		_populate(%Collection,state.collection,"尚未收藏铭牌")
		if action=="craft":
			var receipt:Dictionary=reply.receipt
			%Feedback.text="制作成功 · 实扣 %d 结构、%d 零件 · 收据 #%s" % [-int(receipt.changes.get("structure",0)),-int(receipt.changes.get("components",0)),str(receipt.id).left(8)]
		elif action=="display":%Feedback.text="已免费换展"
		elif action=="public":%Feedback.text="已向地图访客公开刻名" if state.card_public else "已撤下公开刻名"
	else:%Feedback.text="资料尚未取得完整，正在恢复连接"
	_controls()

func _process(_delta:float) -> void:
	if auto_reading and (not visible or not $PageRefresh.foreground):_cancel_auto_read()

func _controls() -> void:
	var reading:bool=(request!=null and not auto_reading) or read_failed
	var price:Dictionary=state.get("price",{})
	var stock:Dictionary=state.get("stock",{})
	var can_pay:=not price.is_empty()
	for resource:String in price:
		if int(stock.get(resource,0))<int(price[resource]):can_pay=false
	%Quote.text="读取私仓报价…" if price.is_empty() else "每块 %d 结构、%d 零件、%d 能源 · 私仓 %d 结构、%d 零件%s" % [int(price.structure),int(price.components),int(price.energy),int(stock.structure),int(stock.components)," · 材料不足" if not can_pay else ""]
	var current:Variant=state.get("displayed_item")
	%CardPublic.disabled=reading or not current is Dictionary
	%CardPublic.text="从公开名片撤下刻名" if state.get("card_public",false) else "向公开地图访客展示刻名"
	%Displayed.text="基地当前陈列 · "+_title(current) if current is Dictionary else "基地尚未陈列铭牌"
	%Page.text=str(_page()+1)
	%Shelf.text=str(_shelf()+1)
	%Prev.disabled=reading or _page()==0
	%Older.disabled=reading or _shelf()==0
	%Next.disabled=reading or not state.get("more",false)
	%Newer.disabled=reading or not state.get("collection_more",false)
	%Refresh.disabled=request!=null
	%Refresh.visible=read_failed
	%Refresh.text="重新连接"
	%Eligible.disabled=reading or _row(%Eligible).is_empty()
	%Collection.disabled=reading or _row(%Collection).is_empty()
	%Craft.disabled=%Eligible.disabled or not can_pay
	%Display.disabled=%Collection.disabled or _row(%Collection).get("id")==state.get("displayed")

func _cancel_auto_read() -> void:
	if not auto_reading:return
	var previous:=request
	request=null
	if is_instance_valid(previous):
		previous.cancel_request()
		previous.queue_free()
	auto_reading=false
	$PageRefresh.defer(read_lease)
	read_lease=-1
