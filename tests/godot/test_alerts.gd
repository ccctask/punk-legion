extends "res://qa/support.gd"

const ALERT_SCENE := "res://camp/defense_alerts.tscn"
var entered: Array[String] = []

func trace_event(event: String, fields: Dictionary = {}) -> void:
	var row := fields.duplicate()
	row.event = event
	row.frame = Engine.get_process_frames()
	print("ALERT_GUI ", JSON.stringify(row))
	var path := OS.get_environment("PILOT_ALERT_EVENTS")
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()

func before_each() -> void:
	entered.clear()

func make_alerts():
	var panel = add_panel(ALERT_SCENE)
	panel.set_screen(true, "", "") # Empty endpoint prevents network; rows are current UI input fixture.
	panel._show_rows([{"node": "brass-yard", "name": "黄铜转运场", "battle": "fresh-gui-a"}])
	return panel

func dispatch_pointer(viewport: Viewport, at: Vector2, label: String) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for down: bool in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		input.position = at
		input.global_position = at
		input.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		trace_event("pointer", {"label": label, "down": down, "x": at.x, "y": at.y})
		viewport.push_input(input, true)
		await wait_idle_frames(2)

func pointer_button(panel, id: String) -> void:
	await wait_idle_frames(2)
	var button: Button = panel.buttons[id]
	assert_true(button.is_visible_in_tree(), "Real alert row is visible")
	var rect := button.get_global_rect()
	assert_gt(rect.size.x, 0.0)
	assert_gt(rect.size.y, 0.0)
	trace_event("target", {"node": id, "instance": button.get_instance_id(), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	# Cache only values and the surviving viewport. Production may free button during release.
	await dispatch_pointer(panel.get_viewport(), rect.get_center(), id)

func hide_in_enter(panel, id: String) -> void:
	entered.append(id)
	trace_event("enter", {"node": id, "count": entered.size()})
	panel.hide()
	panel.set_screen(false, "", "")
	trace_event("sync_screen_hidden", {"rows": panel.buttons.size(), "screen_visible": panel.screen_visible})

func test_real_pointer_synchronous_screen_hide_and_stale_location() -> void:
	var panel = make_alerts()
	panel.enter.connect(func(id: String): hide_in_enter(panel, id))
	await wait_idle_frames(2)
	var at: Vector2 = panel.buttons["brass-yard"].get_global_rect().get_center()
	await pointer_button(panel, "brass-yard")
	assert_eq(entered, ["brass-yard"], "Exactly one correct camp enters during real release")
	assert_false(panel.screen_visible)
	assert_false(panel.visible)
	assert_true(panel.buttons.is_empty())
	await dispatch_pointer(panel.get_viewport(), at, "retired-location")
	assert_eq(entered.size(), 1, "Retired location cannot enter again")

func test_real_pointer_same_frame_clear_rebuild_same_node_once() -> void:
	var panel = make_alerts()
	panel.enter.connect(func(id: String):
		hide_in_enter(panel, id)
		if entered.size() == 1:
			panel.set_screen(true, "", "")
			panel._show_rows([{"node": "brass-yard", "name": "黄铜新警报", "battle": "fresh-gui-b"}])
			trace_event("same_frame_rebuilt", {"nodes": panel.buttons.keys()})
	)
	await pointer_button(panel, "brass-yard")
	assert_eq(entered, ["brass-yard"])
	assert_true(panel.buttons.has("brass-yard"))
	await pointer_button(panel, "brass-yard")
	assert_eq(entered, ["brass-yard", "brass-yard"], "New alert with same ID enters only on its own pointer input")
	assert_true(panel.buttons.is_empty())

func test_real_pointer_locked_background_then_foreground_navigation() -> void:
	var panel = make_alerts()
	panel.enter.connect(func(id: String): hide_in_enter(panel, id))
	panel.set_locked(true)
	await pointer_button(panel, "brass-yard")
	assert_eq(entered.size(), 0, "Locked actual button rejects input")
	panel.set_locked(false)
	panel.background = true
	await pointer_button(panel, "brass-yard")
	assert_eq(entered.size(), 0, "Background guard rejects actual GUI navigation")
	panel.background = false
	await pointer_button(panel, "brass-yard")
	assert_eq(entered, ["brass-yard"], "Foreground unlocked input enters once")
