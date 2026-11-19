extends "res://net/solo.gd"

const Contest := preload("res://net/camp_mission.gd")
const RESULT_REASONS := ["core","retreat","surrender","eliminated","expired","disconnected","timeout"]

func _ready() -> void:
	server="--camp-server" in OS.get_cmdline_user_args()
	get_tree().set_multiplayer(api,get_path())
	api.server_relay=false
	api.connected_to_server.connect(func(): _join.rpc_id(1,credentials.id,credentials.secret))
	api.connection_failed.connect(_lost)
	api.server_disconnected.connect(_lost)
	api.peer_disconnected.connect(_peer_left)
	set_physics_process(server)
	if not server:
		return
	directory=OS.get_environment("CAMP_SAVE_DIR")
	if directory.is_empty():
		directory=ProjectSettings.globalize_path("user://camp")
	DirAccess.make_dir_recursive_absolute(directory)
	peer=ENetMultiplayerPeer.new()
	var port:=OS.get_environment("CAMP_PORT").to_int()
	if peer.create_server(port if port>0 else 24570,64)!=OK:
		push_error("Camp listen failed")
		get_tree().quit(1)
		return
	api.multiplayer_peer=peer
	var ids := {}
	for name in DirAccess.get_files_at(directory):
		for suffix in [".save",".result.json",".progress.json"]:
			if name.ends_with(suffix):
				ids[name.trim_suffix(suffix)] = true
	for id: String in ids:
		var result := _saved_result(id)
		if not result.is_empty():
			orphan_results[id] = result
		else:
			_restore_checkpoint(id)
	print("CAMP_READY port=",port if port>0 else 24570)

func _saved_result(id: String) -> Dictionary:
	var path := directory.path_join(id+".result.json")
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	var result: Variant = json.data.get("result")
	if not result is Dictionary or result.get("id") != id or result.get("winner") not in ["attacker","defender","draw"]:
		return {}
	if result.size() != 6 or result.get("reason") not in RESULT_REASONS or not result.get("reports") is Dictionary:
		return {}
	for events in result.reports.values():
		if not events is Array:
			return {}
	if typeof(result.get("seconds")) not in [TYPE_INT,TYPE_FLOAT] or result.seconds < 0 or result.seconds > Contest.ROUND_SECONDS + 1:
		return {}
	if typeof(result.get("finished_at")) not in [TYPE_INT,TYPE_FLOAT] or result.finished_at <= 0 or result.finished_at != floor(result.finished_at) or json.data.get("finished_at") != result.finished_at:
		return {}
	return result

func _has_saved_result(id: String) -> bool:
	return orphan_results.has(id)

func _restore_checkpoint(id: String) -> bool:
	var path := directory.path_join(id+".save")
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() < 8 or file.get_32() != file.get_length()-4:
		return false
	file.seek(0)
	var saved: Variant = file.get_var()
	file.close()
	if not saved is Dictionary or saved.get("mission") != id or not _checkpoint_fields_valid(saved):
		return false
	var m := Contest.new()
	if not m.restore(saved):
		return false
	sessions[id] = m
	m.recover_clock(saved.saved_at,Time.get_unix_time_from_system())
	_save(m)
	return true

func _checkpoint_fields_valid(saved: Dictionary) -> bool:
	if not saved.has_all(["deployment","expires","units","timeline","elapsed","repairs","stage","outcome","seq","nodes","finished_at","saved_at","round_deadline","lost_attack_at","reason","orders","charges","progress"]):
		return false
	if not saved.deployment is Dictionary or not saved.units is Dictionary or not saved.timeline is Array or not saved.nodes is Array:
		return false
	var squads: Dictionary = saved.deployment
	if not squads.get("turrets") is Array or not squads.get("neutral") is bool:
		return false
	for side in ["attacker","defender"]:
		var squad: Variant = squads.get(side)
		if not squad is Dictionary or not squad.get("units") is Array or not squad.get("inventory") is Dictionary:
			return false
	for unit in saved.units.values():
		if not unit is Dictionary or not unit.has_all(["pos","hp","kills","assists","damage","received_repair"]):
			return false
	for key in ["orders","charges","progress"]:
		if not saved[key] is Array or saved[key].size() != 2:
			return false
	for key in ["finished_at","expires","elapsed","saved_at","round_deadline","lost_attack_at","seq","stage","repairs"]:
		if typeof(saved[key]) not in [TYPE_INT,TYPE_FLOAT]:
			return false
	if saved.outcome == "":
		return saved.finished_at == 0 and saved.reason == ""
	return saved.outcome in ["attacker","defender","draw"] and saved.reason in RESULT_REASONS and saved.finished_at > 0 and saved.finished_at <= saved.expires

