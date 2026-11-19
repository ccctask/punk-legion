extends SceneTree
## One GUI-subtree mechanism probe. No business Root enters the tree, HTTP,
## direct handler/signal calls, wheel input, scroll-value writes or source edits.
## Entry: --script <this file> -- --fixture <new absolute JSON> --out <new dir>
## Optional exact suffix: --mode mechanism|production|workshop-diagnostic|workshop-production.
## Workshop diagnostic: three fixed native starts, all observations retained;
## completion is evidence qualification, never a product-scroll pass.
## Production: native PASS/RELEASE only; no test-side filter override. Three
## drag/click cases plus two disabled GUI gates; no business Root/HTTP success.
## Production receipt/stage must bind baseline SOURCE + four approved deltas
## + this probe SHA, not claim the complete stage still equals baseline SOURCE.
## Fixture exact top: schema, fixture_id, provenance, base_snapshot, base_guide, party.
## provenance exact: origin="new-ui-fixture", account_id(32hex), source_manifest_sha256,
## generated_utc, receipt:{path,sha256}; receipt is a new generator's evidence.
## base_snapshot exact: {base:{revision,used,supply}} (Stats-only API projection).
## base_guide exact: facts:{name,reward,fit,build}, active_mode, damaged, ready_count,
## entry_source, fit_route, daily:{complete:false}, summary:{}; a fresh no-reward guide.
## party exact: self,roomscope,robots,departure_quote. roomscope exact:
## id,code,leader,mode="coop",members; member exact: owner,name,robots,ready,points.
## robots: six exact {id,name,ready:true,points:2}; member robot ids must refer to
## this bounded roster; all members unready/empty selections for this GUI fixture.
## departure_quote exact: source="energy",energy. No credentials or old save data.

const SOURCE := "34c4757a09a19cd3dd5db4336365b4d076a6790de548c5bdf27941bee54d5ee1"
const BASE_STABILITY_SOURCE := "29a4bb888ae35bc080934d15f79320ec99e5771986ef42b49c956fd75351ae96"
const BASE := "res://base/base.tscn"
const PUMP := "res://pump/outing.tscn"
const WORKSHOP := "res://owned/workshop.tscn"
const WORKSHOP_STARTS := ["Scroll/Body/Shop","Scroll/Body/Mode","Scroll/Body/Stock"]
var fixture: Dictionary
var output := ""
var first_error := ""
var records: Array = []
var gate_records: Array = []
var mode := "mechanism"
var active: Dictionary = {}
var business_roots: Array[Node] = []
var canvas: CanvasLayer
var stability_sampler := Callable()
var held := false
var held_key: Key=KEY_NONE
var held_key_window_id: int=-1
var last_at := Vector2.ZERO
var deadline := 0
var recording := false
var party_target := ""

func _initialize() -> void:
	call_deferred("_run")

func _ok(value: bool, message: String) -> bool:
	if not value and first_error.is_empty(): first_error=message
	return value

func _shape(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size()!=keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true

func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length()!=length: return false
	for index: int in range(value.length()):
		if not value.substr(index,1) in "0123456789abcdef": return false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and floorf(float(value))==float(value)

func _fixture_valid() -> bool:
	if not _ok(_shape(fixture,["schema","fixture_id","provenance","base_snapshot","base_guide","party"]),"Fixture exact top fields"):return false
	if not _ok(fixture.schema=="pl-scroll-ui-fixture-v1" and _hex(fixture.fixture_id,32),"New bounded fixture identity"):return false
	var p: Variant=fixture.provenance
	if not _ok(_shape(p,["origin","account_id","source_manifest_sha256","generated_utc","receipt"]),"Provenance fields"):return false
	if not _ok(p.origin=="new-ui-fixture" and p.source_manifest_sha256==SOURCE and _hex(p.account_id,32) and _number(p.generated_utc),"Fresh current-source provenance"):return false
	if not _ok(_shape(p.receipt,["path","sha256"]) and p.receipt.path is String and p.receipt.path.is_absolute_path() and _hex(p.receipt.sha256,64),"Generator receipt reference"):return false
	if not _ok(FileAccess.file_exists(p.receipt.path) and FileAccess.get_sha256(p.receipt.path)==p.receipt.sha256,"Generator receipt missing/drifted"):return false
	if not _ok(_shape(fixture.base_snapshot,["base"]) and _shape(fixture.base_snapshot.base,["revision","used","supply"]),"Stats-only snapshot projection"):return false
	for value: Variant in fixture.base_snapshot.base.values():
		if not _ok(_number(value),"Integer Stats field"):return false
	var g: Variant=fixture.base_guide
	if not _ok(_shape(g,["facts","active_mode","damaged","ready_count","entry_source","fit_route","daily","summary"]),"Guide fields"):return false
	if not _ok(_shape(g.facts,["name","reward","fit","build"]),"Guide fact fields"):return false
	for value: Variant in g.facts.values():
		if not _ok(value is bool,"Guide Boolean facts"):return false
	if not _ok(g.facts.name and not g.facts.reward and g.active_mode=="" and g.damaged=="" and _number(g.ready_count) and g.ready_count>=1 and g.entry_source=="energy" and g.fit_route is String and _shape(g.daily,["complete"]) and g.daily.complete is bool and not g.daily.complete and g.summary is Dictionary and g.summary.is_empty(),"Fresh guide, no summary/history/active mission"):return false
	var data: Variant=fixture.party
	if not _ok(_shape(data,["self","roomscope","robots","departure_quote"]) and data.self==p.account_id and data.robots is Array and data.robots.size()==6,"Own six-row Party fixture"):return false
	var ids := {}
	for robot: Variant in data.robots:
		if not _ok(_shape(robot,["id","name","ready","points"]) and _hex(robot.id,32) and not ids.has(robot.id) and robot.name is String and robot.name.length()>=1 and robot.name.length()<=24 and robot.ready is bool and robot.ready and _number(robot.points) and robot.points==2,"Six distinct ready real-shape rows"):return false
		ids[robot.id]=true
	var room: Variant=data.roomscope
	if not _ok(_shape(room,["id","code","leader","mode","members"]) and _hex(room.id,32) and room.code is String and room.code.length()==8 and room.mode=="coop" and room.members is Array and room.members.size()>=2 and room.members.size()<=3,"Fresh coop room render shape"):return false
	var owners := {}
	for member: Variant in room.members:
		if not _ok(_shape(member,["owner","name","robots","ready","points"]) and _hex(member.owner,32) and not owners.has(member.owner) and member.name is String and member.name.length()>=3 and member.name.length()<=32 and member.robots is Array and member.robots.is_empty() and member.ready is bool and not member.ready and member.points==0,"Fresh unready member rows"):return false
		owners[member.owner]=true
	if not _ok(owners.has(data.self) and owners.has(room.leader) and _shape(data.departure_quote,["source","energy"]) and data.departure_quote.source=="energy" and _number(data.departure_quote.energy) and data.departure_quote.energy>=1,"Own room member/payment display"):return false
	return true

func _base_fixture_valid() -> bool:
	if not _ok(_shape(fixture,["schema","fixture_id","provenance","base_snapshot","base_guide"]) and fixture.schema=="pl-base-stability-fixture-v1" and _hex(fixture.fixture_id,32),"Current Base-only fixture shape"):return false
	var p: Variant=fixture.provenance
	if not _ok(_shape(p,["origin","source_manifest_sha256","generated_utc","receipt"]) and p.origin=="new-display-only-projection" and p.source_manifest_sha256==BASE_STABILITY_SOURCE and _number(p.generated_utc),"Current display-only Base provenance"):return false
	if not _ok(_shape(p.receipt,["path","sha256"]) and p.receipt.path is String and p.receipt.path.is_absolute_path() and _hex(p.receipt.sha256,64),"Base receipt identity"):return false
	if not _ok(FileAccess.file_exists(p.receipt.path) and FileAccess.get_sha256(p.receipt.path)==p.receipt.sha256,"Base receipt absent/drifted"):return false
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(p.receipt.path))
	if not _ok(receipt is Dictionary and receipt.get("schema","")=="pl-base-stability-projection-receipt-v1" and receipt.get("fixture_id","")==fixture.fixture_id and receipt.get("source_manifest_sha256","")==BASE_STABILITY_SOURCE and receipt.get("source_count",0)==545 and receipt.get("generated_utc",-1)==p.generated_utc and receipt.get("projection",{})=={"base_snapshot":fixture.base_snapshot,"base_guide":fixture.base_guide},"Base projection differs from new generator receipt"):return false
	if not _ok(_shape(fixture.base_snapshot,["base"]) and _shape(fixture.base_snapshot.base,["revision","used","supply"]),"Explicit Base Stats display projection"):return false
	for key: String in ["revision","used","supply"]:
		var value: Variant=fixture.base_snapshot.base[key]
		if not _ok(_number(value) and value=={"revision":1,"used":0,"supply":6}[key],"Explicit Base Stats display projection"):return false
	var g: Variant=fixture.base_guide
	if not _ok(_shape(g,["facts","active_mode","damaged","ready_count","entry_source","fit_route","daily","summary"]) and g.facts=={"name":true,"reward":false,"fit":false,"build":true} and g.active_mode=="" and g.damaged=="" and g.ready_count==2 and g.entry_source=="energy" and g.fit_route is String and g.daily=={"complete":false} and g.summary is Dictionary and g.summary.is_empty(),"Explicit new two-ready no-reward Guide projection"):return false
	return true

