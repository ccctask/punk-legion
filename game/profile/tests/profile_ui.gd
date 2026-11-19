extends SceneTree

var panel: Control
var account := "test_" + Crypto.new().generate_random_bytes(8).hex_encode()
var password := Crypto.new().generate_random_bytes(18).hex_encode()
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _panel() -> void:
	change_scene_to_file("res://client/range.tscn")
	await scene_changed
	current_scene.get_node("HUD").get_node("%Profile").pressed.emit()
	await scene_changed
	panel = current_scene
	_check(panel.scene_file_path == "res://profile/profile.tscn", "档案入口")

func _press(name: String) -> void:
	panel.get_node("%" + name).pressed.emit()
	var end := Time.get_ticks_msec() + 10000
	while panel.busy and Time.get_ticks_msec() < end:
		await process_frame
	_check(not panel.busy and not panel.token.is_empty(), name + " · " + str(panel.get_node("%Message").text))

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Register")
	if failed:
		quit(1)
		return
	var ident: String = panel.robots[0].id
	panel.get_node("%RobotName").text = "实验黄铜机"
	await _press("Rename")
	panel.get_node("%Kind").select(2)
	await _press("Assign")
	_check(panel.robots[0].task == "aid" and panel.get_node("%Assign").disabled, "援助占用")
	var assignment: String = panel.robots[0].assignment
	panel.get_node("%Back").pressed.emit()
	await scene_changed
	current_scene.get_node("HUD").get_node("%Profile").pressed.emit()
	await scene_changed
	panel = current_scene
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Login")
	if failed:
		quit(1)
		return
	_check(panel.robots[0].id == ident and panel.robots[0].name == "实验黄铜机" and panel.robots[0].assignment == assignment, "重新进入后档案一致")
	await _press("Cancel")
	_check(panel.robots[0].task == null and not panel.get_node("%Assign").disabled, "取消后可出发")
	if not failed:
		print("PROFILE_UI_PASS range/register/rename/aid/reenter/login/cancel")
	quit(1 if failed else 0)
