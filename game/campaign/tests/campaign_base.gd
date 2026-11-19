extends "res://onboarding/tests/session.gd"

var evidence := OS.get_environment("CAMPAIGN_EVIDENCE")
var shop:Node
var picked := ""
func _setup_capture() -> void:
	clock=Time.get_ticks_msec()
	account=OS.get_environment("CAMPAIGN_LOGIN")
	password=OS.get_environment("CAMPAIGN_PASSWORD")
	folder=OS.get_environment("CAMPAIGN_FRAMES")
	if not folder.is_empty():RenderingServer.frame_post_draw.connect(_record)

func _click_button(host:Node,path:String,wait_on:Node) -> void:
	var button:Button=host.get_node(path)
	if not button.is_visible_in_tree() or button.disabled:
		_fail("控件不可用 "+path+" "+str(button.text))
		return
	var scroll:Node=button.get_parent()
	while scroll:
		if scroll is ScrollContainer:scroll.ensure_control_visible(button)
		scroll=scroll.get_parent()
	await create_timer(0.25).timeout
	button.pressed.emit()
	await _wait(wait_on)

func _select(host:Node,path:String,n:int) -> void:
	var picker:OptionButton=host.get_node(path)
	picker.select(n)
	picker.item_selected.emit(n)

func _open_shop() -> void:
	panel.get_node("%Owned").pressed.emit()
	shop=panel.get_node("Workshop")
	await _wait(shop)

func _leave_shop() -> void:
	shop.get_node("%Back").pressed.emit()
	await process_frame
	await _wait(panel)

func _pick_cell(x:int,y:int) -> void:
	var camera:Camera3D=base.get_node("Camera")
	var position:=camera.unproject_position(Vector3(x-5.5,0,y-4.0))
	var event:=InputEventMouseButton.new()
	event.position=position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	root.push_input(event)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)
	await _wait(base)

func _make(name_for_robot:String) -> String:
	_select(shop,"%Mode",0)
	shop.get_node("%BuildName").text=name_for_robot
	await _click_button(shop,"%Build",shop)
	for r in shop.data.robots:
		if r.name==name_for_robot:return str(r.id)
	_fail("工坊未制造 "+name_for_robot+" "+shop.get_node("%Status").text)
	return ""

func _snap(name_for_file:String,control:Control=null) -> void:
	if control:
		var p:Node=control
		while p:
			if p is ScrollContainer:p.ensure_control_visible(control)
			p=p.get_parent()
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name_for_file+".png"))