func _v(value: Vector2) -> Array:
	return [value.x,value.y]

func _rect(value: Rect2) -> Dictionary:
	return {"position":_v(value.position),"size":_v(value.size)}

func _controls(node: Node) -> Array[Control]:
	var result: Array[Control]=[]
	if node is Control:result.append(node)
	for child: Node in node.get_children():result.append_array(_controls(child))
	return result

func _owners(gui: Node) -> Array:
	var result: Array=[]
	var pending: Array[Node]=[gui]
	active.detached_owners=[]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		pending.append_array(node.get_children())
		var owner := node.owner
		if owner==null:continue
		if owner==gui or gui.is_ancestor_of(owner):result.append([node,owner])
		else:
			active.detached_owners.append({"node":str(gui.get_path_to(node)),"external_owner":str(owner.name)})
			node.owner=null
	return result

func _gui(event: InputEvent, path: String, is_scroll: bool) -> void:
	if not recording:return
	if not _ok(active.events.size()<(8192 if mode in ["base-stability","base-refresh"] else 512),"Finite input observer overflow"):return
	var row: Dictionary={"node":path,"type":event.get_class()}
	if mode in ["base-stability","base-refresh"]:
		row.usec=Time.get_ticks_usec()
		row.viewport_mouse=_v(root.get_mouse_position())
		if event is InputEventMouse:row.position=_v(event.position);row.global_position=_v(event.global_position)
		if event is InputEventMouseButton:row.pressed=event.pressed;row.button_index=event.button_index;row.button_mask=event.button_mask
		if event is InputEventScreenTouch or event is InputEventScreenDrag:row.position=_v(event.position)
		if event is InputEventScreenTouch:row.pressed=event.pressed
	active.events.append(row)
	if event is InputEventMouse:
		active.mouse_events+=1
		if is_scroll:active.scroll_mouse_events+=1
		if event is InputEventMouseButton and event.pressed and path==active.button.node:active.button_mouse_press+=1

func _pressed(path: String) -> void:
	if recording:
		active.pressed.append(path)
		if mode in ["base-stability","base-refresh"]:active.pressed_events.append({"node":path,"usec":Time.get_ticks_usec()})

func _toggled(value: bool, path: String) -> void:
	if recording:
		var row: Dictionary={"node":path,"value":value}
		if mode in ["base-stability","base-refresh"]:row.usec=Time.get_ticks_usec()
		active.toggled.append(row)

func _request(path: String, _fields: Dictionary) -> void:
	if recording:active.requests.append(path)

func _chosen(action: String, _robot: String) -> void:
	if recording:
		active.requests.append("guide:"+action)
		if mode in ["base-stability","base-refresh"]:active.chosen_events.append({"action":action,"usec":Time.get_ticks_usec()})

func _scroll_started() -> void:
	if recording:
		active.scroll_started+=1
		if mode in ["base-stability","base-refresh"]:active.scroll_events.append({"signal":"started","usec":Time.get_ticks_usec()})

func _watch(gui: Control, scroll: ScrollContainer) -> void:
	for control: Control in _controls(gui):
		var path := str(gui.get_path_to(control))
		control.gui_input.connect(_gui.bind(path,control==scroll))
		if control is BaseButton:
			control.pressed.connect(_pressed.bind(path))
			control.toggled.connect(_toggled.bind(path))
	scroll.scroll_started.connect(_scroll_started)

func _chain(target: Control, scroll: ScrollContainer) -> Array:
	var result: Array=[]
	var node: Node=target
	while node!=null:
		if node is Control:result.append({"node":str(scroll.get_path_to(node)),"rect":_rect(node.get_global_rect()),"filter":node.mouse_filter,"effective_filter":node.get_mouse_filter_with_override(),"recursive":node.mouse_behavior_recursive})
		if node==scroll:break
		node=node.get_parent()
	return result

func _clip(scroll: ScrollContainer) -> Rect2:
	var rect := scroll.get_global_rect().intersection(root.get_visible_rect())
	var node: Node=scroll.get_parent()
	while node!=null:
		if node is Control and node.clip_contents:rect=rect.intersection(node.get_global_rect())
		node=node.get_parent()
	return rect

func _load_gui(kind: String) -> Dictionary:
	var scene: PackedScene=load(WORKSHOP if kind=="workshop" else BASE if kind=="base" else PUMP)
	var business := scene.instantiate()
	business_roots.append(business)
	var gui: Control=business.get_node("HUD/Panel" if kind in ["base","workshop"] else "HUD/Lobby")
	var owners := _owners(gui)
	gui.get_parent().remove_child(gui)
	canvas=CanvasLayer.new();root.add_child(canvas);canvas.add_child(gui)
	await process_frame
	for pair: Array in owners:
		if not _ok(is_instance_valid(pair[0]) and pair[0].owner==pair[1],"Embedded scene owner changed"):return {}
	if not _ok(not business.is_inside_tree() and not business.is_node_ready(),"Business Root must never enter/ready"):return {}
	var scroll: ScrollContainer=gui.get_node("Pad/Scroll" if kind=="base" else "Scroll")
	var panel: Node
	if kind=="base":
		panel=gui.get_node("Pad/Scroll/Body/Guide")
		var stats: Label=gui.get_node("Pad/Scroll/Body/Stats")
		var data: Dictionary=fixture.base_snapshot.base
		stats.text="布局 v%d　供电 %d / %d" % [int(data.revision),int(data.used),int(data.supply)]
		if mode!="base-refresh":panel.apply_guide(fixture.base_guide)
		panel.chosen.connect(_chosen)
	elif kind=="party":
		panel=gui.get_node("Scroll/Body/PartyPanel")
		panel.pump_mode="coop";panel.show()
		# Presentation of the normal cooperative ready lobby, using its actual nodes.
		gui.get_node("Scroll/Body/Title").text="泵站遗迹 · 好友合作"
		gui.get_node("Scroll/Body/Rules").text="清除守卫，到达并校准西阀和东阀。共用物资箱开启后，每人带自己的机体在出口确认撤离。战斗限时 5 分钟。"
		for name: String in ["PartyMode","QuickSalvage","Squad","SoloQuote","Start","Claim","PreviousReport"]:
			var item := gui.find_child(name,true,false)
			if item is Control:item.hide()
		panel.set_read_available(true);panel.refresh(fixture.party)
		panel.request.connect(_request)
	else:
		# One fresh display-only Catalog projection, never an account/stock fixture.
		panel=gui.get_node("Scroll/Body")
		var catalog = load("res://loadout/catalog.gd")
		var stock: Label=panel.get_node("Stock")
		stock.text="目录版本 %d · 全新GUI诊断，无账号数据" % int(catalog.VERSION)
		var picker: OptionButton=panel.get_node("Mode")
		picker.add_item("设计与制造")
		picker.add_item("机库与实装")
		active.presentation={"stock":{"property":"Scroll/Body/Stock.text","value":stock.text,"source":"res://loadout/catalog.gd::VERSION","catalog_version":int(catalog.VERSION),"not_business_stock":true},"mode_items":{"property":"Scroll/Body/Mode.items","source":"res://owned/workshop.gd::_ready two add_item statements","item_count":picker.item_count,"texts":[picker.get_item_text(0),picker.get_item_text(1)],"selected_initial":picker.selected,"no_explicit_select":true},"fixture_id":fixture.fixture_id}
	await process_frame
	await process_frame
	return {"gui":gui,"scroll":scroll,"panel":panel,"business":business}

