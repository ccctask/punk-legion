extends Node

const Endpoints:=preload("res://client/endpoints.gd")
const Catalog:=preload("res://loadout/catalog.gd")
const Session:=preload("res://beta/session.gd")
const Base:=preload("res://base/base.tscn")
const Diagnostics:=preload("res://beta/diagnostics.tscn")
var endpoint:=""
var identity:Dictionary={}
var starter:Dictionary={}
var world:Node
var diagnostics:Control
var operation:=""
var state:="checking"
var note:=""
var menu_open:=false
var compatible:=false
var account_ready:=false
const READ_PATHS:={"compat":"/v1/beta/compat","restore":"/v1/profile","layout":"/v1/base","guide":"/v1/onboarding"}
const READ_LABELS:={"compat":"连接与版本","restore":"指挥官档案","layout":"基地布局","guide":"基地指引与今日目标"}
var retry_count:=0
var cached_layout:Dictionary={}
var cached_guide:Dictionary={}
var equipment:Dictionary={}
var display_robot:Node3D
var name_tag:Label3D

func _ready() -> void:
	get_tree().set_meta("base_first_path",true)
	get_tree().quit_on_go_back=false
	get_viewport().size_changed.connect(_fit_keyboard)
	%RobotName.focus_entered.connect(_fit_keyboard)
	%Password.focus_entered.connect(_fit_keyboard)
	endpoint=Endpoints.profile_url()
	identity=Session.load_for(endpoint)
	%Account.text=identity.get("name","")
	%Menu.pressed.connect(_toggle_menu)
	%Resume.pressed.connect(_toggle_menu)
	%Login.pressed.connect(_authenticate.bind(false))
	%Register.pressed.connect(_authenticate.bind(true))
	%Rename.pressed.connect(_rename)
	%RobotName.text_submitted.connect(func(_v:String):_rename())
	%Password.text_submitted.connect(func(_v:String):_dismiss_keyboard(%Password))
	%Retry.pressed.connect(_check)
	%Switch.pressed.connect(_logout)
	%Codes.pressed.connect(_open_recovery.bind(true))
	%Forgot.pressed.connect(_open_recovery.bind(false))
	%Recovery.closed.connect(_close_recovery)
	%Recovery.session_expired.connect(func():
		_logout()
		_state("auth","会话已过期，请重新登录。"))
	%Dossier.pressed.connect(_profile.bind("",""))
	%Range.pressed.connect(_range)
	%Diagnostic.pressed.connect(_diagnostic)
	$HTTP.request_completed.connect(_reply)
	_world(false)
	_check()

func _world(owned:bool) -> void:
	if world:
		world.get_parent().remove_child(world)
		world.queue_free()
	world=Base.instantiate()
	world.preview_only=not owned
	if owned:
		world.endpoint=endpoint
		world.token=identity.token
		world.account=identity.owner
		world.initial_snapshot=cached_layout
		world.initial_guide=cached_guide
		world.closed.connect(_profile.bind("",""))
		world.garage_requested.connect(_guide)
		world.garage_returned.connect(_send.bind("restore",READ_PATHS.restore))
	$World.add_child(world)
	if owned:
		world.get_node("%Back").text="指挥官档案"
		world.get_node("HUD").visibility_changed.connect(_render)

func _dismiss_keyboard(field:Control) -> void:
	field.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):DisplayServer.virtual_keyboard_hide()

func _fit_keyboard() -> void:
	var focus:=get_viewport().gui_get_focus_owner()
	if focus and focus.is_inside_tree() and %Scroll.is_ancestor_of(focus):
		%Scroll.call_deferred("ensure_control_visible",focus)

func _check() -> void:
	if not operation.is_empty():return
	compatible=false
	_state("checking","正在检查连接与版本…")
	_send("compat","/v1/beta/compat")

func _authenticate(register:bool) -> void:
	if not compatible or not operation.is_empty():return
	_dismiss_keyboard(%Password)
	_send("register" if register else "login","/v1/accounts" if register else "/v1/sessions",{"name":%Account.text.strip_edges(),"password":%Password.text})

func _send(op:String,path:String,body:Dictionary={},retrying:=false) -> void:
	if not retrying:retry_count=0
	operation=op
	if READ_PATHS.has(op):
		state="checking"
		note="正在读取%s…" % READ_LABELS[op]
	_render()
	var headers:=Endpoints.headers(identity.get("token","") if op in ["restore","rename","layout","guide"] else "")
	var http:HTTPRequest=$HTTP
	var error:Error=http.request(endpoint+path,headers,HTTPClient.METHOD_GET if body.is_empty() else HTTPClient.METHOD_POST,"" if body.is_empty() else JSON.stringify(body))
	if error!=OK:
		# Android can also emit request_completed later for this synchronous failure.
		# Keep its emitter separate from the request the player starts next.
		http.request_completed.disconnect(_reply)
		var replacement:=http.duplicate(0) as HTTPRequest
		remove_child(http)
		replacement.name="HTTP"
		add_child(replacement)
		replacement.request_completed.connect(_reply)
		http.queue_free()
		operation=""
		_read_failure(op,-1,0,error)

