extends Node3D

signal closed
const Endpoints:=preload("res://client/endpoints.gd")
const Unit:=preload("res://battle/unit.tscn")
const Sim:=preload("res://battle/simulation.gd")
const LobbyIntent:=preload("res://treasure/lobby_intent.gd")
const Kit:=preload("res://assets/salvage/kit.gd")
const SITE_SCENES := {
	"copper_lowland": preload("res://treasure/sites/copper_lowland.tscn"),
	"old_crane_yard": preload("res://treasure/sites/old_crane_yard.tscn"),
	"fogbell_junction": preload("res://treasure/sites/fogbell_junction.tscn"),
}
const SITE_NAMES := {"copper_lowland":"铜管洼地","old_crane_yard":"旧吊车台","fogbell_junction":"雾钟岔道"}
# Three 250 ms authority steps tolerate normal polling and delivery jitter.
const TRACK_IDLE_GRACE:=0.75
const SEALED := preload("res://assets/salvage/sealed_crate.tscn")
const ITEM_MESHES := {"components":"Coil","energy":"Fuel","structure":"Scrap"}
const RESOURCES:={"unknown":"密封物资","structure":"结构","energy":"能源","components":"零件"}
const ERRORS:={"item_taken":"该物资已被拿走","out_of_reach":"需要先移动到物资旁","bag_full":"已满，请选择要放下的货物","return_to_exit":"请把所有存活机体移回己方撤离点","friendship_required":"须先成为双向好友","unknown_friend":"找不到该好友","treasure_closed":"当前事件已停止接收入场","treasure_already_entered":"成员已有本事件队伍或已完成本事件","unit_unavailable":"机体无法出击"}
var endpoint: String
var token: String
var net: Node
var overview:={}
var busy:=false
var attached:=false
var polling:=0.0
var checks:={}
var drawn_roster:Array=[]
var drawn_group:=""
var saved_picks:Array=[]
var sending:=""
var pending_intent:Dictionary={}
var intent_policy:=LobbyIntent.new()
var view_valid:=false
var closing:=false
var page_epoch:=0
var request_number:=0
var active_http:HTTPRequest
var active_callback:Callable
var selected:=""
var grouped:Array[String]=[]
var role_filter:=""
var units:={}
var views:={}
var markers:={}
var bag: Array=[]
var note:=""
var same_tick_seconds:=0.0
var room_id := ""
var shown_site := ""
var app_paused:=false
var refresh_requested:=false
var auth_failed:=false
var connection_failed:=false
var read_failures:=0
var read_delay:=2.0

func _ready() -> void:
	net=get_node("/root/Treasure")
	net.changed.connect(_sync)
	net.acknowledged.connect(func(_seq:int,error:String):
		note=str(ERRORS.get(error,error)) if not error.is_empty() else "指令已确认"
		_sync())
	$Camera.make_current()
	%Back.pressed.connect(_close)
	%Start.pressed.connect(_lobby_action.bind("create"))
	%Friend.text_changed.connect(func(_name:String):_lobby_controls())
	%Submit.pressed.connect(_lobby_action.bind("select"))
	%Station.pressed.connect(_confirm_roster)
	%Claim.pressed.connect(_lobby_action.bind("cancel"))
	%Reconnect.pressed.connect(_join)
	%ReadReconnect.pressed.connect(func(): refresh_requested=true)
	%All.pressed.connect(_cycle)
	%RoleSelect.chosen.connect(_group)
	%RoleSelect.get_node("CustomGroups").recalled.connect(func(ids: Array[String]):
		role_filter = "custom"
		grouped.assign(ids)
		selected = grouped[0])
	%GroupAll.pressed.connect(_group.bind("all"))
	%Core.pressed.connect(_take)
	%Focus.pressed.connect(_focus)
	%Repair.pressed.connect(func():_move(Vector2(-7 if int(net.state.get("side",0))==0 else 7,0)))
	%Retreat.pressed.connect(func():_issue({"action":"extract"}))
	_lobby_controls()
	_request("")

func _label(parent:Node3D, text:String, height:float) -> void:
	var tag:=Label3D.new()
	tag.name="CargoLabel"
	tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size=30
	tag.pixel_size=0.014
	tag.text=text
	tag.position.y=height
	parent.add_child(tag)