func _send_touch(pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index=0;event.position=at;event.pressed=pressed
	Input.parse_input_event(event)
	held=pressed;last_at=at

func _drag(start_at: Vector2, end_at: Vector2) -> void:
	var began := Time.get_ticks_usec()
	_send_touch(true,start_at)
	await process_frame
	var hover := root.gui_get_hovered_control()
	active.hover_after_press=str(hover.get_path()) if is_instance_valid(hover) else ""
	for index: int in range(1,13):
		while Time.get_ticks_usec()<began+index*25000:
			if Time.get_ticks_msec()>=deadline:return
			await process_frame
		var at := start_at.lerp(end_at,float(index)/12.0)
		var event := InputEventScreenDrag.new()
		event.index=0;event.position=at;event.relative=at-last_at
		Input.parse_input_event(event);last_at=at
		await process_frame
	_send_touch(false,end_at)
	active.drag_actual_usec=Time.get_ticks_usec()-began
	await process_frame
	await process_frame

func _png(name: String) -> bool:
	var image := root.get_texture().get_image()
	return _ok(image!=null and not image.is_empty() and image.save_png(output.path_join(name))==OK,"Real viewport image unavailable")

func _target(bundle: Dictionary, kind: String, semantic: String) -> BaseButton:
	var gui: Control=bundle.gui
	var panel: Node=bundle.panel
	if kind=="base":
		if semantic in ["","BaseGuideParty"]:return panel.get_node("Content/Party")
		if semantic=="BaseEconomyToggle":return gui.get_node("Pad/Scroll/Body/EconomyToggle")
	elif kind=="party" and (semantic in ["","PartyOwnedRobot"] or semantic=="PartyOwnedRobot:"+party_target):
		var clip := _clip(bundle.scroll)
		for robot: Dictionary in fixture.party.robots:
			var candidate: BaseButton=panel.robot_buttons[robot.id]
			var center := candidate.get_global_rect().get_center()
			if (party_target.is_empty() or party_target==robot.id) and clip.has_point(center) and clip.has_point(center-Vector2(0,262)):
				party_target=robot.id
				return candidate
	_ok(false,"No eligible fixed target; do not choose another semantic")
	return null

func _arm(kind: String, arm: String, semantic := "") -> bool:
	active={"kind":kind,"arm":arm,"mode":mode,"events":[],"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,"pressed":[],"toggled":[],"requests":[],"scroll_started":0}
	records.append(active)
	var bundle := await _load_gui(kind)
	if bundle.is_empty():return false
	var gui: Control=bundle.gui
	var scroll: ScrollContainer=bundle.scroll
	var panel: Node=bundle.panel
	var clip := _clip(scroll)
	var bar := scroll.get_v_scroll_bar()
	active.scroll={"rect":_rect(scroll.get_global_rect()),"clip":_rect(clip),"value":bar.value,"max":bar.max_value,"page":bar.page}
	if not _ok(scroll.scroll_vertical==0 and bar.max_value-bar.page>10,"Original top/positive scroll room required"):return false
	var button: BaseButton=_target(bundle,kind,semantic)
	var start_at := Vector2(825,400)
	var end_at := Vector2(825,138)
	if not _ok(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,"Eligible original visible button required"):return false
	if kind=="party" or semantic=="BaseEconomyToggle":
		start_at=button.get_global_rect().get_center();end_at=start_at-Vector2(0,262)
	var native_product := mode=="production"
	if not _ok(button.get_mouse_filter_with_override()==(Control.MOUSE_FILTER_PASS if native_product else Control.MOUSE_FILTER_STOP),"Fixed target source filter differs from selected mode"):return false
	if native_product and not _ok(arm=="P" and button.action_mode==BaseButton.ACTION_MODE_BUTTON_RELEASE,"Product target must be native PASS/RELEASE"):return false
	active.semantic=(semantic if not semantic.is_empty() else "BaseGuideParty") if kind=="base" else "PartyOwnedRobot:"+party_target
	active.image_prefix=({"BaseGuideParty":"guide-party","BaseEconomyToggle":"base-economy"}.get(active.semantic,"party-owned") if native_product else kind+arm)
	active.button={"node":str(gui.get_path_to(button)),"rect":_rect(button.get_global_rect()),"chain":_chain(button,scroll),"filter":button.mouse_filter,"effective_filter":button.get_mouse_filter_with_override(),"action_mode":button.action_mode}
	if arm=="B":
		var label: Control=panel.get_node("Content/Daily")
		start_at=label.get_global_rect().intersection(clip).get_center();end_at=start_at-Vector2(0,262)
		for control: Control in _controls(scroll):
			if control!=scroll and control.is_visible_in_tree() and control.get_global_rect().has_point(start_at) and control.get_mouse_filter_with_override()==Control.MOUSE_FILTER_STOP:
				return _ok(false,"Non-button start path is blocked; do not search another point")
	else:
		if not _ok(button.get_global_rect().has_point(start_at),"Original coordinate did not hit intended button geometry"):return false
	if not _ok(clip.has_point(start_at) and clip.has_point(end_at),"Gesture must stay inside actual Scroll clip"):return false
	if mode=="mechanism" and arm=="C":button.mouse_filter=Control.MOUSE_FILTER_PASS
	active.only_pass_override=mode=="mechanism" and arm=="C"
	active.start_at=_v(start_at);active.end_at=_v(end_at);active.nominal_msec=300
	active.selected_before=panel.selected.duplicate() if kind=="party" else []
	_watch(gui,scroll)
	if not _png(active.image_prefix+"-before.png"):return false
	recording=true
	await _drag(start_at,end_at)
	recording=false
	if not _ok(not held and active.mouse_events>0,"Touch-to-mouse input qualification failed"):return false
	active.scroll_after_drag=scroll.scroll_vertical
	active.selected_after=panel.selected.duplicate() if kind=="party" else []
	if not _ok(active.pressed.is_empty() and active.toggled.is_empty() and active.requests.is_empty() and active.selected_before==active.selected_after,"Drag clicked/toggled/navigated unexpectedly"):return false
	if arm=="A":
		if not _ok(active.button_mouse_press>0 and scroll.scroll_vertical==0 and active.scroll_started==0,"Original negative arm did not reproduce; stop"):return false
	else:
		if not _ok(scroll.scroll_vertical>0 and active.scroll_started>0 and active.scroll_mouse_events>0,"Positive scroll arm failed; stop"):return false
	if not _png(active.image_prefix+"-after.png"):return false
	if arm=="C" or native_product:
		if not (await _ordinary_click(kind)):return false
	active.passed=true
	return first_error.is_empty()

func _base_control(control: Control) -> Dictionary:
	return {"rect":_rect(control.get_global_rect()),"minimum":_v(control.get_combined_minimum_size()),"visible":control.visible,"visible_in_tree":control.is_visible_in_tree(),"disabled":(control as BaseButton).disabled if control is BaseButton else null}

func _base_sample(bundle: Dictionary) -> void:
	if not recording:return
	if not _ok(active.trajectory.size()<8192,"Finite Base trajectory overflow"):return
	var scroll: ScrollContainer=bundle.scroll
	var gui: Control=bundle.gui
	var panel: Node=bundle.panel
	var hover: Control=root.gui_get_hovered_control()
	var sample: Dictionary={"usec":Time.get_ticks_usec(),"scroll":scroll.scroll_vertical,"bar_value":scroll.get_v_scroll_bar().value,
		"body_minimum":_v(gui.get_node("Pad/Scroll/Body").get_combined_minimum_size()),"hover":str(hover.get_path()) if is_instance_valid(hover) else "",
		"viewport_mouse":_v(root.get_mouse_position()),"explore":_base_control(gui.get_node("Pad/Scroll/Body/Explore")),
		"return":_base_control(panel.get_node("Content/Return")),"statement":_base_control(panel.get_node("Content/Statement"))}
	if mode=="base-refresh":
		sample.guide={"loaded":panel.loaded,"reading":panel.reading,"queued":panel.refresh_after_read,"go_disabled":panel.get_node("Content/Go").disabled,
			"next":panel.get_node("Content/Next").text,"daily":panel.get_node("Content/Daily").text}
		if active.layout_required:
			_ok(_base_refresh_layout(bundle)==active.stable_layout,"Loaded Guide read changed text/geometry/scroll")
			if panel.reading:_ok(panel.get_node("Content/Go").disabled,"Guide read enabled action before response")
	active.trajectory.append(sample)

func _base_wait(seconds: float) -> bool:
	var until := Time.get_ticks_usec()+int(seconds*1000000.0)
	while Time.get_ticks_usec()<until:
		if not _ok(Time.get_ticks_msec()<deadline and first_error.is_empty(),"Original Base diagnostic deadline/error"):return false
		await process_frame
	return first_error.is_empty()

func _base_refresh_layout(bundle: Dictionary) -> Dictionary:
	var panel: Node=bundle.panel
	return {"next":panel.get_node("Content/Next").text,"daily":panel.get_node("Content/Daily").text,
		"explore":_base_control(bundle.gui.get_node("Pad/Scroll/Body/Explore")),"go_rect":_rect(panel.get_node("Content/Go").get_global_rect()),
		"body_minimum":_v(bundle.gui.get_node("Pad/Scroll/Body").get_combined_minimum_size()),"scroll":bundle.scroll.scroll_vertical}

func _base_refresh_response(result: int, status: int, _headers: PackedStringArray, _body: PackedByteArray, bundle: Dictionary) -> void:
	var panel: Node=bundle.panel
	active.responses.append({"usec":Time.get_ticks_usec(),"result":result,"status":status,"loaded":panel.loaded,"reading":panel.reading,
		"queued":panel.refresh_after_read,"go_disabled":panel.get_node("Content/Go").disabled,"layout":_base_refresh_layout(bundle)})
	if active.responses.size()==3:
		_ok(panel.reading and panel.get_node("Content/Go").disabled and _base_refresh_layout(bundle)==active.stable_layout,"Queued read exposed enabled/stale layout between n3 and n4")

func _base_refresh_wait(panel: Node, expected: int) -> bool:
	var end_msec := mini(deadline,Time.get_ticks_msec()+8000)
	while panel.reading or active.responses.size()<expected:
		if not _ok(Time.get_ticks_msec()<end_msec and first_error.is_empty(),"Bounded actual Guide response wait failed"):return false
		await process_frame
	return _ok(active.responses.size()==expected and first_error.is_empty(),"Unexpected Guide response count/error")

func _base_refresh_case() -> bool:
	active={"kind":"base","arm":"refresh","mode":mode,"events":[],"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,
		"pressed":[],"pressed_events":[],"toggled":[],"requests":[],"chosen_events":[],"scroll_started":0,"scroll_events":[],"trajectory":[],
		"responses":[],"layout_required":false,"complete":false}
	records.append(active)
	var matcher := RegEx.new()
	matcher.compile("^http://127[.]0[.]0[.]1:([1-9][0-9]{0,4})$")
	var address := OS.get_environment("PILOT_BASE_GUIDE_URL")
	var matched := matcher.search(address)
	if not _ok(matched!=null and int(matched.get_string(1))>=1024 and int(matched.get_string(1))<=65535,"One exact ephemeral loopback Guide URL required"):return false
	var bundle := await _load_gui("base")
	if bundle.is_empty():return false
	var panel: Node=bundle.panel
	var scroll: ScrollContainer=bundle.scroll
	var explore: BaseButton=bundle.gui.get_node("Pad/Scroll/Body/Explore")
	panel.endpoint=address;panel.token="pl-guide-display-only"
	active.button={"node":str(bundle.gui.get_path_to(explore))}
	_watch(bundle.gui,scroll)
	scroll.scroll_ended.connect(func():
		if recording:active.scroll_events.append({"signal":"ended","usec":Time.get_ticks_usec()}))
	panel.get_node("HTTP").request_completed.connect(_base_refresh_response.bind(bundle))
	stability_sampler=_base_sample.bind(bundle);process_frame.connect(stability_sampler);recording=true
	if not _ok(not panel.loaded and not panel.reading,"Initial Guide must be real scene default, not pre-applied"):return false
	panel.refresh()
	if not _ok(panel.reading and not panel.loaded and panel.get_node("Content/Go").disabled
		and panel.get_node("Content/Next").text=="正在读取机组进度…" and panel.get_node("Content/Daily").text=="正在读取今日目标…","Actual initial loading presentation missing"):return false
	if not _png("refresh-initial-loading.png"):return false
	if not (await _base_refresh_wait(panel,1)):return false
	if not _ok(panel.loaded and not panel.get_node("Content/Go").disabled,"Initial real GET did not apply Guide"):return false
	await process_frame
	await process_frame
	if not _png("refresh-initial-loaded.png"):return false
	var clip := _clip(scroll)
	var start := Vector2(820,399)
	var end := Vector2(820,141)
	if not _ok(clip.has_point(start) and clip.has_point(end) and panel.get_node("Content/Party").get_global_rect().has_point(start)
		and scroll.scroll_vertical==0 and explore.get_mouse_filter_with_override()==Control.MOUSE_FILTER_PASS,"Original Base touch geometry differs; no correction"):return false
	await _drag(start,end)
	if not (await _base_wait(0.9)):return false
	var point := explore.get_global_rect().get_center()
	if not _ok(active.scroll_events.any(func(row: Dictionary):return row.signal=="ended") and scroll.scroll_vertical>0
		and clip.has_point(point) and active.mouse_events>0 and active.pressed.is_empty() and active.requests.is_empty(),"Real drag did not settle without unintended input"):return false
	active.saved_point=_v(point);active.stable_layout=_base_refresh_layout(bundle);active.layout_required=true
	if not _png("refresh-anchor.png"):return false
	panel.refresh()
	if not _ok(panel.reading and panel.loaded and panel.get_node("Content/Go").disabled and _base_refresh_layout(bundle)==active.stable_layout,"Same-content in-flight layout differs"):return false
	if not _png("refresh-background-pending.png"):return false
	if not (await _base_refresh_wait(panel,2)):return false
	if not _ok(panel.loaded and not panel.get_node("Content/Go").disabled and _base_refresh_layout(bundle)==active.stable_layout,"Same-content success layout differs"):return false
	panel.refresh();panel.refresh(true);panel.refresh(true);panel.refresh(true)
	if not _ok(panel.reading and panel.refresh_after_read and panel.get_node("Content/Go").disabled,"Read merge flag/action gate missing"):return false
	if not (await _base_refresh_wait(panel,4)):return false
	if not _ok(panel.loaded and not panel.refresh_after_read and not panel.get_node("Content/Go").disabled and _base_refresh_layout(bundle)==active.stable_layout,"Queued final success layout/gate differs"):return false
	if not _png("refresh-queued-complete.png"):return false
	active.layout_required=false
	for count: int in [5,6]:
		panel.refresh()
		if not (await _base_refresh_wait(panel,count)):return false
		if not _ok(not panel.loaded and not panel.reading and not panel.refresh_after_read and not panel.get_node("Content/Go").disabled
			and panel.get_node("Content/Go").text=="重试读取" and panel.get_node("Content/Next").text=="指引未更新，请重试读取。"
			and panel.get_node("Content/Daily").text=="今日目标未更新。","503/401 must retain original failure feedback"):return false
		if not _png("refresh-error-"+str(count)+".png"):return false
	if not (await _base_wait(0.6)):return false
	var statuses: Array=[]
	for row: Dictionary in active.responses:statuses.append(row.status)
	if not _ok(statuses==[200,200,200,200,503,401] and not panel.reading and active.pressed.is_empty() and active.requests.is_empty(),"Extra/unknown Guide response or unintended GUI action"):return false
	active.complete=true
	return first_error.is_empty()

func _base_stability_case(delayed: bool) -> bool:
	var label := "delayed" if delayed else "immediate"
	active={"kind":"base","arm":label,"mode":mode,"events":[],"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,
		"pressed":[],"pressed_events":[],"toggled":[],"requests":[],"chosen_events":[],"scroll_started":0,"scroll_events":[],"trajectory":[],"complete":false}
	records.append(active)
	var bundle := await _load_gui("base")
	if bundle.is_empty():return false
	var gui: Control=bundle.gui
	var scroll: ScrollContainer=bundle.scroll
	var explore: BaseButton=gui.get_node("Pad/Scroll/Body/Explore")
	var drag_button: BaseButton=bundle.panel.get_node("Content/Party")
	var clip := _clip(scroll)
	var start := Vector2(820,399)
	var end := Vector2(820,141)
	active.button={"node":str(gui.get_path_to(explore)),"chain":_chain(explore,scroll),"filter":explore.mouse_filter,"action_mode":explore.action_mode}
	active.clip=_rect(clip);active.start_at=_v(start);active.end_at=_v(end)
	if not _ok(scroll.scroll_vertical==0 and clip.has_point(start) and clip.has_point(end) and drag_button.get_global_rect().has_point(start)
		and drag_button.is_visible_in_tree() and not drag_button.disabled and drag_button.get_mouse_filter_with_override()==Control.MOUSE_FILTER_PASS
		and explore.get_mouse_filter_with_override()==Control.MOUSE_FILTER_PASS and explore.action_mode==BaseButton.ACTION_MODE_BUTTON_RELEASE
		and not explore.disabled,"Native Base geometry/PASS/RELEASE gesture qualification differs; no coordinate correction"):return false
	_watch(gui,scroll)
	scroll.scroll_ended.connect(func():
		if recording:active.scroll_events.append({"signal":"ended","usec":Time.get_ticks_usec()}))
	stability_sampler=_base_sample.bind(bundle)
	process_frame.connect(stability_sampler)
	recording=true
	_base_sample(bundle)
	if not _png(label+"-pre-drag.png"):return false
	await _drag(start,end)
	if not _png(label+"-post-drag.png"):return false
	if not (await _base_wait(0.9)):return false
	active.scroll_ended_before_anchor=active.scroll_events.any(func(row: Dictionary):return row.signal=="ended")
	var anchor_rect := explore.get_global_rect()
	var at := anchor_rect.get_center()
	if not _ok(active.scroll_ended_before_anchor and explore.is_visible_in_tree() and not explore.disabled and clip.has_point(at) and active.mouse_events>0 and scroll.scroll_vertical>0,
		"Exact Explore/touch-emulation or scroll-ended not qualified after fixed 0.9 seconds; no extra wait/scroll assignment"):return false
	active.anchor={"usec":Time.get_ticks_usec(),"point":_v(at),"explore":_base_control(explore),"scroll":scroll.scroll_vertical}
	if not _png(label+"-anchor.png"):return false
	if delayed and not (await _base_wait(21.0)):return false
	active.pre_tap={"usec":Time.get_ticks_usec(),"explore":_base_control(explore),"scroll":scroll.scroll_vertical,"saved_point_hits_explore":explore.get_global_rect().has_point(at)}
	active.pressed_before_tap=active.pressed.duplicate()
	if not _png(label+"-pre-tap.png"):return false
	_send_touch(true,at)
	await process_frame
	await process_frame
	_send_touch(false,at)
	if not (await _base_wait(0.4)):return false
	if not _png(label+"-post-tap.png"):return false
	active.correct_target=active.pressed==[active.button.node] and active.requests.is_empty() and active.toggled.is_empty() and active.button_mouse_press==1
	active.geometry_unchanged=active.pre_tap.explore.rect==active.anchor.explore.rect and active.pre_tap.scroll==active.anchor.scroll
	active.complete=not held
	if not delayed and not _ok(active.correct_target and active.pressed_before_tap.is_empty(),"Immediate same-instance Explore click produced wrong/missing GUI intent"):return false
	return _ok(active.complete,"Base touch not released")

func _ordinary_click(kind: String) -> bool:
	var drag_record := active
	await _clear_arm()
	if not _ok(Time.get_ticks_msec()<deadline,"Original probe deadline exhausted before click"):return false
	active={"kind":kind,"phase":"fresh-instance-click","mode":mode,"semantic":drag_record.semantic,"image_prefix":drag_record.image_prefix+"-click","events":[],"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,"pressed":[],"toggled":[],"requests":[],"scroll_started":0}
	drag_record.click=active
	var bundle := await _load_gui(kind)
	if bundle.is_empty():return false
	var gui: Control=bundle.gui
	var scroll: ScrollContainer=bundle.scroll
	var panel: Node=bundle.panel
	var button: BaseButton=_target(bundle,kind,drag_record.semantic)
	if not _ok(is_instance_valid(button),"Same-semantic ordinary click target missing"):return false
	var clip := _clip(scroll)
	var at := button.get_global_rect().get_center()
	active.button={"node":str(gui.get_path_to(button)),"rect":_rect(button.get_global_rect()),"chain":_chain(button,scroll),"filter":button.mouse_filter,"effective_filter":button.get_mouse_filter_with_override(),"action_mode":button.action_mode}
	active.clip=_rect(clip);active.at=_v(at)
	active.scroll_before=scroll.scroll_vertical
	active.selected_before=panel.selected.duplicate() if kind=="party" else []
	active.checkbox_before=button.button_pressed
	var native_product := mode=="production"
	if not _ok(button.is_visible_in_tree() and not button.disabled and clip.has_point(at) and scroll.scroll_vertical==0 and button.get_mouse_filter_with_override()==(Control.MOUSE_FILTER_PASS if native_product else Control.MOUSE_FILTER_STOP),"Fresh same-semantic click qualification failed"):return false
	if native_product and not _ok(button.action_mode==BaseButton.ACTION_MODE_BUTTON_RELEASE,"Product click must retain native RELEASE"):return false
	if mode=="mechanism":button.mouse_filter=Control.MOUSE_FILTER_PASS
	active.only_pass_override=mode=="mechanism"
	_watch(gui,scroll)
	if not _png(active.image_prefix+"-before.png"):return false
	recording=true
	_send_touch(true,at);await process_frame;await process_frame
	_send_touch(false,at);await process_frame;await process_frame
	recording=false
	active.scroll_after=scroll.scroll_vertical
	active.selected_after=panel.selected.duplicate() if kind=="party" else []
	active.checkbox_after=button.button_pressed
	if not _png(active.image_prefix+"-after.png"):return false
	var expected_requests: Array=["guide:party"] if active.semantic=="BaseGuideParty" else []
	if not _ok(not held and active.button_mouse_press==1 and active.pressed==[active.button.node] and active.scroll_after==0 and active.scroll_started==0 and active.requests==expected_requests and active.toggled.size()==(1 if kind=="party" else 0),"PASS ordinary click must produce exactly one target GUI intent without scrolling"):return false
	if kind=="party":
		if not _ok(active.toggled[0].node==active.button.node and active.toggled[0].value==active.checkbox_after and active.checkbox_after!=active.checkbox_before and panel.selected.has(party_target)==active.checkbox_after,"Actual checkbox/selection did not match the one target toggle"):return false
		var before: Array=active.selected_before.duplicate()
		var expected: Array=before.duplicate()
		if active.checkbox_after:expected.append(party_target)
		else:expected.erase(party_target)
		if not _ok(active.selected_after.size()==expected.size() and active.selected_after.all(func(id: Variant):return id in expected) and expected.all(func(id: Variant):return id in active.selected_after),"Only the same owned id may change selection"):return false
	active.passed=true
	active=drag_record
	return true

func _production_gate(case_name: String) -> bool:
	if not _ok(mode=="production" and case_name in ["ready-readgate","owned-disabled"] and not party_target.is_empty(),"Fixed product gate only"):return false
	active={"kind":"party","phase":"disabled-gate","mode":mode,"case":case_name,"events":[],"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,"pressed":[],"toggled":[],"requests":[],"scroll_started":0,"only_pass_override":false}
	gate_records.append(active)
	var bundle := await _load_gui("party")
	if bundle.is_empty():return false
	var gui: Control=bundle.gui
	var scroll: ScrollContainer=bundle.scroll
	var panel: Node=bundle.panel
	var button: BaseButton
	if case_name=="ready-readgate":
		panel.set_read_available(false);panel.enforce_read_gate()
		button=panel.get_node("%Ready")
		active.semantic="PartyReadyReadGate"
		active.unready_owned_checkbox_disabled=panel.robot_buttons[party_target].disabled
		if not _ok(not panel.read_available and not active.unready_owned_checkbox_disabled,"Read gate locks submits, not all draft checkboxes"):return false
	else:
		var data: Dictionary=fixture.party.duplicate(true)
		for member: Dictionary in data.roomscope.members:
			if member.owner==data.self:
				member.ready=true;member.robots=[party_target];member.points=2
		panel.refresh(data)
		button=panel.robot_buttons[party_target]
		active.semantic="PartyOwnedRobot:"+party_target
		active.derived_ui_state={"owner":data.self,"ready":true,"robots":[party_target],"points":2,"origin":"UI-only refresh, not a server Ready"}
		if not _ok(panel.local_ready,"Actual refresh must establish local-ready disabled state"):return false
	await process_frame
	await process_frame
	var clip := _clip(scroll)
	var at := button.get_global_rect().get_center()
	active.button={"node":str(gui.get_path_to(button)),"rect":_rect(button.get_global_rect()),"chain":_chain(button,scroll),"filter":button.mouse_filter,"effective_filter":button.get_mouse_filter_with_override(),"action_mode":button.action_mode}
	active.clip=_rect(clip);active.at=_v(at);active.scroll_before=scroll.scroll_vertical
	active.disabled_before=button.disabled;active.checkbox_before=button.button_pressed
	active.selected_before=panel.selected.duplicate()
	if not _ok(button.is_visible_in_tree() and clip.has_point(at) and button.disabled and scroll.scroll_vertical==0 and button.get_mouse_filter_with_override()==Control.MOUSE_FILTER_PASS and button.action_mode==BaseButton.ACTION_MODE_BUTTON_RELEASE,"Visible native PASS/RELEASE disabled target required"):return false
	_watch(gui,scroll)
	if not _png("gate-"+case_name+"-before.png"):return false
	recording=true
	_send_touch(true,at);await process_frame;await process_frame
	var hover := root.gui_get_hovered_control()
	active.hover_after_press=str(hover.get_path()) if is_instance_valid(hover) else ""
	_send_touch(false,at);await process_frame;await process_frame
	recording=false
	active.scroll_after=scroll.scroll_vertical;active.disabled_after=button.disabled
	active.checkbox_after=button.button_pressed;active.selected_after=panel.selected.duplicate()
	if not _png("gate-"+case_name+"-after.png"):return false
	if not _ok(not held and active.mouse_events>0 and active.scroll_after==0 and active.scroll_started==0 and active.disabled_after and active.pressed.is_empty() and active.toggled.is_empty() and active.requests.is_empty() and active.checkbox_before==active.checkbox_after and active.selected_before==active.selected_after,"Disabled product target must reject real shortclick without bypass"):return false
	active.passed=true
	return true

func _workshop_popups(gui: Control) -> Array[String]:
	var paths: Array[String]=[]
	var pending: Array[Node]=[gui]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		pending.append_array(node.get_children(true))
		if node is Window and node.visible:paths.append(str(gui.get_path_to(node)))
	return paths

func _workshop_popup_visibility(popup: Window, node_path: String) -> void:
	if not recording:return
	var event := {"node":node_path,"visible":popup.visible,"ticks_msec":Time.get_ticks_msec()}
	if active.popup_events.size()>=16:
		# Preserve the first overflow event and explicitly close this observer;
		# never call a partial popup trace complete or silently drop its event.
		active.popup_overflow_event=event
		active.popup_observer_closed_on_overflow=true
		popup.visibility_changed.disconnect(_workshop_popup_visibility.bind(popup,node_path))
		_ok(false,"Fixed Mode popup observer overflow; later events unobserved")
		return
	active.popup_events.append(event)

func _workshop_diagnostic_arm(node_path: String, positive: bool = false) -> bool:
	# Fixed declaration, not a search for a start that happens to scroll.
	active={"kind":"workshop","mode":mode,"fixed_node":node_path,"complete":false,"events":[],"popup_events":[],"popup_observer_closed_on_overflow":false,"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,"pressed":[],"toggled":[],"requests":[],"scroll_started":0,"only_pass_override":false}
	records.append(active)
	if not _ok(node_path in WORKSHOP_STARTS and Time.get_ticks_msec()<deadline,"Fixed diagnostic start/deadline required"):return false
	var bundle := await _load_gui("workshop")
	if bundle.is_empty():return false
	var gui: Control=bundle.gui
	var scroll: ScrollContainer=bundle.scroll
	var target: Control=gui.get_node(node_path)
	var clip := _clip(scroll)
	var bar := scroll.get_v_scroll_bar()
	var start_at := target.get_global_rect().get_center()
	# Same declared short-gesture formula for both fixed top-of-panel starts.
	var distance := minf(64.0,start_at.y-clip.position.y-4.0)
	var end_at := start_at-Vector2(0,distance)
	active.scroll={"rect":_rect(scroll.get_global_rect()),"clip":_rect(clip),"value":bar.value,"max":bar.max_value,"page":bar.page,"deadzone":scroll.scroll_deadzone}
	active.button={"node":str(gui.get_path_to(target)),"class":target.get_class(),"rect":_rect(target.get_global_rect()),"chain":_chain(target,scroll),"filter":target.mouse_filter,"effective_filter":target.get_mouse_filter_with_override()}
	active.start_at=_v(start_at);active.end_at=_v(end_at);active.nominal_msec=300
	if target is BaseButton:
		active.button.action_mode=target.action_mode
		active.button.disabled=target.disabled
	active.other_stop_at_start=[]
	for control: Control in _controls(scroll):
		if control!=scroll and control!=target and control.is_visible_in_tree() and control.get_global_rect().has_point(start_at) and control.get_mouse_filter_with_override()==Control.MOUSE_FILTER_STOP:
			active.other_stop_at_start.append(str(gui.get_path_to(control)))
	if target is OptionButton:
		active.selected_before=target.selected
		active.item_count_before=target.item_count
		active.item_texts_before=[target.get_item_text(0),target.get_item_text(1)]
		var popup: PopupMenu=target.get_popup()
		popup.visibility_changed.connect(_workshop_popup_visibility.bind(popup,str(gui.get_path_to(popup))))
	if positive and target is BaseButton:
		if not _ok(target.get_mouse_filter_with_override()==Control.MOUSE_FILTER_PASS and target.action_mode==BaseButton.ACTION_MODE_BUTTON_RELEASE,"Workshop product source must be native PASS/RELEASE"):return false
	active.popups_before=_workshop_popups(gui)
	var prefix: String={"Scroll/Body/Shop":"workshop-shop","Scroll/Body/Mode":"workshop-mode","Scroll/Body/Stock":"workshop-stock"}[node_path]
	if not _png(prefix+"-before.png"):return false
	if not _ok((target is Button if node_path==WORKSHOP_STARTS[0] else target is OptionButton if node_path==WORKSHOP_STARTS[1] else target is Label) and target.is_visible_in_tree() and active.other_stop_at_start.is_empty(),"Fixed diagnostic target class/visibility/coverage differs"):return false
	if not _ok(scroll.scroll_vertical==0 and bar.max_value-bar.page>10 and distance>float(scroll.scroll_deadzone) and clip.has_point(start_at) and clip.has_point(end_at),"Fixed diagnostic clip/room/deadzone qualification failed; no alternate point"):return false
	_watch(gui,scroll)
	recording=true
	await _drag(start_at,end_at)
	recording=false
	active.scroll_after_drag=scroll.scroll_vertical
	active.scroll_delta=scroll.scroll_vertical-int(active.scroll.value)
	active.popups_after=_workshop_popups(gui)
	if target is OptionButton:active.selected_after=target.selected
	active.observed_scroll=active.scroll_delta!=0 and active.scroll_started>0
	active.observed_gui_intent=not active.pressed.is_empty() or not active.toggled.is_empty() or not active.requests.is_empty()
	active.observed_popup_change=active.popups_after!=active.popups_before or not active.popup_events.is_empty()
	# STOP/no-scroll and any GUI intent are observations, not a reason to skip later arms.
	var input_complete: bool = not held and active.mouse_events>0 and Time.get_ticks_msec()<deadline
	var image_complete := _png(prefix+"-after.png")
	active.complete=input_complete and image_complete and Time.get_ticks_msec()<deadline
	if not positive:return _ok(active.complete,"Diagnostic input/image collection incomplete")
	if not _ok(active.complete and active.observed_scroll and active.scroll_mouse_events>0 and active.pressed.is_empty() and active.toggled.is_empty() and active.requests.is_empty() and active.popups_before.is_empty() and active.popups_after.is_empty() and not active.popup_observer_closed_on_overflow,"Workshop product drag must scroll without GUI intent or popup"):return false
	for popup_event: Dictionary in active.popup_events:
		if not _ok(not popup_event.visible,"Workshop drag opened popup during gesture"):return false
	if target is OptionButton and not _ok(active.selected_after==active.selected_before,"Workshop drag changed selected item"):return false
	active.product_passed=true
	return true

func _workshop_choice(value: int, source: Node, signal_name: String) -> void:
	if not recording:return
	var event := {"signal_name":signal_name,"node":str(source.get_path()),"value":value,"ticks_msec":Time.get_ticks_msec()}
	if active.choice_events.size()>=16:
		active.choice_overflow_event=event
		active.choice_observer_closed_on_overflow=true
		source.disconnect(signal_name,_workshop_choice.bind(source,signal_name))
		_ok(false,"Workshop choice observer overflow; later events unobserved")
		return
	active.choice_events.append(event)

func _workshop_key(popup: PopupMenu, key: Key) -> Dictionary:
	if not _ok(key in [KEY_DOWN,KEY_ENTER] and held_key==0 and popup.visible and Time.get_ticks_msec()<deadline,"Only one current Popup Down/Enter key pair allowed"):return {}
	var window_id: int=popup.get_window_id()
	if not _ok(window_id>=0,"Current Popup Window id is invalid; no key fallback"):return {}
	var before_focus: int=popup.get_focused_item()
	var press := InputEventKey.new()
	press.window_id=window_id;press.keycode=key;press.pressed=true
	held_key=key;held_key_window_id=window_id
	active.key_events.append({"key":key,"window_id":window_id,"pressed":true,"ticks_msec":Time.get_ticks_msec(),"focused":before_focus,"popup_has_focus":popup.has_focus()})
	Input.parse_input_event(press)
	await process_frame
	# Keyup always precedes any transition/deadline assertion.
	var release := InputEventKey.new()
	release.window_id=window_id;release.keycode=key;release.pressed=false
	Input.parse_input_event(release);held_key=KEY_NONE;held_key_window_id=-1
	active.key_events.append({"key":key,"window_id":window_id,"pressed":false,"ticks_msec":Time.get_ticks_msec(),"focused":popup.get_focused_item(),"popup_has_focus":popup.has_focus()})
	await process_frame
	return {"before":before_focus,"after":popup.get_focused_item(),"popup_visible":popup.visible,"ticks_msec":Time.get_ticks_msec()}

func _workshop_fresh_click(node_path: String) -> bool:
	active={"kind":"workshop","mode":mode,"phase":"fresh-click","fixed_node":node_path,"product_passed":false,"events":[],"popup_events":[],"popup_observer_closed_on_overflow":false,"choice_events":[],"choice_observer_closed_on_overflow":false,"key_events":[],"mouse_events":0,"scroll_mouse_events":0,"button_mouse_press":0,"pressed":[],"toggled":[],"requests":[],"scroll_started":0,"only_pass_override":false}
	records.append(active)
	if not _ok(node_path in [WORKSHOP_STARTS[0],WORKSHOP_STARTS[1]] and mode=="workshop-production" and Time.get_ticks_msec()<deadline,"Only fixed workshop product Shop/Mode click"):return false
	var bundle := await _load_gui("workshop")
	if bundle.is_empty():return false
	var gui: Control=bundle.gui
	var scroll: ScrollContainer=bundle.scroll
	var button: BaseButton=gui.get_node(node_path)
	var at := button.get_global_rect().get_center()
	var clip := _clip(scroll)
	var prefix := "workshop-shop-click" if node_path==WORKSHOP_STARTS[0] else "workshop-mode-click"
	active.button={"node":str(gui.get_path_to(button)),"rect":_rect(button.get_global_rect()),"chain":_chain(button,scroll),"filter":button.mouse_filter,"effective_filter":button.get_mouse_filter_with_override(),"action_mode":button.action_mode}
	if not _ok(button.is_visible_in_tree() and not button.disabled and clip.has_point(at) and scroll.scroll_vertical==0 and button.get_mouse_filter_with_override()==Control.MOUSE_FILTER_PASS and button.action_mode==BaseButton.ACTION_MODE_BUTTON_RELEASE,"Fresh fixed click must retain source PASS/RELEASE and actual clip"):return false
	var picker: OptionButton=null
	var popup: PopupMenu=null
	if node_path==WORKSHOP_STARTS[1]:
		picker=button as OptionButton
		if not _ok(picker!=null and picker.item_count==2 and picker.selected==0,"Fresh Mode must have two natural items/selection0"):return false
		popup=picker.get_popup()
		active.selected_before=picker.selected
		active.expected_popup_id=popup.get_item_id(1)
		popup.visibility_changed.connect(_workshop_popup_visibility.bind(popup,str(gui.get_path_to(popup))))
		popup.id_pressed.connect(_workshop_choice.bind(popup,"id_pressed"))
		picker.item_selected.connect(_workshop_choice.bind(picker,"item_selected"))
	_watch(gui,scroll)
	active.popups_before=_workshop_popups(gui)
	if not _png(prefix+"-before.png"):return false
	recording=true
	active.touch_down_msec=Time.get_ticks_msec()
	_send_touch(true,at)
	await process_frame
	await process_frame
	var hover := root.gui_get_hovered_control()
	active.hover_after_press=str(hover.get_path()) if is_instance_valid(hover) else ""
	active.after_press={"pressed":active.pressed.duplicate(),"popup_visible":popup.visible if popup!=null else false,"ticks_msec":Time.get_ticks_msec()}
	var press_ok: bool=active.pressed.is_empty() and (popup==null or not popup.visible)
	active.touch_up_msec=Time.get_ticks_msec()
	_send_touch(false,at)
	await process_frame
	await process_frame
	active.after_release={"pressed":active.pressed.duplicate(),"popup_visible":popup.visible if popup!=null else false,"ticks_msec":Time.get_ticks_msec()}
	if not _ok(press_ok and not held and active.button_mouse_press==1 and active.pressed==[active.button.node] and scroll.scroll_vertical==0 and active.scroll_started==0 and active.requests.is_empty(),"Fresh short tap must trigger once only after release, without scroll/request"):return false
	if picker==null:
		recording=false
		active.popups_after=_workshop_popups(gui)
		if not _png(prefix+"-after.png"):return false
		if not _ok(active.popups_before.is_empty() and active.popups_after.is_empty() and active.toggled.is_empty(),"Shop short tap opened popup or toggled"):return false
	else:
		if not _ok(popup.visible and active.choice_events.is_empty() and picker.selected==0,"Mode release must open menu without choosing"):return false
		active.opened={"position":_v(Vector2(popup.position)),"size":_v(Vector2(popup.size)),"has_focus":popup.has_focus(),"window_id":popup.get_window_id(),"root_window_id":root.get_window_id(),"popup_force_native":popup.get_force_native(),"root_embeds_subwindows":root.is_embedding_subwindows(),"focused_item":popup.get_focused_item(),"selected":picker.selected,"ticks_msec":Time.get_ticks_msec()}
		if not _png(prefix+"-opened.png"):return false
		var focus: int=popup.get_focused_item()
		if not _ok(focus in [-1,0,1],"Unexpected natural Mode popup focus"):return false
		if focus==-1:
			var first_down: Dictionary=await _workshop_key(popup,KEY_DOWN)
			if not _ok(not first_down.is_empty() and first_down.before==-1 and first_down.after==0 and popup.visible,"First natural Down must move -1 to0; no retry"):return false
			focus=0
		if focus==0:
			var second_down: Dictionary=await _workshop_key(popup,KEY_DOWN)
			if not _ok(not second_down.is_empty() and second_down.before==0 and second_down.after==1 and popup.visible,"Natural Down must move0 to1; no retry"):return false
		var enter: Dictionary=await _workshop_key(popup,KEY_ENTER)
		if not _ok(not enter.is_empty() and enter.before==1 and held_key==0,"Exactly one Enter from focused second item required"):return false
		recording=false
		active.selected_after=picker.selected
		active.popups_after=_workshop_popups(gui)
		var ids: Array=[]
		var items: Array=[]
		for choice: Dictionary in active.choice_events:
			if choice.signal_name=="id_pressed":ids.append(choice.value)
			elif choice.signal_name=="item_selected":items.append(choice.value)
		if not _png(prefix+"-selected.png"):return false
		if not _ok(not popup.visible and picker.selected==1 and ids==[active.expected_popup_id] and items==[1] and not active.popup_observer_closed_on_overflow and not active.choice_observer_closed_on_overflow and active.pressed==[active.button.node] and active.requests.is_empty() and scroll.scroll_vertical==0 and active.scroll_started==0,"Real popup key choice must select second once and close without scroll/request"):return false
	if not _ok(Time.get_ticks_msec()<deadline,"Original workshop product deadline exhausted"):return false
	active.product_passed=true
	return true

func _clear_arm() -> void:
	recording=false
	if stability_sampler.is_valid():
		if process_frame.is_connected(stability_sampler):process_frame.disconnect(stability_sampler)
		stability_sampler=Callable()
	if held:_send_touch(false,last_at)
	if held_key!=0:
		var release := InputEventKey.new()
		release.window_id=held_key_window_id;release.keycode=held_key;release.pressed=false
		Input.parse_input_event(release);held_key=KEY_NONE;held_key_window_id=-1
		_ok(false,"Unpaired workshop key released during cleanup")
	if is_instance_valid(canvas):canvas.queue_free()
	await process_frame
	await process_frame
	for node: Node in business_roots:
		if is_instance_valid(node):node.free()
	business_roots.clear();canvas=null

func _finish() -> void:
	if mode=="workshop-production" and held_key!=0:
		var release := InputEventKey.new()
		release.window_id=held_key_window_id;release.keycode=held_key;release.pressed=false
		Input.parse_input_event(release);held_key=KEY_NONE;held_key_window_id=-1
		_ok(false,"Unpaired workshop key released at finish")
	var result := {"passed":first_error.is_empty(),"first_error":first_error,"fixture_id":fixture.get("fixture_id",""),"mode":mode,"display_server":DisplayServer.get_name(),"touchscreen_available":DisplayServer.is_touchscreen_available(),"emulate_mouse_from_touch":Input.is_emulating_mouse_from_touch(),"emulate_touch_from_mouse":Input.is_emulating_touch_from_mouse(),"viewport":_v(Vector2(root.size)),"arms":records,"gates":gate_records,"held_input":held,"live_business_roots":business_roots.size(),"limitation":"GUI-subtree only; no business HTTP/navigation/Android verdict; production data is baseline plus declared deltas, not a new candidate manifest"}
	if mode=="workshop-diagnostic":
		result.diagnostic_complete=first_error.is_empty() and records.size()==3 and records[0].get("complete",false) and records[1].get("complete",false) and records[2].get("complete",false)
		result.product_scroll_passed=null
		result.limitation="Fixed native workshop GUI starts only; complete can include blocked/accidental GUI behavior. No product/HTTP/Android pass, no filter or scroll override."
	if mode=="base-stability":
		result.diagnostic_complete=records.size()==2 and records[0].get("complete",false) and records[1].get("complete",false) and first_error.is_empty()
		result.product_scroll_passed=null
		result.delayed_stable=records[1].get("correct_target",false) and records[1].get("geometry_unchanged",false) if records.size()==2 else null
		result.source_manifest_sha256=BASE_STABILITY_SOURCE
		result.limitation="Current Base GUI subtree only; diagnostic completion may include delayed drift/wrong target. No business Root/HTTP/automatic refresh/navigation/Android/FPS verdict."
	if mode=="base-refresh":
		result.guide_refresh_passed=first_error.is_empty() and records.size()==1 and records[0].get("complete",false)
		result.product_scroll_passed=null
		result.limitation="Actual Guide GET/presentation/GUI only; Python Fixture request/exception/cleanup evidence is additionally required. No Base10s scheduling/business Root/navigation/Android/general-auth verdict."
	if mode=="workshop-production":
		var complete: bool=records.size()==5 and not held and held_key==0
		for row: Dictionary in records:complete=complete and row.get("product_passed",false)
		_ok(complete,"Workshop product requires all five fixed arms")
		result.passed=first_error.is_empty() and complete
		result.first_error=first_error
		result.product_scroll_passed=result.passed
		result.held_key=held_key
		result.held_key_window_id=held_key_window_id
		result.limitation="Five fixed native workshop GUI positive arms; real Popup keyboard choice is not Android touch-menu/business HTTP validation."
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
		else:_ok(false,"Cannot preserve result")
	print(JSON.stringify({"passed":first_error.is_empty(),"first_error":first_error,"output":output}))
	quit(0 if first_error.is_empty() else 1)

func _run() -> void:
	deadline=Time.get_ticks_msec()+20000
	var args := OS.get_cmdline_user_args()
	if not _ok(args.size() in [4,6] and args[0]=="--fixture" and args[2]=="--out" and args[1].is_absolute_path() and args[3].is_absolute_path(),"Exact absolute fixture/output arguments"): _finish();return
	if args.size()==6:
		if not _ok(args[4]=="--mode" and args[5] in ["mechanism","production","workshop-diagnostic","workshop-production","base-stability","base-refresh"],"Only fixed declared probe modes"): _finish();return
		mode=args[5]
	if mode in ["base-stability","base-refresh"]:deadline=Time.get_ticks_msec()+60000;Engine.max_fps=60
	output=args[3]
	if not _ok(not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output),"New output only"):output="";_finish();return
	if not _ok(DirAccess.make_dir_recursive_absolute(output)==OK,"Cannot create own output"):output="";_finish();return
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not _ok(raw is Dictionary,"Fixture must be JSON dictionary"):_finish();return
	fixture=raw
	if not (_base_fixture_valid() if mode in ["base-stability","base-refresh"] else _fixture_valid()):_finish();return
	root.size=Vector2i(960,540)
	await process_frame
	if not _ok(root.size==Vector2i(960,540) and DisplayServer.is_touchscreen_available() and Input.is_emulating_mouse_from_touch(),"Real viewport/touchscreen/mouse-emulation qualification required"):_finish();return
	if mode=="base-refresh":
		await _base_refresh_case()
		await _clear_arm()
		_finish()
		return
	if mode=="base-stability":
		var immediate := await _base_stability_case(false)
		await _clear_arm()
		if immediate and first_error.is_empty():
			await _base_stability_case(true)
			await _clear_arm()
		_finish()
		return
	if mode=="workshop-diagnostic":
		for node_path: String in WORKSHOP_STARTS:
			await _workshop_diagnostic_arm(node_path)
			await _clear_arm()
			_ok(Time.get_ticks_msec()<deadline,"Original diagnostic deadline exhausted")
		await _clear_arm()
		_finish()
		return
	if mode=="workshop-production":
		for node_path: String in WORKSHOP_STARTS:
			var passed: bool = await _workshop_diagnostic_arm(node_path,true)
			await _clear_arm()
			if not passed or not _ok(Time.get_ticks_msec()<deadline,"Original product deadline exhausted"):break
		if first_error.is_empty():
			for node_path: String in [WORKSHOP_STARTS[0],WORKSHOP_STARTS[1]]:
				var passed: bool = await _workshop_fresh_click(node_path)
				await _clear_arm()
				if not passed or not _ok(Time.get_ticks_msec()<deadline,"Original product deadline exhausted"):break
		await _clear_arm()
		_finish()
		return
	var scenarios: Array=[["base","A",""],["base","B",""],["base","C",""],["party","A",""],["party","C",""]]
	if mode=="production":scenarios=[["base","P","BaseGuideParty"],["base","P","BaseEconomyToggle"],["party","P","PartyOwnedRobot"]]
	for scenario: Array in scenarios:
		var passed := await _arm(scenario[0],scenario[1],scenario[2])
		await _clear_arm()
		if not passed or not _ok(Time.get_ticks_msec()<deadline,"Original probe deadline exhausted"):break
	if mode=="production" and first_error.is_empty():
		for case_name: String in ["ready-readgate","owned-disabled"]:
			var passed := await _production_gate(case_name)
			await _clear_arm()
			if not passed or not _ok(Time.get_ticks_msec()<deadline,"Original probe deadline exhausted"):break
	await _clear_arm()
	_finish()
