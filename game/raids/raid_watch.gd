extends Node3D
const Endpoints:=preload("res://client/endpoints.gd")
const BaseBuilding:=preload("res://base/building.gd")
const FacilityRecovery:=preload("res://base/facility_recovery.gd")

signal closed
signal condition_requested(robot:String)
const Robot := preload("res://assets/steam_crawler/robot.tscn")
const SalvageArt := preload("res://assets/salvage/kit.gd")
const Bee := preload("res://raids/salvage_bee.tscn")
const BEE_OFFSETS := [Vector3(-0.34,0.12,0.23), Vector3(0.34,0.12,-0.23), Vector3(0.16,0.22,0.35)]
const PRESSURE_REASONS := {"previous_loss":"上次失守", "guard_recovery":"上次驻防机尚未修复"}
const RESOURCES := {"structure":"结构","components":"零件","energy":"能源"}
var endpoint := ""
var token := ""
var data := {}
var report_id := ""
var rendered_id := ""
var rendered_revision := -1
var elapsed := 0.0
var poll := 0.0
var replay_at := -1.0
var last_frame := -1
const READ_DELAYS := [0.65, 1.5]
const ACTIVE_RECHECK := 10.0
var busy := false
var slow_recheck := false
var leaving := false
var retry_count := 0
var retry_in := -1.0
var read_blocked := false
var sending_guard := false
var pending_guard := {}
var guard_raid := ""
var guard_options: Array = []
var guard_recommended := false
var guard_view: Node3D
var foes := {}
var towers := {}
var approach_cells:Array=[]
var app_paused:=false
var refresh_requested:=false
var auth_failed:=false
var received_ms:=0

func _ready() -> void:
	%Refresh.pressed.connect(_manual_refresh)
	%Refresh.hide()
	%Refresh.text="重新连接"
	%Back.pressed.connect(_leave)
	%Commit.pressed.connect(_guard)
	%GuardCondition.pressed.connect(func():
		if _has_guard_damage(): condition_requested.emit(str(data.guard.id)))
	%Guard.item_selected.connect(func(_index:int): _update_commit())
	%DetailsToggle.toggled.connect(_toggle_details)
	%Replay.pressed.connect(func(): replay_at=0.0; last_frame=-1)
	$HTTP.request_completed.connect(_received)
	%Guard.hide()
	%Commit.hide()
	%Replay.hide()
	_request()

func _leave() -> void:
	if leaving:return
	leaving=true
	set_process(false)
	$HTTP.cancel_request()
	closed.emit.call_deferred()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		app_paused=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_paused=false
		refresh_requested=true

func _page_active() -> bool:
	return not leaving and not app_paused and is_visible_in_tree()

func _exit_tree() -> void:
	leaving=true
	$HTTP.cancel_request()

func _has_guard_damage() -> bool:
	return data.get("stage")=="replay" and data.get("guard") is Dictionary and not str(data.guard.get("id","")).is_empty() and int(data.receipt.repair_cost)>0

func _guard() -> void:
	if busy or read_blocked or not pending_guard.is_empty() or data.get("stage")!="warning" or data.get("guard")!=null or data.get("id")!=guard_raid or %Guard.selected<0:
		return
	var id:String=%Guard.get_selected_metadata()
	if data.eligible.any(func(robot):return robot.id==id):
		_request({"raid":guard_raid,"robot":id})

func _update_commit() -> void:
	%Refresh.visible=read_blocked and not auth_failed
	%Refresh.disabled=busy or (retry_in>=0.0 and not slow_recheck)
	%Commit.disabled=busy or read_blocked or not pending_guard.is_empty() or not %Guard.visible or %Guard.selected<0

func _refresh_guards() -> void:
	var warning:bool=data.stage=="warning" and data.get("guard")==null
	var raid:String=data.id if warning else ""
	var options:Array=data.eligible if warning else []
	var new_raid:=raid!=guard_raid
	%Guard.visible=not options.is_empty()
	%Commit.visible=%Guard.visible
	if new_raid or guard_options!=options:
		var previous:String="" if new_raid or %Guard.selected<0 else str(%Guard.get_selected_metadata())
		if %Guard.get_popup().visible:
			%Guard.get_popup().hide()
		if new_raid:guard_recommended=false
		guard_raid=raid
		guard_options=options.duplicate(true)
		%Guard.clear()
		var selected_index:=-1
		for robot:Dictionary in options:
			var id:String=robot.id
			var short_id:=id.left(8)
			while short_id.length()<id.length() and options.any(func(other):return other.id!=id and other.id.begins_with(short_id)):
				short_id=id.left(short_id.length()+1)
			var index:int=%Guard.item_count
			%Guard.add_item("#%s · %s" % [short_id,robot.name])
			%Guard.set_item_metadata(index,id)
			if id==previous:selected_index=index
		if not guard_recommended and not options.is_empty():
			selected_index=0
			guard_recommended=true
		%Guard.select(selected_index)
		if selected_index<0 and not options.is_empty():
			%Guard.text="原机体不可驻防，请重新选择"
	_update_commit()

