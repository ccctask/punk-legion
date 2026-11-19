extends Node

const TIMEOUT_MS := 20000
var phase := "joining"
var deadline: int
var original_seat := 0
var goal: Vector2
var host: String
var port: int
var expect_full := false

func _ready() -> void:
	host = OS.get_environment("ROOM_TEST_HOST")
	port = OS.get_environment("ROOM_TEST_PORT").to_int()
	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	expect_full = "--expect-full" in OS.get_cmdline_user_args()
	Room.status_changed.connect(_on_status)
	Room.connect_room(host, port)

func _on_status(message: String) -> void:
	print("PROBE ", message)
	if expect_full and message == "房间席位已满":
		print("PROBE_FULL_REJECTED")
		get_tree().quit()
	if phase == "leaving" and message == "已退出房间":
		print("PROBE_RELEASED seat=", original_seat)
		get_tree().quit()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("Probe timed out in %s, seat=%s positions=%s" % [phase, original_seat, Room.positions])
		get_tree().quit(1)
		return
	if Room.local_seat == 0:
		return
	if expect_full:
		push_error("Third client unexpectedly admitted")
		get_tree().quit(1)
		return
	if phase == "joining" and Room.positions.size() == 2:
		original_seat = Room.local_seat
		print("PROBE_BOTH_PRESENT seat=", original_seat)
		phase = "capacity"
	elif phase == "capacity" and FileAccess.file_exists(OS.get_environment("ROOM_TEST_GATE")):
		goal = Vector2(-5, 1) if original_seat == 1 else Vector2(5, -1)
		Room.move_to(Vector2(goal.x * 3, goal.y))
		phase = "moving"
	elif phase == "moving" and _at(1, Vector2(-5, 1)) and _at(2, Vector2(5, -1)):
		if original_seat == 1:
			phase = "reconnecting"
			Room.disconnect_room()
			_reconnect.call_deferred()
		else:
			phase = "watch"
	elif phase == "reconnecting":
		if Room.local_seat != original_seat or not _at(1, goal):
			push_error("Seat or position lost during reconnect")
			get_tree().quit(1)
			return
		print("PROBE_RESUMED ", Room.local_seat)
		Room.move_to(Vector2(-3, 2))
		phase = "watch"
	elif phase == "watch" and _at(1, Vector2(-3, 2)) and _at(2, Vector2(5, -1)):
		print("PROBE_PASS seat=", original_seat, " positions=", Room.positions)
		var observed := FileAccess.open(OS.get_environment("ROOM_TEST_GATE") + str(original_seat), FileAccess.WRITE)
		observed.close()
		phase = "observed"
	elif phase == "observed" and FileAccess.file_exists(OS.get_environment("ROOM_TEST_GATE") + str(3 - original_seat)):
		phase = "leaving"
		Room.leave_room()

func _reconnect() -> void:
	await get_tree().create_timer(0.5).timeout
	Room.connect_room(host, port)

func _at(seat: int, target: Vector2) -> bool:
	return Room.positions.has(seat) and Room.positions[seat].distance_to(target) < 0.01