func _exit_tree() -> void:
	_invalidate_page()
	$BattleAudio.reset_audio()
	if attached:net.disconnect_mission()

func _close() -> void:
	if closing:return
	_invalidate_page()
	closed.emit()

func _invalidate_page() -> void:
	closing=true
	page_epoch+=1
	view_valid=false
	pending_intent.clear()
	_retire_request(false)

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
		if is_node_ready() and not attached:
			# Only a read is retired here. An already-issued write is observed later, never resent.
			if busy and sending.is_empty():_retire_request()
			pending_intent.clear()
			view_valid=false
			_lobby_controls()
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true

func _page_active() -> bool:
	return not closing and not app_paused and is_visible_in_tree()

func _retire_request(replace:=true) -> void:
	var old:HTTPRequest=active_http
	active_http=null
	request_number+=1
	busy=false
	sending=""
	if not is_instance_valid(old):return
	if active_callback.is_valid() and old.request_completed.is_connected(active_callback):
		old.request_completed.disconnect(active_callback)
	active_callback=Callable()
	old.cancel_request()
	if replace and not closing and is_inside_tree():
		var next:=old.duplicate(0) as HTTPRequest
		remove_child(old)
		next.name="HTTP"
		add_child(next)
	old.queue_free()

func _lobby_action(action:String) -> void:
	if not _page_active() or attached or auth_failed or not view_valid or not pending_intent.is_empty() or (busy and not sending.is_empty()):return
	var intent:=intent_policy.capture(action,overview,_checked(),%Friend.text)
	if intent.is_empty():return
	if busy:
		pending_intent=intent
		%Feedback.text="正在刷新名单，随后核对本次操作。"
		_lobby_controls()
	else:
		_request(intent.suffix,intent.body)

func _request(suffix:String, body:Dictionary={}) -> void:
	if closing or attached or busy or not is_inside_tree():return
	if auth_failed:return
	if not _page_active():
		if suffix.is_empty():refresh_requested=true
		return
	if suffix.is_empty():refresh_requested=false
	if not suffix.is_empty() and not view_valid:return
	busy=true
	sending=suffix
	request_number+=1
	var serial:=request_number
	var epoch:=page_epoch
	var http:HTTPRequest=$HTTP
	active_http=http
	active_callback=_response.bind(http,serial,epoch,suffix)
	http.request_completed.connect(active_callback)
	_lobby_controls()
	var err:Error=http.request(endpoint+"/v1/treasure"+suffix,Endpoints.headers(token),HTTPClient.METHOD_GET if suffix.is_empty() else HTTPClient.METHOD_POST,"" if suffix.is_empty() else JSON.stringify(body))
	if err!=OK:
		_fail_view(suffix,"档案连接失败")

func _fail_view(suffix:String, reason:String, network_error:=true) -> void:
	var unsent:=not pending_intent.is_empty()
	view_valid=false
	pending_intent.clear()
	_retire_request()
	polling=0.0 if suffix.is_empty() else 2.0
	connection_failed=network_error
	if network_error:read_failures+=1
	read_delay=minf(20.0,5.0*pow(2.0,mini(read_failures-1,2))) if network_error else 2.0
	%Feedback.text=("连接中断，本次待处理操作未发送。" if unsent else reason) if suffix.is_empty() else reason+"；连接恢复后将核对原操作结果。"
	_lobby_controls()

