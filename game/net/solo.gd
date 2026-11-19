extends Node

signal changed
const Mission := preload("res://net/solo_mission.gd")
const Armory := preload("res://net/armory_mission.gd")
const PORT := 24568
var seat_state := "offline"
var state := {}
var receipt := {}
var message := ""
var server := false
var api := SceneMultiplayer.new()
var peer: ENetMultiplayerPeer
var credentials := {}
var sessions := {}
var offline_expiries := {}
var orphan_results := {}
var players := {}
var pending_auth := {}
var settling := {}
var seq := 0
var _move_attempt := 0
var _move_rejection := ""
var _move_rejection_until := 0
var sync_time := 0.0
var save_time := 0.0
var resettle := 0.0
var directory := ""
# Solo-only orchestration. Shared persistence and derived room contracts stay below.
var _solo_unsaved := {}
var _solo_retry_at := {}
var _solo_parked := {}
var _solo_admissions := {}
var _solo_auth_requests := {}
var _solo_inflight := {}
var _solo_generations := {}
var _solo_completed := {}
var _solo_cleanup := {}
var _solo_serial := 0

func _ready() -> void:
	server = "--solo-server" in OS.get_cmdline_user_args()
	get_tree().set_multiplayer(api,get_path())
	api.server_relay = false
	api.connected_to_server.connect(func(): _join.rpc_id(1,credentials.get("id",""),credentials.get("secret","")))
	api.connection_failed.connect(_lost)
	api.server_disconnected.connect(_lost)
	api.peer_disconnected.connect(_peer_left)
	set_physics_process(server)
	if not server:
		return
	directory = OS.get_environment("SOLO_SAVE_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("user://solo")
	DirAccess.make_dir_recursive_absolute(directory)
	peer = ENetMultiplayerPeer.new()
	var port := OS.get_environment("SOLO_PORT").to_int()
	var err := peer.create_server(port if port > 0 else PORT,64)
	if err != OK:
		push_error("Expedition ENet listen failed")
		get_tree().quit(1)
		return
	api.multiplayer_peer = peer
	_solo_restore_directory()
	print("SOLO_READY port=",port if port > 0 else PORT)

func connect_mission(host: String, port: int, admission: Dictionary) -> void:
	disconnect_mission()
	seat_state = "connecting"
	credentials = admission.duplicate(true)
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(host,port)
	if err != OK:
		_lost()
		return
	api.multiplayer_peer = peer
	message = "正在连接探索区域"
	changed.emit()

func disconnect_mission() -> void:
	if server:
		return
	if peer != null:
		peer.close()
	api.multiplayer_peer = null
	peer = null
	seat_state = "offline"
	state.clear()
	receipt.clear()
	credentials.clear()
	_clear_move_feedback()

func _lost() -> void:
	_clear_move_feedback()
	if seat_state in ["rejected","displaced","settled"]:
		return
	seat_state = "offline"
	message = "已离线 · 可重连原场"
	changed.emit()

func _peer_left(id: int) -> void:
	pending_auth.erase(id)
	_solo_auth_requests.erase(id)
	if players.has(id):
		var mission_id: String = players[id]
		_solo_forget_admission(mission_id,id)
		if not _solo_terminal_gate(mission_id) and sessions.has(mission_id) and not _solo_unsaved.has(mission_id):
			_solo_commit(sessions[mission_id])
		players.erase(id)

func authorized() -> bool:
	return seat_state=="active" and peer!=null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED and not state.is_empty() and state.id==credentials.get("id","") and receipt.is_empty()

func can_command(action: String) -> bool:
	return authorized() and str(state.outcome).is_empty() and not state.get("withdrawn",false) and (action=="retreat" or state.get("assembly",{}).get("phase","")!="assembling")

func command(action: String, selected: Array, target := "", pos := Vector2.ZERO) -> void:
	var had_feedback := _move_rejection_until > 0
	_clear_move_feedback()
	if had_feedback:
		changed.emit()
	if not can_command(action):
		return
	seq = maxi(seq,int(state.seq)) + 1
	_move_attempt = seq if action in ["move","route"] else 0
	_order.rpc_id(1,str(state.id),seq,action,selected,target,pos)

func _clear_move_feedback() -> void:
	_move_attempt = 0
	_move_rejection = ""
	_move_rejection_until = 0

func movement_feedback() -> String:
	if not can_command("move") or (_move_rejection_until > 0 and Time.get_ticks_msec() >= _move_rejection_until):
		_clear_move_feedback()
	return "附近无法容纳当前队形，请换个落点" if _move_rejection == "no_space" else ""

@rpc("authority","call_remote","reliable")
func _move_rejected(id: String, attempt: int, reason: String) -> void:
	if not can_command("move") or state.id != id or attempt != _move_attempt or attempt != seq or int(state.seq) >= attempt or reason != "no_space" or _move_rejection_until > 0:
		return
	_move_rejection = reason
	_move_rejection_until = Time.get_ticks_msec() + 3000
	changed.emit()

func _process(_delta: float) -> void:
	if not server and _move_rejection_until > 0 and (Time.get_ticks_msec() >= _move_rejection_until or not can_command("move")):
		_clear_move_feedback()
		changed.emit()

func _service_prefix() -> String:
	return "/internal/expedition/"

func _service(route: String, body: Dictionary) -> Dictionary:
	var key_file := OS.get_environment("ROOM_AUTH_FILE")
	if key_file.is_empty() or not FileAccess.file_exists(key_file):
		return {}
	var url := OS.get_environment("SOLO_PROFILE_URL").trim_suffix("/")
	var http := HTTPRequest.new()
	http.timeout = 5
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+FileAccess.get_file_as_string(key_file).strip_edges()])
	var err := http.request(url+_service_prefix()+route,headers,HTTPClient.METHOD_POST,JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {}
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Dictionary else {}

@rpc("any_peer","call_remote","reliable")
func _join(id: String, secret: String) -> void:
	var from := _solo_sender()
	if not server or id.length() != 32 or not id.is_valid_hex_number() or secret.length() != 43 or pending_auth.has(from) or players.has(from):
		return
	var request := _solo_begin_request(id)
	var generation := _solo_generation(id)
	_solo_auth_requests[from] = request
	pending_auth[from] = true
	var answer := await _service("open",{"id":id,"secret":secret})
	_solo_join_answer(from,id,secret,request,generation,answer)
	_solo_end_request(request)

func _solo_join_answer(from: int, id: String, secret: String, request: int, generation: int, answer: Dictionary) -> void:
	if _solo_auth_requests.get(from) != request:
		return
	_solo_auth_requests.erase(from)
	pending_auth.erase(from)
	if not _solo_peers().has(from):
		return
	if answer.has("receipt"):
		if _solo_valid_receipt(id,answer.receipt):
			_solo_finish(id,answer.receipt)
			_solo_award(from,answer.receipt)
		else:
			_solo_issue(from,"任务回执暂不可用，请重连")
		return
	if not answer.get("deployment") is Dictionary or not _solo_number(answer.get("expires")):
		_solo_issue(from,"任务暂不可用，请刷新档案或重连")
		return
	if _solo_completed.has(id):
		_solo_award(from,_solo_completed[id])
		return
	# An old deployment response can authenticate a peer, but cannot resurrect play.
	if generation != _solo_generation(id) and not _solo_terminal_gate(id):
		_solo_issue(from,"任务状态已变化，请重连查看")
		return
	_solo_bind(id,from,request,secret)
	if _solo_terminal_gate(id):
		if _solo_parked.get(id) == "result_conflict":
			_solo_recover_receipt(id)
		elif _solo_parked.has(id):
			_solo_release_for_reconnect(id,"战果文件暂不可用，请稍后重连")
		elif not settling.has(id):
			_deliver_disk(id)
		return
	if not sessions.has(id):
		var mission := _load(id)
		if mission == null:
			if FileAccess.file_exists(directory.path_join(id+".save")):
				_solo_release_for_reconnect(id,"任务存档暂时无法读取")
				return
			var location: Variant="old_armory" if answer.deployment.get("location")=="old_armory" or answer.get("location")=="old_armory" else answer.deployment.get("location",answer.get("location",""))
			mission = _new_solo_mission(location)
			if not mission.create(id,answer.deployment,int(answer.expires)):
				_solo_release_for_reconnect(id,"无法建立任务存档")
				return
		sessions[id] = mission
	offline_expiries.erase(id)
	var current: Mission = sessions[id]
	if _solo_unsaved.has(id):
		return
	_solo_expire(current)
	if _solo_commit(current):
		_solo_publish(current)

@rpc("any_peer","call_remote","reliable")
func _order(id: String, number: int, action: String, selected: Array, target: String, pos: Vector2) -> void:
	var from := _solo_sender()
	if not server or players.get(from,"") != id or not sessions.has(id):
		return
	if _solo_terminal_gate(id) or _solo_unsaved.has(id):
		return
	var mission: Mission = sessions[id]
	if not mission.outcome.is_empty():
		return
	if _solo_expire(mission):
		_solo_commit(mission)
		return
	var before := mission.stage
	if mission.order(number,action,selected,target,pos):
		if not _solo_commit(mission):
			return
		if before != mission.stage:
			_solo_full(from,mission)
		else:
			_solo_ack(from,id,number,mission.last_notice)
	elif action in ["move","route"] and mission.last_move_rejection == "no_space":
		_move_rejected.rpc_id(from,id,number,"no_space")

func _has_saved_result(id: String) -> bool:
	return FileAccess.file_exists(directory.path_join(id+".result.json"))

func _save(mission: Mission) -> bool:
	if not mission.outcome.is_empty() and mission.finished_at == 0:
		mission.finished_at = int(Time.get_unix_time_from_system())
	var trusted := mission.settlement()
	var suffix := ".progress.json" if mission.outcome.is_empty() else ".result.json"
	var evidence := directory.path_join(mission.mission+suffix)
	if mission.outcome.is_empty() or not _has_saved_result(mission.mission):
		var evidence_file := FileAccess.open(evidence+".tmp",FileAccess.WRITE)
		if evidence_file == null:
			return false
		var contents := trusted if mission.outcome.is_empty() else {"result":trusted,"finished_at":mission.finished_at}
		evidence_file.store_string(JSON.stringify(contents))
		evidence_file.flush()
		var written := evidence_file.get_error() == OK
		evidence_file.close()
		if not written or DirAccess.rename_absolute(evidence+".tmp",evidence) != OK:
			return false
	var path := directory.path_join(mission.mission+".save")
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(mission.checkpoint())
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(path+".tmp",path) != OK:
		return false
	mission.sim.blast_checkpoint_due = false
	return true

func _new_solo_mission(location: Variant = "") -> Mission:
	if location=="old_armory":return Armory.new()
	var model:=Mission.new()
	# The actual standard factory branch also covers ordinary deployments without a location field.
	model.configure_safe_turning(location in ["","rustrail"])
	model.configure_light_inertia(location in ["","rustrail"])
	return model

func _load(id: String) -> Mission:
	var path := directory.path_join(id+".save")
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return null
	var saved: Variant = file.get_var()
	file.close()
	if not saved is Dictionary:
		return null
	var deployment: Variant=saved.get("deployment",{})
	if not deployment is Dictionary:return null
	var mission: Mission = _new_solo_mission(saved.get("location",deployment.get("location","")))
	if not mission.restore(saved):
		return null
	var terminal := _terminal(id)
	if not terminal.is_empty():
		mission.outcome = terminal.result.outcome
		mission.finished_at = int(terminal.finished_at)
	return mission

func _terminal(id: String) -> Dictionary:
	var path := directory.path_join(id+".result.json")
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _physics_process(delta: float) -> void:
	sync_time += delta
	save_time += delta
	resettle += delta
	for player in players.keys():
		if not _solo_peers().has(player):
			continue
		var id: String = players[player]
		if _solo_terminal_gate(id) or _solo_unsaved.has(id) or not sessions.has(id):
			continue
		var mission: Mission = sessions[id]
		if not mission.outcome.is_empty():
			continue
		if mission.sim.blast_checkpoint_due and (save_time < 1 or not _solo_commit(mission)):
			continue
		var previous := mission.objective_revision()
		if not _solo_expire(mission):
			mission.step(delta)
		if save_time >= 1 or previous != mission.objective_revision() or not mission.outcome.is_empty() or mission.sim.blast_checkpoint_due:
			if not _solo_commit(mission):
				continue
		if previous != mission.objective_revision():
			_solo_full(player,mission)
		elif sync_time >= 0.12:
			_send_delta(player,mission)
	if sync_time >= 0.12:
		sync_time = 0
	if save_time >= 1:
		save_time = 0
	if resettle >= 1:
		resettle = 0
		var now := int(Time.get_unix_time_from_system())
		for id in offline_expiries.keys():
			if _solo_terminal_gate(id) or sessions.has(id):
				offline_expiries.erase(id)
				continue
			if now >= int(offline_expiries[id]):
				var resumed := _load(id)
				if resumed != null:
					sessions[id] = resumed
				offline_expiries.erase(id)
		for id in sessions.keys():
			if _solo_terminal_gate(id):
				continue
			var mission: Mission = sessions[id]
			_solo_expire(mission)
			var recovering := _solo_unsaved.has(id)
			if recovering or not mission.outcome.is_empty() or id not in players.values():
				if not _solo_commit(mission):
					continue
				if recovering:
					_solo_publish(mission)
				if id not in players.values():
					offline_expiries[id] = mission.expires
					sessions.erase(id)
		for id in orphan_results.keys():
			if not settling.has(id) and not _solo_parked.has(id):
				_deliver_disk(id)
		for id in _solo_cleanup.keys():
			_solo_clean_files(id)

func _deliver(mission: Mission) -> void:
	_deliver_disk(mission.mission)

func _deliver_disk(id: String) -> void:
	if settling.has(id) or _solo_parked.has(id) or _solo_completed.has(id):
		return
	var terminal := _solo_read_terminal(id)
	if terminal.is_empty():
		if _solo_parked.has(id):
			_solo_release_for_reconnect(id,"战果文件暂不可用，请稍后重连")
		return
	var generation := _solo_generation(id)
	var request := _solo_begin_request(id)
	settling[id] = request
	var response := await _service("settle",terminal.result)
	if generation == _solo_generation(id) and settling.get(id) == request:
		settling.erase(id)
		if _solo_valid_receipt(id,response.get("receipt")):
			_solo_finish(id,response.receipt)
		elif response.get("error") == "result_conflict":
			_solo_parked[id] = "result_conflict"
			_solo_recover_receipt(id)
	_solo_end_request(request)

func _solo_sender() -> int:
	return api.get_remote_sender_id()

func _solo_peers() -> PackedInt32Array:
	return api.get_peers()

func _solo_generation(id: String) -> int:
	return _solo_generations.get(id,0)

func _solo_begin_request(id: String) -> int:
	_solo_serial += 1
	_solo_inflight[_solo_serial] = id
	return _solo_serial

func _solo_end_request(request: int) -> void:
	var id: String = _solo_inflight.get(request,"")
	_solo_inflight.erase(request)
	if not id.is_empty():
		_solo_collect(id)

func _solo_collect(id: String) -> void:
	# Tombstones live exactly as long as their task, cleanup or late responses.
	if id in _solo_inflight.values() or _solo_cleanup.has(id) or sessions.has(id) or orphan_results.has(id) or offline_expiries.has(id):
		return
	if id in players.values() or _solo_admissions.has(id) or _solo_unsaved.has(id) or _solo_parked.has(id):
		return
	_solo_completed.erase(id)
	_solo_generations.erase(id)

func _solo_advance(id: String) -> void:
	_solo_serial += 1
	_solo_generations[id] = _solo_serial

func _solo_result_present(id: String) -> bool:
	var path := directory.path_join(id+".result.json")
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

func _solo_terminal_gate(id: String) -> bool:
	if _solo_completed.has(id):
		return true
	if orphan_results.has(id):
		return true
	if not _solo_result_present(id):
		return false
	# Once evidence exists, no call to shared _load may merge it into an old save.
	orphan_results[id] = true
	sessions.erase(id)
	offline_expiries.erase(id)
	_solo_unsaved.erase(id)
	_solo_retry_at.erase(id)
	_solo_advance(id)
	return true

func _solo_restore_directory() -> void:
	var ids := {}
	for name in DirAccess.get_files_at(directory):
		for suffix in [".save",".result.json"]:
			if name.ends_with(suffix):
				ids[name.trim_suffix(suffix)] = true
	# A directory occupying the final-result path is also an unreadable barrier.
	for name in DirAccess.get_directories_at(directory):
		if name.ends_with(".result.json"):
			ids[name.trim_suffix(".result.json")] = true
	for id: String in ids:
		if _solo_terminal_gate(id):
			_solo_read_terminal(id)
			continue
		var saved := _load(id)
		if saved == null:
			continue
		if not saved.outcome.is_empty():
			sessions[id] = saved
			_solo_unsaved[id] = true
		else:
			offline_expiries[id] = saved.expires

func _solo_expire(mission: Mission) -> bool:
	if mission.outcome.is_empty() and Time.get_unix_time_from_system() >= mission.expires:
		mission.outcome = "expired"
	return not mission.outcome.is_empty()

func _solo_commit(mission: Mission) -> bool:
	var id := mission.mission
	if _solo_terminal_gate(id):
		return false
	if _solo_unsaved.has(id) and Time.get_ticks_msec() < int(_solo_retry_at.get(id,0)):
		return false
	var ok := _save(mission)
	if not mission.outcome.is_empty():
		if ok:
			# Only this complete, current checkpoint may publish a terminal frame.
			_solo_publish(mission)
		if _solo_terminal_gate(id):
			return false
	if not ok:
		if not _solo_unsaved.has(id):
			print("SOLO_SAVE_WAIT mission=",id)
		_solo_unsaved[id] = true
		_solo_retry_at[id] = Time.get_ticks_msec() + 1000
		return false
	_solo_unsaved.erase(id)
	_solo_retry_at.erase(id)
	return true

func _solo_publish(mission: Mission) -> void:
	for person in players.keys():
		if players[person] == mission.mission and _solo_peers().has(person):
			_solo_full(person,mission)

func _solo_full(person: int, mission: Mission) -> void:
	_full.rpc_id(person,mission.view())

func _solo_ack(person: int, id: String, number: int, note: String) -> void:
	_ack.rpc_id(person,id,number,note)

func _solo_award(person: int, result: Dictionary) -> void:
	_award.rpc_id(person,result)

func _solo_issue(person: int, note: String) -> void:
	_issue.rpc_id(person,note)

func _solo_bind(id: String, person: int, request: int, secret: String) -> void:
	for old in players.keys():
		if players[old] == id and old != person:
			players.erase(old)
			if _solo_peers().has(old):
				_solo_issue(old,"该任务已在另一个窗口接管")
	_solo_admissions.erase(id)
	players[person] = id
	_solo_admissions[id] = {"peer":person,"request":request,"secret":secret}

func _solo_forget_admission(id: String, person: int) -> void:
	if _solo_admissions.get(id,{}).get("peer") == person:
		_solo_admissions.erase(id)

func _solo_release_for_reconnect(id: String, note: String) -> void:
	for person in players.keys():
		if players[person] == id:
			if _solo_peers().has(person):
				_solo_issue(person,note)
			players.erase(person)
	_solo_admissions.erase(id)

func _solo_recover_receipt(id: String) -> void:
	if settling.has(id) or not _solo_admissions.has(id):
		return
	var admission: Dictionary = _solo_admissions[id]
	var person: int = admission.peer
	if not _solo_peers().has(person) or players.get(person) != id:
		_solo_admissions.erase(id)
		return
	var generation := _solo_generation(id)
	var admission_request: int = admission.request
	var request := _solo_begin_request(id)
	settling[id] = request
	var answer := await _service("open",{"id":id,"secret":admission.secret})
	# Do not retain a second credential reference while interpreting the response.
	admission = {}
	if generation == _solo_generation(id) and settling.get(id) == request:
		settling.erase(id)
		if _solo_valid_receipt(id,answer.get("receipt")):
			_solo_finish(id,answer.receipt)
		# A late failure belongs to its old admission, not a replacement seat.
		elif _solo_admissions.get(id,{}).get("request") == admission_request:
			_solo_release_for_reconnect(id,"战果正在核对，请重连原场查看")
		elif _solo_admissions.has(id):
			# A replacement admission gets its own single recovery attempt.
			_solo_recover_receipt(id)
	_solo_end_request(request)

func _solo_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func _solo_read_terminal(id: String) -> Dictionary:
	var path := directory.path_join(id+".result.json")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		_solo_parked[id] = "unreadable_result"
		return {}
	var text := file.get_as_text()
	var error := file.get_error()
	file.close()
	var json := JSON.new()
	if error not in [OK,ERR_FILE_EOF] or json.parse(text) != OK or not json.data is Dictionary:
		_solo_parked[id] = "invalid_result"
		return {}
	var record: Dictionary = json.data
	var result: Variant = record.get("result")
	if not _solo_number(record.get("finished_at")) or record.finished_at <= 0 or record.finished_at != floor(record.finished_at):
		_solo_parked[id] = "invalid_result"
		return {}
	if not result is Dictionary or result.get("id") != id or result.get("outcome") not in ["win","retreat","defeat","expired"]:
		_solo_parked[id] = "invalid_result"
		return {}
	if not result.get("nodes") is Array or not result.get("reports") is Dictionary or not result.get("commanded") is bool or not _solo_number(result.get("seconds")):
		_solo_parked[id] = "invalid_result"
		return {}
	if result.seconds < 0 or result.seconds > Mission.CLOCK_LIMIT or (result.has("cause") and not result.cause is String):
		_solo_parked[id] = "invalid_result"
		return {}
	for events in result.reports.values():
		if not events is Array:
			_solo_parked[id] = "invalid_result"
			return {}
	return record

func _solo_valid_receipt(id: String, value: Variant) -> bool:
	return value is Dictionary and value.get("mission") == id and value.get("id") is String and not value.id.is_empty() and value.get("operation") in ["expedition_result","armory_result"]

func _solo_finish(id: String, result: Dictionary) -> void:
	if not _solo_valid_receipt(id,result) or _solo_completed.has(id):
		return
	_solo_completed[id] = result.duplicate(true)
	_solo_advance(id)
	settling.erase(id)
	for person in players.keys():
		if players[person] == id:
			if _solo_peers().has(person):
				_solo_award(person,result)
			players.erase(person)
	_solo_admissions.erase(id)
	sessions.erase(id)
	orphan_results.erase(id)
	offline_expiries.erase(id)
	_solo_unsaved.erase(id)
	_solo_retry_at.erase(id)
	_solo_parked.erase(id)
	# Terminal evidence is the restart barrier; it must be removed last.
	_solo_cleanup[id] = {"attempts":0,"remaining":[".save",".progress.json",".save.tmp",".progress.json.tmp",".result.json.tmp",".result.json"]}
	_solo_clean_files(id)

func _solo_clean_files(id: String) -> void:
	var work: Dictionary = _solo_cleanup[id]
	if work.attempts >= 3:
		return
	work.attempts += 1
	var remaining := []
	for suffix: String in work.remaining:
		if suffix == ".result.json" and not remaining.is_empty():
			remaining.append(suffix)
			continue
		var path := directory.path_join(id+suffix)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			if DirAccess.remove_absolute(path) != OK or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
				remaining.append(suffix)
	work.remaining = remaining
	if remaining.is_empty():
		_solo_cleanup.erase(id)
		_solo_collect(id)
	elif work.attempts == 3:
		print("SOLO_CLEANUP_WAIT mission=",id," remaining=",remaining)

func _exit_tree() -> void:
	_solo_admissions.clear()
	_solo_auth_requests.clear()
	_solo_inflight.clear()
	_solo_generations.clear()
	_solo_unsaved.clear()
	_solo_retry_at.clear()
	_solo_parked.clear()
	_solo_completed.clear()
	_solo_cleanup.clear()

func _send_delta(player: int, mission: Mission, cart: Dictionary = {}) -> void:
	var packed := PackedFloat32Array()
	for u in mission.sim.units.values():
		packed.append_array(PackedFloat32Array([u.pos.x,u.pos.y,u.hp,u.last_heading.x,u.last_heading.y,
			float(u.walking),u.last_shot,u.impact_point.x,u.impact_point.y,u.last_service]))
		if mission.sim.has_jammer:packed.append_array(PackedFloat32Array([u.protected_until,u.last_jam]))
	_delta.rpc_id(player,mission.mission,mission.stage,mission.sim.elapsed,mission.sim.repair_charges,mission.fighting,mission.marching,packed,cart)

@rpc("authority","call_remote","reliable")
func _issue(note: String) -> void:
	_clear_move_feedback()
	if seat_state not in ["connecting","active"]:
		return
	seat_state = "displaced" if seat_state=="active" else "rejected"
	message = note
	changed.emit()

@rpc("authority","call_remote","reliable")
func _award(result: Dictionary) -> void:
	_clear_move_feedback()
	if seat_state not in ["connecting","active","settled"]:
		return
	seat_state = "settled"
	receipt = result
	message = "探索结算已入账"
	changed.emit()

@rpc("authority","call_remote","reliable")
func _full(frame: Dictionary) -> void:
	_accept(frame)

@rpc("authority","call_remote","unreliable_ordered")
func _delta(id: String, stage: int, elapsed: float, repairs: int, fighting: float, marching: float, rows: PackedFloat32Array, cart: Dictionary = {}) -> void:
	if seat_state!="active" or state.is_empty() or state.id != id or state.stage != stage or elapsed < state.elapsed or not state.outcome.is_empty():
		return
	# The reliable start frame must arrive before movement advances this seat's clock.
	if state.get("assembly",{}).get("phase","")=="assembling":
		return
	var stride:=rows.size()/maxi(1,state.units.size())
	if stride not in [9,10,12]:return
	if rows.size() != state.units.size()*stride:
		return
	var i := 0
	for unit in state.units.values():
		unit.pos = Vector2(rows[i],rows[i+1])
		unit.hp = rows[i+2]
		unit.heading = Vector2(rows[i+3],rows[i+4])
		unit.walking = rows[i+5] > 0
		unit.shot = rows[i+6]
		unit.impact = Vector2(rows[i+7],rows[i+8])
		if stride>=10:unit.service=rows[i+9]
		if stride==12:
			unit.protected_until=rows[i+10]
			unit.last_jam=rows[i+11]
		i += stride
	state.elapsed = elapsed
	state.repairs = repairs
	state.fighting = fighting
	state.marching = marching
	if state.has("factory"):
		state.factory.merge(cart,true)
	changed.emit()

@rpc("authority","call_remote","reliable")
func _ack(id: String, number: int, notice: String) -> void:
	if seat_state=="active" and not state.is_empty() and state.id == id:
		if number >= _move_attempt:
			_clear_move_feedback()
		state.seq = maxi(int(state.seq),number)
		message = notice
		changed.emit()

func _accept(frame: Dictionary) -> void:
	if seat_state not in ["connecting","active"] or frame.get("id","") != credentials.get("id",""):
		return
	if not state.is_empty() and (frame.elapsed < state.elapsed or frame.seq < state.seq):
		return
	if state.get("id","") != frame.id or not str(frame.outcome).is_empty() or frame.get("withdrawn",false) or int(frame.seq) >= _move_attempt:
		_clear_move_feedback()
	seat_state = "active"
	state = frame
	message = str(frame.notice)
	changed.emit()
