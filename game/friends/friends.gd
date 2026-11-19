extends CanvasLayer
const Endpoints:=preload("res://client/endpoints.gd")

const Catalog:=preload("res://loadout/catalog.gd")

signal closed
const Base:=preload("res://base/base.tscn")
const Battle:=preload("res://camp/camp.tscn")
const STATES:={"offered":"待对方确认","accepted":"已预留","locked":"正在参战","returning":"战后归还","withdrawn":"已召回","declined":"已拒绝","expired":"已到期","complete":"已归还"}
const ERRORS:={"unknown_friend":"未找到该账号","self_friend":"不能添加自己","friendship_required":"双方须先同意好友关系","respond_to_request":"对方已申请，请选中后同意",
	"not_invited":"请由收到申请的玩家确认","aid_already_offered":"这台机体已有派遣提议","aid_budget":"双方合计超过12台或24点","recipient_needs_window":"受援者须先在地图登记本次进攻资格",
	"recipient_needs_robot":"受援方需要一台可出战的自有机体","unit_unavailable":"这台机体当前不可派遣","camp_role_changed":"接收方当前不能担任该营地的此方指挥","camp_contested":"攻防已经锁定",
	"design_slots_full":"可用方案栏已满，可在工坊腾出一栏后再保存","inactive_design":"请先在工坊激活该装配方案","conflicting_aid":"受援方与此机体其他派遣冲突","offer_inactive":"这项派遣已结束"}
var endpoint: String
var token: String
var busy:=false
var child_open:=false
var social:={}
var poll:=0.0
var keys:={}
var action:=""
var closing:=false
var app_paused:=false
var refresh_requested:=false
var connection_failed:=false
var auth_failed:=false
var read_failures:=0
var read_delay:=2.0

func _ready() -> void:
	%Side.add_item("协助进攻")
	%Side.add_item("协助驻防")
	%Site.add_item("黄铜转运场")
	%Site.add_item("线圈港")
	%Reload.pressed.connect(_manual_refresh)
	%Reload.hide()
	%Reload.text="重新连接"
	%Back.pressed.connect(func():
		closing=true
		closed.emit()
	)
	%Request.pressed.connect(func(): _request("request",{"friend":%FriendName.text.strip_edges()}))
	for pair in [[%Accept,"accept"],[%Remove,"remove"],[%Visit,"visit"]]:
		pair[0].pressed.connect(_friend_action.bind(pair[1]))
	%Offer.pressed.connect(_offer)
	%AgreeAid.pressed.connect(_aid.bind("accept-aid"))
	%RejectAid.pressed.connect(_aid.bind("reject-aid"))
	%Recall.pressed.connect(_aid.bind("recall"))
	%Join.pressed.connect(_join)
	%Share.pressed.connect(_share)
	%Save.pressed.connect(_save)
	for list in [%Pals,%Aids,%Shares]:
		list.item_selected.connect(func(_i): _enable())
	$HTTP.request_completed.connect(_response)
	refresh()

func refresh() -> void:
	if not _page_active() or busy:
		refresh_requested=true
		return
	if auth_failed:return
	refresh_requested=false
	_request("")

func _page_active() -> bool:
	return not closing and not child_open and not app_paused and visible and %Back.is_visible_in_tree()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true

func _exit_tree() -> void:
	closing=true
	$HTTP.cancel_request()

func _manual_refresh() -> void:
	if closing or child_open or (busy and not action.is_empty()):
		return
	%Hint.text="正在重新连接…"
	refresh()

func _retire_request() -> void:
	# A canceled transport may already have scheduled its completion signal.
	var old:HTTPRequest=$HTTP
	old.request_completed.disconnect(_response)
	old.cancel_request()
	var replacement:=old.duplicate(0) as HTTPRequest
	remove_child(old)
	replacement.name="HTTP"
	add_child(replacement)
	replacement.request_completed.connect(_response)
	old.queue_free()
	busy=false

