extends Node

signal changed
signal acknowledged(sequence: int, error: String)
var api := SceneMultiplayer.new()
var peer: ENetMultiplayerPeer
var server := false
var credentials := {}
var seats := {}
var polling := {}
var sending := {}
var ended := {}
var pending := false
var state := {}
var message := ""
var sync_time := 0.0
const SEAT_REPLACED := "本席位已从另一窗口接管"
var receiving_frames := false

func _ready() -> void:
	server = "--treasure-server" in OS.get_cmdline_user_args()
	get_tree().set_multiplayer(api,get_path())
	api.server_relay = false
	api.connected_to_server.connect(func(): _join.rpc_id(1,credentials.id,credentials.secret))
	api.connection_failed.connect(_lost)
	api.server_disconnected.connect(_lost)
	api.peer_disconnected.connect(func(id): seats.erase(id); polling.erase(id); sending.erase(id); ended.erase(id))
	set_physics_process(server)
	if not server:
		return
	peer=ENetMultiplayerPeer.new()
	if peer.create_server(24571,64)!=OK:
		push_error("Treasure ENet listen failed")
		get_tree().quit(1)
		return
	api.multiplayer_peer=peer
	print("TREASURE_READY port=24571")

func connect_mission(host:String, port:int, admission:Dictionary) -> void:
	disconnect_mission()
	credentials=admission.duplicate()
	peer=ENetMultiplayerPeer.new()
	if peer.create_client(host,port)!=OK:
		_lost()
		return
	api.multiplayer_peer=peer
	receiving_frames=true
	message="连接秘宝区域中"
	changed.emit()

func disconnect_mission() -> void:
	if server:return
	receiving_frames=false
	if peer:peer.close()
	api.multiplayer_peer=null
	peer=null
	credentials.clear()
	state.clear()
	pending=false
	message=""

func _lost() -> void:
	receiving_frames=false
	pending=false
	message="连接中断，可重连同一场秘宝争夺"
	changed.emit()

func command(order:Dictionary) -> void:
	if not pending and not state.is_empty() and peer and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
		pending=true
		_command.rpc_id(1,int(state.seq)+1,order)

func _service(route:String, body:Dictionary) -> Dictionary:
	var key_file:=OS.get_environment("ROOM_AUTH_FILE")
	if not FileAccess.file_exists(key_file):return {}
	var http:=HTTPRequest.new()
	http.timeout=5
	add_child(http)
	var headers:=PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+FileAccess.get_file_as_string(key_file).strip_edges()])
	var error:=http.request(OS.get_environment("SOLO_PROFILE_URL").trim_suffix("/")+"/internal/treasure/"+route,headers,HTTPClient.METHOD_POST,JSON.stringify(body))
	if error!=OK:
		http.queue_free()
		return {}
	var response:Array=await http.request_completed
	http.queue_free()
	if response[0]!=HTTPRequest.RESULT_SUCCESS:return {}
	var data:Variant=JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Dictionary else {}

@rpc("any_peer","call_remote","reliable")
func _join(id:String,secret:String) -> void:
	var from:=api.get_remote_sender_id()
	if not server or sending.has(from) or seats.has(from) or id.length()!=32 or not id.is_valid_hex_number() or secret.length()!=43:return
	var auth:={"id":id,"secret":secret}
	sending[from]=true
	var response:=await _service("poll",auth)
	sending.erase(from)
	if from not in api.get_peers():return
	if not response.has("state"):
		_error.rpc_id(from,"无法核验入场，请返回重连")
		return
	for old in seats.keys():
		if seats[old]==auth:
			seats.erase(old)
			if old in api.get_peers():_error.rpc_id(old,SEAT_REPLACED)
	seats[from]=auth
	_frame.rpc_id(from,response.state)

func _physics_process(delta:float) -> void:
	sync_time+=delta
	if sync_time<0.25:return
	sync_time=0
	var groups:={}
	for id in seats.keys():
		var battle:String=seats[id].id
		if ended.has(id) or sending.has(id) or polling.has(battle):continue
		if not groups.has(battle):groups[battle]=[]
		groups[battle].append(id)
	for battle in groups:_poll(battle,groups[battle])

func _poll(battle:String,ids:Array) -> void:
	polling[battle]=true
	var secrets:=[]
	for id in ids:secrets.append(seats[id].secret)
	var data:=await _service("frames",{"id":battle,"seats":secrets})
	polling.erase(battle)
	if not data.get("frames") is Array or data.frames.size()!=ids.size():return
	for i in ids.size():
		var id:int=ids[i]
		if seats.get(id,{}).get("secret")!=secrets[i] or id not in api.get_peers():continue
		_frame.rpc_id(id,data.frames[i])
		if data.frames[i].outcome!=null:ended[id]=true

@rpc("any_peer","call_remote","reliable")
func _command(sequence:int,order:Dictionary) -> void:
	var from:=api.get_remote_sender_id()
	if not server or not seats.has(from) or sending.has(from) or order.size()>5:return
	var auth:Dictionary=seats[from]
	sending[from]=true
	var response:=await _service("command",auth.merged({"seq":sequence,"order":order}))
	sending.erase(from)
	if seats.get(from)!=auth or from not in api.get_peers():return
	if response.has("state"):
		_answer.rpc_id(from,sequence,response.state)
	else:_error.rpc_id(from,"指令未确认，请重试")

@rpc("authority","call_remote","reliable")
func _frame(view:Dictionary) -> void:
	if not state.is_empty() and (int(view.tick)<int(state.tick) or int(view.seq)<int(state.seq)):return
	state=view
	changed.emit()

@rpc("authority","call_remote","reliable")
func _answer(sequence:int,view:Dictionary) -> void:
	pending=false
	_frame(view)
	acknowledged.emit(sequence,str(view.error))

@rpc("authority","call_remote","reliable")
func _error(text:String) -> void:
	if text==SEAT_REPLACED:receiving_frames=false
	pending=false
	message=text
	changed.emit()
