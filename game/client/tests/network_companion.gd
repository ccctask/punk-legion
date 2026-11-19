extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room := root.get_node("Room")
	room.connect_room("127.0.0.1",OS.get_environment("ROOM_PORT").to_int())
	while room.local_seat == 0:
		await process_frame
	print("COMPANION seat=",room.local_seat)
	room.set_exercise_ready(true)
	while room.exercise_state.get("result",{}).is_empty():
		await process_frame
	room.leave_room()
	while room.local_seat > 0:
		await process_frame
	quit()