func _response(result:int,code:int,_headers:PackedStringArray,bytes:PackedByteArray,http:HTTPRequest,serial:int,epoch:int,suffix:String) -> void:
	if closing or not is_inside_tree() or is_queued_for_deletion() or attached or http!=active_http or serial!=request_number or epoch!=page_epoch:return
	if not _page_active():
		pending_intent.clear()
		_retire_request()
		view_valid=false
		refresh_requested=true
		return
	var json:=JSON.new()
	var parse_error:Error=json.parse(bytes.get_string_from_utf8())
	if parse_error!=OK:
		_fail_view(suffix,"秘宝资料暂不可用，正在恢复连接。")
		return
	var data:Variant=json.data
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary:
		if code==401:auth_failed=true
		var reason:=str(data.get("error","网络异常")) if data is Dictionary else "网络异常"
		_fail_view(suffix,_lobby_error(reason),result!=HTTPRequest.RESULT_SUCCESS or code>=500 or code in [0,408,429] or not data is Dictionary)
		return
	if not intent_policy.valid_view(data.get("treasure")):
		_fail_view(suffix,"秘宝资料暂不可用，正在恢复连接。")
		return
	# Capture current manual choices before rendering can replace the controls.
	var chosen:=_checked()
	var friend_name:String=%Friend.text
	var pending:=pending_intent
	pending_intent={}
	_retire_request()
	view_valid=true
	connection_failed=false
	read_failures=0
	read_delay=2.0
	polling=0.0
	overview=data.treasure
	%Feedback.text=""
	if overview.has("admission"):
		_lobby_controls()
		_join()
		return
	_render_lobby()
	if not pending.is_empty():
		var decision:=intent_policy.revalidate(pending,overview,chosen,friend_name)
		if decision.decision=="send":
			_request(decision.suffix,decision.body)
		else:
			%Feedback.text=decision.reason

func _lobby_error(reason:String) -> String:
	match reason:
		"stale_roster":return "阵容已变动，请核对新名单后重新确认。"
		"loadout_changed":return "装备已有变动，请重新提交变更机体的名单，再由双方确认。"
		"roster_incomplete":return "两位队员都提交机体后才能确认。"
		"personal_point_limit","point_limit":return "超过个人指挥点上限，请减少机体或更换装配。"
		"personal_unit_limit","unit_limit":return "所选台数不符合个人名额，请调整名单。"
	return str(ERRORS.get(reason,reason))

func _confirm_roster() -> void:
	_lobby_action("confirm")

func _my_member(group:Dictionary) -> Dictionary:
	for member:Dictionary in group.get("members",[]):
		if member.mine:return member
	return {}

func _render_lobby() -> void:
	var group:Dictionary=overview.group if overview.group is Dictionary else {}
	var gid:=str(group.get("id",""))
	var member:=_my_member(group)
	var saved:Array=member.get("robots",[])
	var changed_group:=gid!=drawn_group
	var chosen:=_checked()
	if changed_group or saved!=saved_picks:
		if not saved.is_empty():chosen=saved.duplicate()
	if drawn_roster!=overview.roster or changed_group or saved!=saved_picks:
		var first:=checks.is_empty() and saved.is_empty()
		for child in %Roster.get_children():
			%Roster.remove_child(child)
			child.queue_free()
		checks.clear()
		for row:Dictionary in overview.roster:
			var check:=CheckButton.new()
			check.text="%s · %s · %d 点" % [row.name,str(row.id).left(8),row.points]
			check.button_pressed=row.id in chosen or (first and checks.is_empty())
			check.toggled.connect(func(_on:bool):_lobby_controls())
			%Roster.add_child(check)
			checks[row.id]=check
		drawn_roster=overview.roster.duplicate(true)
	drawn_group=gid
	saved_picks=saved.duplicate()
	%Title.text="%s · 限时秘宝" % overview.event.name
	_lobby_controls()