func _read_failure(op:String,result:int,code:int,err:int=OK) -> void:
	print("BASE_READ_FAILED op=",op," result=",result," status=",code," err=",err)
	if op=="register":
		_state("auth","注册结果尚未确认，账号可能已创建。请先用相同账号和密码点「登录已有基地」核对。")
		return
	if op=="login":
		_state("auth","登录结果尚未确认。请检查连接，再点「登录已有基地」。")
		return
	if READ_PATHS.has(op) and retry_count<2:
		retry_count+=1
		operation=op
		_state("checking","%s暂未响应，正在重试（%d/2）…" % [READ_LABELS[op],retry_count])
		await get_tree().create_timer(0.35 if retry_count==1 else 0.9).timeout
		if operation==op:_send(op,READ_PATHS[op],{},true)
	else:
		var subject:String=READ_LABELS.get(op,"档案服务")
		_state("network",subject+"未能同步。请检查网络后点重试，将核对已保存的指挥官与机体。")

func _reply(result:int,code:int,_headers:PackedStringArray,raw:PackedByteArray) -> void:
	var op:=operation
	operation=""
	var body:Variant=null
	if result==HTTPRequest.RESULT_SUCCESS and not raw.is_empty():
		var json:=JSON.new()
		if json.parse(raw.get_string_from_utf8())==OK:
			body=json.data
	if code==426:
		compatible=false
		_state("upgrade","此版本无法连接当前服务。请向内测负责人领取新版 APK 并覆盖安装。")
		return
	if result!=HTTPRequest.RESULT_SUCCESS or code>=500 or code in [408,429] or not body is Dictionary:
		_read_failure(op,result,code)
		return
	if code!=200:
		if op in ["restore","rename","layout","guide"] and code==401:
			_logout()
			_state("auth","会话已过期，请重新登录找回基地。")
		elif op=="rename" and code==409:
			_send("restore","/v1/profile")
		elif op=="rename":
			_state("name","名称需要 1–24 个可见字符，请重新输入。")
		elif op in ["login","register"]:
			var reason:String=body.get("error","")
			_state("auth",{"account_exists":"账号已存在，请登录找回基地。","invalid_credentials":"账号或密码有误。","invalid_account":"账号使用 3–32 位字母、数字、短横线或下划线。","invalid_password":"密码需要 8–128 个字符。"}.get(reason,"登录未完成，请重试。"))
		else:_state("network","未能取得档案，请重试连接。")
		return
	if op=="compat":
		var protocol:=int(ProjectSettings.get_setting("beta/protocol",2))
		if protocol<int(body.get("protocol_min",999)) or protocol>int(body.get("protocol_max",-1)):
			_state("upgrade","协议不兼容，请向负责人领取新版 APK 并覆盖安装。")
			return
		if "base_first_naming" not in body.get("capabilities",[]):
			_state("upgrade","档案服务尚未支持基地内命名，请联系负责人更新服务或领取匹配的安装包。")
			return
		if "starter_equipment_snapshot" not in body.get("capabilities",[]):
			_state("upgrade","档案服务尚未支持首机装配快照。请使用匹配版本，或在服务更新后重试。")
			return
		compatible=true
		if identity.get("token","").is_empty():_state("auth","登录已有基地，或注册一位新指挥官。")
		else:_send("restore","/v1/profile")
		return
	if op=="layout":
		if not body.get("base") is Dictionary or not body.base.get("buildings") is Array or not body.base.get("roads") is Array:
			_read_failure(op,result,code)
			return
		cached_layout=body
		if account_ready:world.apply_base_snapshot(cached_layout)
		_send("guide",READ_PATHS.guide)
		return
	if op=="guide":
		if not body.get("guide") is Dictionary or not body.guide.get("facts") is Dictionary:
			_read_failure(op,result,code)
			return
		cached_guide=body.guide
		if account_ready:world.get_node("%Guide").apply_guide(cached_guide)
		_present()
		return
	var has_account:bool=body.get("account") is Dictionary and body.account.get("id") is String and not body.account.id.strip_edges().is_empty() and body.account.get("name") is String and not body.account.name.strip_edges().is_empty()
	var has_robots:bool=body.get("robots") is Array and not body.robots.is_empty()
	if op in ["register","login"]:
		if not has_account or not has_robots or not body.get("token") is String or body.token.strip_edges().is_empty():
			_read_failure(op,result,code)
			return
		identity={"token":body.token,"owner":body.account.id,"name":body.account.name,"endpoint":endpoint}
		%Password.clear()
		Session.store(identity)
	elif not has_account or not has_robots:
		_state("network","服务端尚未返回完整的机体档案，请重试。")
		return
	elif body.account.id!=identity.get("owner",""):
		_logout()
		_state("auth","指挥官身份已改变，请重新登录。")
		return
	var first:Variant=body.robots[0]
	if not _valid_starter(first,body):
		_state("network","服务未返回可核对的首机身份与装配，请点重试重新读取档案。")
		return
	if op=="rename" and (first.id!=identity.get("pending_robot","") or first.name!=identity.get("pending_name","")):
		_state("network","收到的机体名称与提交不一致，请重新核对。")
		return
	starter=first
	equipment={} if body.starter_equipment==null else body.starter_equipment
	if op=="rename":
		_send("guide",READ_PATHS.guide)
	else:
		_send("layout",READ_PATHS.layout)

