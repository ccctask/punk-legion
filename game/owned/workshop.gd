extends Node3D
const Endpoints:=preload("res://client/endpoints.gd")

signal closed
const Catalog := preload("res://loadout/catalog.gd")
const Rules := preload("res://loadout/rules.gd")
const OPTIONS := {"core":["boiler","reinforced_boiler"],"head":["eye","visor"],"weapon":["cannon","drill","chimney_arm","rivet_repeater"],"utility":["","repair_arm","jammer"],"armor":["","rivet_shield"],"survey":["","survey_radar"]}
const ERRORS := {"robot_busy":"机体任务进行中，暂不能改装","item_unavailable":"部件已被占用或不属于该账号","fit_changed":"实装已变更，请重新选择","insufficient_stock":"制造材料不足","blueprint_locked":"尚未获得该工具蓝图","exclusive":"战术目镜与钻头争用精密总线","incomplete_fit":"机体尚有空槽","unchanged_fit":"装配没有变化","parts_full":"背包已满","hangar_full":"机库已满","invalid_name":"名称限 1 至 24 个可见字符","session_expired":"登录已失效，请返回档案重新登录"}
const RESOURCE_NAMES := {"structure":"结构","components":"零件","energy":"能源"}
const HULLS := Catalog.HULLS
var preview_robot := ""
var item_context := []
var endpoint := ""
var token := ""
var account := ""
var data := {}
var pending := {}
var busy := false
var draft_changed := false
var open_garage := false
var recovery_attempt := 0
var recovery_note := ""
var proven_refit := {}
var auto_reading := false
var read_failed := false
var read_lease := -1
var issued_identity: Array = []

func _ready() -> void:
	$PageRefresh.configure(_page_active, _can_auto_read, 10.0)
	$PageRefresh.read_due.connect(_auto_read)
	for editor in [%HullNumber.get_node("Fields"), %Orders.get_node("Body")]:
		editor.visibility_changed.connect(func():
			if editor.is_visible_in_tree():_cancel_auto_read())
	$Camera.look_at(Vector3(0,0.95,0))
	$Camera.h_offset = -1.7
	for hull:String in HULLS:
		%DraftHull.add_item("制造底盘 · "+Catalog.HULL_LABELS[hull])
		%HullTarget.add_item("预览底盘 · "+Catalog.HULL_LABELS[hull])
	%DraftHull.item_selected.connect(_draft_changed)
	%HullTarget.item_selected.connect(func(_n:int):_render())
	%ApplyHull.pressed.connect(func():
		var unit:Dictionary = data.robots[%Robot.get_selected_id()]
		_begin("chassis",{"robot":unit.id,"expected":unit.chassis,"chassis":HULLS[%HullTarget.selected]}))
	%Mode.add_item("设计与制造")
	%Mode.add_item("机库与实装")
	if open_garage:
		%Mode.select(1)
	for slot: String in OPTIONS:
		var picker := _picker(slot)
		for part: String in OPTIONS[slot]:
			picker.add_item(Catalog.LABELS[slot] + " · " + Catalog.LABELS[part])
		picker.item_selected.connect(_draft_changed)
		%Slot.add_item(Catalog.LABELS[slot])
	if open_garage:
		%Slot.select(2)
	%Mode.item_selected.connect(func(_n: int): _render())
	%HullNumber.changed.connect(func(value:String): $Robot.set_hull_number(value))
	%HullNumber.save_requested.connect(func(fields:Dictionary):_begin("hull-number",fields))
	%Favorite.pressed.connect(func():
		var unit:Dictionary=data.robots[%Robot.get_selected_id()]
		_begin("favorite",{"robot":unit.id,"saved":not bool(unit.get("favorite",false))}))
	%OnlyFavorites.toggled.connect(func(_enabled:bool):
		_fill(%Robot,data.get("robots",[]),_selected_id(%Robot,data.get("robots",[])),false)
		_render())
	%Robot.item_selected.connect(func(_n: int): _render())
	%Slot.item_selected.connect(func(_n: int): _render())
	%Item.item_selected.connect(func(_n: int): _refit_preview(true))
	%Design.item_selected.connect(func(_n: int): _load_design())
	%Name.text_changed.connect(func(_s: String): _draft_changed(0))
	%Save.pressed.connect(func(): _begin("design",{"name":%Name.text,"version":Catalog.VERSION,"chassis":HULLS[%DraftHull.selected],"slots":_parts()}))
	%Build.pressed.connect(_build)
	%Install.pressed.connect(_install)
	%ClaimPumpArm.pressed.connect(func():
		if pending.get("action")=="claim-pump-arm":_send()
		else:_begin("claim-pump-arm",{}))
	%Orders.save_orders.connect(func(orders:Variant):_begin("orders",{"robot":data.robots[%Robot.get_selected_id()].id,"orders":orders}))
	%Shop.pressed.connect(_shop)
	%Replace.pressed.connect(func(): _begin("design",{"name":%Name.text,"version":Catalog.VERSION,"chassis":HULLS[%DraftHull.selected],"slots":_parts(),"replace":data.designs[%Design.selected].id}))
	%Remove.pressed.connect(func(): _begin("remove",{"design":data.designs[%Design.selected].id}))
	%ApplyDesign.pressed.connect(_preview_apply)
	%ApplyPreview.dismissed.connect(func(): $HUD/Panel.show())
	%ApplyPreview.apply_requested.connect(func(fields:Dictionary):_begin("apply",fields))
	%ApplyPreview.retry_write.connect(func():
		if pending.get("action")=="apply":_send())

	%CopyDesign.pressed.connect(func():
		DisplayServer.clipboard_set(JSON.stringify({"version":Catalog.VERSION,"name":%Name.text,"chassis":HULLS[%DraftHull.selected],"slots":_parts()}))
		%Status.text="方案已复制，可发给好友预览。")
	%ImportDesign.pressed.connect(_import_design)
	%Retry.pressed.connect(_retry)
	%ReadRetry.pressed.connect(_retry)
	%RefitRetry.pressed.connect(_retry)
	$RecoveryTimer.timeout.connect(_send)
	%Back.pressed.connect(func(): closed.emit())
	$HTTP.request_completed.connect(_response)
	_restore()
	if pending.get("action")=="refit":
		%Mode.select(1)
		%Slot.select(OPTIONS.keys().find(pending.fields.slot))
	_send()