func _lobby_controls() -> void:
	%ReadReconnect.visible=connection_failed and not auth_failed and not attached
	%ReadReconnect.disabled=busy
	if closing or attached or not view_valid:
		for button in [%Start,%Submit,%Station,%Claim]:button.disabled=true
		return
	var group:Dictionary=overview.group if overview.group is Dictionary else {}
	var duo:bool=group.members.size()==2 if not group.is_empty() else not %Friend.text.strip_edges().is_empty()
	var point_cap:=int(group.get("point_cap",12 if duo else 24))
	var unit_cap:=int(group.get("unit_cap",6 if duo else 12))
	var queued:bool=group.get("phase","")=="queued"
	var chosen:=_checked()
	var points:=0
	for row:Dictionary in overview.roster:
		if row.id in chosen:points+=int(row.points)
	var mine:=_my_member(group)
	if queued:
		chosen=mine.robots
		points=int(mine.points)
	%Budget.text="我的选择 %d/%d 台 %d/%d 指挥点" % [chosen.size(),unit_cap,points,point_cap]
	var problems:=PackedStringArray()
	if chosen.size()>unit_cap:problems.append("台数超出 %d 台" % (chosen.size()-unit_cap))
	if points>point_cap:problems.append("指挥点超出 %d 点" % (points-point_cap))
	if not problems.is_empty():%Budget.text+=" "+", ".join(problems)
	%Info.text="单人最多 12 台、24 点。双人每人最多 6 台、12 点。\n每人可携 2 件货物，撤离后入库。落败会丢失货物，机体按战损维修。\n参与奖 · 本人首次拾取成功，即使失能或超时也可得 1 个通用零件。按开场 UTC 日期，每人每日限一次。货物先入库，零件仓满也计次数。"
	var salvage:Dictionary=overview.salvage
	var day:=Time.get_date_string_from_unix_time(int(salvage.day)*86400)
	%Info.text+="\n加固锅炉打捞 · 本人带货撤离，每个开场 UTC 日一次。命中率 20%，连续两次未得后保底命中。"
	%Info.text+="\n%s UTC · %s · 保底进度 %d/2" % [day,"机会可用" if salvage.available else "机会已用",int(salvage.misses)]
	if salvage.available:
		%Info.text+=" · 本次保底命中" if salvage.guaranteed else " · 本次命中率 %d%%" % int(salvage.chance_percent)
	elif salvage.guaranteed:
		%Info.text+=" · 下次有效机会保底命中"
	if int(salvage.part_space)==0:
		%Info.text+="\n部件仓已满。命中时若仍满仓，本次机会照用，锅炉不入库，保底留到下次有效打捞。"
	var rows:=PackedStringArray()
	for member:Dictionary in group.get("members",[]):
		var roster:Array=member.robots
		var status:="已确认" if member.confirmed else ("待确认" if not roster.is_empty() else "待选机")
		rows.append("%s%s · %d/%d 台 %d/%d 点 · %s" % [member.name," (我)" if member.mine else "",roster.size(),unit_cap,member.points,point_cap,status])
		if duo and not roster.is_empty():
			var names:=PackedStringArray()
			for rid:String in roster:
				names.append("%s·%s" % [member.get("names",{}).get(rid,"机体"),rid.left(6)])
			rows.append(", ".join(names))
	%Members.text="\n".join(rows)
	%Members.visible=not rows.is_empty()
	%Start.visible=group.is_empty()
	%Start.disabled=intent_policy.capture("create",overview,chosen,%Friend.text).is_empty()
	%Friend.visible=group.is_empty()
	%Claim.visible=not group.is_empty()
	%Submit.visible=not group.is_empty() and duo and not queued
	var submitted:Array=mine.get("robots",[])
	var same:=submitted.size()==chosen.size() and chosen.all(func(id):return id in submitted)
	%Submit.text="重新核对我的机体" if same else "提交我的机体"
	%Submit.disabled=intent_policy.capture("select",overview,chosen,%Friend.text).is_empty()
	%Station.text="确认本轮阵容与风险" if duo else "确认风险并出发"
	%Station.visible=not group.is_empty() and not queued
	%Station.disabled=intent_policy.capture("confirm",overview,chosen,%Friend.text).is_empty()
	%Claim.disabled=intent_policy.capture("cancel",overview,chosen,%Friend.text).is_empty()
	if not pending_intent.is_empty() or (busy and not sending.is_empty()):
		for button in [%Start,%Submit,%Station,%Claim]:button.disabled=true
	for check:CheckButton in checks.values():check.disabled=queued
	if queued:%Info.text+="\n已确认，正在等待对手。"
	elif duo and not group.is_empty():%Info.text+="\n双方先提交机体，再确认同一轮阵容。改选需双方重新确认。"
	if overview.last is Dictionary:%Info.text+="\n上次："+_result(overview.last)
	if not overview.event.active:%Info.text+="\n本事件已停止入场"
	elif overview.played:%Info.text+="\n本事件已参加"

func _checked() -> Array:
	var result:=[]
	for id in checks:
		if checks[id].button_pressed:result.append(id)
	return result

