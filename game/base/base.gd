extends Node3D
const Endpoints:=preload("res://client/endpoints.gd")
const Expedition:=preload("res://expedition/expedition.gd")

signal closed
signal garage_requested(action:String,robot:String)
signal garage_returned
const Building := preload("res://base/building.tscn")
const MODES := ["build","move","road","erase","power"]
const TYPES := ["foundry","warehouse","workshop","repair","turret","hangar","relay","research_station","radar_station"]
const TITLES := {"core":"核心","foundry":"冶炼","warehouse":"仓库","workshop":"装配","repair":"修理","turret":"防御平台","hangar":"军营机库","relay":"配电柱","research_station":"光学研究站","radar_station":"雷达远征站"}
const REASONS := {"outside_grid":"占地超出边界","occupied":"此处已有建筑或道路。\n请另选靠路的空地。","entrance_reserved":"入口需要保留",
	"road_disconnected":"该操作会切断道路","building_disconnected":"建筑必须靠近与入口相连的道路",
	"road_missing":"这里没有道路","same_position":"机体设施已在此格","stale_layout":"布局已变化，正在重新取得当前布局，请重新选择位置",
	"insufficient_stock":"库存不足","session_expired":"会话已失效，请返回档案登录",
	"research_requires_workshop":"需先建造并供电给装配车间","already_researched":"科技已掌握，正在更新状态","research_station_missing":"请选择已建成的光学研究站","research_station_unpowered":"研究站未供电，请恢复供电后研究",
	"nothing_to_claim":"暂无可领取产出","core_required":"核心必须持续供能"}
var endpoint := ""
var token := ""
var account := ""
var visit_layout := {}
var visitor_title := ""
var layout := {}
var pending := {}
var preview := {}
var chosen := ""
var op := ""
var busy := false
var frozen := false
var latest := ""
var action_key := ""
var submitted := {}
var save_state := ""
var active_http:HTTPRequest
var freeze_key := ""
var freeze_revision := 0
var read_failed := false
var auto_reading := false
var read_lease := -1
var auto_hint := ""

var initial_snapshot:Dictionary={}
var initial_guide:Dictionary={}
var preview_only := false

func _ready() -> void:
	$PageRefresh.configure(_page_active, _can_auto_read, 10.0)
	$PageRefresh.read_due.connect(_auto_read)
	if preview_only:
		$HUD.hide()
		set_process_unhandled_input(false)
		$Camera.position=Vector3(-9,16,-14)
		$Camera.look_at(Vector3.ZERO)
		$Camera.h_offset=2.8
		$Camera.make_current()
		return
	if not visit_layout.is_empty():
		$Camera.position=Vector3(-9,16,-14)
		$Camera.look_at(Vector3.ZERO)
		$Camera.h_offset=2.8
		$Camera.make_current()
		var body: VBoxContainer=%Stats.get_parent()
		for item in body.get_children():
			item.visible=item in [body.get_node("Title"),%Stats,%Back]
		body.get_node("Title").text=visitor_title
		%Back.text="返回好友"
		%Back.pressed.connect(func():closed.emit())
		set_process_unhandled_input(false)
		_draw(visit_layout)
		_show_plaque(visit_layout.get("plaque"))
		return
	%Guide.endpoint=endpoint
	%Guide.token=token
	%DefenseAlerts.enter.connect(_open_defense)
	$HUD.visibility_changed.connect(_sync_alerts)
	$HUD/Panel.visibility_changed.connect(_sync_alerts)
	_sync_alerts()
	%Guide.chosen.connect(_guide_action)
	$Camera.position = Vector3(-9,16,-14)
	$Camera.look_at(Vector3.ZERO)
	$Camera.h_offset = 2.8
	for label in ["建造设施","移动设施","铺设道路","移除道路或雷达站","切换供能"]:
		%Mode.add_item(label)
	for kind in TYPES:
		%Type.add_item(TITLES[kind])
	%Mode.item_selected.connect(func(_i): _reset())
	%Type.item_selected.connect(func(_i): _reset())
	%Confirm.pressed.connect(_confirm)
	%Freeze.pressed.connect(_freeze)
	%Snapshot.pressed.connect(func(): _request("snapshot","/v1/base/snapshots/" + latest))
	%Refresh.pressed.connect(refresh)
	%Economy.request.connect(_request)
	%FacilityRecovery.repair_requested.connect(func(fields:Dictionary): _request("facility_repair","/v1/base/facility-repair",fields))
	%FacilityRecovery.refresh_due.connect(_read_facility_due)
	%Explore.pressed.connect(_open_area.bind(preload("res://expedition/expedition.tscn")))
	%Armory.pressed.connect(_open_area.bind(preload("res://armory/outing.tscn")))
	%Factory.pressed.connect(_open_area.bind(preload("res://factory/outing.tscn")))
	%WorldMap.pressed.connect(_open_area.bind(preload("res://world/world.tscn")))
	%Raids.pressed.connect(_raids)
	%EconomyToggle.pressed.connect(_toggle_economy)
	%PlaqueOrders.pressed.connect(_plaques)
	%Back.pressed.connect(func():
		_abandon_save()
		closed.emit())
	if not initial_snapshot.is_empty() and not initial_guide.is_empty():
		apply_base_snapshot(initial_snapshot)
		%Guide.apply_guide(initial_guide)
		initial_snapshot={}
		initial_guide={}
	else:refresh()