func _preview_apply() -> void:
	_cancel_auto_read()
	if %ApplyDesign.disabled:return
	var unit:Dictionary=data.robots[%Robot.get_selected_id()]
	var design:Dictionary=data.designs[%Design.get_selected_id()]
	$HUD/Panel.hide()
	%ApplyPreview.open(endpoint,token,unit,design)

func _intent_path() -> String:
	return "user://owned-" + (endpoint + account).sha256_text() + ".cfg"

func _shop() -> void:
	_cancel_auto_read()
	var page:=preload("res://store/store.tscn").instantiate()
	page.endpoint=endpoint
	page.token=token
	page.account=account
	page.preview.connect(_preview_store_robot)
	page.closed.connect(func(): page.queue_free(); $HUD/Panel.show(); _send())
	$HUD/Panel.hide()
	$Robot.hide()
	$HUD.add_child(page)

func _preview_store_robot(robot:Dictionary,paint:String) -> void:
	if robot.has("parts") and robot.has("chassis"):
		_show_robot(robot.chassis,robot.parts,paint,robot.get("hull_number",""))
	else:
		$Robot.hide()

func _equipped_parts(robot:Dictionary) -> Dictionary:
	var parts:={}
	for slot:String in robot.slots:
		parts[slot]=robot.slots[slot].definition
	return parts

func _import_design() -> void:
	var value:Variant=JSON.parse_string(DisplayServer.clipboard_get().left(2048))
	if not value is Dictionary or value.get("version")!=Catalog.VERSION or not value.get("slots") is Dictionary or not value.get("name") is String:
		%Status.text="无法读取方案，请复制完整的分享内容。"
		return
	var hull:Variant=value.get("chassis","crawler")
	if hull not in HULLS:
		%Status.text="方案底盘无法识别。"
		return
	var entities:={"preview":hull}
	for slot:String in OPTIONS:
		var part:Variant=value.slots.get(slot,"")
		if part=="" and "" in OPTIONS[slot]:continue
		if part not in OPTIONS[slot]:
			%Status.text="方案含不兼容的部件。"
			return
		entities[part]=part
	var check:=Rules.validate_unit({"version":Catalog.VERSION,"chassis":"preview","slots":value.slots},entities)
	if not check.ok:
		%Status.text=check.detail
		return
	%Name.text=str(value.name).left(24)
	%DraftHull.select(HULLS.find(hull))
	for slot:String in OPTIONS:
		_picker(slot).select(OPTIONS[slot].find(value.slots.get(slot,"")))
	_draft_changed(0)
	%Status.text="好友方案预览。保存占用常用位置，实装需自有部件。"

func _restore() -> void:
	var config := ConfigFile.new()
	if config.load(_intent_path()) == OK:
		pending = config.get_value("request","pending",{})

func _begin(action: String, fields: Dictionary) -> void:
	_cancel_auto_read()
	if busy or not $RecoveryTimer.is_stopped() or not pending.is_empty():
		return
	fields.key = Crypto.new().generate_random_bytes(16).hex_encode()
	recovery_attempt=0
	recovery_note=""
	pending = {"action":action,"fields":fields}
	var config := ConfigFile.new()
	config.set_value("request","pending",pending)
	if config.save(_intent_path()) != OK:
		pending.clear()
		%Status.text = "无法保存操作，请检查本地存储"
		return
	_send()

func _retry() -> void:
	_cancel_auto_read()
	if busy or not $RecoveryTimer.is_stopped():return
	recovery_attempt=0
	_send()

func _page_active() -> bool:
	return not token.is_empty() and $HUD/Panel.is_visible_in_tree() and not %ApplyPreview.visible and not %HullNumber.get_node("Fields").is_visible_in_tree() and not %Orders.get_node("Body").is_visible_in_tree()

func _process(_delta:float) -> void:
	if auto_reading and (not _page_active() or not $PageRefresh.foreground):_cancel_auto_read()

func _can_auto_read() -> bool:
	return not busy and pending.is_empty() and $RecoveryTimer.is_stopped()

func _auto_read() -> void:
	if not _can_auto_read():
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
	if busy or not $RecoveryTimer.is_stopped():
		return
	if read_only and not pending.is_empty():
		$PageRefresh.defer(read_lease)
		return
	var path := endpoint + "/v1/workshop"
	var method := HTTPClient.METHOD_GET
	var body := ""
	if not read_only and not pending.is_empty() and proven_refit.is_empty():
		path += "/" + str(pending.action)
		method = HTTPClient.METHOD_POST
		body = JSON.stringify(pending.fields)
	issued_identity=[endpoint,token,account]
	busy = true
	if %ApplyPreview.visible and pending.get("action")=="apply":
		%ApplyPreview.write_status("正在提交本次换装…",false,false)
	_render()
	var err: Error = $HTTP.request(path,Endpoints.headers(token),method,body)
	if err != OK:
		_retire_http()
		busy = false
		if pending.is_empty():
			read_failed=true
			$PageRefresh.settled(false,false,read_lease)
			read_lease=-1
			auto_reading=false
		if _recoverable():
			_uncertain()
			return
		%Status.text = "连接失败，请重试"
		if %ApplyPreview.visible and pending.get("action")=="apply":%ApplyPreview.write_status(%Status.text,true,false)
		_render()