func _join() -> void:
	if closing or not view_valid:return
	if not overview.has("admission"):return
	pending_intent.clear()
	var address:=Endpoints.transport("treasure",endpoint)
	if address.is_empty():
		%Feedback.text=Endpoints.issue("treasure")
		return
	var next_room := str(overview.admission.id)
	if room_id != next_room:
		_set_site("")
		for object:Node in views.values()+markers.values():
			object.get_parent().remove_child(object)
			object.queue_free()
		views.clear()
		units.clear()
		markers.clear()
		selected=""
		grouped.clear()
		role_filter=""
		note=""
		bag.clear()
		%Swap.clear()
		for button in [%All,%Core,%Focus,%Repair,%Retreat,%Swap]:
			button.disabled=false
		room_id=next_room
	attached=true
	%Lobby.hide()
	%Fight.show()
	net.connect_mission(address.host,address.port,overview.admission)

func _process(delta:float) -> void:
	if not _page_active():return
	if not attached:
		if auth_failed:return
		polling+=delta
		if not busy and (refresh_requested or polling>=read_delay):
			polling=0
			_request("")
		return
	if net.state.is_empty() or net.state.get("id","")!=room_id:return
	for id in views:
		var u:Sim.Fighter=units[id]
		var row:Dictionary=net.state.units[id]
		var pos:=Vector2(row.pos[0],row.pos[1])
		var diff:=pos-u.pos
		u.walking=diff.length()>0.04
		u.last_heading=Vector2(row.heading[0],row.heading[1])
		u.pos=u.pos.lerp(pos,minf(1.0,delta*12))
		views[id].sync(u,float(net.state.tick)*0.25,(id==selected or id in grouped),delta)
		if row.get("out",false):views[id].hide()
	if _audio_active(net.state):
		var audio=$BattleAudio
		var battle:String=net.state.id
		var elapsed:=float(net.state.tick)*0.25
		if audio.session!=battle or elapsed!=audio.last_elapsed:
			same_tick_seconds=0.0
			audio.observe(battle,elapsed,units,views,$Camera,int(net.state.side),audio.session!=battle)
		else:
			same_tick_seconds+=delta
			if same_tick_seconds>=TRACK_IDLE_GRACE and audio.tread.playing and audio.tread.stream==audio.TRACK_LOOP:
				if not _visible_friendly_crawler_walking(int(net.state.side)):
					audio.tread.stop()

func _visible_friendly_crawler_walking(side:int) -> bool:
	for id in units:
		var unit:Sim.Fighter=units[id]
		if unit.walking and unit.side==side and unit.hp>0 and unit.profile.get("chassis","crawler")=="crawler" and views[id].is_visible_in_tree():
			if $Camera.is_position_in_frustum(Vector3(unit.pos.x,0.7,unit.pos.y)):return true
	return false

func _audio_active(frame:Dictionary) -> bool:
	return net.get("receiving_frames")==true and not frame.is_empty() and frame.get("id")==overview.get("admission",{}).get("id") and not frame.get("outcome") and not frame.get("receipt")

func _set_site(site:String) -> void:
	if shown_site==site:return
	shown_site=site
	for old in $SiteScenery.get_children():
		$SiteScenery.remove_child(old)
		old.queue_free()
	var scene:PackedScene=SITE_SCENES.get(site)
	$Deck.visible=scene==null
	if scene:
		$SiteScenery.add_child(scene.instantiate())

func _update_marker(key:String, resource:String) -> void:
	var marker := markers.get(key) as Node3D
	if not marker:
		marker = Node3D.new()
		$Objects.add_child(marker)
		_label(marker,"",1.7)
		markers[key] = marker
	if marker.get_meta("resource","") == resource:
		return
	var previous := marker.get_node_or_null("Cargo")
	if previous:
		previous.free()
	var cargo:Node3D = Kit.part(ITEM_MESHES[resource]) if ITEM_MESHES.has(resource) else SEALED.instantiate()
	cargo.name = "Cargo"
	marker.add_child(cargo)
	marker.get_node("CargoLabel").text = RESOURCES.get(resource,RESOURCES.unknown)
	marker.set_meta("resource",resource)