func _service_prefix() -> String:
	return "/internal/camp/"

func _lost() -> void:
	_clear_move_feedback()
	if seat_state in ["displaced","rejected","settled"]:
		return
	seat_state="offline"
	message="营地连接中断，可重新进入原场次"
	changed.emit()

@rpc("authority","call_remote","reliable")
func _award(result: Dictionary) -> void:
	seat_state="settled"
	super._award(result)

@rpc("any_peer","call_remote","reliable")
func _join(id: String, secret: String) -> void:
	var from:=api.get_remote_sender_id()
	if not server or id.length()!=32 or not id.is_valid_hex_number() or secret.length()!=43 or pending_auth.has(from) or players.has(from):
		return
	pending_auth[from]=true
	var reply:=await _service("open",{"id":id,"secret":secret})
	if not pending_auth.erase(from) or from not in api.get_peers():
		return
	if reply.has("receipt"):
		_award.rpc_id(from,reply.receipt)
		return
	if not reply.has("squads"):
		_issue.rpc_id(from,"营地入场失败 · "+str(reply.get("error","请刷新后重试")))
		return
	var role: String=reply.role
	if orphan_results.has(id):
		players[from]=[id,role]
		return
	var stamp:=Time.get_unix_time_from_system()
	var m: Contest=sessions.get(id)
	if not sessions.has(id):
		m=Contest.new()
		if FileAccess.file_exists(directory.path_join(id+".save")) or FileAccess.file_exists(directory.path_join(id+".result.json")) or FileAccess.file_exists(directory.path_join(id+".progress.json")) or not m.create(id,reply.squads,int(reply.expires)):
			_issue.rpc_id(from,"无法读取或保存此场营地战")
			return
		m.lose_attacker(stamp)
	if not m.principals.has(role):
		_issue.rpc_id(from,"此角色没有本场指挥席")
		return
	var previous_deadline:=m.lost_attack_at
	m.authenticate(role,stamp)
	if not _save(m):
		m.lost_attack_at=previous_deadline
		_issue.rpc_id(from,"无法保存此场营地战")
		return
	sessions[id]=m
	for old in players.keys():
		if players[old]==[id,role]:
			players.erase(old)
			if old in api.get_peers():
				_issue.rpc_id(old,"指挥权已转至另一窗口")
	players[from]=[id,role]
	_full.rpc_id(from,m.personalized(role))

func _peer_left(person: int) -> void:
	pending_auth.erase(person)
	if players.has(person):
		var seat: Array=players[person]
		players.erase(person)
		if sessions.has(seat[0]) and seat[1]=="attacker" and not players.values().has(seat):
			var m: Contest=sessions[seat[0]]
			m.lose_attacker(Time.get_unix_time_from_system())
			_save(m)

@rpc("any_peer","call_remote","reliable")
func _order(id: String, number: int, action: String, selected: Array, target: String, pos: Vector2) -> void:
	var from:=api.get_remote_sender_id()
	if not server or not players.has(from) or players[from][0]!=id or not sessions.has(id):
		return
	var m: Contest=sessions[id]
	var role: String=players[from][1]
	if m.command(role,number,action,selected,target,pos):
		if _save(m):
			_full.rpc_id(from,m.personalized(role))
	elif action == "move" and m.last_move_rejection == "no_space":
		_move_rejected.rpc_id(from,id,number,"no_space")

