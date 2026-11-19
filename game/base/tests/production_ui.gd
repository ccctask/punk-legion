extends "res://profile/tests/profile_ui.gd"

func _idle(node: Node) -> void:
	var end := Time.get_ticks_msec() + 9000
	while node.busy and Time.get_ticks_msec() < end:
		await process_frame
	_check(not node.busy, "请求超时")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text = OS.get_environment("PRODUCTION_DEMO_NAME")
	panel.get_node("%Password").text = OS.get_environment("PRODUCTION_DEMO_PASS")
	await _press("Login")
	if failed:
		quit(1)
		return
	panel.get_node("%Base").pressed.emit()
	var base := panel.get_node("PrivateBase")
	await _idle(base)
	base.get_node("%EconomyToggle").pressed.emit()
	await _idle(base)
	var econ := base.get_node("%Economy")
	_check(econ.visible and not econ.get_node("%Claim").disabled, "生产面板领取状态")
	econ.get_node("%Claim").pressed.emit()
	await _idle(base)
	_check(econ.get_node("%Claim").disabled and base.get_node("%Hint").text.contains("已入库"), "领取回执")
	econ.get_node("%Study").pressed.emit()
	await _idle(base)
	_check("drill" in econ.state.tech and econ.get_node("%Study").disabled, "钻头研究")
	base.get_node("%Back").pressed.emit()
	await process_frame
	panel.get_node("%Owned").pressed.emit()
	var workshop := panel.get_node("Workshop")
	await _idle(workshop)
	workshop.get_node("%Name").text = "能源钻工"
	workshop.get_node("%Weapon").select(1)
	workshop.get_node("%Weapon").item_selected.emit(1)
	workshop.get_node("%Save").pressed.emit()
	await _idle(workshop)
	workshop.get_node("%BuildName").text = "钻台01"
	workshop.get_node("%Build").pressed.emit()
	await _idle(workshop)
	var produced := false
	for robot in workshop.data.robots:
		if robot.name == "钻台01" and robot.slots.weapon.definition == "drill":
			produced = true
	_check(produced, "档案工坊实际制造研究后的钻头机体")
	if not failed:
		print("PRODUCTION_UI_PASS base/claim/research/owned_workshop/drill_robot")
	quit(1 if failed else 0)