func _sync() -> void:
	var groups = %RoleSelect.get_node("CustomGroups")
	if not attached or not _audio_active(net.state):
		groups.suspend()
	if not attached:return
	var s:Dictionary=net.state
	if not _audio_active(s) and not $BattleAudio.session.is_empty():
		$BattleAudio.reset_audio()
	if s.is_empty() or s.get("id","")!=room_id:
		%Status.text=net.message
		return
	_set_site(str(s.get("site","")))
	var carried:=[]
	for key in s.items:
		var item:Dictionary=s.items[key]
		_update_marker(key, item.resource)
		markers[key].position=Vector3(item.pos[0],0.05,item.pos[1])
		markers[key].visible=not item.removed and str(item.bearer).is_empty()
		if item.bearer==s.owner and not item.removed:carried.append(key)
	if bag!=carried or %Swap.item_count==0:
		bag=carried
		%Swap.clear()
		%Swap.add_item("不替换")
		for key in bag:%Swap.add_item("")
	for i in bag.size():
		var key:String=bag[i]
		%Swap.set_item_text(i+1,"换下"+str(RESOURCES.get(s.items[key].resource,RESOURCES.unknown))+key.right(1))
	for id in s.units:
		var r:Dictionary=s.units[id]
		if not views.has(id):
			var u:=Sim.Fighter.new()
			u.id=id
			u.side=int(r.side)
			u.profile={"chassis":r.get("chassis","crawler"),"parts":r.parts}
			u.stats={"max_hp":r.max_hp}
			u.pos=Vector2(r.pos[0],r.pos[1])
			var v:=Unit.instantiate()
			$Units.add_child(v)
			v.setup(u)
			v.set_paint(r.paint)
			v.robot.set_hull_number(str(r.get("hull_number","")))
			var label:Label3D=v.get_node("OwnedName")
			label.text=r.name+(" · 我的" if r.owner==s.owner else (" · 队友" if int(r.side)==int(s.side) else " · 对手"))
			label.show()
			views[id]=v
			units[id]=u
		units[id].last_service=float(r.get("last_service",-10))
		units[id].protected_until=float(r.get("protected_until",0))
		units[id].last_jam=float(r.get("last_jam",-10))
		units[id].hp=r.hp
		units[id].last_shot=r.shot
		units[id].impact_point=Vector2(r.impact[0],r.impact[1])
	var roster := {}
	if _audio_active(s):
		for id: String in s.units:
			var u: Dictionary = s.units[id]
			if u.owner == s.owner and u.hp > 0 and not u.get("out",false):
				roster[id] = str(u.name)
		groups.bind_roster("treasure/%s/%s" % [s.id,s.owner],roster)
	if role_filter == "custom":
		if _audio_active(s):
			grouped.assign(grouped.filter(func(id): return roster.has(id)))
			selected = "" if grouped.is_empty() else grouped[0]
	elif not role_filter.is_empty():_group(role_filter)
	elif selected.is_empty() or float(s.units[selected].hp)<=0:_cycle()
	var goods:Array=[]
	for key in carried:goods.append(RESOURCES.get(s.items[key].resource,RESOURCES.unknown))
	%Title.text="%s · %s方撤离 · %ds" % [SITE_NAMES.get(shown_site,"秘宝争夺"),"左" if int(s.side)==0 else "右",maxi(0,ceili(s.deadline-s.now))]
	%Status.text="临时包 %d/2" % carried.size()
	if not goods.is_empty():%Status.text += " · " + ", ".join(goods)
	if not note.is_empty():%Status.text += " · " + note
	if not net.message.is_empty() and net.message.begins_with("连接中断"):
		%Status.text=net.message
	if s.receipt is Dictionary:
		%Status.text=_result(s.receipt)
		for b in [%All,%Core,%Focus,%Repair,%Retreat,%Swap]:b.disabled=true

func _result(receipt:Dictionary) -> String:
	var actual:Array=[]
	for key in receipt.cargo_changes:
		if int(receipt.cargo_changes[key])>0:actual.append("%s×%d"%[RESOURCES.get(key,key),int(receipt.cargo_changes[key])])
	var reward:Dictionary=receipt.participation
	var award_text:="本人未成功拾取"
	if reward.eligible:
		if reward.already_claimed:award_text="当日次数已用"
		elif int(reward.credited)>0:award_text="通用零件 +%d" % int(reward.credited)
		else:award_text="仓满入库 0，当日次数已用"
	var salvage:Dictionary=receipt.salvage
	var result:String
	match salvage.status:
		"awarded":result="加固锅炉已入部件仓 #%s" % str(salvage.part_id).left(8)
		"parts_full":result="命中时部件仓已满，加固锅炉未入库。本场开场日机会已用，请腾出空位"
		"already_used":result="本场开场日的机会已用"
		"miss":result="本次未获得加固锅炉，本场开场日机会已用"
		"ineligible":result="本人未带货撤离，本场未消耗机会"
		_:result="打捞结果未确认"
	result+=" · 保底进度 %d/2" % int(salvage.misses)
	if int(salvage.misses)==2:
		result+=" · 下次有效机会保底命中"
	return "%s · 带出 %d 件 · 货物入库 %s\n参与奖 · %s\n稀有打捞 · %s" % [{"extracted":"已撤离","expired":"撤离超时","defeated":"机体失能"}.get(receipt.outcome,receipt.outcome),receipt.cargo.size(),", ".join(actual) if not actual.is_empty() else "0",award_text,result]

