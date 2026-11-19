extends SceneTree

var home:Node
var mode:=OS.get_environment("HOME_QA_MODE")
var folder:=OS.get_environment("HOME_QA_PROOF")
var account:=OS.get_environment("HOME_QA_ACCOUNT")
var password:=OS.get_environment("HOME_QA_PASSWORD")
var given:=OS.get_environment("HOME_QA_NAME")
var failed:=false

func _initialize() -> void:_run.call_deferred()

func _assert(ok:bool,msg:String) -> void:
	if not ok:
		failed=true
		push_error(msg)
		quit(1)

func _wait_for(want:String) -> void:
	var until:=Time.get_ticks_msec()+13000
	while is_instance_valid(home) and (home.state!=want or not home.operation.is_empty()) and Time.get_ticks_msec()<until:
		await create_timer(.05).timeout
	_assert(is_instance_valid(home) and home.state==want and home.operation.is_empty(),"Expected "+want+" got "+str(home.state)+" / "+str(home.note))

func _verified_base() -> void:
	var b:Node=home.world
	var guide:Node=b.get_node("%Guide")
	_assert(not b.preview_only and b.layout.get("roads",[]).size()>0 and b.get_node("Buildings").get_child_count()>0,"no authoritative layout or physical core")
	_assert(guide.loaded and guide.get_node("Content/Daily").text.contains("今日目标") and not guide.get_node("Content/Next").text.contains("失败"),"mixed or absent guide")
	print("BASE_READY layout=",b.layout.revision," roads=",b.layout.roads.size()," buildings=",b.get_node("Buildings").get_child_count()," guide=",guide.current)

func _snap(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(mode+"-"+label+".png"))

func _tap(id:String) -> void:
	var button:Button=home.get_node("%"+id)
	_assert(button.is_visible_in_tree() and not button.disabled,"unavailable "+id)
	button.pressed.emit()

func _run() -> void:
	change_scene_to_file("res://beta/entry.tscn")
	await scene_changed
	home=current_scene
	if mode=="incompatible":
		await _wait_for("upgrade")
		_assert(not home.account_ready and home.get_node("%Retry").visible,"upgrade UI")
		await _snap("upgrade")
	elif mode in ["offline","layout_down","guide_down"]:
		await _wait_for("network")
		_assert(not home.account_ready and home.world.preview_only,"offline leaked base")
		await _snap("offline")
		DirAccess.remove_absolute(OS.get_environment("HOME_QA_FAULT"))
		_tap("Retry")
		await _wait_for("home")
		_verified_base()
	elif mode=="expired":
		await _wait_for("auth")
		_assert(home.note.contains("过期") and not home.account_ready,"expired token")
		home.get_node("%Account").text=account
		home.get_node("%Password").text=password
		_tap("Login")
		await _wait_for("home")
		_verified_base()
	elif mode=="restore":
		await _wait_for("home")
		_verified_base()
		_assert(home.starter.name==given and home.name_tag.text==given,"conditional rename not retained")
		await _snap("home")
		_tap("Menu")
		_tap("Diagnostic")
		await create_timer(.25).timeout
		_assert(is_instance_valid(home.diagnostics),"diagnostics unreachable")
		home.diagnostics.get_node("%Play").pressed.emit()
		await _wait_for("home")
		_verified_base()
		_tap("Menu")
		_tap("Range")
		await scene_changed
		var range_page:=current_scene
		var ret:Button=range_page.get_node("HUD/%Home")
		_assert(ret.visible,"range return")
		ret.pressed.emit()
		await scene_changed
		home=current_scene
		await _wait_for("home")
		_verified_base()
		_assert(home.starter.name==given and home.identity.name==account,"range changed owner")
		_tap("Menu")
		_tap("Dossier")
		await scene_changed
		var profile:=current_scene
		var until:=Time.get_ticks_msec()+6000
		while profile.robots.is_empty() and Time.get_ticks_msec()<until:await create_timer(.05).timeout
		_assert(profile.robots[0].name==given,"profile lost account")
		profile.get_node("%Back").pressed.emit()
		await scene_changed
		home=current_scene
		await _wait_for("home")
		_verified_base()
		_tap("Menu")
		_tap("Switch")
		await _wait_for("auth")
		_assert(home.identity.is_empty() and not home.account_ready and home.starter.is_empty(),"logout leaked robot")
	else:
		await _wait_for("auth")
		_assert(home.world.preview_only and home.world.get_node("Terrain").visible,"missing private base before authentication")
		await _snap("auth")
		home.get_node("%Account").text=account
		home.get_node("%Password").text=password
		home.get_node("%Password").text_submitted.emit(password)
		await create_timer(.15).timeout
		_assert(home.state=="auth" and home.operation.is_empty() and not home.note.contains("有误"),"IME Done chose authentication")
		_tap("Register")
		await _wait_for("name")
		_verified_base()
		var original:String=home.starter.id
		_assert(home.name_tag.text==home.starter.name and home.display_robot.chassis==home.equipment.chassis,"real starter preview")
		await _snap("name")
		home.get_node("%RobotName").text=given
		_tap("Rename")
		if mode=="lost":
			await _wait_for("network")
			_tap("Retry")
		await _wait_for("home")
		_verified_base()
		_assert(original==home.starter.id and home.starter.name==given and bool(home.starter.named),"wrong authoritative name")
		await _snap("named")
		print("BASE_FIRST_ROBOT ",original," ",given)
	if not failed:print("BASE_FIRST_PASS ",mode)
	quit(int(failed))
