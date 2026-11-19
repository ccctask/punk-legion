extends Node

signal status_changed(message: String)
signal exercise_move_result(id: String, attempt: int, accepted: bool, reason: String)
signal exercise_changed
signal state_changed

const DEFAULT_PORT := 24567
const PROTOCOL_VERSION := 3
const ResultOutbox := preload("res://net/result_outbox.gd")
const Exercise := preload("res://net/exercise.gd")
const GRACE_MS := 30000
const SPEED := 3.0
const SNAPSHOT_INTERVAL := 0.1
const MIN_POSITION := Vector2(-5.0, -3.0)
const MAX_POSITION := Vector2(5.0, 3.0)

class Seat:
	var peer_id: int
	var token: String
	var position: Vector2
	var target: Vector2
	var expires_at_ms: int
	var last_command: int

var pending_ticket := ""
var _seat_tickets := {}
var _resolving := false
var _settlement_recorded := false
var _outbox: ResultOutbox
var exercise_state := {}
var _exercise := Exercise.new()
var _ack := {}
var _battle_sequence := 0
var _latest_move_attempt := 0
var _move_rejection_until := 0
var local_seat := 0
var positions: Dictionary[int, Vector2] = {}
var _seats: Dictionary[int, Seat] = {}
var _token := ""
var _endpoint := ""
var _sequence := 0
var _snapshot_elapsed := 0.0
var _transport: ENetMultiplayerPeer
var _server := false

func exercise_seat_identity() -> String:
	return _token.sha256_text()

func is_server_mode() -> bool:
	return _server

func _ready() -> void:
	_server = "--server" in OS.get_cmdline_user_args()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_physics_process(_server)
	if _server:
		_outbox = ResultOutbox.new()
		add_child(_outbox)
		# All game messages flow through the server. Peer-to-peer relaying
		# also sends peer-list updates to clients that may be closing.
		(multiplayer as SceneMultiplayer).server_relay = false
		var port_text := OS.get_environment("ROOM_PORT")
		var port := DEFAULT_PORT if port_text.is_empty() else port_text.to_int()
		_transport = ENetMultiplayerPeer.new()
		var err := _transport.create_server(port, 8)
		if err != OK:
			push_error("room listen failed: %s" % error_string(err))
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = _transport
		print("ROOM_READY udp=", port, " protocol=", PROTOCOL_VERSION)