func _response(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if auto_reading and (not _page_active() or not $PageRefresh.foreground):
		_cancel_auto_read()
		return
	if issued_identity!=[endpoint,token,account]:
		busy=false
		read_failed=true
		$PageRefresh.settled(false,true,read_lease)
		return
	if not busy:return
	busy = false
	var payload: Variant = JSON.parse_string(bytes.get_string_from_utf8()) if not bytes.is_empty() else null
	var recovered_read:=read_failed
	if pending.is_empty():
		read_failed=not (result==HTTPRequest.RESULT_SUCCESS and status==200 and payload is Dictionary and _valid_workshop(payload.get("workshop")))
		$PageRefresh.settled(not read_failed,status in [401,426],read_lease)
		read_lease=-1
		auto_reading=false
	var applying:bool=pending.get("action")=="apply"
	var refitting:bool=pending.get("action")=="refit"
	var scoped:bool=_recoverable()
	if scoped and (result!=HTTPRequest.RESULT_SUCCESS or status in [408,429] or status>=500 or status<100 or not payload is Dictionary):
		_uncertain()
		return
	if scoped and status!=200 and (status<400 or not payload.get("error") is String or payload.error.is_empty()):
		_uncertain()
		return
	if scoped and status==200:
		if not _valid_workshop(payload.get("workshop")):
			_uncertain()
			return
		if refitting:
			if proven_refit.is_empty():
				if not _matches_receipt(payload.get("receipt")):
					_uncertain()
					return
				if not _matches_mount(payload.workshop,payload.receipt):
					# Another session may have changed this fit after the original commit.
					proven_refit=payload.receipt
					call_deferred("_send")
					return
			else:
				payload.receipt=proven_refit
			var matches:=_matches_mount(payload.workshop,payload.receipt)
			recovery_note=("实装已确认" if matches else "已查到原换装收据，当前装配已有变化。已刷新机库。")+" · #"+str(payload.receipt.id).left(8)
			proven_refit={}
			%Mode.select(1)
			%Slot.select(OPTIONS.keys().find(pending.fields.slot))
		elif pending.get("action") in ["design","build"]:
			if not _confirmed_work_order(payload.get("receipt"),payload.workshop.designs):
				_uncertain()
				return
			recovery_note="%s已确认 · 收据 #%s" % [_operation_label(),str(payload.receipt.id).left(8)]
		else:
			recovery_note=""
		recovery_attempt=0
	var numbering:bool=pending.get("action")=="hull-number"
	var missing_receipt:bool=applying and status==200 and (not payload is Dictionary or not payload.get("workshop") is Dictionary or not payload.get("receipt") is Dictionary or payload.receipt.get("operation")!="apply" or payload.receipt.get("robot")!=pending.fields.robot or payload.receipt.get("design")!=pending.fields.design)
	if numbering and status==200:
		var receipt:Variant=payload.get("receipt") if payload is Dictionary else null
		missing_receipt=not _valid_workshop(payload.get("workshop") if payload is Dictionary else null) or not receipt is Dictionary or not receipt.get("id") is String or receipt.get("operation")!="hull-number" or receipt.get("robot")!=pending.fields.robot or receipt.get("previous")!=pending.fields.expected or receipt.get("value")!=pending.fields.value
	if pending.get("action")=="claim-pump-arm" and status==200:
		missing_receipt=not _arm_receipt_valid(payload)
	if result != HTTPRequest.RESULT_SUCCESS or not payload is Dictionary or status >= 500 or missing_receipt:
		%Status.text = "服务未响应，重试将沿用同一操作编号"
		if applying and %ApplyPreview.visible:%ApplyPreview.write_status(%Status.text,true,false)
		_render()
		return
	if not pending.is_empty() and status != 401:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_intent_path()))
		pending.clear()
	if status != 200:
		var errors:=ERRORS.duplicate()
		errors.merge({"different_chassis":"方案底盘不同，请先在机库更换底盘。","weight":"部件超载，请先卸下重件。","unit_unavailable":"只有待命且完好的机体能更换底盘。","design_slots_full":"常用方案已满，可替换或移出一套。","inactive_design":"历史方案尚未占用可用位置。","design_part_missing":"缺少此方案所需的自有闲置部件。","design_already_active":"该名称已拥有常用位置。"})
		errors.merge({"number_robot_unavailable":"只有待命且完好的机体能改号。","invalid_hull_number":"请输入两位半角数字，或清空机身号。","unchanged_number":"机身号已相同。","number_changed":"另一窗口已改号，正在刷新当前机身号。","unknown_robot":"未找到这台自有机体。"})
		errors["no_pending_pump_arm"]="没有待领的泵房维修臂，正在刷新机库。"
		%Status.text = errors.get(payload.get("error",""),str(payload.get("error",status)))
		if scoped:
			recovery_note=%Status.text
			proven_refit={}
		if applying and %ApplyPreview.visible:
			%ApplyPreview.write_status(%Status.text+" · 请重新预览。",false,status!=401)
		elif status == 409 or payload.get("error")=="blueprint_locked":
			call_deferred("_reload_after_conflict")
		_render()
		return
	var old_robot := _selected_id(%Robot, data.get("robots",[]))
	var old_design := _selected_id(%Design, data.get("designs",[]))
	data = payload.workshop
	var receipt: Dictionary = payload.get("receipt",{})
	if receipt.get("operation")=="build":
		%OnlyFavorites.set_pressed_no_signal(false)
	_fill(%Robot,data.robots,str(receipt.get("robot",old_robot)),false)
	_fill(%Design,data.designs,str(receipt.get("design",old_design)),true)
	if receipt.get("operation")=="build" and _selected_id(%Robot,data.robots)!=receipt.robot:
		%Robot.select(-1)
		recovery_note+=" · 原机体已不在机库"
	if receipt.get("operation") in ["build","design"] and _selected_id(%Design,data.designs)!=receipt.design:
		%Design.select(-1)
		recovery_note+=" · 原方案已不在列表"
	if applying and %ApplyPreview.visible:
		%ApplyPreview.write_status("换装已完成 · 收据 #"+str(receipt.id).left(8),false,true)
	if receipt.get("operation","") == "build":
		%Mode.select(1)
	if not receipt.is_empty():
		%Status.text = "账本已记录 · " + str(receipt.id).left(8)
		if numbering:
			%Mode.select(1)
			var selected:Array=data.robots.filter(func(unit):return unit.id==receipt.robot)
			if not selected.is_empty() and selected[0].get("hull_number","")==receipt.value:
				%Status.text = "机身号已保存 · "+("无号" if str(receipt.value).is_empty() else str(receipt.value))
			else:
				%Status.text = "原编号收据已确认，当前机身号已有变化。"
	if %Design.selected >= 0 and (not draft_changed or receipt.get("operation","") == "design"):
		_load_design()
	if recovered_read and not read_failed:
		%Status.text=""
	_render()