func _valid_starter(first:Variant,body:Dictionary) -> bool:
	if not first is Dictionary or not first.get("id") is String or first.id.is_empty() or not first.get("name") is String or first.name.is_empty() or first.get("state") not in ["ready","damaged","repairing","retired"] or not body.has("starter_equipment"):
		return false
	var kit:Variant=body.starter_equipment
	if first.state=="retired":
		return kit==null
	if not kit is Dictionary or kit.get("id")!=first.id or kit.get("owner")!=identity.owner or not Catalog.CHASSIS.has(kit.get("chassis")) or kit.get("paint") not in ["base","mint"] or not kit.get("slots") is Dictionary:
		return false
	var mounts:Dictionary=Catalog.CHASSIS[kit.chassis].slots
	for slot in kit.slots:
		var part:Variant=kit.slots[slot]
		if not mounts.has(slot) or not part is Dictionary or not part.get("id") is String or part.id.is_empty() or not Catalog.PARTS.has(part.get("definition")):
			return false
		if Catalog.PARTS[part.definition].kind!=mounts[slot].kind:
			return false
	return true

func _present() -> void:
	if not account_ready:
		account_ready=true
		_world(true)
	if equipment.is_empty():
		if is_instance_valid(display_robot):
			display_robot.queue_free()
		display_robot=null
		name_tag=null
	else:
		if not is_instance_valid(display_robot):
			display_robot=preload("res://assets/steam_crawler/robot.tscn").instantiate()
			display_robot.name="StarterRobot"
			world.get_node("%HomeShowcase").add_child(display_robot)
			display_robot.position=Vector3(-1.45,0.05,-0.5)
			display_robot.rotation.y=.75
			display_robot.scale=Vector3.ONE*.82
			name_tag=Label3D.new()
			name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			name_tag.no_depth_test=true
			name_tag.font_size=28
			name_tag.pixel_size=.012
			name_tag.position=Vector3.UP*2.45
			display_robot.add_child(name_tag)
		display_robot.set_chassis(equipment.chassis)
		display_robot.set_paint(equipment.paint)
		display_robot.set_hull_number(str(equipment.get("hull_number","")))
		display_robot.head=int(equipment.slots.get("head",{}).get("definition")=="visor")
		display_robot.set_weapon_definition(equipment.slots.get("weapon",{}).get("definition",""))
		display_robot.set_repair_arm(equipment.slots.get("utility",{}).get("definition")=="repair_arm")
		display_robot.set_jammer(equipment.slots.get("utility",{}).get("definition")=="jammer")
		display_robot.set_shield(equipment.slots.get("armor",{}).get("definition")=="rivet_shield")
		display_robot.set_survey_radar(equipment.slots.get("survey",{}).get("definition")=="survey_radar")
		display_robot.set_slots_present(equipment.slots.has("head"),equipment.slots.has("weapon"))
	if is_instance_valid(name_tag):name_tag.text=starter.name
	%Account.text=identity.name
	if bool(starter.get("named",false)) or starter.name!="新虎机组" or starter.state=="retired":
		identity.erase("pending_robot")
		identity.erase("pending_name")
		Session.store(identity)
		_state("home","")
	else:
		if identity.get("pending_robot","")==starter.id:%RobotName.text=identity.get("pending_name","")
		_state("name","当前名称「%s」 · %s底盘\n登记号 %s" % [starter.name,Catalog.HULL_LABELS[equipment.get("chassis","crawler")],str(starter.id).left(8)])

