extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://profile/profile.tscn")
	await scene_changed
	var panel := current_scene
	panel.get_node("%Account").text = OS.get_environment("SERVICE_TEST_NAME")
	panel.get_node("%Password").text = OS.get_environment("SERVICE_TEST_PASS")
	panel.get_node("%Login").pressed.emit()
	await wait_response(panel)
	var recovery := panel.get_node("%Recovery")
	recovery.get_node("Open").pressed.emit()
	await wait_response(panel)
	var ok: bool = recovery.data.state == "damaged" and not recovery.get_node("Details/Actions/Repair").disabled
	recovery.get_node("Details/Actions/Recycle").pressed.emit()
	ok = ok and not recovery.get_node("Confirm").visible and recovery.get_node("Details/Actions/Recycle").disabled and "保留至少一台" in recovery.get_node("Details/Summary").text
	recovery.get_node("Confirm").hide()
	recovery.get_node("Details/Actions/Repair").pressed.emit()
	await wait_response(panel)
	ok = ok and recovery.data.state=="repairing" and panel.get_node("%Assign").disabled
	ok = ok and panel.get_node("%Cancel").disabled and "进入维修队列" in recovery.get_node("Details/Events").text
	print("RECOVERY_UI_PASS" if ok else "RECOVERY_UI_FAIL")
	quit(0 if ok else 1)

func wait_response(panel: Node) -> void:
	while panel.busy:
		await process_frame