func _recoverable() -> bool:
	return pending.is_empty() or pending.get("action") in ["refit","build","design"]

func _operation_label() -> String:
	return {"refit":"实装","build":"制造","design":"方案保存"}.get(pending.get("action",""),"机库读取")

func _confirmed_work_order(receipt:Variant,designs:Array) -> bool:
	if not receipt is Dictionary or receipt.get("operation")!=pending.action or receipt.get("confirmation_key")!=pending.fields.key:
		return false
	for field in ["id","design"]:
		if not receipt.get(field) is String or receipt[field].is_empty():return false
	if pending.action=="design":
		var revision:Variant=receipt.get("revision")
		if not (revision is float or revision is int) or revision<1 or revision!=floor(revision):return false
		for design:Dictionary in designs:
			if design.id==receipt.design:
				return design.revision==revision and design.name==str(pending.fields.name).strip_edges() and design.slots==pending.fields.slots and design.get("chassis","crawler")==pending.fields.chassis
		return true
	var installed:Variant=receipt.get("installed")
	if receipt.design!=pending.fields.design or not receipt.get("robot") is String or receipt.robot.is_empty() or not installed is Dictionary or not installed.has_all(["core","head","weapon"]):
		return false
	var ids:={}
	for design:Dictionary in designs:
		if design.id==receipt.design and (design.slots.size()!=installed.size() or not installed.has_all(design.slots.keys())):return false
	for slot:Variant in installed:
		var id:Variant=installed[slot]
		if not OPTIONS.has(slot) or not id is String or id.is_empty() or ids.has(id):return false
		ids[id]=true
	return true

func _uncertain() -> void:
	if pending.is_empty():
		recovery_note="机库连接中断，正在恢复连接。"
		%Status.text=recovery_note
		_render()
		return
	recovery_note="机库尚未读取" if pending.is_empty() and data.is_empty() else _operation_label()+"待确认"
	if recovery_attempt==0:
		recovery_attempt=1
		recovery_note+=" · 正在自动重试"
		$RecoveryTimer.start()
	else:
		recovery_note+=" · 请手动核对"
	%Status.text=recovery_note
	_render()
	if %ReadNotice.is_visible_in_tree():
		$HUD/Panel/Scroll.call_deferred("ensure_control_visible",%ReadNotice)

func _valid_workshop(w:Variant) -> bool:
	if not w is Dictionary or not w.get("robots") is Array or not w.get("designs") is Array or not w.get("available") is Array:return false
	for field in ["stock","chassis_cost"]:
		if not w.get(field) is Dictionary:return false
		for resource in RESOURCE_NAMES:
			if not w[field].has(resource):return false
	if not w.has("part_capacity") or not w.has("hangar_capacity"):return false
	for unit:Variant in w.robots:
		if not unit is Dictionary or not unit.has_all(["id","name","task","chassis","slots"]) or not unit.slots is Dictionary:return false
		for part:Variant in unit.slots.values():
			if not part is Dictionary or not part.has_all(["id","definition"]):return false
	for part:Variant in w.available:
		if not part is Dictionary or not part.has_all(["id","definition"]):return false
	for design:Variant in w.designs:
		if not design is Dictionary or not design.has_all(["id","name","revision","slots"]) or not design.slots is Dictionary:return false
	return true

func _matches_receipt(r:Variant) -> bool:
	var f:Dictionary=pending.fields
	return r is Dictionary and r.get("id") is String and not r.id.is_empty() and r.get("operation")=="refit" and r.get("robot")==f.robot and r.get("slot")==f.slot and r.get("installed")==f.item and r.get("returned") in [f.expected,""]