func _rename() -> void:
	if not operation.is_empty() or state!="name" or not account_ready:return
	var requested:String=%RobotName.text.strip_edges()
	if requested.is_empty():_state("name","请输入 1–24 个可见字符。");return
	_dismiss_keyboard(%RobotName)
	identity.pending_name=requested
	identity.pending_robot=starter.id
	Session.store(identity)
	_send("rename","/v1/robots/"+str(starter.id)+"/rename",{"name":requested,"first_name_only":true})

func _logout() -> void:
	if not operation.is_empty():return
	identity.clear()
	starter.clear()
	cached_layout.clear()
	cached_guide.clear()
	equipment.clear()
	display_robot=null
	name_tag=null
	Session.forget()
	Room.pending_ticket=""
	account_ready=false
	menu_open=false
	%RobotName.clear()
	%Password.clear()
	%Account.clear()
	_world(false)
	_state("auth" if compatible else "network","登录另一位指挥官，或创建新基地。")

func _guide(action:String,robot:String) -> void:
	if action=="name" and state=="name":
		menu_open=false
		_render()
		%RobotName.grab_focus()
	else:_profile(action,robot)

func _profile(action:String,robot:String) -> void:
	if not account_ready:return
	get_tree().set_meta("base_first_profile_action",[action,robot])
	get_tree().call_deferred("change_scene_to_file","res://profile/profile.tscn")

func _range() -> void:
	if account_ready and compatible:get_tree().call_deferred("change_scene_to_file","res://client/range.tscn")

func _diagnostic() -> void:
	if diagnostics:return
	diagnostics=Diagnostics.instantiate()
	$Overlay/Controls.hide()
	$Overlay.add_child(diagnostics)
	diagnostics.closed.connect(func():
		diagnostics.queue_free()
		diagnostics=null
		$Overlay/Controls.show()
		menu_open=false
		_check())

func _open_recovery(issue: bool) -> void:
	if not operation.is_empty() or not compatible or issue!=account_ready:return
	%Password.clear()
	%Recovery.open(endpoint,identity.get("token","") if issue else "",identity.get("name","") if issue else %Account.text)
	_render()
	%Scroll.scroll_vertical=0

func _close_recovery(account_name: String, notice: String) -> void:
	if not account_name.is_empty():%Account.text=account_name
	if not notice.is_empty():note=notice
	_render()
	%Scroll.scroll_vertical=0

func _toggle_menu() -> void:
	menu_open=not menu_open
	_render()

func _state(next:String,message:String) -> void:
	state=next
	note=message
	_render()

func _render() -> void:
	var active:=not operation.is_empty()
	var in_base:bool=not account_ready or not world or world.get_node("HUD").visible
	%Menu.visible=in_base and not %Recovery.visible
	%Menu.text="关闭菜单" if menu_open else "基地菜单"
	%Panel.visible=in_base and (menu_open or state!="home")
	%Options.visible=menu_open and not %Recovery.visible
	%Form.visible=not menu_open and state=="auth" and not %Recovery.visible
	%Naming.visible=not menu_open and state=="name"
	%Retry.visible=not menu_open and state in ["network","upgrade"]
	%Title.text=("账号恢复码" if account_ready else "找回私人基地") if %Recovery.visible else "基地菜单" if menu_open else ("初始机体命名" if state=="name" else "私人基地")
	%Info.text=(identity.get("name","")+" · "+starter.get("name","")) if menu_open and account_ready else note
	%Info.visible=not %Recovery.visible and not %Info.text.is_empty()
	%Codes.visible=account_ready
	%Codes.disabled=active
	%Forgot.disabled=active
	%Range.disabled=active or not account_ready or not compatible
	%Dossier.disabled=%Range.disabled
	%Switch.visible=not identity.is_empty()
	for button in [%Login,%Register,%Rename,%Retry,%Switch]:button.disabled=active
	if account_ready:
		world.get_node("%Back").disabled=active
		world.get_node("HUD/Panel").visible=state=="home" and not menu_open
		if in_base:world.set_process_unhandled_input(state=="home" and not menu_open)
	%Commander.visible=account_ready and in_base and not menu_open and state=="home" and is_instance_valid(display_robot)
	%Commander.text="初始机体 · "+str(starter.get("name",""))

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if %Recovery.visible:
			if get_viewport().gui_get_focus_owner() is LineEdit:_dismiss_keyboard(get_viewport().gui_get_focus_owner())
			else:%Recovery._close()
		elif diagnostics:diagnostics.closed.emit()
		elif world and account_ready and not world.get_node("HUD").visible:return
		elif get_viewport().gui_get_focus_owner() is LineEdit:
			get_viewport().gui_release_focus()
			DisplayServer.virtual_keyboard_hide()
		else:_toggle_menu()
