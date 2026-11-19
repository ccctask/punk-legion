extends "res://base/tests/base_ui.gd"

func _settled(view:Node) -> void:
	var end:=Time.get_ticks_msec()+8000
	while view.busy and Time.get_ticks_msec()<end:
		await process_frame
	_check(not view.busy,"等待平台请求")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text="platform_demo"
	panel.get_node("%Password").text="local-test-only-password"
	await _press("Login")
	panel.get_node("%Base").pressed.emit()
	base=panel.get_node("PrivateBase")
	await _wait()
	base.get_node("%Type").select(base.TYPES.find("turret"))
	await _click(5,3)
	base.get_node("%Confirm").pressed.emit()
	await _wait()
	await _click(5,3)
	var view:=panel.get_node("DefensePlatform")
	await _settled(view)
	_check(view.get_node("%Mounted").text.contains("空底座"),"新建平台没有炮")
	var expected := ""
	for i in view.data.parts.size():
		if view.data.parts[i].definition=="repair_arm":
			view.get_node("%Parts").select(i)
			view.get_node("%Parts").item_selected.emit(i)
			expected=view.data.parts[i].id
	_check(not expected.is_empty() and not view.get_node("%Install").disabled,"维修工具在背包中可安装")
	view.get_node("%Install").pressed.emit()
	await _settled(view)
	if not view.data.mounted is Dictionary:
		printerr("平台安装未生效 ",view.get_node("%Status").text," busy=",view.busy," intent=",view.intent)
		quit(1)
		return
	_check(view.data.mounted.id==expected and view.get_node("%Mounted").text.contains("维修臂"),"实装后显示原实物")
	var dest:=OS.get_environment("PLATFORM_CAPTURE")
	if not dest.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dest)
	view.get_node("%Back").pressed.emit()
	await process_frame
	await _wait()
	_check(base.visible,"退出平台返回私人基地")
	if not dest.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dest.get_basename()+"-base.png")
	await _click(5,3)
	view=panel.get_node("DefensePlatform")
	await _settled(view)
	view.get_node("%Detach").pressed.emit()
	await _settled(view)
	_check(view.data.mounted==null and view.data.parts.any(func(p):return p.id==expected),"原实物回到背包")
	view.get_node("%Remove").pressed.emit()
	await process_frame
	var deadline:=Time.get_ticks_msec()+6000
	while not base.visible and Time.get_ticks_msec()<deadline:
		await process_frame
	_check(base.visible,"移除平台后返回基地")
	if not failed:
		print("PLATFORM_UI_PASS real projected build/open, compatibility, mounted identity, return, detach and remove")
	quit(1 if failed else 0)