func _matches_mount(w:Dictionary,r:Dictionary) -> bool:
	for unit:Dictionary in w.robots:
		if unit.id!=r.robot:continue
		if unit.slots.get(r.slot,{}).get("id","")!=r.installed:return false
		var prior:String=pending.fields.expected
		if prior.is_empty():return true
		var in_bag:bool=w.available.any(func(part:Dictionary):return part.id==prior)
		# Temporary relief parts are consumed on removal, ordinary parts return to the bag.
		return in_bag==(r.returned==prior)
	return false

func _reload_after_conflict() -> void:
	if not busy and pending.is_empty():
		_send()

func _arm_receipt_valid(payload:Variant) -> bool:
	if not payload is Dictionary or not payload.get("workshop") is Dictionary or not payload.get("receipt") is Dictionary:
		return false
	var receipt:Dictionary=payload.receipt
	var arm:Variant=payload.workshop.get("recovered_arm")
	if not arm is Dictionary or arm.get("status")!="delivered" or not arm.get("part_id") is String or arm.part_id.is_empty():
		return false
	return receipt.get("operation")=="pump_arm_claim" and receipt.get("id") is String and not receipt.id.is_empty() and receipt.get("part") is Dictionary and receipt.part.get("definition")=="repair_arm" and receipt.part.get("id")==arm.part_id and arm.get("mission")==receipt.get("mission")

func _show_recovered_arm(locked:bool) -> void:
	var arm:Dictionary=data.get("recovered_arm",{})
	var retrying:bool=pending.get("action")=="claim-pump-arm"
	var waiting:bool=arm.get("status")=="pending"
	var full:bool=waiting and data.available.size()>=int(data.part_capacity)
	%RecoveredArm.visible=waiting or arm.get("status")=="delivered" or retrying
	%ClaimPumpArm.visible=waiting or retrying
	%ClaimPumpArm.disabled=busy if retrying else (locked or full)
	%ClaimPumpArm.text="核对本次领取" if retrying else "领取泵房维修臂"
	if retrying:
		%RecoveredArm.text="正在核对维修臂领取结果" if busy else "维修臂领取尚未确认，可用原请求重试。"
	elif waiting:
		%RecoveredArm.text="泵房首通维修臂待领"+(" · 背包已满，先装上一件闲置部件腾出一个仓位。" if full else " · 可领入背包。")
	elif arm.get("status")=="delivered":
		var part_id:String=arm.part_id
		var caption:="泵房回收 · 维修臂 #%s" % part_id.left(8)
		for robot:Dictionary in data.robots:
			if robot.slots.get("utility",{}).get("id","")==part_id:
				%RecoveredArm.text=caption+" · 已装于 %s 的 AUX 槽" % robot.name
				return
		for item:Dictionary in data.available:
			if item.id==part_id:
				%RecoveredArm.text=caption+" · 在背包，可装在带 AUX 接口的底盘上。"
				return
		%RecoveredArm.text=caption

func _fill(picker: OptionButton, rows: Array, focus: String, designs: bool) -> void:
	picker.clear()
	for i in rows.size():
		var row: Dictionary = rows[i]
		if not designs and %OnlyFavorites.button_pressed and not row.get("favorite",false):
			continue
		var tag:=(" · %d 格" % int(row.position) if row.get("active",false) else " · 历史") if designs else ""
		picker.add_item(str(row.name) + (" · v%d" % int(row.revision) + tag if designs else " · ID " + str(row.id).left(8)) + (" ★" if row.get("favorite",false) else ""),i)
		if row.id == focus:
			picker.select(picker.item_count-1)

func _selected_id(picker: OptionButton, rows: Array) -> String:
	return str(rows[picker.get_selected_id()].id) if picker.selected >= 0 and picker.get_selected_id() < rows.size() else ""

func _picker(slot: String) -> OptionButton:
	return {"core":%Core,"head":%Head,"weapon":%Weapon,"utility":%Utility,"armor":%Armor,"survey":%Survey}[slot]

func _parts() -> Dictionary:
	var parts := {}
	for slot: String in OPTIONS:
		if slot=="survey" and HULLS[%DraftHull.selected]!="survey_wheel":continue
		var chosen:String=OPTIONS[slot][_picker(slot).selected]
		if not chosen.is_empty():parts[slot]=chosen
	return parts

func _draft_changed(_index: int) -> void:
	draft_changed = true
	_render()

func _load_design() -> void:
	var design: Dictionary = data.designs[%Design.selected]
	%Name.text = design.name
	%DraftHull.select(HULLS.find(design.get("chassis","crawler")))
	for slot: String in OPTIONS:
		_picker(slot).select(OPTIONS[slot].find(design.slots.get(slot,"")))
	draft_changed = false
	_render()

func _build() -> void:
	if not %Build.disabled and %Design.selected >= 0:
		_begin("build",{"design":data.designs[%Design.selected].id,"name":%BuildName.text})

func _install() -> void:
	if %Install.disabled:return
	var robot: Dictionary = data.robots[%Robot.get_selected_id()]
	var slot: String = OPTIONS.keys()[%Slot.selected]
	_begin("refit",{"robot":robot.id,"slot":slot,"expected":robot.slots.get(slot,{}).get("id",""),"item":%Item.get_selected_metadata()})