func connect_room(host: String, port: int = DEFAULT_PORT) -> Error:
	if _server or host.strip_edges().is_empty() or port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	disconnect_room()
	var endpoint := "%s:%s" % [host.strip_edges(), port]
	if endpoint != _endpoint:
		_token = ""
	_endpoint = endpoint
	_transport = ENetMultiplayerPeer.new()
	var err := _transport.create_client(host.strip_edges(), port)
	if err != OK:
		_transport = null
		status_changed.emit("连接失败 · %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = _transport
	status_changed.emit("连接中")
	return OK

func disconnect_room() -> void:
	if _server:
		return
	_reset_client()
	status_changed.emit("已断开")

func leave_room() -> void:
	if local_seat > 0 and _transport != null:
		_leave.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable", 0)
func _leave() -> void:
	if not _server:
		return
	var peer := multiplayer.get_remote_sender_id()
	for index in _seats:
		if _seats[index].peer_id == peer:
			_release_seat(index)
			_left.rpc_id(peer)
			print("ROOM_RELEASE seat=", index)
			return

@rpc("authority", "call_remote", "reliable", 0)
func _left() -> void:
	_token = ""
	_reset_client()
	status_changed.emit("已退出房间")

func _reset_client() -> void:
	if _transport != null:
		_transport.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_transport = null
	local_seat = 0
	exercise_state.clear()
	clear_movement_feedback()
	positions.clear()
	state_changed.emit()

func _on_connected() -> void:
	_join.rpc_id(1, PROTOCOL_VERSION, _token)

func _on_connection_failed() -> void:
	_reset_client()
	status_changed.emit("连接失败")

func _on_server_disconnected() -> void:
	_reset_client()
	status_changed.emit("服务器已断开")

@rpc("any_peer", "call_remote", "reliable", 0)
func _join(version: int, token: String) -> void:
	if not _server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if version != PROTOCOL_VERSION or token.length() > 64:
		_denied.rpc_id(peer, "房间版本不兼容")
		return
	_remove_expired()
	for index in _seats:
		var existing := _seats[index]
		if existing.peer_id == peer:
			return
	if not token.is_empty():
		for index in _seats:
			var existing := _seats[index]
			if existing.token == token:
				var previous := existing.peer_id
				if previous > 0:
					_transport.disconnect_peer(previous)
				_assign(index, existing, peer)
				return
		_denied.rpc_id(peer, "席位已过期，请重新加入")
		return
	for index in range(1, 3):
		if not _seats.has(index):
			var seat := Seat.new()
			seat.token = Crypto.new().generate_random_bytes(24).hex_encode()
			seat.position = Vector2(-2 if index == 1 else 2, 0)
			seat.target = seat.position
			_seats[index] = seat
			_assign(index, seat, peer)
			return
	_denied.rpc_id(peer, "房间席位已满")

func _assign(index: int, seat: Seat, peer: int) -> void:
	seat.peer_id = peer
	seat.expires_at_ms = 0
	seat.last_command = 0
	seat.target = seat.position
	_admitted.rpc_id(peer, index, seat.token, _snapshot())
	_send_exercise(index)
	print("ROOM_JOIN seat=", index, " peer=", peer, " position=", seat.position)

@rpc("authority", "call_remote", "reliable", 0)
func _denied(reason: String) -> void:
	_token = ""
	_reset_client()
	status_changed.emit(reason)

@rpc("authority", "call_remote", "reliable", 0)
func _admitted(index: int, token: String, snapshot: Dictionary) -> void:
	local_seat = index
	_token = token
	_sequence = 0
	positions.assign(snapshot)
	status_changed.emit("已连接 · %s 号席位" % index)
	state_changed.emit()

func move_to(target: Vector2) -> void:
	if local_seat == 0 or _transport == null or not target.is_finite():
		return
	_sequence += 1
	_move.rpc_id(1, _sequence, target)

@rpc("any_peer", "call_remote", "reliable", 0)
func _move(sequence: int, target: Vector2) -> void:
	if not _server or not target.is_finite():
		return
	var peer := multiplayer.get_remote_sender_id()
	for index in _seats:
		var seat := _seats[index]
		if seat.peer_id == peer and sequence > seat.last_command:
			seat.last_command = sequence
			seat.target = target.clamp(MIN_POSITION, MAX_POSITION)
			print("ROOM_MOVE seat=", index, " seq=", sequence, " target=", seat.target)
			return

func _on_peer_disconnected(peer: int) -> void:
	if not _server:
		return
	for index in _seats:
		var seat := _seats[index]
		if seat.peer_id == peer:
			seat.peer_id = 0
			if _exercise.id.is_empty():
				_exercise.ready.erase(index)
				_broadcast_exercise()
			seat.target = seat.position
			seat.expires_at_ms = Time.get_ticks_msec() + GRACE_MS
			print("ROOM_LEAVE seat=", index)
			return

func _remove_expired() -> void:
	var now := Time.get_ticks_msec()
	for index in _seats.keys():
		var seat := _seats[int(index)]
		if seat.peer_id == 0 and seat.expires_at_ms <= now:
			_release_seat(index)

func _snapshot() -> Dictionary:
	var snapshot := {}
	for index in _seats:
		snapshot[index] = _seats[index].position
	return snapshot

func _physics_process(delta: float) -> void:
	_remove_expired()
	_exercise.step(delta)
	if not _exercise.sim.result.is_empty() and not _settlement_recorded:
		_refresh_exercise()
	for seat in _seats.values():
		seat.position = seat.position.move_toward(seat.target, SPEED * delta)
	_snapshot_elapsed += delta
	if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
		_snapshot_elapsed = fmod(_snapshot_elapsed, SNAPSHOT_INTERVAL)
		var snapshot := _snapshot()
		var stream := PackedByteArray()
		var decoded_size := 0
		if not _exercise.id.is_empty() and _exercise.sim.result.is_empty():
			var raw := var_to_bytes(_exercise.snapshot(false))
			decoded_size = raw.size()
			stream = raw.compress(FileAccess.COMPRESSION_ZSTD)
		for seat in _seats.values():
			if seat.peer_id > 0:
				_update.rpc_id(seat.peer_id, snapshot)
				if not stream.is_empty():
					_exercise_stream.rpc_id(seat.peer_id, stream, decoded_size)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _update(snapshot: Dictionary) -> void:
	if local_seat > 0:
		positions.assign(snapshot)
		state_changed.emit()

func set_exercise_ready(value: bool) -> void:
	if local_seat > 0:
		_ready_for_exercise.rpc_id(1, value, pending_ticket if value else "")

func send_exercise_order(action: String, ids: Array, dest := Vector2.ZERO, enemy := "") -> int:
	clear_movement_feedback()
	if local_seat > 0 and not str(exercise_state.get("id", "")).is_empty():
		_battle_sequence += 1
		_latest_move_attempt = _battle_sequence if action == "move" else 0
		_order.rpc_id(1, exercise_state.id, _battle_sequence, action, ids, dest, enemy)
		return _battle_sequence
	return 0

func acknowledge_exercise() -> void:
	if local_seat > 0:
		_acknowledge.rpc_id(1, str(exercise_state.get("id", "")))

func _sender_seat() -> int:
	var peer := multiplayer.get_remote_sender_id()
	for seat in _seats:
		if _seats[seat].peer_id == peer:
			return seat
	return 0

@rpc("any_peer", "call_remote", "reliable", 0)
func _ready_for_exercise(value: bool, ticket: String) -> void:
	if not _server or _resolving or not _exercise.id.is_empty():
		return
	var seat := _sender_seat()
	if seat == 0 or ticket.length() > 128:
		return
	_seat_tickets.erase(seat)
	if value and not ticket.is_empty():
		_seat_tickets[seat] = ticket
	if value:
		_exercise.ready[seat] = true
	else:
		_exercise.ready.erase(seat)
	_broadcast_exercise()
	if _exercise.ready.size() == 2:
		_start_ready_battle()

func _start_ready_battle() -> void:
	var tickets := {}
	for seat in _seat_tickets:
		if str(_seat_tickets[seat]).begins_with("owned_"):
			tickets[str(seat)] = _seat_tickets[seat]
	var snapshots := {}
	var battle_id := ""
	if not tickets.is_empty():
		_resolving = true
		var result := await _load_deployments(tickets)
		_resolving = false
		if _exercise.ready.size() < 2:
			return
		snapshots = result.get("snapshots",{})
		battle_id = str(result.get("battle",""))
		if snapshots.size() != tickets.size() or battle_id.is_empty():
			_exercise.ready.clear()
			for seat in _seats.values():
				if seat.peer_id:
					_deploy_failed.rpc_id(seat.peer_id)
			_broadcast_exercise()
			return
	if _exercise.start(snapshots,battle_id):
		print("EXERCISE_START id=", _exercise.id, " owned=", snapshots.size())
	_broadcast_exercise()

func _load_deployments(tickets: Dictionary) -> Dictionary:
	if _outbox.endpoint.is_empty() or not FileAccess.file_exists(_outbox.key_file):
		return {}
	var fetch := HTTPRequest.new()
	add_child(fetch)
	fetch.timeout = 5.0
	var secret := FileAccess.get_file_as_string(_outbox.key_file).strip_edges()
	var url := _outbox.endpoint.get_base_dir() + "/deploy"
	var headers := ["Authorization: Bearer " + secret, "Content-Type: application/json"]
	var response := {}
	if fetch.request(url,headers,HTTPClient.METHOD_POST,JSON.stringify({"tickets":tickets})) == OK:
		var result: Array = await fetch.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			var parsed: Variant = JSON.parse_string(result[3].get_string_from_utf8())
			if parsed is Dictionary:
				response = parsed
	fetch.queue_free()
	return response

@rpc("authority", "call_remote", "reliable", 0)
func _deploy_failed() -> void:
	status_changed.emit("机体入场券无法核实，请检查档案服务或更新入场券后准备")

@rpc("any_peer", "call_remote", "reliable", 0)
func _order(id: String, sequence: int, action: String, ids: Array, dest: Vector2, enemy: String) -> void:
	if _server:
		var seat := _sender_seat()
		var accepted := _exercise.order(seat, id, sequence, action, ids, dest, enemy)
		if action == "move" and (accepted or _exercise.last_move_rejection == "no_space"):
			_exercise_move_result.rpc_id(multiplayer.get_remote_sender_id(),id,sequence,accepted,"" if accepted else "no_space")

func clear_movement_feedback() -> void:
	_latest_move_attempt = 0
	_move_rejection_until = 0

func _process(_delta: float) -> void:
	if not _server and _move_rejection_until > 0 and (Time.get_ticks_msec() >= _move_rejection_until or local_seat <= 0 or not exercise_state.get("result",{}).is_empty()):
		clear_movement_feedback()
		exercise_changed.emit()

func movement_feedback() -> String:
	if local_seat <= 0 or not exercise_state.get("result",{}).is_empty() or Time.get_ticks_msec() >= _move_rejection_until:
		_move_rejection_until = 0
	return "附近无法容纳当前队形，请换个落点" if _move_rejection_until > 0 else ""

@rpc("authority", "call_remote", "reliable", 0)
func _exercise_move_result(id: String, attempt: int, accepted: bool, reason: String) -> void:
	if local_seat <= 0 or exercise_state.get("id","") != id or not exercise_state.get("result",{}).is_empty() or attempt != _latest_move_attempt or attempt != _battle_sequence:
		return
	if not accepted and reason != "no_space":
		return
	_latest_move_attempt = 0
	_move_rejection_until = 0 if accepted else Time.get_ticks_msec() + 3000
	exercise_move_result.emit(id,attempt,accepted,reason)
	exercise_changed.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _acknowledge(id: String) -> void:
	var seat := _sender_seat()
	if not _server or seat == 0 or id != _exercise.id or _exercise.sim.result.is_empty():
		return
	_ack[seat] = true
	_refresh_exercise()

func _release_seat(seat: int) -> void:
	_seats.erase(seat)
	if _exercise.id.is_empty():
		_seat_tickets.erase(seat)
		_exercise.ready.erase(seat)
	else:
		if _exercise.sim.result.is_empty():
			_exercise.sim.retreat()
			_exercise.tick += 1
		_ack[seat] = true
	_refresh_exercise()

func _refresh_exercise() -> void:
	if not _exercise.sim.result.is_empty() and not _settlement_recorded:
		if _exercise.finished_at == 0:
			_exercise.finished_at = int(Time.get_unix_time_from_system())
		if not _outbox.enqueue(_exercise.id, _seat_tickets, _exercise.sim.result.winner, _exercise.service_reports(), _exercise.finished_at):
			return
		_settlement_recorded = true
	if _ack.size() == 2:
		_settlement_recorded = false
		_seat_tickets.clear()
		_ack.clear()
		_exercise = Exercise.new()
	_broadcast_exercise()

func _broadcast_exercise() -> void:
	for seat in _seats:
		_send_exercise(seat)

func _send_exercise(seat: int) -> void:
	var peer := _seats[seat].peer_id
	if peer == 0 or (not _exercise.sim.result.is_empty() and not _settlement_recorded):
		return
	if _ack.has(seat):
		_exercise_full.rpc_id(peer, {"id":"", "ready":{}, "waiting":true})
	else:
		_exercise_full.rpc_id(peer, _exercise.snapshot(true))

@rpc("authority", "call_remote", "reliable", 0)
func _exercise_full(state: Dictionary) -> void:
	if local_seat <= 0:
		return
	if state.get("id","") != exercise_state.get("id","") or not state.get("result",{}).is_empty():
		_latest_move_attempt = 0
		_move_rejection_until = 0
	exercise_state = state
	if not str(state.get("id", "")).is_empty():
		pending_ticket = ""
	_battle_sequence = maxi(_battle_sequence, int(state.get("seq", {}).get(local_seat, 0)))
	exercise_changed.emit()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _exercise_stream(packet: PackedByteArray, decoded_size: int) -> void:
	if decoded_size < 1 or decoded_size > 32768:
		return
	var state: Dictionary = bytes_to_var(packet.decompress(decoded_size, FileAccess.COMPRESSION_ZSTD))
	if local_seat <= 0 or state.id != exercise_state.get("id", "") or state.tick <= exercise_state.get("tick", 0) or not exercise_state.get("result", {}).is_empty():
		return
	exercise_state.merge(state, true)
	exercise_changed.emit()
func reconnect_room() -> Error:
	if _endpoint.is_empty():
		return ERR_UNCONFIGURED
	var split := _endpoint.rfind(":")
	return connect_room(_endpoint.left(split), _endpoint.substr(split + 1).to_int())
