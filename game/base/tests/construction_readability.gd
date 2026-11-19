extends "res://beta/tests/base_first.gd"

var base:Node
var hint:Label

func click_at(point:Vector2) -> void:
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
		await process_frame

func wait_request() -> void:
	var until:=Time.get_ticks_msec()+6000
	while base.busy and Time.get_ticks_msec()<until:
		await create_timer(.03).timeout
	_assert(not base.busy,"base HTTP timed out")
	await process_frame
	await process_frame

func tile(cell:Vector2i) -> void:
	var camera:Camera3D=base.get_node("Camera")
	var point:=camera.unproject_position(Vector3(cell.x-5.5,0,cell.y-4.0))
	await click_at(point)
	await wait_request()

func check_hint(stage:String,phrase:String) -> void:
	var scroll:ScrollContainer=base.get_node("HUD/Panel/Pad/Scroll")
	var rect:=hint.get_global_rect()
	var vis:=scroll.get_global_rect()
	_assert(hint.text.contains(phrase),stage+" got "+hint.text)
	_assert(vis.encloses(rect),stage+" outside viewport: "+str([vis,rect]))
	var max_width:=0.0
	for line:String in hint.text.split("\n"):
		max_width=maxf(max_width,hint.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,hint.get_theme_font_size("font_size")).x)
	print("HINT ",stage," line_width=",max_width," label=",rect," scroll=",vis," lines=",hint.get_line_count()," transform=",root.get_final_transform()," window=",root.size)
	_assert(max_width<=rect.size.x,stage+" requires additional word-breaking")
	await _snap(stage)

func _run() -> void:
	change_scene_to_file("res://beta/entry.tscn")
	await scene_changed
	home=current_scene
	await _wait_for("auth")
	home.get_node("%Account").text=account
	home.get_node("%Password").text=password
	_tap("Login")
	await _wait_for("name")
	home.get_node("%RobotName").text=given
	_tap("Rename")
	await _wait_for("home")
	_verified_base()
	base=home.world
	hint=base.get_node("%Hint")
	var fold:Button=base.get_node("%Guide/Fold")
	await click_at(fold.get_global_rect().get_center())
	var scroll:ScrollContainer=base.get_node("HUD/Panel/Pad/Scroll")
	scroll.ensure_control_visible(base.get_node("%Confirm"))
	await process_frame
	await check_hint("start","点已建军营进入机库")
	var picker:OptionButton=base.get_node("%Type")
	await click_at(picker.get_global_rect().get_center())
	var popup:=picker.get_popup()
	_assert(popup.visible,"facility selector did not open")
	var hangar_index:int=base.TYPES.find("hangar")
	popup.index_pressed.emit(hangar_index)
	popup.hide()
	await process_frame
	_assert(picker.selected==base.TYPES.find("hangar"),"selection via facility menu")
	await tile(Vector2i(4,4))
	await check_hint("occupied","已有建筑或道路")
	_assert(base.get_node("%Confirm").disabled,"occupied enabled confirm")
	await tile(Vector2i(5,2))
	await check_hint("preview","军营机库预览")
	var confirm:Button=base.get_node("%Confirm")
	_assert(not confirm.disabled,"legal preview rejected")
	await click_at(confirm.get_global_rect().get_center())
	await wait_request()
	await check_hint("built","已扣 1 结构材料")
	_assert(confirm.disabled and base.layout.revision==2,"saved revision/disable")
	await tile(Vector2i(7,2))
	await check_hint("insufficient","结构材料不足")
	_assert(confirm.disabled,"insufficient enabled confirm")
	await tile(Vector2i(5,2))
	var garage:Node=base.get_parent().get_child(-1)
	var until:=Time.get_ticks_msec()+6500
	while garage!=base and garage.get("busy") and Time.get_ticks_msec()<until:await create_timer(.04).timeout
	_assert(garage!=base and garage.get("open_garage")==true and not garage.get("data").get("robots",[]).is_empty(),"physical hangar did not open inventory")
	await _snap("garage")
	if not failed:print("M11_READABILITY_PASS")
	quit(int(failed))
