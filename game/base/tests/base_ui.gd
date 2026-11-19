extends "res://profile/tests/profile_ui.gd"

var base: Node

func _wait() -> void:
	var end := Time.get_ticks_msec() + 9000
	while base.busy and Time.get_ticks_msec() < end:
		await process_frame
	_check(not base.busy, "HTTP 超时")

func _click(x: int,y: int) -> void:
	var camera: Camera3D = base.get_node("Camera")
	var pos := camera.unproject_position(Vector3(x-5.5,0,y-4.0))
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion)
	var click := InputEventMouseButton.new()
	click.position = pos
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await _wait()

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Register")
	panel.get_node("%Base").pressed.emit()
	base = panel.get_node("PrivateBase")
	await _wait()
	if base.layout.is_empty():
		push_error("基地加载失败")
		quit(1)
		return
	for row in [[0,3,2],[1,5,3],[2,7,2],[3,1,5],[4,3,5]]:
		base.get_node("%Type").select(row[0])
		await _click(row[1],row[2])
		if base.preview.is_empty():
			push_error("投影点选未触发合法预览 · " + str(base.get_node("%Hint").text))
			quit(1)
			return
		base.get_node("%Confirm").pressed.emit()
		await _wait()
		_check(base.get_node("%Confirm").disabled and base.preview.is_empty() and base.get_node("%Hint").text.contains("已保存"), "已入账后不能重复确认")
	_check(base.layout.buildings.size()==6, "六类建筑")
	base.get_node("%Freeze").pressed.emit()
	await _wait()
	base.get_node("%Mode").select(1)
	base.get_node("%Mode").item_selected.emit(1)
	await _click(1,2)
	await _click(5,5)
	base.get_node("%Confirm").pressed.emit()
	await _wait()
	_check(base.layout.buildings[0].x == 5, "移动核心")
	base.get_node("%Snapshot").pressed.emit()
	await _wait()
	_check(base.frozen and base.get_node("%Stats").text.contains("v6"), "原防守快照")
	base.get_node("%Refresh").pressed.emit()
	await _wait()
	var screenshot := OS.get_environment("BASE_CAPTURE")
	if not screenshot.is_empty() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(screenshot) == OK, "保存截图")
	base.get_node("%Back").pressed.emit()
	await process_frame
	_check(panel.get_node("Scroll").visible, "返回档案")
	if not failed:
		print("BASE_UI_PASS profile/touch_projection/six_facilities/power/move/freeze/return")
	quit(1 if failed else 0)