func _manual_refresh() -> void:
	if busy or (retry_in>=0.0 and not slow_recheck):
		return
	retry_in=-1.0
	if not slow_recheck:retry_count=0
	_request()

func _request(fields:Dictionary={}) -> void:
	if busy or leaving or not is_inside_tree():
		return
	if fields.is_empty() and (not _page_active() or replay_at>=0):
		refresh_requested=true
		return
	if auth_failed:return
	refresh_requested=false
	busy=true
	sending_guard=not fields.is_empty()
	if sending_guard:
		pending_guard=fields.duplicate()
	_update_commit()
	var http:HTTPRequest=$HTTP
	var url:=endpoint+"/v1/base/raids"+("/guard" if sending_guard else "")
	var err:=http.request(url,Endpoints.headers(token),HTTPClient.METHOD_POST if sending_guard else HTTPClient.METHOD_GET,
		JSON.stringify(fields) if sending_guard else "")
	if err!=OK:
		# A synchronous failure can still deliver a deferred signal on Android.
		http.request_completed.disconnect(_received)
		var next:=http.duplicate(0) as HTTPRequest
		remove_child(http)
		next.name="HTTP"
		add_child(next)
		next.request_completed.connect(_received)
		http.queue_free()
		_failed(-1,0,err,true,"连接未完成")

func _failed(result:int,status:int,error:int,transient:bool,reason:String,uncertain:=false) -> void:
	print("RAID_READ_FAILED op=", "guard" if sending_guard else "status",
		" result=",result," status=",status," err=",error," retries=",retry_count)
	busy=false
	read_blocked=true
	auth_failed=status==401
	if sending_guard:
		sending_guard=false
		if transient or uncertain:
			retry_count=0
			%Status.text="驻防登记结果未确认，正在核实战况…"
			_request()
			return
		pending_guard.clear()
	var subject:="驻防登记结果未确认。" if not pending_guard.is_empty() else ""
	if transient and not slow_recheck and retry_count<READ_DELAYS.size():
		retry_in=READ_DELAYS[retry_count]
		retry_count+=1
		%Status.text=subject+"战况暂未取得，正在重试（%d/2）…" % retry_count
	elif transient and data.get("stage") in ["warning","live"]:
		slow_recheck=true
		retry_in=ACTIVE_RECHECK
		%Status.text=subject+"显示上次确认的战况，正在自动恢复连接。"
	else:
		slow_recheck=false
		retry_in=-1.0
		%Status.text=subject+reason+("。" if status==401 else "。可重新连接核对战况。")
	_update_commit()

func _numeric_fields(value:Variant,keys:Array) -> bool:
	if not value is Dictionary:
		return false
	for key in keys:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT]:
			return false
	return true

func _coordinates(value:Variant,size:int) -> bool:
	if not value is Array or value.size()!=size:
		return false
	for entry in value:
		if typeof(entry) not in [TYPE_FLOAT,TYPE_INT]:
			return false
	return true

func _valid_frame(frame:Variant) -> bool:
	if not _numeric_fields(frame,["tick"]) or not frame.get("foes") is Array or not frame.get("towers") is Dictionary or not frame.get("shots") is Array or not frame.get("repairs",[]) is Array:
		return false
	if not frame.get("marks",[]) is Array:return false
	for mark in frame.get("marks",[]):
		if not _numeric_fields(mark,["due","radius"]) or not _coordinates(mark.get("target"),2):
			return false
	for foe in frame.foes:
		if not _coordinates(foe,3):
			return false
	for shot in frame.shots + frame.get("repairs",[]):
		if not shot is Dictionary or not shot.get("source") is String or not _coordinates(shot.get("origin"),2) or not _coordinates(shot.get("target"),2):
			return false
		if shot.has("at") and (not _numeric_fields(shot,["at"]) or shot.at < frame.tick or shot.at >= frame.tick+1):
			return false
	return true