func _request(op: String, fields: Dictionary={}) -> void:
	if closing or child_open or auth_failed:
		return
	if op.is_empty() and not _page_active():
		refresh_requested=true
		return
	if busy:
		if not action.is_empty() or op.is_empty():
			return
		_retire_request()
	busy=true
	action=op
	if not op.is_empty():
		%Hint.text="正在办理，请稍候…"
	_enable()
	var path:=endpoint+"/v1/friends"+("/"+op if not op.is_empty() else "")
	var err: Error=$HTTP.request(path,Endpoints.headers(token),
		HTTPClient.METHOD_GET if op.is_empty() else HTTPClient.METHOD_POST,"" if op.is_empty() else JSON.stringify(fields))
	if err!=OK:
		_retire_request()
		poll=0
		connection_failed=true
		read_failures+=1
		read_delay=minf(20.0,5.0*pow(2.0,mini(read_failures-1,2)))
		_enable()
		%Hint.text="无法连接档案服务"

func _response(status: int, code: int, _headers: PackedStringArray, raw: PackedByteArray) -> void:
	if closing or is_queued_for_deletion():
		return
	busy=false
	poll=0
	_enable()
	var data: Variant=JSON.parse_string(raw.get_string_from_utf8())
	if status!=HTTPRequest.RESULT_SUCCESS or not data is Dictionary or code!=200:
		var error: String=str(data.get("error","网络异常")) if data is Dictionary else "网络异常"
		%Hint.text=ERRORS.get(error,error)
		auth_failed=code==401
		if status!=HTTPRequest.RESULT_SUCCESS or code>=500 or code in [0,408,429] or not data is Dictionary:
			connection_failed=true
			read_failures+=1
			read_delay=minf(20.0,5.0*pow(2.0,mini(read_failures-1,2)))
		_enable()
		return
	if connection_failed:%Hint.text=""
	connection_failed=false
	read_failures=0
	read_delay=2.0
	if data.has("social"):
		social=data.social
		_display()
	if action!="":
		%Hint.text={"request":"已发送好友申请","accept":"已成为好友","remove":"关系已更新","share":"已分享装配定义","save":"已保存方案","offer":"派遣提议已发送","accept-aid":"援军已预留","recall":"召回请求已记录","reject-aid":"已拒绝派遣"}.get(action,"")
		if action in ["save","offer"]:
			keys.clear()
	if data.has("visit"):
		var scene:=Base.instantiate()
		scene.visit_layout=data.visit.layout
		scene.visitor_title="参观 · "+str(data.visit.name)
		_open(scene)

func _metadata(list: ItemList) -> Dictionary:
	var selected:=list.get_selected_items()
	return list.get_item_metadata(selected[0]) if selected.size() else {}

func _options(list: OptionButton, rows: Array) -> void:
	var previous: String=str(list.get_selected_metadata()) if list.item_count else ""
	list.clear()
	for r in rows:
		list.add_item(str(r.name))
		list.set_item_metadata(list.item_count-1,r.id)
		if r.id==previous:
			list.select(list.item_count-1)

func _list(list: ItemList, rows: Array, labels: Array) -> void:
	var previous: String=str(_metadata(list).get("id",""))
	list.clear()
	for i in rows.size():
		list.add_item(labels[i])
		list.set_item_metadata(i,rows[i])
		if rows[i].id==previous or i==0:
			list.select(i)

func _display() -> void:
	var pals: Array=social.friends
	_list(%Pals,pals,pals.map(func(p): return p.name+(" · 好友" if p.state=="friends" else (" · 已申请" if p.outgoing else " · 待同意"))))
	_options(%Robot,social.robots.filter(func(r):return r.ready))
	_options(%Design,social.designs)
	var aids: Array=social.aids
	_list(%Aids,aids,aids.map(func(a): return "%s → %s　%s · %s · %s" % [a.sender_name,a.recipient_name,a.robot_name+" · "+("线圈港" if a.node=="coil-depot" else "黄铜转运场"),"进攻" if a.side=="attacker" else "驻防",STATES.get(a.phase,a.phase)]))
	var shares: Array=social.shares
	_list(%Shares,shares,shares.map(_shared_summary))
	_enable()

func _shared_summary(design:Dictionary) -> String:
	var labels:=PackedStringArray([design.name,Catalog.HULL_LABELS[design.chassis]])
	for slot:String in Catalog.CHASSIS[design.chassis].slots:
		if Catalog.CHASSIS[design.chassis].slots[slot].get("optional",false) and design.slots.has(slot):
			labels.append(Catalog.LABELS[design.slots[slot]])
	labels.append("v%d" % int(design.version))
	return " · ".join(labels)

