extends "res://profile/tests/profile_ui.gd"

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text="m17_return"
	panel.get_node("%Password").text="test-password-42"
	await _press("Login")
	panel.get_node("%Base").pressed.emit()
	var base:=panel.get_node("PrivateBase")
	var guide:=base.get_node("%Guide")
	var deadline:=Time.get_ticks_msec()+10000
	while not guide.loaded and Time.get_ticks_msec()<deadline:
		await process_frame
	guide.get_node("Content/Return").pressed.emit()
	var statement:Label=guide.get_node("Content/Statement")
	_check(statement.is_visible_in_tree() and "168.0 小时" in statement.text and "已于" in statement.text and "野生袭击" in statement.text,"老档回归摘要")
	base.get_node("HUD/Panel/Pad/Scroll").ensure_control_visible(statement)
	if not OS.get_environment("M17_CAPTURE").is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("M17_CAPTURE"))
	if not failed:
		print("M17_OLD_UI_PASS normal range > profile login > private base > offline summary; all before/after, repair and raid entries shown")
	quit(1 if failed else 0)
