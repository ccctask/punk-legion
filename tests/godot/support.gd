extends GutTest

func negative(group: String) -> bool:
	return OS.get_environment("PILOT_NEGATIVE_GROUP") == group

func click(button: BaseButton) -> void:
	assert_true(button.is_visible_in_tree(), "Target is a real visible scene control")
	assert_false(button.disabled, "Target is enabled before pointer input")
	await wait_idle_frames(2)
	var button_name := button.name
	var button_rect := button.get_global_rect()
	var at := button_rect.get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	button.get_viewport().push_input(move, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.get_viewport().push_input(event, true)
		await wait_idle_frames(2)
	print("PILOT_POINTER target=", button_name, " rect=", button_rect, " point=", at)

func fixture_events() -> Array:
	var path := OS.get_environment("PILOT_HTTP_EVENTS")
	if not FileAccess.file_exists(path): return []
	var rows: Array = []
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary: rows.append(parsed)
	return rows

func has_http_event(robot: String, event: String, status: int = -1) -> bool:
	for row: Dictionary in fixture_events():
		if row.get("robot") == robot and row.get("event") == event and (status < 0 or row.get("status") == status):
			return true
	return false

func add_panel(path: String):
	var panel = load(path).instantiate()
	var host := SubViewport.new()
	host.size = Vector2i(960, 540)
	host.disable_3d = true
	host.handle_input_locally = true
	add_child_autofree(host)
	host.add_child(panel)
	if panel.anchor_left == panel.anchor_right and panel.anchor_top == panel.anchor_bottom:
		panel.set_deferred("size", Vector2(850, 500))
	return panel