func _valid_layout(layout:Variant) -> bool:
	if not _numeric_fields(layout,["revision","width","height","used","supply"]) or not layout.get("buildings") is Array or not layout.get("roads") is Array:
		return false
	for road in layout.roads:
		if not _coordinates(road,2):
			return false
	for building in layout.buildings:
		if not _numeric_fields(building,["x","y","w","h"]) or not building.get("id") is String or not building.get("powered") is bool or not BaseBuilding.MODELS.has(building.get("kind")):
			return false
		if building.get("module")!=null and (not building.module is Dictionary or not building.module.get("definition") is String):
			return false
	return true

func _valid_raid(value:Variant) -> bool:
	if not value is Dictionary or value.get("stage") not in ["protected","warning","live","replay"]:
		return false
	if not _numeric_fields(value,["now","due","loot_cap","combined_cap"]) or not _numeric_fields(value.get("insurance"),RESOURCES.keys()) or not value.get("eligible") is Array:
		return false
	for candidate in value.eligible:
		if not candidate is Dictionary or not candidate.get("id") is String or not candidate.get("name") is String:
			return false
	if value.stage!="protected" and (not value.get("id") is String or not _numeric_fields(value,["starts"]) or not value.has("guard")):
		return false
	var guard:Variant=value.get("guard")
	if guard!=null and (not guard is Dictionary or not guard.has_all(["id","name","slots"]) or not guard.slots is Dictionary or not guard.slots.has_all(["head","weapon"])):
		return false
	if guard is Dictionary:
		if not value.has("layout"):
			return false
		for slot in guard.slots:
			if not guard.slots[slot] is Dictionary or not guard.slots[slot].get("definition") is String:
				return false
	if value.has("layout") and (not _valid_layout(value.layout) or not _numeric_fields(value,["wealth","budget"]) or not value.has_all(["id","guard"])):
		return false
	if value.stage!="protected":
		var roster:Variant=value.get("enemy_roster")
		if not roster is Array or roster.is_empty() or roster.size()!=roster.count("patrol")+roster.count("dismantler")+roster.count("swarm"):
			return false
		if not _numeric_fields(value,["budget"]) or value.budget!=roster.size()+roster.count("dismantler"):
			return false
	if value.stage=="warning":
		var pressure:Variant=value.get("pressure")
		if not _numeric_fields(pressure,["base","reduction"]) or not pressure.get("reasons") is Array:
			return false
		if pressure.base-pressure.reduction!=value.budget or pressure.reduction!=pressure.reasons.size():
			return false
		for reason in pressure.reasons:
			if not PRESSURE_REASONS.has(reason):
				return false
	if value.stage=="warning" and value.has("loot_preview"):
		var preview:Variant=value.loot_preview
		if not preview is Dictionary or not _numeric_fields(preview,["max_loot"]) or not _numeric_fields(preview.get("exposed"),RESOURCES.keys()):
			return false
	if value.stage=="warning" and value.has("approach_path"):
		if not value.approach_path is Array or value.approach_path.size()<3:
			return false
		for cell in value.approach_path:
			if not _coordinates(cell,2):
				return false
	if value.stage in ["live","replay"] and not value.get("frames") is Array:
		return false
	if value.has("frames"):
		if not value.frames is Array or not value.frames.all(_valid_frame):
			return false
		for frame:Dictionary in value.frames:
			for foe:Array in frame.foes:
				if value.stage=="protected" or int(foe[0])!=foe[0] or foe[0]<0 or foe[0]>=value.enemy_roster.size():
					return false
	if value.stage=="replay" and (value.frames.is_empty() or not value.get("receipt") is Dictionary or not _numeric_fields(value.receipt,["leaks","repair_cost","recovery_seconds"]) or value.receipt.get("outcome") not in ["win","loss"] or not value.receipt.get("changes") is Dictionary):
		return false
	if value.stage=="replay":
		var facility:Variant=value.receipt.get("facility_damage")
		if facility!=null and (not facility is Dictionary or facility.get("kind") not in FacilityRecovery.NAMES or not _numeric_fields(facility,["x","y","due"]) or not facility.get("cost") is Dictionary or not _numeric_fields(facility.cost,["structure"])):
			return false
		for resource in value.receipt.changes:
			if not RESOURCES.has(resource) or not _numeric_fields(value.receipt.changes,[resource]):
				return false
	return true

