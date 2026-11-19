extends "res://net/solo.gd"

const PartyMission := preload("res://net/party_mission.gd")
const PumpMission := preload("res://net/pump_mission.gd")
const FactoryMission := preload("res://net/factory_mission.gd")
const PARTY_PORT := 24569
var frozen_results := {}
var pending_checkpoint := {}

func _ready() -> void:
	server = "--party-server" in OS.get_cmdline_user_args()
	get_tree().set_multiplayer(api,get_path())
	api.server_relay = false
	api.connected_to_server.connect(func(): _join.rpc_id(1,credentials.get("id",""),credentials.get("secret","")))
	api.connection_failed.connect(_lost)
	api.server_disconnected.connect(_lost)
	api.peer_disconnected.connect(_peer_left)
	set_physics_process(server)
	if not server:
		return
	directory = OS.get_environment("PARTY_SAVE_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("user://party")
	DirAccess.make_dir_recursive_absolute(directory)
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(PARTY_PORT,64) != OK:
		push_error("Party listen failed")
		get_tree().quit(1)
		return
	api.multiplayer_peer = peer
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".save"):
			var mission := _read_party(file.trim_suffix(".save"))
			if mission != null:
				sessions[mission.mission] = mission
	print("PARTY_READY port=",PARTY_PORT)

func _service_prefix() -> String:
	return "/internal/party/"

func _new_party(activity: Variant) -> PartyMission:
	match activity:
		"pump_ruin": return PumpMission.new()
		"factory_escort": return FactoryMission.new()
	return PartyMission.new()

func _read_party(id: String) -> PartyMission:
	var f := FileAccess.open(directory.path_join(id+".save"),FileAccess.READ)
	if f == null:
		return null
	var data: Variant = f.get_var()
	if not data is Dictionary:
		return null
	var mission: PartyMission = _new_party(data.get("activity"))
	return mission if mission.restore_party(data) else null

func _persist(m: PartyMission) -> bool:
	if not m.outcome.is_empty() and m.finished_at==0:
		m.finished_at=int(Time.get_unix_time_from_system())
	var path := directory.path_join(m.mission+".save")
	var f := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(m.save_party())
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok or DirAccess.rename_absolute(path+".tmp",path) != OK:
		return false
	var terminal:=not m.outcome.is_empty()
	var suffix:=".result.json" if terminal else ".progress.json"
	var result_path := directory.path_join(m.mission+suffix)
	if terminal and FileAccess.file_exists(result_path):
		return true
	f=FileAccess.open(result_path+".tmp",FileAccess.WRITE)
	if f==null:
		return false
	f.store_string(JSON.stringify({"id":m.mission,"finished_at":m.finished_at,"results":m.results()}))
	f.flush()
	ok=f.get_error()==OK
	f.close()
	return ok and DirAccess.rename_absolute(result_path+".tmp",result_path)==OK

func _save_before_publish(m: PartyMission) -> bool:
	if not _persist(m):
		pending_checkpoint[m.mission] = true
		return false
	pending_checkpoint.erase(m.mission)
	m.sim.blast_checkpoint_due = false
	return true

@rpc("any_peer","call_remote","reliable")
func _join(id: String, secret: String) -> void:
	var from := api.get_remote_sender_id()
	if not server or id.length()!=32 or not id.is_valid_hex_number() or secret.length()!=43 or pending_auth.has(from) or players.has(from):
		return
	pending_auth[from]=true
	var response := await _service("open",{"id":id,"secret":secret})
	if not pending_auth.erase(from) or from not in api.get_peers():
		return
	if response.has("receipt"):
		_award.rpc_id(from,response.receipt)
		return
	if not response.has("squads"):
		_issue.rpc_id(from,"队伍不可用，请返回组队页刷新")
		return
	var stamp:=Time.get_unix_time_from_system()
	var owner: String = response.owner
	if not sessions.has(id):
		var m: PartyMission = _new_party(response.get("activity"))
		if not m.create_party(id,response.squads,int(response.expires),stamp):
			_issue.rpc_id(from,"创建探索区域失败")
			return
		m.join_order.assign(response.join_order)
		m.leader=response.leader
		sessions[id]=m
	var m: PartyMission=sessions[id]
	m.seat_names=response.names
	# Authentication completing after the deadline cannot rescue an absent seat.
	m.resolve_assembly(stamp,_online_seats(id))
	for old in players.keys():
		if players[old]==[id,owner]:
			players.erase(old)
			_issue.rpc_id(old,"队伍席位已由其他窗口接管")
	players[from]=[id,owner]
	m.absent_until.erase(owner)
	m.resolve_assembly(stamp,_online_seats(id))
	if _save_before_publish(m):
		_broadcast(m)
	print("PARTY_JOIN id=",id," owned=",m.owners.values().count(owner)," members=",m.commander_sequence.size())