func apply_base_snapshot(snapshot:Dictionary) -> void:
	if not busy and submitted.is_empty() and pending.is_empty() and preview.is_empty() and chosen.is_empty() and not frozen:
		op="get"
		_apply_response(200,snapshot)

func refresh() -> void:
	if not submitted.is_empty():
		if not busy:_check_save()
		return
	_request("get","/v1/base")
	%Guide.refresh()

func _page_active() -> bool:
	return not preview_only and visit_layout.is_empty() and not token.is_empty() and is_visible_in_tree() and $HUD.visible and $HUD/Panel.is_visible_in_tree()

func _process(_delta:float) -> void:
	if auto_reading and (not _page_active() or not $PageRefresh.foreground):_cancel_auto_read()

func _can_auto_read() -> bool:
	return not busy and not frozen and pending.is_empty() and preview.is_empty() and chosen.is_empty() and submitted.is_empty() and %FacilityRecovery.request.is_empty()

func _auto_read() -> void:
	if not _can_auto_read():
		$PageRefresh.defer()
		return
	auto_reading = true
	auto_hint = %Hint.text
	read_lease = $PageRefresh.current_lease()
	_request("production" if %Economy.visible else "get", "/v1/base/production" if %Economy.visible else "/v1/base")
	%Guide.refresh()

func _cancel_auto_read() -> void:
	if not auto_reading:
		return
	if is_instance_valid(active_http):
		active_http.cancel_request()
		active_http.queue_free()
		active_http = null
	busy = false
	auto_reading = false
	$PageRefresh.defer(read_lease)
	read_lease = -1

func _read_facility_due() -> void:
	if not busy and not frozen and pending.is_empty() and submitted.is_empty() and $HUD.visible and %FacilityRecovery.claim_due_read():
		_request("facility_due","/v1/base")

func _guide_action(action:String,robot:String) -> void:
	_abandon_save()
	if action in ["solo","party","reward","command"]:
		_open_area(preload("res://expedition/expedition.tscn"),action=="party")
	else:
		garage_requested.emit(action,robot)

func _radar(building:Dictionary) -> void:
	var station:=preload("res://base/radar_panel.tscn").instantiate()
	station.station_id=building.id
	station.endpoint=endpoint
	station.token=token
	$HUD.hide()
	set_process_unhandled_input(false)
	add_child(station)
	station.power_observed.connect(func(powered:bool):
		for model in $Buildings.get_children():
			if model.get_meta("building_id","")==building.id:
				model.update_radar_power(powered))
	station.destination.connect(_leave_radar.bind(station))

func _leave_radar(target:String,station:Node) -> void:
	remove_child(station)
	station.queue_free()
	$HUD.show()
	set_process_unhandled_input(true)
	match target:
		"explore": _open_area(preload("res://expedition/expedition.tscn"))
		"world": _open_area(preload("res://world/world.tscn"))
		"guard": _raids()
		_: refresh()