func _render_hull_quote(robot:Dictionary,target:String,choice:Dictionary,locked:bool) -> void:
	var hull:String=robot.chassis
	if hull==target:
		%HullQuote.text="已装备 · "+Catalog.HULL_LABELS[hull]+"底盘\n"+_combat_line(_validate_fit(hull,choice,true))+"\n"+_hull_sockets(hull)
		%ApplyHull.text="已装备"
		%ApplyHull.disabled=true
		return
	%ApplyHull.text="确认更换底盘"
	var mass:=0
	for definition:String in choice.values():
		mass+=int(Catalog.PARTS[definition].mass)
	var price:Dictionary=data.chassis_cost
	var affordable:bool=data.stock.structure>=-price.structure and data.stock.components>=-price.components and data.stock.energy>=-price.energy
	%HullQuote.text="当前 "+_stats(hull)+"\n预览 "+_stats(target)+"\n费用 %d 结构、%d 零件、%d 能源。旧底盘拆解，无返料；已装部件留用。" % [-price.structure,-price.components,-price.energy]
	%HullQuote.text+="\n更换后 · "+_command_points(_validate_fit(target,choice))
	var unsupported:=PackedStringArray()
	for mount:String in choice:
		if not Catalog.CHASSIS[target].slots.has(mount):
			unsupported.append(Catalog.LABELS[mount]+"上的"+Catalog.LABELS[choice[mount]])
	if not unsupported.is_empty():
		%HullQuote.text+="\n接口不兼容，请先卸下"+"、".join(unsupported)+"。"
	elif mass>int(Catalog.CHASSIS[target].payload):
		%HullQuote.text+="\n当前装配超载，请先卸下重件。"
	elif not affordable:
		%HullQuote.text+="\n库存不足。"
	%ApplyHull.disabled=locked or not unsupported.is_empty() or not affordable or mass>int(Catalog.CHASSIS[target].payload) or robot.task!=null or robot.state!="ready"

func _hull_sockets(hull:String) -> String:
	var sockets:=PackedStringArray()
	for mount:String in Catalog.CHASSIS[hull].slots:
		sockets.append(Catalog.LABELS[mount])
	return "接口 · "+"、".join(sockets)

func _stats(hull:String) -> String:
	var stats:Dictionary=Catalog.CHASSIS[hull]
	return "%s · 耐久 %d / 速度 %.1f / 载重 %d / 底盘基础 %d 点\n%s" % [Catalog.HULL_LABELS[hull],stats.max_hp,stats.move_speed,stats.payload,stats.points,_hull_sockets(hull)]

func _validate_fit(hull:String, slots:Dictionary, partial := false) -> Dictionary:
	var inventory:={"preview":hull}
	for definition:String in slots.values():
		inventory[definition]=definition
	return Rules.validate_unit({"version":Catalog.VERSION,"chassis":"preview","slots":slots},inventory,Catalog.CHASSIS,Catalog.PARTS,partial)

func _combat_line(fit:Dictionary) -> String:
	if not fit.ok:
		return "不可出战 · " + str(fit.detail)
	return "最大耐久 %d　移速 %.1f　载重 %d/%d　指挥点 %d" % [fit.combat.max_hp,fit.combat.move_speed,fit.totals.mass,fit.totals.payload,fit.totals.points]

func _refit_preview(show_candidate:=false) -> void:
	%Install.disabled = true
	%CombatPreview.text = ""
	if %Robot.selected < 0 or %Mode.selected != 1:return
	var robot:Dictionary = data.robots[%Robot.get_selected_id()]
	var parts := _equipped_parts(robot)
	var hull:String = robot.chassis
	%CombatPreview.text = "当前　" + _combat_line(_validate_fit(hull,parts,true))
	if %Item.selected < 0:return
	var slot:String = OPTIONS.keys()[%Slot.selected]
	var item_id:String = %Item.get_selected_metadata()
	if item_id.is_empty():
		parts.erase(slot)
	else:
		var replacement := ""
		for item:Dictionary in data.available:
			if item.id == item_id:
				replacement = item.definition
				break
		if replacement.is_empty():return
		parts[slot] = replacement
	if parts.get("weapon")=="rivet_repeater":
		%CombatPreview.text+=" · 连发器：射程 3.5 米，每 0.4 秒直击 3 点"
	if parts.get("survey")=="survey_radar":
		%CombatPreview.text+=" · 测绘雷达：秘宝场 5 米内共享箱情报"
	if slot=="weapon" and parts.get("weapon")=="chimney_arm":
		%CombatPreview.text+=" · 烟囱炮臂：预警 0.8 秒，落点半径 2 米"
	if show_candidate:_show_robot(hull,parts,robot.get("paint","base"),%HullNumber.displayed())
	var after := _validate_fit(hull,parts,true)
	%CombatPreview.text += ("\n拆卸后　" if item_id.is_empty() else "\n装入后　") + _combat_line(after)
	var legal:bool = after.ok or after.code == "missing_slot"
	var bag_full:bool = item_id.is_empty() and data.available.size() >= int(data.part_capacity)
	if bag_full:%CombatPreview.text += "\n背包已满，暂不能拆卸"
	%Install.disabled = (busy and not auto_reading) or read_failed or not pending.is_empty() or robot.task != null or not legal or bag_full

func _command_points(fit:Dictionary) -> String:
	if not fit.ok:
		return "不可出战 · " + str(fit.detail)
	return "整机出战 %d 指挥点　载重 %d/%d" % [fit.totals.points,fit.totals.mass,fit.totals.payload]

