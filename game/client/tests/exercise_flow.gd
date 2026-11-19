extends SceneTree

const Exercise := preload("res://net/exercise.gd")
var deadline: int
var done := false

func _initialize() -> void:
	deadline = Time.get_ticks_msec() + 215000
	call_deferred("run")

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() > deadline:
		fail("timeout")
	return false

func fail(message: String) -> void:
	done = true
	push_error("EXERCISE_FAIL " + message)
	quit(1)

func click_world(scene: Node, point: Vector2, height: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene.get_node("Camera3D").unproject_position(Vector3(point.x, height, point.y))
	scene._unhandled_input(event)

func run() -> void:
	var rules := Exercise.new()
	rules.ready = {1:true, 2:true}
	if not rules.start():
		fail("fixture")
		return
	var ally := rules.sim.alive_ids(0)[0]
	var foreign := rules.sim.alive_ids(0)[1]
	var enemy := rules.sim.alive_ids(1)[0]
	if not rules.order(1, rules.id, 1, "focus", [ally], Vector2.ZERO, enemy):
		fail("valid focus")
		return
	if rules.order(1, rules.id, 1, "move", [ally], Vector2.ZERO, "") or rules.order(1, rules.id, 2, "move", [ally, foreign], Vector2.ZERO, "") or rules.sim.units[ally].target_id != enemy or rules.sim.units[foreign].movement_goal != rules.sim.UNSET:
		fail("ownership or replay validation")
		return
	var room := root.get_node("Room")
	change_scene_to_file("res://client/range.tscn")
	await scene_changed
	while room.local_seat == 0:
		await process_frame
	var seat: int = room.local_seat
	room.pending_ticket = OS.get_environment("ROOM_TEST_TICKET%d" % seat)
	current_scene.get_node("HUD").get_node("%Exercise").pressed.emit()
	await scene_changed
	var scene := current_scene
	var hud := scene.get_node("HUD")
	if scene.scene_file_path != "res://client/exercise.tscn" or scene.selected.size() != 6:
		fail("entry or default ownership")
		return
	var id: String = room.exercise_state.id
	hud.get_node("%All").pressed.emit()
	click_world(scene, Vector2(-4, seat * 3 - 4), 0)
	while room.exercise_state.get("seq", {}).get(seat, 0) < 1:
		await process_frame
	var unit_id: String = scene.selected[0]
	if room.exercise_state.units[unit_id][7] == Exercise.Simulation.UNSET:
		fail("movement goal absent")
		return
	for key: String in room.exercise_state.roster:
		if room.exercise_state.roster[key][0] == 0:
			click_world(scene, room.exercise_state.units[key][0], 0.68)
			break
	while room.exercise_state.get("seq", {}).get(seat, 0) < 2:
		await process_frame
	if room.exercise_state.units[unit_id][6] == "":
		fail("focus target absent")
		return
	if seat == 1:
		var before: int = room.exercise_state.tick
		hud.get_node("%Retreat").pressed.emit()
		await create_timer(1.2).timeout
		hud.get_node("%Retry").pressed.emit()
		while room.exercise_state.get("tick", 0) <= before:
			await process_frame
		if room.exercise_state.id != id or room.local_seat != seat or room.exercise_state.seq.get(seat, 0) != 2:
			fail("reconnected state")
			return
		print("EXERCISE_RESUMED ", id, " tick=", before, " -> ", room.exercise_state.tick)
	while not scene.finished:
		await process_frame
	var digest := JSON.stringify(room.exercise_state.result).sha256_text()
	if seat == 2:
		room.disconnect_room()
		await create_timer(0.4).timeout
		hud.get_node("%Retry").pressed.emit()
		while room.exercise_state.get("result", {}).is_empty():
			await process_frame
		if room.exercise_state.id != id or JSON.stringify(room.exercise_state.result).sha256_text() != digest:
			fail("retained result")
			return
	if not hud.get_node("%Workshop").is_visible_in_tree():
		fail("missing result button")
		return
	print("EXERCISE_RESULT ", id, " ", digest, " reason=", room.exercise_state.result.reason, " seat=", seat)
	hud.get_node("%Workshop").pressed.emit()
	await scene_changed
	if current_scene.scene_file_path != "res://client/range.tscn":
		fail("return to range")
		return
	room.leave_room()
	while room.local_seat > 0:
		await process_frame
	done = true
	quit()