func _enable() -> void:
	%Reload.visible=connection_failed and not auth_failed
	var submitting:=busy and not action.is_empty()
	%Request.disabled=submitting
	%Reload.disabled=submitting
	var p:=_metadata(%Pals)
	var mutual: bool=p.get("state","")=="friends"
	%Visit.disabled=not mutual
	%Share.disabled=not mutual or not %Design.item_count
	%Offer.disabled=not mutual or not %Robot.item_count
	%Accept.disabled=p.get("state","")!="pending" or bool(p.get("outgoing",false))
	%Remove.disabled=p.is_empty()
	var aid:=_metadata(%Aids)
	var phase: String=aid.get("phase","")
	%AgreeAid.disabled=phase!="offered" or bool(aid.get("outgoing",false))
	%RejectAid.disabled=%AgreeAid.disabled
	%Recall.disabled=not bool(aid.get("outgoing",false)) or phase not in ["offered","accepted","locked"]
	%Join.disabled=not aid.get("admission") is Dictionary
	var design:=_metadata(%Shares)
	%Save.disabled=design.is_empty()
	if submitting or connection_failed or auth_failed:
		%Request.disabled=true
		for button in [%Visit,%Share,%Offer,%Accept,%Remove,%AgreeAid,%RejectAid,%Recall,%Join,%Save]:
			button.disabled=true
	if design.is_empty():
		%Definition.text="选择收到的装配查看定义与缺件。"
		return
	var slots:Dictionary=design.slots
	var missing:=PackedStringArray()
	for part in design.missing:
		missing.append("%s ×%d" % [Catalog.LABELS[part],int(design.missing[part])])
	var fields:=PackedStringArray(["底盘 · "+Catalog.HULL_LABELS[design.chassis]])
	for slot:String in Catalog.CHASSIS[design.chassis].slots:
		fields.append("%s · %s" % [Catalog.LABELS[slot],Catalog.LABELS[slots.get(slot,"")]])
	var lines:=PackedStringArray()
	for index in range(0,fields.size(),2):
		lines.append("　　".join(fields.slice(index,index+2)))
	lines.append("新装缺件 · "+("无" if missing.is_empty() else "、".join(missing)))
	%Definition.text="\n".join(lines)

func _friend_action(op: String) -> void:
	var p:=_metadata(%Pals)
	if p.has("name"):
		_request(op,{"friend":p.name})

func _key(marker: String) -> String:
	if not keys.has(marker):
		keys[marker]=Crypto.new().generate_random_bytes(12).hex_encode()
	return keys[marker]

func _offer() -> void:
	var p:=_metadata(%Pals)
	if p.is_empty() or not %Robot.item_count:
		return
	var rid: String=str(%Robot.get_selected_metadata())
	var side: String="attacker" if %Side.selected==0 else "defender"
	var node:String=["brass-yard","coil-depot"][%Site.selected]
	_request("offer",{"friend":p.name,"robot":rid,"node":node,"side":side,"key":_key(str(p.id)+rid+side+node)})

func _aid(op: String) -> void:
	var a:=_metadata(%Aids)
	if not a.is_empty():
		_request(op,{"aid":a.id})

func _share() -> void:
	var p:=_metadata(%Pals)
	if not p.is_empty() and %Design.item_count:
		_request("share",{"friend":p.name,"design":str(%Design.get_selected_metadata())})

func _save() -> void:
	var design:=_metadata(%Shares)
	if not design.is_empty():
		_request("save",{"share":design.id,"key":_key(design.id)})

func _join() -> void:
	if closing or child_open or (busy and not action.is_empty()):
		return
	var a:=_metadata(%Aids)
	if not a.get("admission") is Dictionary:
		return
	var scene:=Battle.instantiate()
	scene.endpoint=endpoint
	scene.token=token
	scene.node_id=a.node
	scene.initial_admission=a.admission
	_open(scene)

func _open(scene: Node) -> void:
	if busy:
		_retire_request()
	child_open=true
	hide()
	get_parent().add_child(scene)
	scene.closed.connect(func():
		scene.queue_free()
		child_open=false
		show()
		refresh()
	)

func _process(delta: float) -> void:
	if not _page_active() or busy or auth_failed:
		return
	poll+=delta
	if refresh_requested or poll>=read_delay:
		refresh()