func _draft_quote(hull:String,parts:Dictionary,fit:Dictionary) -> bool:
	var lines:=PackedStringArray([_stats(hull)])
	if parts.get("survey")=="survey_radar":
		lines.append("测绘雷达 · 在秘宝场 5 米内与全队共享密封箱内容")
	if parts.get("weapon")=="rivet_repeater":
		lines.append("铆钉连发器 · 射程 3.5 米，每 0.4 秒直击 3 点")
	if not fit.ok:
		lines.append(_command_points(fit))
		%DraftStats.text="\n".join(lines)
		return false
	if not data.has("build_prices") or not data.has("buildable_weapons"):
		lines.append("制造报价暂未取得，连接恢复后自动更新。")
		%DraftStats.text="\n".join(lines)
		return false
	if parts.weapon=="chimney_arm":
		lines.append(_command_points(fit))
		lines.append("旧武器库探索实体件 · 可保存配置，实装需持有烟囱炮臂。")
		%DraftStats.text="\n".join(lines)
		return false
	var costs:=PackedStringArray()
	var missing:=PackedStringArray()
	var prices:Dictionary=data.build_prices
	for resource:String in RESOURCE_NAMES:
		var required:=-int(prices.chassis[hull][resource])
		for part:String in parts.values():
			required-=int(prices.parts[part].get(resource,0))
		costs.append("%s %d" % [RESOURCE_NAMES[resource],required])
		var shortage:=required-int(data.stock[resource])
		if shortage>0:missing.append("%s %d" % [RESOURCE_NAMES[resource],shortage])
	lines.append(_command_points(fit)+"　机库 %d/%d" % [data.robots.size(),data.hangar_capacity])
	lines.append("制造消耗 · "+"　".join(costs))
	var blocks:=PackedStringArray()
	if not missing.is_empty():blocks.append("缺少"+"、".join(missing))
	if parts.weapon not in data.buildable_weapons:blocks.append("未掌握"+str(Catalog.LABELS[parts.weapon])+"配方")
	if data.robots.size()>=int(data.hangar_capacity):blocks.append("机库已满")
	if not blocks.is_empty():
		lines.append("暂不能制造 · "+"；".join(blocks))
	elif draft_changed or %Design.selected<0:
		lines.append("保存方案后可制造")
	elif not data.designs[%Design.selected].active:
		lines.append("方案需先启用")
	%DraftStats.text="\n".join(lines)
	return blocks.is_empty()

