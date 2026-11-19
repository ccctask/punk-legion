extends PanelContainer

signal apply_requested(fields:Dictionary)
signal retry_write
signal dismissed

const Catalog:=preload("res://loadout/catalog.gd")
const Endpoints:=preload("res://client/endpoints.gd")
const REASONS:={"unchanged_fit":"实装与方案一致，无需更换。","different_chassis":"底盘不同，请先更换底盘。","unit_unavailable":"机体忙碌或需要维修。","robot_busy":"机体忙碌，暂不能换装。","parts_full":"背包余位不足，无法放回拆下的部件。","design_part_missing":"缺少上述闲置部件。","inactive_design":"方案不在可用的常用位置。","fit_changed":"实装或可用部件已变化，请重新预览。"}
var target:={}
var plan:={}
var endpoint:=""
var token:=""
var request:HTTPRequest

func _ready() -> void:
	%Cancel.pressed.connect(dismiss)
	%Refresh.pressed.connect(load_plan)
	%Confirm.pressed.connect(func():
		if %Confirm.disabled:return
		if not %Refresh.visible:
			retry_write.emit()
		elif not plan.is_empty() and plan.can_apply:
			apply_requested.emit({"robot":plan.robot,"design":plan.design,"fingerprint":plan.fingerprint}))

func open(url:String,auth:String,robot:Dictionary,design:Dictionary) -> void:
	endpoint=url
	token=auth
	target={"robot":robot.id,"design":design.id}
	%Subject.text="%s · #%s　　%s · v%d" % [robot.name,str(robot.id).left(8),design.name,int(design.revision)]
	show()
	load_plan()

func dismiss() -> void:
	_stop_read()
	plan={}
	target={}
	token=""
	hide()
	dismissed.emit()

func _stop_read() -> void:
	if request:
		var old:=request
		request=null
		old.cancel_request()
		old.queue_free()

func load_plan() -> void:
	if target.is_empty():return
	_stop_read()
	plan={}
	%Rows.text=""
	%Reason.text="正在核对实体机体与空闲背包…"
	%Confirm.disabled=true
	%Confirm.text="确认换装"
	%Refresh.show()
	var http:=HTTPRequest.new()
	http.timeout=6
	add_child(http)
	request=http
	http.request_completed.connect(_received.bind(http))
	var err:=http.request(endpoint+"/v1/workshop/apply-preview",Endpoints.headers(token),HTTPClient.METHOD_POST,JSON.stringify(target))
	if err!=OK:_received(HTTPRequest.RESULT_CANT_CONNECT,0,[],PackedByteArray(),http)

func _received(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray,http:HTTPRequest) -> void:
	if http!=request:return
	request=null
	http.queue_free()
	var parser:=JSON.new()
	var data:Variant=parser.data if not body.is_empty() and parser.parse(body.get_string_from_utf8())==OK else null
	if result!=HTTPRequest.RESULT_SUCCESS or status!=200 or not data is Dictionary or not data.get("plan") is Dictionary:
		%Reason.text="未能读取该机体的换装预览，请重新预览。"
		return
	var info:Dictionary=data.plan
	var hull: Dictionary = Catalog.CHASSIS.get(info.get("design_chassis",""),{})
	if info.get("robot")!=target.robot or info.get("design")!=target.design or hull.is_empty() or not info.get("slots") is Array or info.slots.size()!=hull.slots.size() or not info.get("fingerprint") is String:
		%Reason.text="未能确认所选机体和方案，请重新预览。"
		return
	plan=info
	%Subject.text="%s · #%s　　%s · v%d" % [plan.robot_name,str(plan.robot).left(8),plan.design_name,int(plan.revision)]
	var lines:=PackedStringArray()
	for slot:Dictionary in plan.slots:
		var before:=_part(slot.current,slot.current_id)
		var after:=_part(slot.wanted,slot.item)
		var move:String
		match slot.action:
			"keep":move="沿用 "+before
			"empty":move="保持空槽"
			"missing":move="缺少 "+_part(slot.wanted,"")
			"remove":move="方案留空"
			_:move="装入 "+after
		if slot.disposition=="bag":move+="　·　"+before+" 退回背包"
		elif slot.disposition=="discard":move+="　·　"+before+" 为救援件，拆下后回收"
		elif slot.action=="missing" and not str(slot.current_id).is_empty():move+="　·　当前 "+before
		lines.append(str(Catalog.LABELS[slot.slot])+"　"+move)
	%Rows.text="\n".join(lines)
	var reason:String=REASONS.get(plan.reason,"可按此预览确认换装。" if plan.can_apply else "当前不能套用此方案。")
	%Reason.text="%s → %s底盘　背包 %d → %d / %d\n%s" % [Catalog.HULL_LABELS[plan.chassis],Catalog.HULL_LABELS[plan.design_chassis],plan.bag_used,plan.bag_after,plan.bag_capacity,reason]
	%Confirm.disabled=not plan.can_apply

func _part(what:String,id:String) -> String:
	return str(Catalog.LABELS.get(what,what))+(" #"+id.left(8) if not id.is_empty() else "")

func write_status(message:String,retry:bool,finished:bool) -> void:
	plan={}
	%Reason.text=message
	%Refresh.visible=finished
	%Confirm.disabled=not retry
	%Confirm.text="重查本次换装" if retry else "确认换装"