func _group(role:String) -> void:
	role_filter=role
	grouped.clear()
	for id in net.state.get("units",{}):
		var u:Dictionary=net.state.units[id]
		if u.owner==net.state.owner and u.hp>0 and not u.get("out",false) and (role=="all" or role==u.get("orders",Sim.default_orders(u.parts)).role):
			grouped.append(id)
	selected="" if grouped.is_empty() else grouped[0]

func _cycle() -> void:
	role_filter=""
	grouped.clear()
	var own:=[]
	for id in net.state.get("units",{}):
		var u:Dictionary=net.state.units[id]
		if u.owner==net.state.owner and u.hp>0 and not u.get("out",false):own.append(id)
	if own.is_empty():selected=""
	else:selected=own[(own.find(selected)+1)%own.size()]

func _issue(order:Dictionary) -> void:
	if selected.is_empty():return
	order.robot=selected
	if not grouped.is_empty() and order.action in ["move","focus"]:order.robots=grouped.duplicate()
	net.command(order)

func _move(pos:Vector2) -> void:
	_issue({"action":"move","pos":[clampf(pos.x,-9,9),clampf(pos.y,-9,9)]})

func _take() -> void:
	if selected.is_empty():return
	var pos:Vector2=units[selected].pos
	var found:=""
	var best:=INF
	for id in net.state.items:
		var item:Dictionary=net.state.items[id]
		var d:=pos.distance_to(Vector2(item.pos[0],item.pos[1]))
		if item.bearer=="" and not item.removed and d<best:
			found=id
			best=d
	if not found.is_empty():_issue({"action":"take","item":found,"replace":bag[%Swap.selected-1] if %Swap.selected>0 else ""})

func _focus() -> void:
	if selected.is_empty():return
	var best:=INF
	var target:=""
	for id in units:
		var u:Sim.Fighter=units[id]
		var d:float=u.pos.distance_to(units[selected].pos)
		if u.side!=int(net.state.side) and u.hp>0 and not net.state.units[id].get("out",false) and d<best:
			best=d
			target=id
	if not target.is_empty():_issue({"action":"focus","target":target})

func _enemy_at(at:Vector2) -> String:
	var target:=""
	var best:=22.0
	for id:String in units:
		var unit:Sim.Fighter=units[id]
		if unit.side==int(net.state.side) or unit.hp<=0 or net.state.units[id].get("out",false):
			continue
		var feet:=Vector3(unit.pos.x,0.38,unit.pos.y)
		var head:=Vector3(unit.pos.x,1.25,unit.pos.y)
		var closest:=Geometry2D.get_closest_point_to_segment(at,$Camera.unproject_position(feet),$Camera.unproject_position(head))
		var distance:=at.distance_to(closest)
		if distance<best or (distance==best and not target.is_empty() and id<target):
			target=id
			best=distance
	return target

func _unhandled_input(event:InputEvent) -> void:
	if not attached or selected.is_empty() or net.state.get("outcome")!=null or event.device==InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if not event.pressed or event.index!=0 or event.canceled:return
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
	else:
		return
	get_viewport().set_input_as_handled()
	var at:Vector2=event.position
	var enemy:=_enemy_at(at)
	if not enemy.is_empty():
		_issue({"action":"focus","target":enemy})
		return
	var hit:Variant=Plane(Vector3.UP,0).intersects_ray($Camera.project_ray_origin(at),$Camera.project_ray_normal(at))
	if hit is Vector3:_move(Vector2(hit.x,hit.z))
