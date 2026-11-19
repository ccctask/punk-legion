extends SceneTree
## Run two copies against a fresh local test room (see CLIENT.md).

var room: Node
var view: Node3D
var seat := 0
var deadline := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	deadline = Time.get_ticks_msec() + 30000
	room = root.get_node("Room")
	if change_scene_to_file("res://client/range.tscn") != OK:
		_fail("load range")
		return
	await scene_changed
	view = current_scene
	while room.positions.size() != 2 or view.views.size() != 2:
		if _expired("waiting for both robot views"):
			return
		await process_frame
	seat = room.local_seat
	var goals := {1: Vector2(-3.0, 1.0), 2: Vector2(3.0, -1.0)}
	var point: Vector2 = goals[seat]
	var camera: Camera3D = view.get_node("Camera3D")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(Vector3(point.x, 0.0, point.y))
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	while not _views_match(goals):
		if _expired("two destination positions"):
			return
		await process_frame
	if seat == 1:
		view.get_node("HUD/%Leave").pressed.emit()
		if room.local_seat != 0 or not view.views.is_empty():
			_fail("disconnect clears views")
			return
		await create_timer(0.4).timeout
		view.get_node("HUD/%Join").pressed.emit()
		while room.local_seat != seat or not _views_match(goals):
			if _expired("recover original seat and two views"):
				return
			await process_frame
	else:
		await create_timer(1.5).timeout
	var capture_dir := OS.get_environment("CLIENT_CAPTURE_DIR")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		if capture.save_png(capture_dir.path_join("seat-%d.png" % seat)) != OK:
			_fail("save viewport image")
			return
	print("CLIENT_SMOKE_PASS seat=", seat, " positions=", room.positions)
	quit()


func _views_match(goals: Dictionary) -> bool:
	if view.views.size() != 2:
		return false
	for id: int in goals:
		if not view.views.has(id):
			return false
		var pos: Vector3 = view.views[id].position
		if Vector2(pos.x, pos.z).distance_to(goals[id]) > 0.09:
			return false
	return true


func _expired(condition: String) -> bool:
	if Time.get_ticks_msec() < deadline:
		return false
	_fail(condition)
	return true


func _fail(condition: String) -> void:
	push_error("CLIENT_SMOKE_FAIL %s seat=%s" % [condition, seat])
	quit(1)