func _raids() -> void:
	_cancel_auto_read()
	if busy or not $HUD.visible:
		return
	_abandon_save()
	var watch:=preload("res://raids/raid_watch.tscn").instantiate()
	watch.endpoint=endpoint
	watch.token=token
	frozen=false
	_reset()
	%HomeShowcase.hide()
	$PlaqueStand.hide()
	$HUD.hide()
	set_process_unhandled_input(false)
	add_child(watch)
	watch.condition_requested.connect(func(id:String): garage_requested.emit("raid_guard_recovery",id),CONNECT_DEFERRED)
	watch.closed.connect(func():
		remove_child(watch)
		watch.queue_free()
		_reset()
		%HomeShowcase.show()
		_show_plaque(layout.get("plaque"))
		$HUD.show()
		set_process_unhandled_input(true)
		refresh())

func _open_area(area: PackedScene, party := false) -> void:
	var scene := area.instantiate()
	if scene is Expedition:
		scene.configure_sessions(get_node("/root/Solo"),get_node("/root/Party"))
	if party:
		scene.start_in_party=true
	_show_area(scene)

func _sync_alerts() -> void:
	%DefenseAlerts.set_screen($HUD.visible and $HUD/Panel.is_visible_in_tree() and not frozen,endpoint,token)

func _open_defense(node_id:String) -> void:
	_cancel_auto_read()
	if busy or frozen or not submitted.is_empty() or not pending.is_empty() or not chosen.is_empty():return
	var scene:=preload("res://camp/camp.tscn").instantiate()
	scene.node_id=node_id
	_show_area(scene)

func _show_area(scene: Node) -> void:
	_cancel_auto_read()
	_abandon_save()
	scene.endpoint = endpoint
	scene.token = token
	hide()
	$HUD.hide()
	set_process_unhandled_input(false)
	get_parent().add_child(scene)
	scene.closed.connect(func():
		scene.queue_free()
		show()
		$HUD.show()
		$Camera.make_current()
		set_process_unhandled_input(true)
		if scene.scene_file_path=="res://owned/workshop.tscn" and garage_returned.has_connections():
			garage_returned.emit()
		else:
			refresh()
	)

func _toggle_economy(station := "") -> void:
	_cancel_auto_read()
	%Economy.select_station(station)
	%Economy.visible = not %Economy.visible
	%EconomyToggle.text = "返回布局" if %Economy.visible else "生产与研究"
	for control in [%Mode,%Type,%Confirm,%Freeze,%Refresh,%Snapshot]:
		control.visible = not %Economy.visible
	_reset()
	if %Economy.visible:
		%Hint.text = ""
		_request("production","/v1/base/production")

func _plaques() -> void:
	_cancel_auto_read()
	if busy or frozen or not visit_layout.is_empty() or not $HUD.visible:return
	_abandon_save()
	var page:=preload("res://base/plaques.tscn").instantiate()
	page.endpoint=endpoint
	page.token=token
	$HUD.hide()
	set_process_unhandled_input(false)
	add_child(page)
	page.closed.connect(func():
		page.queue_free()
		$HUD.show()
		set_process_unhandled_input(true)
		refresh())

func _show_plaque(plaque:Variant) -> void:
	$PlaqueStand.visible=plaque is Dictionary
	%PlaqueDisplay.visible=plaque is Dictionary
	if plaque is Dictionary:
		$PlaqueStand/Legend.text="#" + str(plaque.battle).left(8)
		%PlaqueDisplay.get_node("%Inscription").text="%s\n战役 #%s" % [plaque.name,str(plaque.battle).left(8)]

func _request(action: String, path: String, data: Dictionary = {}) -> void:
	if busy:
		if auto_reading:
			_cancel_auto_read()
		else:
			return
	if action=="production" and not layout.get("facility_damage",[]).is_empty():
		action="get"
		path="/v1/base"
	busy = true
	op = action
	if action == "edit":
		%Hint.text = "正在保存布局…"
	_controls()
	var http:=HTTPRequest.new()
	http.timeout=6
	add_child(http)
	active_http=http
	http.request_completed.connect(_received.bind(http,token),CONNECT_ONE_SHOT)
	var err:=http.request(endpoint+path,Endpoints.headers(token),HTTPClient.METHOD_GET if data.is_empty() else HTTPClient.METHOD_POST,"" if data.is_empty() else JSON.stringify(data))
	if err!=OK:
		_received(-1,0,[],PackedByteArray(),http,token)

