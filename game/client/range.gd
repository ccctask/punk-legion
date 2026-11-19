extends Node3D

const UNIT_SCENE := preload("res://client/unit_view.tscn")
const Endpoints := preload("res://client/endpoints.gd")
const Sortie := preload("res://loadout/sortie.gd")
const LIMIT := Vector2(5.0, 3.0)

@onready var camera: Camera3D = $Camera3D
@onready var units: Node3D = $Units
@onready var host_input: LineEdit = $HUD.get_node("%HostInput")
@onready var status_label: Label = $HUD.get_node("%StatusLabel")
@onready var seat_label: Label = $HUD.get_node("%SeatLabel")
@onready var join_button: Button = $HUD.get_node("%Join")
@onready var leave_button: Button = $HUD.get_node("%Leave")
@onready var target_marker: Node3D = $TargetMarker

var views: Dictionary = {}
var marker_age := 0.0
var destination_scene := ""
var entering_exercise := false


func _ready() -> void:
	if Room.is_server_mode():
		$HUD.hide()
		set_process(false)
		set_process_unhandled_input(false)
		return
	if get_tree().has_meta("base_first_path"):
		$HUD.get_node("%Home").show()
		$HUD.get_node("%Home").pressed.connect(_open_scene.bind("res://beta/entry.tscn"))
	Room.state_changed.connect(_sync_room)
	Room.status_changed.connect(_set_status)
	Room.exercise_changed.connect(_sync_exercise)
	$HUD.get_node("%Exercise").pressed.connect(_toggle_ready)
	join_button.pressed.connect(_connect_room)
	leave_button.pressed.connect(Room.disconnect_room)
	$HUD.get_node("%Workshop").pressed.connect(_open_scene.bind(Sortie.WORKSHOP))
	$HUD.get_node("%Profile").pressed.connect(_open_scene.bind("res://profile/profile.tscn"))
	host_input.text_submitted.connect(func(_address: String) -> void: _connect_room())
	host_input.text = Endpoints.room_host()
	_sync_room()
	if Room.local_seat > 0:
		_set_status("已连接")
	elif OS.get_name() == "Android" and Endpoints.development():
		host_input.placeholder_text = "电脑局域网 IP"
		_set_status("模拟器用 10.0.2.2，真机填写电脑局域网 IP")
	else:
		_connect_room()


func _connect_room() -> void:
	var host := host_input.text.strip_edges()
	if host.is_empty():
		_set_status(Endpoints.issue("room"))
		return
	host_input.release_focus()
	var address := Endpoints.transport("room","",host)
	if address.is_empty():
		_set_status(Endpoints.issue("room"))
		return
	Endpoints.remember("room",host)
	var result: Error = Room.connect_room(address.host,address.port)
	if result != OK:
		_set_status(error_string(result))


func _open_scene(path: String) -> void:
	if not destination_scene.is_empty() or entering_exercise:
		return
	destination_scene = path
	if Room.local_seat > 0:
		join_button.disabled = true
		leave_button.disabled = true
		$HUD.get_node("%Workshop").disabled = true
		$HUD.get_node("%Profile").disabled = true
		_set_status("正在退出房间")
		Room.leave_room()
	else:
		Room.disconnect_room()
	# _sync_room handles the acknowledged leave or offline reset.


func _set_status(message: String) -> void:
	status_label.text = message


func _sync_room() -> void:
	_sync_exercise()
	var current: int = Room.local_seat
	if not destination_scene.is_empty():
		if current == 0:
			get_tree().call_deferred("change_scene_to_file", destination_scene)
		return
	seat_label.text = "机组 %02d" % current if current > 0 else "等待分配"
	join_button.disabled = current > 0
	host_input.editable = current == 0 and Endpoints.development()
	if current == 0:
		target_marker.hide()
	for id: Variant in views.keys():
		if not Room.positions.has(id) or current == 0:
			views[id].queue_free()
			views.erase(id)
	if current == 0:
		return
	for id: Variant in Room.positions:
		if not views.has(id):
			var unit := UNIT_SCENE.instantiate()
			units.add_child(unit)
			views[id] = unit
			unit.configure(int(id), int(id) == current, Room.positions[id])
		else:
			views[id].set_destination(Room.positions[id])


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or Room.local_seat <= 0:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(click.position), camera.project_ray_normal(click.position))
	if point == null:
		return
	var destination := Vector2(point.x, point.z)
	if absf(destination.x) > LIMIT.x or absf(destination.y) > LIMIT.y:
		return
	Room.move_to(destination)
	target_marker.position = Vector3(destination.x, 0.045, destination.y)
	target_marker.show()
	marker_age = 0.0
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if target_marker.visible:
		marker_age += delta
		target_marker.scale = Vector3.ONE * (1.0 + marker_age * 0.3)
		if marker_age > 0.85:
			target_marker.hide()


func _toggle_ready() -> void:
	Room.set_exercise_ready(not Room.exercise_state.get("ready", {}).has(Room.local_seat))

func _sync_exercise() -> void:
	var state := Room.exercise_state
	var ready: Dictionary = state.get("ready", {})
	var button: Button = $HUD.get_node("%Exercise")
	button.disabled = Room.local_seat == 0 or state.get("waiting", false)
	button.text = ("取消准备" if ready.has(Room.local_seat) else "双人演习 · 准备") + "  %d/2" % ready.size()
	if state.get("waiting", false):
		button.text = "等待队友返回"
	if destination_scene.is_empty() and not entering_exercise and Room.local_seat > 0 and not str(state.get("id", "")).is_empty():
		entering_exercise = true
		get_tree().call_deferred("change_scene_to_file", "res://client/exercise.tscn")
