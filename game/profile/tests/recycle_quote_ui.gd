extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://profile/profile.tscn")
	await scene_changed
	var panel:=current_scene
	panel.get_node("%Account").text=OS.get_environment("SERVICE_TEST_NAME")
	panel.get_node("%Password").text=OS.get_environment("SERVICE_TEST_PASS")
	panel.get_node("%Login").pressed.emit()
	await wait_response(panel)
	var box:=panel.get_node("%Recovery")
	box.get_node("Open").pressed.emit()
	await wait_response(panel)
	var ok:=false
	match OS.get_environment("QUOTE_MODE"):
		"one":
			box.get_node("Details/Actions/Recycle").pressed.emit()
			ok=box.get_node("Details/Actions/Recycle").disabled and not box.get_node("Confirm").visible and "保留至少一台" in box.get_node("Details/Summary").text
		"two":
			box.get_node("Details/Actions/Recycle").pressed.emit()
			ok=box.get_node("Confirm").visible and "预计返还结构材料 1" in box.get_node("Confirm").dialog_text
			box.get_node("Confirm").confirmed.emit()
			await wait_response(panel)
			ok=ok and box.data.state=="retired" and box.get_node("Details/Actions/Recycle").disabled
		"timer":
			ok=box.data.state=="repairing" and panel.get_node("%Assign").disabled
			var deadline:=Time.get_ticks_msec()+10000
			while box.data.state=="repairing" and Time.get_ticks_msec()<deadline:
				await process_frame
			ok=ok and box.data.state=="ready" and not panel.get_node("%Assign").disabled and "维修中" not in panel.get_node("%Identity").text and "工坊维修完成" in box.get_node("Details/Events").text
	print("QUOTE_UI_",OS.get_environment("QUOTE_MODE"),"_", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func wait_response(panel:Node) -> void:
	while panel.busy:
		await process_frame