func _received(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray,http:HTTPRequest,issued_token:String) -> void:
	if http!=active_http:return
	if auto_reading and (not _page_active() or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	active_http=null
	http.queue_free()
	busy=false
	if issued_token!=token or is_queued_for_deletion() or not is_inside_tree():return
	var data:Variant=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	var transport_ok:=result==HTTPRequest.RESULT_SUCCESS
	var background_read:=auto_reading
	var recovered_read:=read_failed
	if op in ["get", "production"]:
		var valid_read:bool = transport_ok and status==200 and data is Dictionary and ((op=="get" and _valid_base(data.get("base"))) or (op=="production" and data.get("production") is Dictionary))
		read_failed = not valid_read
		$PageRefresh.settled(valid_read, status in [401,426], read_lease)
		auto_reading = false
		read_lease = -1
	if op=="facility_due" and (not transport_ok or status!=200 or not data is Dictionary or not _valid_base(data.get("base"))):
		%FacilityRecovery.read_failed(not transport_ok or status>=500 or status in [200,408,429])
		_controls()
		return
	if op=="facility_repair":
		var rejected:bool=transport_ok and status>=400 and status<500 and status!=408 and data is Dictionary and data.get("error") is String
		if rejected:
			var message:String={"facility_not_damaged":"该设施已恢复，本次未扣费","insufficient_stock":"结构材料不足，本次未扣费"}.get(data.error,REASONS.get(data.error,str(data.error)))
			%FacilityRecovery.finish(message)
			_request("get","/v1/base")
			return
		var receipt:Dictionary=data.receipt if data is Dictionary and data.get("receipt") is Dictionary else {}
		var intent:Dictionary=%FacilityRecovery.request
		if not (transport_ok and status==200 and _valid_base(data.get("base") if data is Dictionary else null) and data.get("production") is Dictionary and receipt.get("operation")=="facility_repair" and receipt.get("building")==intent.get("building") and receipt.get("raid")==intent.get("raid") and receipt.get("id") is String and not receipt.id.is_empty() and receipt.get("changes",{}).get("structure")==-1):
			%FacilityRecovery.finish("结果待确认，可核对原抢修收据",true)
			_controls()
			return
		%FacilityRecovery.finish("设施已抢修 · 扣 1 结构\n收据 #%s" % str(receipt.id).left(8))
	if op=="verify_edit":
		_accept_check(data if transport_ok and status==200 else null)
		return
	if op=="edit":
		var rejected:bool=transport_ok and status>=400 and status<500 and status!=408 and data is Dictionary and data.get("error") is String
		if not rejected and not (transport_ok and status==200 and _valid_result(data)):
			_check_save()
			return
		submitted.clear()
		save_state=""
	if not transport_ok:
		%Hint.text="连接中断，正在恢复连接。"
		if op=="get":%Stats.text="正在恢复基地连接…"
		_controls()
		return
	_apply_response(status,data)
	if background_read and not recovered_read and not read_failed:
		%Hint.text=auto_hint

func _valid_result(data:Variant) -> bool:
	if not data is Dictionary or not _valid_base(data.get("base")):return false
	var receipt:Variant=data.get("receipt")
	return receipt is Dictionary and receipt.get("operation")=="base_edit" and receipt.get("changes") is Dictionary and receipt.get("id") is String and not receipt.id.is_empty() and int(receipt.get("revision",-1))==int(submitted.revision)+1 and int(data.base.revision)>=int(receipt.revision)

func _valid_base(state:Variant) -> bool:
	return state is Dictionary and state.has_all(["width","height","supply","used","revision"]) and state.get("roads") is Array and state.get("buildings") is Array and not state.buildings.is_empty()

func _check_save() -> void:
	if submitted.is_empty() or busy:return
	save_state="checking"
	%Hint.text="正在核对本次保存及材料收据…"
	_request("verify_edit","/v1/base/edits/"+str(submitted.key))

func _accept_check(data:Variant) -> void:
	if submitted.is_empty():return
	if not data is Dictionary or data.get("key")!=submitted.key or not data.has("receipt") or not _valid_base(data.get("base")) or (data.receipt!=null and not _valid_result(data)):
		save_state="unconfirmed"
		%Hint.text="保存结果仍待确认，可恢复本次保存查看原收据。"
	elif data.receipt==null and int(data.base.revision)==int(submitted.revision):
		layout=data.base
		save_state="retry"
		%Hint.text="未查到本次收据，布局仍为 v%d\n可以重试原保存，或重新选址。" % int(layout.revision)
	else:
		var receipt:Variant=data.receipt
		submitted.clear()
		save_state=""
		op="get"
		_apply_response(200,{"base":data.base})
		if receipt==null:
			%Hint.text="未查到本次收据，布局已变为 v%d\n请重新选址预览。" % int(layout.revision)
		else:
			var cost:=absi(int(receipt.changes.get("structure",0)))
			%Hint.text="本次已保存 v%d · 当前布局 v%d\n%s · 收据 #%s" % [int(receipt.revision),int(layout.revision),"已扣 %d 结构材料" % cost if cost else "本次未消耗材料",str(receipt.id).left(8)]
	_controls()
	_scroll_to_preview()

func _abandon_save() -> void:
	if submitted.is_empty():return
	if active_http:
		active_http.cancel_request()
		active_http.queue_free()
		active_http=null
	busy=false
	submitted.clear()
	save_state=""
	_reset()

func _power_changes(next:Dictionary) -> String:
	var old := {}
	for b:Dictionary in layout.buildings:
		old[b.id]=b
	var lines:=PackedStringArray()
	for b:Dictionary in next.buildings:
		var before:Dictionary=old.get(b.id,{})
		var reason:String=b.get("power_reason","")
		if reason.is_empty() or (not before.is_empty() and before.get("power_reason")==reason and not (pending.get("building")==b.id and pending.get("action")=="move")):
			continue
		var note:String={"powered":"供能","paused":"手动暂停","out_of_range":"超出供区","budget":"六点预算不足"}.get(reason,reason)
		if b.kind=="relay" and reason=="out_of_range":note="超出核心直供，配电柱不能串接"
		lines.append("%s (%d,%d) · %s" % [TITLES[b.kind],int(b.x),int(b.y),note])
	return "\n".join(lines)

func _apply_response(status:int,data:Variant) -> void:
	if not data is Dictionary:
		%Hint.text = "服务响应格式异常"
	elif status != 200:
		%Hint.text = str(REASONS.get(data.get("error",""),data.get("error",status)))
		if data.get("error")=="stale_layout":
			pending.clear()
			preview.clear()
			chosen=""
			_request.call_deferred("get","/v1/base")
		if op in ["preview","edit"]:
			if data.get("error")=="insufficient_stock" and pending.get("action")=="build":
				%Hint.text = "结构材料不足。\n建造需要 %d 份。\n可在生产面板领取材料。" % int(layout.price)
			if not preview.is_empty():
				_draw(layout)
			preview.clear()
	elif op in ["production","claim","research"]:
		%Economy.receive(data)
		%FacilityRecovery.set_stock(int(data.production.lines.structure.stock))
		if op == "claim":
			%Guide.refresh(true)
		%Hint.text = {"production":"","claim":"产出已入库","research":"已完成研究"}.get(op,"")
	elif op == "preview":
		preview = data.preview
		_draw(preview)
		%Stats.text = "当前 v%d · 预览供电 %d/%d" % [int(layout.revision),int(preview.used),int(preview.supply)]
		var off := 0
		for building in preview.buildings:
			if not building.powered:
				off += 1
		var edit_name:String=TITLES.get(pending.get("kind",""),{"move":"移动","power":"供能","road":"铺路","erase":"移除","remove":"拆除雷达站"}.get(pending.get("action",""),""))
		%Hint.text = "%s预览 (%d, %d)\n结构材料 %d 份\n道路可达 · 断电设施 %d" % [edit_name,pending.x,pending.y,abs(int(data.cost.get("structure",0))),off]
		var changes:=_power_changes(preview)
		if not changes.is_empty():%Hint.text+="\n"+changes
	elif op == "snapshot":
		frozen = true
		%FacilityRecovery.hide()
		_show_plaque(null)
		preview.clear()
		pending.clear()
		$Cursor.hide()
		_draw(data.snapshot)
		%Hint.text = "封存布局只读，可返回当前基地。"
	else:
		layout = data.base
		if layout.has("plaque"):_show_plaque(layout.plaque)
		if data.has("raid_stage"):
			%Raids.text = {"warning":"野生机袭击预警","live":"防守正在进行","protected":"基地防守 · 保护中","replay":"基地防守 · 有战报"}.get(data.raid_stage,"基地防守")
		if data.has("production"):
			%Economy.receive(data)
		%FacilityRecovery.update_state(layout.get("facility_damage",[]),int(%Economy.state.get("lines",{}).get("structure",{}).get("stock",0)),int(layout.get("server_now",-1)))
		frozen = false
		if data.has("latest_snapshot"):
			latest = data.latest_snapshot
		if data.get("receipt",{}).has("snapshot"):
			latest = data.receipt.snapshot
			freeze_key = ""
		_reset()
		if op == "freeze":
			%Hint.text = "已封存布局 v%d" % layout.revision
		elif op == "edit":
			var cost := absi(int(data.receipt.changes.get("structure",0)))
			%Hint.text = "布局 v%d 已保存。\n%s" % [int(data.receipt.revision),("已扣 %d 结构材料。" % cost) if cost else "本次未消耗材料。"]
			if %Mode.selected==0 and layout.buildings.any(func(b):return b.kind=="hangar"):
				%Hint.text += "\n点已建军营进入机库。"
	_controls()
	if op in ["preview","edit"] and is_visible_in_tree():
		_scroll_to_preview()

func _scroll_to_preview() -> void:
	# Wrapped text changes the sidebar height after the containers finish sorting.
	await get_tree().process_frame
	if is_inside_tree() and is_visible_in_tree() and $HUD.visible:
		$HUD/Panel/Pad/Scroll.ensure_control_visible(%Confirm if not %Confirm.disabled else %Hint)

func _controls() -> void:
	var locked:=(busy and not auto_reading) or read_failed or (not submitted.is_empty() and save_state!="retry")
	%DefenseAlerts.set_locked(busy or frozen or not pending.is_empty() or not submitted.is_empty() or not chosen.is_empty())
	if not preview_only and visit_layout.is_empty():_sync_alerts()
	%Confirm.text="重试原保存" if save_state=="retry" else "确认布局"
	%Refresh.visible = frozen or read_failed or not submitted.is_empty()
	%Refresh.text="返回当前基地" if frozen else ("恢复本次保存" if not submitted.is_empty() else "重新连接")
	%Economy.set_wait((busy and not auto_reading) or read_failed)
	%Economy.get_node("%Refresh").visible = read_failed
	%Economy.get_node("%Refresh").text = "重新连接"
	if not frozen:
		%FacilityRecovery.set_locked(locked or not preview.is_empty())
	%EconomyToggle.disabled = locked or frozen
	%Factory.visible = layout.get("rustrail_east",false) and not frozen
	%Factory.disabled = locked
	%Armory.visible = layout.get("factory_south",false) and not frozen
	%Armory.disabled = locked
	%PlaqueOrders.disabled = busy or frozen
	%Mode.disabled = locked or frozen
	%Type.visible = not %Economy.visible and %Mode.selected == 0
	%Type.disabled = locked or frozen
	%Confirm.disabled = locked or frozen or preview.is_empty()
	%Freeze.disabled = locked or frozen or layout.is_empty()
	%Refresh.disabled = busy
	%Snapshot.disabled = locked or latest.is_empty()
	if %FacilityRecovery.due_read:_read_facility_due.call_deferred()

func _reset() -> void:
	_cancel_auto_read()
	if save_state=="retry":
		submitted.clear()
		save_state=""
	chosen = ""
	pending.clear()
	preview.clear()
	action_key = ""
	$Cursor.hide()
	if not layout.is_empty():
		_draw(layout)
	%Hint.text = "先点要移动的建筑。\n再点新位置的左上角。" if %Mode.selected == 1 else "点靠路空地预览设施。\n确认后消耗结构材料。\n点已建军营进入机库。"
	if %Mode.selected >= 2:
		%Hint.text = ["点相邻空地预览道路。","点道路或雷达站预览移除。","点建筑预览供能变更。"][%Mode.selected - 2]
	if %Mode.selected==0 and TYPES[%Type.selected]=="relay":
		%Hint.text="配电柱须在核心直供六格内，不能串接。邻路建造后向外供六格，总预算不变。"
	_controls()

func _freeze() -> void:
	_cancel_auto_read()
	if freeze_key.is_empty() or freeze_revision != int(layout.revision):
		freeze_key = Crypto.new().generate_random_bytes(16).hex_encode()
		freeze_revision = int(layout.revision)
	_request("freeze","/v1/base/freeze",{"revision":int(layout.revision),"key":freeze_key})

func _confirm() -> void:
	_cancel_auto_read()
	if busy or preview.is_empty() or (not submitted.is_empty() and save_state!="retry"):return
	if submitted.is_empty():
		submitted=pending.duplicate()
		submitted.key=action_key
	save_state="sending"
	_request("edit","/v1/base/edit",submitted)

func pick(cell: Vector2i) -> void:
	_cancel_auto_read()
	if busy or frozen or (not submitted.is_empty() and save_state!="retry") or %Economy.visible or layout.is_empty() or not visit_layout.is_empty():
		return
	if save_state=="retry":_reset()
	if layout.has("rustrail_east") and not layout.rustrail_east and cell.x >= 12 and cell.x < 15 and cell.y >= 0 and cell.y < 9:
		_reset()
		%Hint.text = "东侧土地尚未开放。\n亲自通关锈轨回收场即可扩地。"
		return
	var mode: String = MODES[%Mode.selected]
	if mode=="build":
		for b in layout.buildings:
			if not Rect2i(int(b.x),int(b.y),int(b.w),int(b.h)).has_point(cell):
				continue
			if %FacilityRecovery.choose(b.id):
				_reset()
				$HUD/Panel/Pad/Scroll.ensure_control_visible(%FacilityRecovery)
				return
			if b.kind=="radar_station":
				_radar(b)
				return
			if b.kind=="research_station":
				_toggle_economy(b.id)
				$HUD/Panel/Pad/Scroll.ensure_control_visible(%Economy)
				return
			if b.kind=="repair":
				_show_area(preload("res://base/repair_bay.tscn").instantiate())
				return
			if b.kind=="turret":
				var platform:=preload("res://base/platform.tscn").instantiate()
				platform.platform=b.id
				_show_area(platform)
				return
			if b.kind=="hangar":
				var garage := preload("res://owned/workshop.tscn").instantiate()
				garage.account=account
				garage.open_garage=true
				_show_area(garage)
				return
	if mode == "power":
		chosen = ""
	if mode in ["move","power"] and chosen.is_empty():
		for b in layout.buildings:
			if Rect2i(int(b.x),int(b.y),int(b.w),int(b.h)).has_point(cell):
				chosen = b.id
				if mode == "power":
					break
				%Hint.text = "已选%s，请点新位置。" % TITLES[b.kind]
				_draw(layout)
				_controls()
				return
		if chosen.is_empty():
			%Hint.text = "请选择一栋建筑。"
			return
	pending = {"revision":int(layout.revision),"action":mode,"x":cell.x,"y":cell.y}
	if mode=="erase":
		for b:Dictionary in layout.buildings:
			if b.kind=="radar_station" and Rect2i(int(b.x),int(b.y),int(b.w),int(b.h)).has_point(cell):
				pending.action="remove"
				pending.building=b.id
				break
	if mode in ["move","power"]:
		pending.building = chosen
	elif mode == "build":
		pending.kind = TYPES[%Type.selected]
	action_key = Crypto.new().generate_random_bytes(16).hex_encode()
	preview.clear()
	_draw(layout)
	$Cursor.position = _cell(float(cell.x),float(cell.y)) + Vector3.UP * 0.16
	$Cursor.show()
	_request("preview","/v1/base/preview",pending)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Variant = Plane(Vector3.UP,0).intersects_ray($Camera.project_ray_origin(event.position),$Camera.project_ray_normal(event.position))
		if point != null:
			pick(Vector2i(floori(point.x+6.0),floori(point.z+4.5)))
			get_viewport().set_input_as_handled()

func _cell(x: float, y: float) -> Vector3:
	return Vector3(x-5.5,0,y-4.0)

func _draw(state: Dictionary) -> void:
	var shows_east := state.has("rustrail_east")
	var columns := 15 if shows_east else int(state.width)
	$Terrain.scale.z = float(state.height) / 9.0
	$Terrain.position.z = (int(state.height)-9)*0.5
	$Terrain.scale.x = columns / 12.0
	$Terrain.position.x = (columns - 12) * 0.5
	%EastLand.visible = shows_east and visit_layout.is_empty() and not preview_only
	%EastLand.text = "东侧三列已开放 · 27 格" if state.get("rustrail_east",false) else "东侧三列待开放\n亲自通关锈轨回收场后免费获得"
	if state.get("factory_south",false):
		%EastLand.text += " · 工厂南地已开放 30 格"
	if shows_east:
		_frame_land(columns,int(state.height))
	else:
		$Camera.size=12.7
		$Camera.h_offset=2.8
		$Camera.v_offset=0.0
	%Stats.text = "布局 v%d　供电 %d / %d" % [int(state.revision),int(state.used),int(state.supply)]
	var show_power:bool=not frozen and not preview_only and visit_layout.is_empty() and not %Economy.visible and state.has("coverage") and (
		%Mode.selected==4 or (%Mode.selected==0 and (TYPES[%Type.selected]=="relay" or not preview.is_empty())) or (%Mode.selected==1 and not chosen.is_empty()))
	%PowerLegend.visible=show_power
	var covered:={}
	var direct:={}
	if show_power:
		for pair in state.coverage:covered[Vector2i(int(pair[0]),int(pair[1]))]=true
		for pair in state.core_coverage:direct[Vector2i(int(pair[0]),int(pair[1]))]=true
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.use_colors = true
	tiles.mesh = $TileTemplate.mesh
	tiles.instance_count = columns * int(state.height)
	var roads := {}
	for pair in state.roads:
		roads[Vector2i(int(pair[0]),int(pair[1]))] = true
	for y in int(state.height):
		for x in columns:
			var i := y * columns + x
			tiles.set_instance_transform(i,Transform3D(Basis.IDENTITY,_cell(x,y)-Vector3.UP*0.07))
			var color := Color("#678777") if (x+y)%2 == 0 else Color("#70907d")
			if x >= int(state.width):
				color = Color("#424e50") if (x+y)%2 == 0 else Color("#485456")
			elif x >= 12 or y >= 9:
				color = Color("#719873") if (x+y)%2 == 0 else Color("#82a17d")
			var cell:=Vector2i(x,y)
			if show_power and x<int(state.width):
				color=Color("#49b6ce") if direct.has(cell) else (Color("#82c65f") if covered.has(cell) else Color("#606976"))
			if roads.has(cell) and not show_power:
				color = Color("#bf9855") if x > 0 else Color("#f4bd4e")
			tiles.set_instance_color(i,color)
	$PowerRoads.visible=show_power
	if show_power:
		var marks:=MultiMesh.new()
		marks.transform_format=MultiMesh.TRANSFORM_3D
		marks.mesh=$PowerRoadTemplate.mesh
		marks.instance_count=state.roads.size()
		for i in state.roads.size():
			var road:Array=state.roads[i]
			marks.set_instance_transform(i,Transform3D(Basis.IDENTITY,_cell(float(road[0]),float(road[1]))+Vector3.UP*0.014))
		$PowerRoads.multimesh=marks
	$Tiles.multimesh = tiles
	for child in $Buildings.get_children():
		$Buildings.remove_child(child)
		child.queue_free()
	for b in state.buildings:
		var building := Building.instantiate()
		$Buildings.add_child(building)
		building.position = _cell(float(b.x)+(float(b.w)-1.0)/2.0,float(b.y)+(float(b.h)-1.0)/2.0)
		var damaged:bool=state.get("facility_damage",[]).any(func(d):return d.building==b.id)
		building.configure(b,TITLES[b.kind]+(" · 停工" if damaged else ""))

func _frame_land(columns:int,rows:int) -> void:
	var camera:Camera3D=$Camera
	var screen:=get_viewport().get_visible_rect().size
	var usable:=screen.x if preview_only else $HUD/Panel.get_global_rect().position.x as float
	if usable < 1.0 or screen.y < 1.0:
		return
	camera.h_offset=0.0
	camera.v_offset=0.0
	camera.size=12.7
	var bounds:=Rect2(camera.unproject_position(_cell(-0.5,-0.5)),Vector2.ZERO)
	for x:float in [-0.5,columns-0.5]:
		for y:float in [-0.5,rows-0.5]:
			bounds=bounds.expand(camera.unproject_position(_cell(x,y)))
	camera.size*=maxf(bounds.size.x/maxf(1.0,usable-26.0),bounds.size.y/maxf(1.0,screen.y-44.0))
	var middle:=_cell((columns-1)*0.5,(rows-1)*0.5)
	var offset:=camera.unproject_position(middle)-Vector2(usable*0.5,screen.y*0.5+8.0)
	var units_per_pixel:=camera.size/screen.y
	camera.h_offset=offset.x*units_per_pixel
	camera.v_offset=-offset.y*units_per_pixel