func _received(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
	if leaving or not is_inside_tree():return
	if status>=400 and status<500 and status not in [408,429]:
		var reason:String={401:"会话已过期，请返回基地重新登录",404:"未找到本场战况",409:"驻防状态已变化，登记未完成"}.get(status,"服务拒绝请求（HTTP %d）" % status)
		_failed(result,status,OK,false,reason)
		return
	if result!=HTTPRequest.RESULT_SUCCESS or status>=500 or status in [0,408,429]:
		_failed(result,status,OK,true,"未能取得战况")
		return
	var json:=JSON.new()
	if status!=200 or body.is_empty() or json.parse(body.get_string_from_utf8())!=OK or not json.data is Dictionary or not _valid_raid(json.data.get("raid")):
		_failed(result,status,OK,false,"战况响应格式有误",true)
		return
	var checking:=not pending_guard.is_empty()
	var submitted:=pending_guard
	pending_guard={}
	sending_guard=false
	read_blocked=false
	slow_recheck=false
	busy=false
	retry_in=-1
	retry_count=0
	data=json.data.raid
	elapsed=0
	received_ms=Time.get_ticks_msec()
	poll=1.0 if data.stage=="live" else 10.0
	if data.stage=="warning":
		poll=minf(poll,maxf(0.25,float(data.starts-data.now)))
	if data.has("layout") and (data.id!=rendered_id or int(data.layout.revision)!=rendered_revision):
		rendered_id=data.id
		rendered_revision=int(data.layout.revision)
		last_frame=-1
		replay_at=-1.0
		for mark in $Marks.get_children():mark.queue_free()
		for old in $Units.get_children():
			old.queue_free()
		foes.clear()
		guard_view=null
		get_parent()._draw(data.layout)
		towers.clear()
		for i in data.layout.buildings.size():
			var b:Dictionary=data.layout.buildings[i]
			if b.kind=="turret":
				towers[b.id]=get_parent().get_node("Buildings").get_child(i).find_child("PL_PuffSentry",true,false)
	var stage:String=data.stage
	_show_approach(data.get("approach_path",[]) if stage=="warning" else [])
	%Back.text="回基地调整防线" if stage=="warning" else "返回基地"
	var names:Dictionary={"protected":"保护中","warning":"野生机预警","live":"防守进行中 · 服务器战况","replay":"已结算 · 服务器战报"}
	var lines:=PackedStringArray([names[stage]])
	if stage!="protected":
		var roster:Array=data.enemy_roster
		var heavy:int=roster.count("dismantler")
		lines.append("来袭 %d 台 · 威胁预算 %d 点" % [roster.size(),data.budget])
		if stage=="warning" and data.pressure.reduction>0:
			var reasons:=PackedStringArray()
			for reason:String in data.pressure.reasons:
				reasons.append(PRESSURE_REASONS[reason])
			lines.append("%s · 减免 %d 点（基础 %d 点）" % ["、".join(reasons), data.pressure.reduction, data.pressure.base])
		var bees:int=roster.count("swarm")
		if bees>0:
			lines.append("回收蜂机 %d 台 · 同时进路" % bees)
		lines.append("失控巡逻机 %d 台 · 重型拆解机 %d 台" % [roster.count("patrol"),heavy])
		if heavy>0 and stage=="warning":
			lines.append("重机披甲带钻，耐久约为巡逻机两倍，每两秒前进一格。")
	if stage=="warning":
		var preview:Dictionary=data.get("loot_preview",{})
		if preview.is_empty():
			lines.append("当前物资风险暂未取得，正在等待有效情报")
		elif int(preview.max_loot)==0:
			lines.append("按当前库存估算：物资全部受保")
			lines.append("本次失守最多被掠夺 0 份物资")
		else:
			lines.append("按当前库存估算")
			lines.append("超出保险："+_resource_amounts(preview.exposed))
			lines.append("本次失守最多被掠夺 %d 份物资" % int(preview.max_loot))
	if data.has("layout"):
		if stage=="warning":
			lines.append("本场防线 v%d · 开战前保存的调整自动生效" % int(data.layout.revision))
		else:
			lines.append("本场已锁定防线 v%d" % int(data.layout.revision))
		lines.append("预警财富 %d" % data.wealth)
		var platforms:=0
		for building:Dictionary in data.layout.buildings:
			if building.kind!="turret":continue
			platforms+=1
			var module:Variant=building.get("module",{"definition":"legacy"})
			var label:="空底座"
			if module is Dictionary:
				label="原装哨戒炮" if module.definition=="legacy" else str(preload("res://base/platform.gd").NAMES.get(module.definition,module.definition))
			lines.append("(%d,%d) %s · %s" % [building.x,building.y,label,"供电" if building.powered else "停电"])
		if platforms==0:lines.append("本场没有防御平台")
		var guard_text := "无驻防机" if stage=="replay" else "尚无机体"
		if data.guard is Dictionary:
			guard_text="%s · %s" % [data.guard.name, "已结束驻防" if stage=="replay" else "战后解锁"]
		lines.append("驻防："+guard_text)
		if data.guard is Dictionary and data.guard.slots.get("utility",{}).get("definition")=="jammer" or data.layout.buildings.any(func(b):return b.get("module") is Dictionary and b.module.definition=="jammer"):
			lines.append("本次野生机只会突入核心，没有可干扰的武器或维修动作。")
	%DetailsToggle.visible=stage=="replay"
	if stage=="replay":
		var receipt:Dictionary=data.receipt
		if report_id!=data.id:
			report_id=data.id
			%DetailsToggle.set_pressed_no_signal(false)
			$HUD/Panel/Pad/Scroll.scroll_vertical=0
		var damage:Variant=receipt.get("facility_damage")
		if damage is Dictionary:
			lines.append("%s · 原定 %s 免费修复。提前抢修需 %d 结构，确认时扣除。" % [FacilityRecovery.site(damage),FacilityRecovery.deadline(damage),int(damage.cost.structure)])
		if _has_guard_damage():
			lines.append("受损守军：%s #%s" % [data.guard.name,str(data.guard.id).left(8)])
			lines.append("本场维修估价 %d 份材料。确认送修时按当前报价扣除。" % int(receipt.repair_cost))
		if receipt.get("platform_repair",0)>0:
			lines.append("平台战地修复　%d 点" % int(receipt.platform_repair))
		lines.append("若整段恢复期均未上线，回归后另有 24 小时整备。")
		%Details.text="\n".join(lines)
		_toggle_details(%DetailsToggle.button_pressed)
		%Status.text=_report_summary(receipt)
	else:
		report_id=""
		%Details.hide()
		lines.append("保险储量："+_resource_amounts(data.insurance))
		lines.append("单次掠夺上限 %d 份，含维修总损失上限 %d 份。" % [int(data.loot_cap),int(data.combined_cap)])
		%Status.text="\n".join(lines)
	if stage=="warning" and data.guard==null and data.eligible.is_empty():
		%Status.text+="\n当前没有可驻防的待命机体。"
	if checking:
		if data.get("id")==submitted.raid and data.get("guard") is Dictionary and data.guard.id==submitted.robot:
			%Status.text+="\n本场已登记所选驻防机。"
		elif data.get("id")==submitted.raid and stage=="warning" and data.get("guard")==null:
			%Status.text+="\n当前未登记驻防机，可重新选择并确认。"
		else:
			%Status.text+="\n已核实当前战况，请查看本场驻防状态。"
	_refresh_guards()
	%Replay.visible=stage=="replay"
	%GuardCondition.visible=_has_guard_damage()
	if data.get("guard") is Dictionary and not guard_view:
		guard_view=Robot.instantiate()
		$Units.add_child(guard_view)
		guard_view.set_chassis(data.guard.get("chassis","crawler"))
		guard_view.set_repair_arm(data.guard.slots.get("utility",{}).get("definition")=="repair_arm")
		guard_view.set_shield(data.guard.slots.get("armor",{}).get("definition")=="rivet_shield")
		guard_view.set_survey_radar(data.guard.slots.get("survey",{}).get("definition")=="survey_radar")
		guard_view.set_paint(data.guard.get("paint","base"))
		guard_view.set_hull_number(str(data.guard.get("hull_number","")))
		guard_view.scale=Vector3.ONE*0.36
		guard_view.head=int(data.guard.slots.head.definition=="visor")
		guard_view.set_weapon_definition(data.guard.slots.weapon.definition)
		for b in data.layout.buildings:
			if b.kind=="core":
				guard_view.position=_cell(b.x,b.y)+Vector3.UP*0.4
	if stage=="live" and not data.frames.is_empty():
		_frame(data.frames.back())

func _toggle_details(expanded:bool) -> void:
	%Details.visible=expanded
	%DetailsToggle.text="收起战报详情" if expanded else "展开战报详情"

func _report_summary(receipt:Dictionary) -> String:
	var lines:=PackedStringArray()
	lines.append(("守住核心" if receipt.outcome=="win" else "核心失守")+" · 突入 %d 台" % receipt.leaks)
	var debits:=PackedStringArray()
	for key:String in RESOURCES:
		var amount:=-int(receipt.changes.get(key,0))
		if amount>0:debits.append("%s %d" % [RESOURCES[key],amount])
	lines.append("实际掠夺："+("无（0 份）" if debits.is_empty() else "、".join(debits)))
	var guard:="未派驻" if data.guard==null else ("受损" if _has_guard_damage() else "完好")
	var facility:Variant=receipt.get("facility_damage")
	lines.append("守军："+guard)
	lines.append("设施："+(FacilityRecovery.site(facility)+" 受损" if facility is Dictionary else "完好"))
	lines.append("整备 %d 小时 · 从本场结算起" % roundi(float(receipt.recovery_seconds)/3600.0))
	return "\n".join(lines)

func _resource_amounts(amounts:Dictionary) -> String:
	var values:=PackedStringArray()
	for key:String in RESOURCES:
		values.append("%s %d" % [RESOURCES[key],int(amounts[key])])
	return "、".join(values)

func _cell(x:float,y:float) -> Vector3:
	return Vector3(x-5.5,0,y-4.0)

func _show_approach(cells:Array) -> void:
	if cells==approach_cells:
		return
	approach_cells=cells
	var route:MeshInstance3D=$ApproachRoute
	route.visible=not cells.is_empty()
	if cells.is_empty():
		route.mesh=null
		return
	var marks:=ImmediateMesh.new()
	marks.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in cells.size()-1:
		var start:=_cell(cells[i][0],cells[i][1])
		var end:=_cell(cells[i+1][0],cells[i+1][1])
		var forward:=end-start
		var side:=Vector3(-forward.z,0,forward.x)
		var middle:=start.lerp(end,0.5)+Vector3.UP*0.045
		# Dark rim keeps the light arrow visible on both brass road and bare ground.
		for inset in [false,true]:
			var tip:=0.38 if not inset else 0.27
			var wing:=0.27 if not inset else 0.17
			var tail:=-0.30 if not inset else -0.19
			marks.surface_set_color(Color("#ffdd7d") if inset else Color("#7a2617"))
			var center:=middle+Vector3.UP*0.007 if inset else middle
			marks.surface_add_vertex(center+forward*tip)
			marks.surface_add_vertex(center+forward*tail+side*wing)
			marks.surface_add_vertex(center+forward*tail-side*wing)
	marks.surface_end()
	route.mesh=marks
	var entry:Array=cells[2]
	$ApproachRoute/Entry.position=_cell(entry[0],entry[1])+Vector3.UP*0.8

func _foe_offset(id:int) -> Vector3:
	if data.enemy_roster[id]=="swarm":
		return BEE_OFFSETS[id % 3]
	return Vector3(0,0.04,0.18 if id%2 else -0.18)

func _frame(frame:Dictionary) -> void:
	if last_frame==int(frame.tick):
		return
	last_frame=int(frame.tick)
	var present:={}
	for arr in frame.foes:
		var id:=int(arr[0])
		if not foes.has(id):
			var bee:bool=data.enemy_roster[id]=="swarm"
			var view:Node3D=(Bee if bee else Robot).instantiate()
			$Units.add_child(view)
			if not bee:
				view.scale=Vector3.ONE*0.34
				view.set_motion(true)
			if data.enemy_roster[id]=="dismantler":
				view.weapon=1
				view.scale=Vector3(0.50,0.46,0.47)
				var armor:=SalvageArt.part("ChiefPlate")
				armor.name="DismantlerArmor"
				armor.rotation.y=PI
				armor.scale=Vector3.ONE*1.55
				armor.position=Vector3(0,0.88,0.06)
				view.add_child(armor)
			foes[id]=view
		foes[id].show()
		foes[id].position=_cell(arr[1],arr[2])+_foe_offset(id)
		present[id]=true
	for id in foes:
		if not present.has(id):
			foes[id].hide()
	for id:String in frame.towers:
		var tower:Node3D=towers.get(id)
		if tower:
			var forward:Vector3=-tower.muzzle_transform().basis.z
			var angle:=float(frame.towers[id])
			tower.yaw_pivot.rotate_y(wrapf(angle-atan2(forward.x,forward.z),-PI,PI))
	for previous in $Marks.get_children():previous.queue_free()
	for mark:Dictionary in frame.get("marks",[]):
		var warning:=preload("res://battle/blast_warning.tscn").instantiate()
		$Marks.add_child(warning)
		warning.position=_cell(mark.target[0],mark.target[1])+Vector3.UP*0.16
		warning.scale=Vector3(mark.radius,1,mark.radius)
	_clear_shots()
	var beams:Array=frame.shots.duplicate()
	beams.append_array(frame.get("repairs",[]))
	for shot in beams:
		var origin:=_cell(shot.origin[0],shot.origin[1])+Vector3.UP*0.7
		var tower:Node3D=towers.get(shot.source)
		if tower and not shot.has("amount"):
			origin=tower.muzzle_transform().origin
		var end:=_cell(shot.target[0],shot.target[1])+Vector3.UP*0.42
		var target_id:=int(shot.get("enemy",-1))
		if target_id>=0 and target_id<data.enemy_roster.size() and data.enemy_roster[target_id]=="swarm":
			end=_cell(shot.target[0],shot.target[1])+_foe_offset(target_id)+Vector3.UP*0.12
		if origin.distance_squared_to(end)<0.0001:
			continue
		var beam:=MeshInstance3D.new()
		beam.mesh=$Beam.mesh
		if shot.has("amount"):
			var service:=StandardMaterial3D.new()
			service.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			service.albedo_color=Color("#55ffe1")
			beam.material_override=service
		$Shots.add_child(beam)
		beam.position=origin.lerp(end,0.5)
		beam.look_at(end,Vector3.RIGHT if absf((end-origin).normalized().y)>0.99 else Vector3.UP)
		beam.scale=Vector3(0.045,0.045,origin.distance_to(end))
		var pulse := beam.create_tween()
		if shot.has("at"):
			var delay := clampf(float(shot.at) - float(frame.tick), 0, 1)
			if delay > 0:
				beam.hide()
				pulse.tween_interval(delay)
				pulse.tween_callback(beam.show)
		pulse.tween_interval(0.12 if shot.has("at") else 0.3)
		pulse.tween_callback(beam.queue_free)

func _clear_shots() -> void:
	for shot in $Shots.get_children():
		shot.queue_free()

func _process(delta:float) -> void:
	if not _page_active() or auth_failed:return
	if refresh_requested and not busy and replay_at<0:
		_request()
	if retry_in>=0.0 and not busy:
		retry_in-=delta
		if retry_in<=0.0:
			retry_in=-1.0
			_request()
	if data.is_empty():
		return
	elapsed=float(Time.get_ticks_msec()-received_ms)/1000.0
	poll-=delta
	var due:float=data.get("starts",data.due) if data.stage=="warning" else data.due
	var left:=maxi(0,int(due-float(data.now)-elapsed))
	%Time.text=("距开战锁定" if data.stage=="warning" else "保护剩余")+" %02d:%02d:%02d" % [left/3600,left/60%60,left%60]
	%Time.visible=data.stage!="replay" or replay_at>=0 or slow_recheck
	if data.stage=="live":
		%Time.text="实时防守 · 第 %d 秒" % last_frame
	elif data.stage=="replay":
		%Time.text="本场防守已结束"
	if slow_recheck:
		%Time.text="上次确认 · 开战前预警" if data.stage=="warning" else "上次确认 · 第 %d 秒" % last_frame
	if replay_at>=0 and data.stage=="replay":
		var i:=mini(floori(replay_at),data.frames.size()-1)
		_frame(data.frames[i])
		%Time.text="战报回放 · 第 %d 秒" % i
		for event in data.frames[i].get("repairs",[]):
			%Time.text+="\n维修平台 → 驻防机 +%d" % int(event.amount)
		replay_at+=delta
		if replay_at>=data.frames.size():
			replay_at=-1
	if poll<=0 and not busy and not read_blocked and replay_at<0:
		poll=5
		_request()
