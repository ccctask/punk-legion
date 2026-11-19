extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func fail(message:String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	change_scene_to_file("res://profile/profile.tscn")
	await scene_changed
	var panel:=current_scene
	panel.endpoint=OS.get_environment("PINS_URL")
	panel.token=OS.get_environment("PINS_TOKEN")
	panel.account_id=OS.get_environment("PINS_OWNER")
	panel._refresh_profile()
	await idle(panel)
	var ident:=OS.get_environment("PINS_ROBOT")
	var history:=panel.get_node("%History")
	if history.robot!=ident:
		fail("wrong initial selection")
		return
	# Enter the normal owned workshop from the profile.
	panel._owned_workshop(true)
	var hangar:Node
	for child in panel.get_children():
		if child is Node3D:hangar=child
	if not hangar:
		fail("workshop not opened")
		return
	await idle(hangar)
	hangar.get_node("%OnlyFavorites").button_pressed=true
	if hangar.get_node("%Robot").item_count!=1 or ident not in hangar.get_node("%Identity").text:
		fail("favorite filter did not resolve permanent robot")
		return
	hangar.get_node("%Back").pressed.emit()
	await idle(panel)
	print("PIN_UI_PASS")
	quit()

func idle(panel:Node) -> void:
	await process_frame
	while panel.busy:
		await process_frame
	await process_frame