func _peer_left(id: int) -> void:
	pending_auth.erase(id)
	if not players.has(id):
		return
	var info: Array=players[id]
	players.erase(id)
	if sessions.has(info[0]):
		var m: PartyMission=sessions[info[0]]
		m.absent_until[info[1]]=int(Time.get_unix_time_from_system())+30
		if _save_before_publish(m):
			_broadcast(m)

@rpc("any_peer","call_remote","reliable")
func _order(id: String, number: int, action: String, selected: Array, target: String, pos: Vector2) -> void:
	var from := api.get_remote_sender_id()
	if not server or not players.has(from) or players[from][0]!=id or not sessions.has(id) or pending_checkpoint.has(id):
		return
	var m: PartyMission=sessions[id]
	if m.party_order(players[from][1],number,action,selected,target,pos):
		if action == "retreat" and not m.battle_started:
			m.resolve_assembly(Time.get_unix_time_from_system(),_online_seats(id))
		if not _save_before_publish(m):
			return
		if action in ["move","route"]:
			_ack.rpc_id(from,id,number,m.last_notice)
		if action in ["collect","retreat"]:
			_broadcast(m)
		else:
			_full.rpc_id(from,m.personalized(players[from][1],_online_seats(m.mission)))
	elif action in ["move","route"] and m.last_move_rejection == "no_space":
		_move_rejected.rpc_id(from,id,number,"no_space")

func _online_seats(mission_id: String) -> Array[String]:
	var online: Array[String] = []
	var connected := api.get_peers()
	for person: int in players:
		if players[person][0] == mission_id and person in connected:
			online.append(players[person][1])
	return online

func _broadcast(m: PartyMission) -> void:
	for person in players:
		if players[person][0]==m.mission and person in api.get_peers():
			_full.rpc_id(person,m.personalized(players[person][1],_online_seats(m.mission)))

func suggest(kind: String,target: String,point: Vector2) -> void:
	if can_command("suggest"):
		_suggest.rpc_id(1,str(credentials.get("id","")),kind,target,point)

@rpc("any_peer","call_remote","reliable")
func _suggest(id: String,kind: String,target: String,point: Vector2) -> void:
	var from:=api.get_remote_sender_id()
	if not server or not players.has(from) or players[from][0]!=id or not sessions.has(id) or pending_checkpoint.has(id):
		return
	var mission:PartyMission=sessions[id]
	if mission.suggest(str(players[from][1]),kind,target,point):
		_broadcast(mission)

func _physics_process(delta: float) -> void:
	sync_time+=delta
	save_time+=delta
	resettle+=delta
	var stamp:=Time.get_unix_time_from_system()
	var now:=int(stamp)
	for id in sessions.keys():
		var m: PartyMission=sessions[id]
		if pending_checkpoint.has(id):
			if save_time<1 or not _save_before_publish(m):
				continue
			_broadcast(m)
		if not m.battle_started and m.outcome.is_empty():
			var online:=_online_seats(id)
			if m.resolve_assembly(stamp,online):
				if not _save_before_publish(m):
					continue
				_broadcast(m)
			else:
				var remaining:=m.assembly_remaining(stamp)
				if remaining != m.last_assembly_second:
					m.last_assembly_second=remaining
					_broadcast(m)
				continue
		var before:=m.stage
		var left:=m.departures.size()
		for owner in m.absent_until.keys():
			if now>=int(m.absent_until[owner]):
				m.leave_member(owner,"expired")
		if m.outcome.is_empty():
			if now>=m.expires:
				m.outcome="expired"
			else:
				m.step(delta)
		if left!=m.departures.size():
			if not _save_before_publish(m):
				continue
			_broadcast(m)
		var final:=not m.outcome.is_empty()
		if final:
			if not frozen_results.has(id):
				if not _save_before_publish(m):
					continue
				frozen_results[id]=true
				_broadcast(m)
			if resettle>=1 and not settling.has(id):
				_deliver_party(m)
			continue
		if save_time>=1 or before!=m.stage or m.sim.blast_checkpoint_due:
			if not _save_before_publish(m):
				continue
		if sync_time>=0.15 or before!=m.stage:
			for person in players:
				if players[person][0]==id and person in api.get_peers():
					if before!=m.stage:
						_full.rpc_id(person,m.personalized(players[person][1],_online_seats(m.mission)))
					elif m is FactoryMission:
						_send_delta(person,m,m.cart_state())
					else:
						_send_delta(person,m)
	if sync_time>=0.15:sync_time=0
	if save_time>=1:save_time=0
	if resettle>=1:resettle=0

func _deliver_party(m: PartyMission) -> void:
	var id:=m.mission
	settling[id]=true
	var response:=await _service("settle",{"id":id,"results":m.results()})
	settling.erase(id)
	if not response.has("receipts"):
		return
	for person in players.keys():
		if players[person][0]==id:
			if person in api.get_peers():
				_award.rpc_id(person,response.receipts[players[person][1]])
			players.erase(person)
	sessions.erase(id)
	frozen_results.erase(id)
	for suffix in [".save",".result.json",".progress.json"]:
		DirAccess.remove_absolute(directory.path_join(id+suffix))