func _render() -> void:
	var drafting: bool = %Mode.selected == 0
	if %ApplyPreview.visible:
		if drafting or %ApplyPreview.target.get("robot")!=_selected_id(%Robot,data.robots) or %ApplyPreview.target.get("design")!=_selected_id(%Design,data.designs):
			%ApplyPreview.dismiss()
	%Draft.visible = drafting
	%Garage.visible = not drafting
	%Retry.disabled = busy or not $RecoveryTimer.is_stopped()
	%Retry.text = "重新连接" if pending.is_empty() else "恢复本次操作"
	%Retry.visible = read_failed or not pending.is_empty()
	%Back.disabled = busy and not auto_reading
	var locked:bool = (busy and not auto_reading) or read_failed or not $RecoveryTimer.is_stopped() or not pending.is_empty() or data.is_empty()
	_show_recovered_arm(locked)
	%Shop.disabled=locked
	%OnlyFavorites.disabled=locked
	%Favorite.disabled=locked or %Robot.selected<0
	var no_selection:bool=not drafting and %Robot.selected<0
	var empty_favorites:bool=no_selection and %OnlyFavorites.button_pressed
	for control:Control in %Garage.get_children():
		if control!=%Robot and control!=%OnlyFavorites.get_parent():
			control.visible=not no_selection
	var refitting:bool=pending.get("action")=="refit"
	var waiting:bool=busy or not $RecoveryTimer.is_stopped()
	var confirming_write:bool=pending.get("action") in ["design","build"]
	var order_note:bool=recovery_note.begins_with("制造已确认") or recovery_note.begins_with("方案保存已确认")
	%ReadNotice.visible=confirming_write or order_note or (data.is_empty() and (pending.is_empty() or refitting)) or (pending.is_empty() and recovery_note.begins_with("机库读取待确认"))
	%ReadNotice.text=recovery_note if not recovery_note.is_empty() else ("正在核对本次"+_operation_label() if not pending.is_empty() else "正在读取机库")
	%ReadRetry.visible=%ReadNotice.visible and not order_note and not waiting
	%ReadRetry.text="核对本次"+_operation_label() if not pending.is_empty() else "重新连接"
	%Mode.disabled=refitting or confirming_write or data.is_empty()
	for picker:OptionButton in [%Robot,%Slot,%Item]:picker.disabled=refitting
	%RefitNotice.visible=not data.is_empty() and not drafting and not empty_favorites and not %ReadNotice.visible and (refitting or not recovery_note.is_empty())
	%RefitNotice.text=recovery_note if not recovery_note.is_empty() else "正在核对本次换装"
	%Install.visible=not refitting and not no_selection
	%RefitRetry.visible=%RefitNotice.visible and refitting
	%RefitRetry.disabled=waiting
	if data.is_empty() and _recoverable():
		%Draft.hide()
		%Garage.hide()
	if empty_favorites:
		$Robot.hide()
		%Hint.text="暂无收藏机体，关闭「仅看收藏」可浏览机库。"
		return
	var active_design:bool=not data.is_empty() and %Design.selected>=0 and bool(data.designs[%Design.selected].get("active",false))
	%ApplyDesign.disabled=locked or not active_design or %Robot.selected<0
	%ApplyDesign.text="预览套用「%s」v%d 到此机体" % [data.designs[%Design.selected].name,data.designs[%Design.selected].revision] if active_design else "先在设计页选择常用方案"
	%Replace.disabled=locked or not active_design
	%Remove.disabled=locked or %Design.selected<0
	%Save.disabled = locked
	%Build.disabled = locked or draft_changed or not active_design
	%Install.disabled = true
	if data.is_empty():
		$Robot.hide()
		return
	if not drafting and %Robot.selected<0:
		$Robot.hide()
		%Identity.text="未选中机体"
		%Hint.text=""
		return
	%Stock.text = "结构 %d　零件 %d　能源 %d　方案 %d/%d" % [data.stock.structure,data.stock.components,data.stock.energy,data.get("design_used",0),data.get("design_capacity",6)]
	if confirming_write or recovery_note.begins_with("机库读取待确认"):
		%Stock.text="上次读取 · "+%Stock.text
	var choice := _parts()
	if drafting:
		var hull:String=HULLS[%DraftHull.selected]
		_show_robot(hull,choice,"base")
		var validation:=_validate_fit(hull,choice)
		%Survey.visible=Catalog.CHASSIS[hull].slots.has("survey")
		var can_build:=_draft_quote(hull,choice,validation)
		%Save.disabled=locked or not validation.ok
		%Replace.disabled=%Replace.disabled or not validation.ok
		%Build.disabled=%Build.disabled or not can_build
		%Hint.text=""

	elif %Robot.selected >= 0:
		var robot: Dictionary = data.robots[%Robot.get_selected_id()]
		%Favorite.text="取消收藏" if robot.get("favorite",false) else "收藏机体"
		%Orders.bind(robot,data.robots,locked)
		choice = _equipped_parts(robot)
		var hull:String=robot.get("chassis","crawler")
		if preview_robot!=robot.id:
			preview_robot=robot.id
			%HullTarget.select(HULLS.find(hull))
		var survey_index:=OPTIONS.keys().find("survey")
		var survey_supported:bool=Catalog.CHASSIS[hull].slots.has("survey")
		%Slot.set_item_disabled(survey_index,not survey_supported)
		if not survey_supported and %Slot.selected==survey_index:%Slot.select(2)
		var target:String=HULLS[%HullTarget.selected]
		%HullNumber.bind(robot,locked)
		_show_robot(target,choice,robot.get("paint","base"),%HullNumber.displayed())
		_render_hull_quote(robot,target,choice,locked)
		var slot: String = OPTIONS.keys()[%Slot.selected]
		var installed: Dictionary = robot.slots.get(slot,{})
		%Identity.text = "实体 ID · " + str(robot.id) + "\n" + Catalog.LABELS[slot] + " · " + (Catalog.LABELS.get(installed.get("definition",""),"空槽")) + "  " + str(installed.get("id","")).left(8)
		%Identity.text+="\n当前实装 · "+_command_points(_validate_fit(hull,choice))
		var context := [robot.id,slot,installed.get("id","")]
		var previous:Variant = %Item.get_selected_metadata() if context == item_context and %Item.selected >= 0 else null
		item_context = context
		%Item.clear()
		if not installed.is_empty():
			%Item.add_item("拆卸 · 归还背包")
			%Item.set_item_metadata(0,"")
		for item in data.available:
			if item.definition in OPTIONS[slot]:
				var source:=" · 泵房回收" if item.id==data.get("recovered_arm",{}).get("part_id","") else ""
				%Item.add_item("安装 · " + Catalog.LABELS[item.definition] + "  " + str(item.id).left(8)+source)
				%Item.set_item_metadata(%Item.item_count-1,item.id)
		if previous != null:
			%Item.select(-1)
			for index in %Item.item_count:
				if %Item.get_item_metadata(index) == previous:
					%Item.select(index)
					break
		_refit_preview()
		if refitting:
			%CombatPreview.text="等待核对时，暂不展示换装前后的战斗数值。"
			%Identity.text="机体 #%s · %s实装待确认" % [str(pending.fields.robot).left(8),Catalog.LABELS[pending.fields.slot]]
		var condition: String = {"ready":"待命","damaged":"待维修","repairing":"维修中"}.get(robot.get("state","ready"),str(robot.get("state","")))
		var assignment: String = {"expedition":"出征中","guard":"驻防中","aid":"援助中","repair":"维修中"}.get(str(robot.task),condition)
		%Hint.text = "%s · 机库 %d/%d　背包 %d/%d" % [assignment,data.robots.size(),data.hangar_capacity,data.available.size(),data.part_capacity]

	if not drafting and choice.get("survey")=="survey_radar":
		%Identity.text+="\n秘宝场 · 5 米内向全队揭示密封箱"
	if choice.get("head")=="visor":
		%Hint.text += ("" if %Hint.text.is_empty() else "\n")+"战术目镜：新目标锁定 0.05 秒（普通头 0.25 秒）。持续射速由武器决定。"


func _show_robot(hull:String,choice:Dictionary,paint:String,hull_number:="") -> void:
	$Robot.show()
	if $Robot.chassis!=hull:
		$Robot.set_chassis(hull)
	$Robot.set_paint(paint)
	$Robot.set_hull_number(hull_number)
	$Robot.set_repair_arm(choice.get("utility")=="repair_arm")
	$Robot.set_jammer(choice.get("utility")=="jammer")
	$Robot.set_shield(choice.get("armor")=="rivet_shield")
	$Robot.set_survey_radar(choice.get("survey")=="survey_radar")
	$Robot.head = 1 if choice.get("head") == "visor" else 0
	$Robot.set_weapon_definition(choice.get("weapon",""))
	$Robot.scale = Vector3.ONE * (1.2 if choice.get("core") == "reinforced_boiler" else 1.0)
	$Robot.set_slots_present(choice.has("head"),choice.has("weapon"))


func _retire_http() -> void:
	var previous:HTTPRequest=$HTTP
	previous.request_completed.disconnect(_response)
	previous.cancel_request()
	var replacement:=previous.duplicate(0) as HTTPRequest
	remove_child(previous)
	replacement.name="HTTP"
	add_child(replacement)
	replacement.request_completed.connect(_response)
	previous.queue_free()