@rpc("authority","call_remote","unreliable_ordered")
func _camp_delta(id: String, elapsed: float, progress: Vector2, repairs: int, acked: int, rows: PackedFloat32Array) -> void:
	if seat_state!="active" or state.is_empty() or state.id!=id or elapsed<state.elapsed or not state.outcome.is_empty():
		return
	var stride:=rows.size()/maxi(1,state.units.size())
	if stride not in [9,10,12]:return
	if rows.size()!=state.units.size()*stride:
		return
	state.elapsed=elapsed
	state.progress=[progress.x,progress.y]
	state.repairs=repairs
	if acked >= _move_attempt:
		_clear_move_feedback()
	state.seq=maxi(int(state.seq),acked)
	var i:=0
	for unit in state.units.values():
		unit.pos=Vector2(rows[i],rows[i+1])
		unit.hp=rows[i+2]
		unit.heading=Vector2(rows[i+3],rows[i+4])
		unit.walking=rows[i+5]>0
		unit.shot=rows[i+6]
		unit.impact=Vector2(rows[i+7],rows[i+8])
		if stride>=10:unit.service=rows[i+9]
		if stride==12:
			unit.protected_until=rows[i+10]
			unit.last_jam=rows[i+11]
		i+=stride
	changed.emit()

func _physics_process(delta: float) -> void:
	sync_time+=delta
	save_time+=delta
	resettle+=delta
	for id in sessions.keys():
		var m: Contest=sessions[id]
		if m.sim.blast_checkpoint_due and (save_time < 1 or not _save(m)):
			continue
		m.step(delta)
		var final:=not m.outcome.is_empty()
		if final and not orphan_results.has(id):
			if not _save(m):
				continue
			orphan_results[id]=m.settlement()
		elif not final and (save_time>=1 or m.sim.blast_checkpoint_due):
			if not _save(m):
				continue
		if sync_time>=0.2 or final and resettle>=1:
			var rows:=PackedFloat32Array()
			if not final:
				for u in m.sim.units.values():
					rows.append_array(PackedFloat32Array([u.pos.x,u.pos.y,u.hp,u.last_heading.x,u.last_heading.y,
						float(u.walking),u.last_shot,u.impact_point.x,u.impact_point.y,u.last_service]))
					if m.sim.has_jammer:rows.append_array(PackedFloat32Array([u.protected_until,u.last_jam]))
			for person in players:
				if players[person][0]==id and person in api.get_peers():
					var role: String=players[person][1]
					if final:
						_full.rpc_id(person,m.personalized(role))
					else:
						var side:=int(m.principals[role])
						_camp_delta.rpc_id(person,m.mission,m.sim.elapsed,Vector2(m.progress[0],m.progress[1]),m.charges[side],m._sequence_for(role),rows)
	if resettle>=1:
		for id in orphan_results.keys():
			if not settling.has(id):
				_deliver_disk(id)
		resettle=0
	if save_time>=1:
		save_time=0
	if sync_time>=0.2:
		sync_time=0

func _deliver_disk(id: String) -> void:
	settling[id]=true
	var response:=await _service("settle",orphan_results[id])
	settling.erase(id)
	if not response.has("receipt"):
		var error: String = str(response.get("error",""))
		if error in ["result_conflict","report_conflict","report_identity","unknown_contest","contest_not_live","qualification_expired","ownership_changed","unknown_battle_admission"] or error.begins_with("invalid_"):
			# Keep the original files for the profile's normal expiry path. A
			# permanent rejection must not post the same result every second.
			orphan_results.erase(id)
			# Some report validation requires the profile's tickets. A rejected disk
			# result can still have an independent, usable same-contest checkpoint.
			var restored := error.begins_with("invalid_") and not sessions.has(id) and _restore_checkpoint(id)
			if not restored:
				sessions.erase(id)
			for person in players.keys():
				if players[person][0]==id:
					players.erase(person)
					if person in api.get_peers():
						var note := "营地已从检查点恢复，请重新入场" if restored else "档案已拒绝该战报，请返回营地刷新"
						_issue.rpc_id(person,note)
		return
	for person in players.keys():
		if players[person][0]==id:
			if person in api.get_peers():
				_award.rpc_id(person,response.receipt)
			players.erase(person)
	sessions.erase(id)
	orphan_results.erase(id)
	for suffix in [".save",".progress.json",".result.json"]:
		DirAccess.remove_absolute(directory.path_join(id+suffix))
