extends Node3D

const Simulation := preload("res://battle/simulation.gd")
const Visual := preload("res://battle/unit.tscn")
var fighters: Dictionary[String, Simulation.Fighter] = {}
var views := {}
var selected: Array[String] = []
var owner_seat := 0
var finished := false
var pending_seq := 0
var pending_move_accepted := false
var pending_action := ""
var pending_battle := ""
var sent_at_us := 0
var last_receipt := 0
var draw_receipts: Array[Array] = []
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	owner_seat = Room.local_seat
	if OS.is_debug_build():
		RenderingServer.frame_post_draw.connect(_measure)
	Room.exercise_changed.connect(_refresh)
	Room.exercise_move_result.connect(_move_result)
	Room.state_changed.connect(_connection)
	Room.status_changed.connect(_status)
	hud.get_node("%All").pressed.connect(_select_group.bind(-1))
	hud.get_node("%Alpha").pressed.connect(_select_group.bind(0))
	hud.get_node("%Bravo").pressed.connect(_select_group.bind(1))
	hud.get_node("%Support").pressed.connect(_select_group.bind(2))
	hud.get_node("%CustomGroups").recalled.connect(func(ids: Array[String]): selected.assign(ids))
	hud.get_node("%Repair").pressed.connect(func() -> void: _issue("repair",Vector2.ZERO,""))
	hud.get_node("%Retreat").text = "断线"
	hud.get_node("%Retreat").pressed.connect(Room.disconnect_room)
	hud.get_node("%Retry").text = "重连"
	hud.get_node("%Retry").pressed.connect(Room.reconnect_room)
	hud.get_node("%Workshop").text = "返回试车台"
	hud.get_node("%Workshop").pressed.connect(_return_to_range)
	hud.get_node("%Light").hide()
	hud.get_node("%Heavy").hide()
	_refresh()

func _exit_tree() -> void:
	Room.clear_movement_feedback()

func _return_to_range() -> void:
	if finished and Room.local_seat > 0:
		Room.acknowledge_exercise()
	else:
		get_tree().change_scene_to_file("res://client/range.tscn")

func _status(message: String) -> void:
	if Room.local_seat == 0:
		hud.get_node("%Summary").text = message + "  ·  席位保留 30 秒"

func _connection() -> void:
	if Room.local_seat == 0:
		pending_seq = 0
		pending_move_accepted = false
		pending_action = ""
		pending_battle = ""
		hud.get_node("%CustomGroups").suspend()
		$BattleAudio.reset_audio()
		hud.get_node("Modal").show()
		hud.get_node("Commands").hide()
		hud.get_node("%Title").text = "与演习断开连接"
		hud.get_node("%Retry").show()
		hud.get_node("%Workshop").show()

func _select_group(group: int) -> void:
	selected.clear()
	for id in fighters:
		var u := fighters[id]
		if u.hp > 0 and Room.exercise_state.roster[id][0] == owner_seat and (group < 0 or u.orders.role == ["front","fire","support"][group]):
			selected.append(id)

func _refresh() -> void:
	var state := Room.exercise_state
	if str(state.get("id", "")).is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://client/range.tscn")
		return
	var first := fighters.is_empty()
	if Room.local_seat > 0:
		owner_seat = Room.local_seat
	for id: String in state.units:
		var meta: Array = state.roster[id]
		if not fighters.has(id):
			var u := Simulation.Fighter.new()
			u.id = id
			u.slot = meta[1]
			u.side = 1 if meta[0] == 0 else 0
			u.profile = {"parts":meta[2],"chassis":meta[7] if meta.size()>7 else "crawler"}
			u.orders=Simulation.default_orders(meta[2])
			if meta.size()>6:u.orders.role=meta[6]
			u.stats = {"max_hp":meta[3]}
			var view := Visual.instantiate()
			$Units.add_child(view)
			view.setup(u)
			view.set_paint(str(meta[5]) if meta.size()>5 else "base")
			view.robot.set_hull_number(str(meta[8]) if meta.size()>8 else "")
			if meta.size() > 4 and not str(meta[4]).is_empty():
				view.get_node("OwnedName").text = str(meta[4])
				view.get_node("OwnedName").show()
			fighters[id] = u
			views[id] = view
		var row: Array = state.units[id]
		var unit := fighters[id]
		unit.pos = row[0]
		unit.hp = row[1]
		unit.last_heading = row[2]
		unit.walking = row[3]
		unit.last_service = float(row[8]) if row.size()>8 else -10.0
		unit.protected_until=float(row[9]) if row.size()>9 else 0.0
		unit.last_jam=float(row[10]) if row.size()>10 else -10.0
		unit.last_shot = row[4]
		unit.impact_point = row[5]
		if unit.hp <= 0:
			selected.erase(id)
	if first:
		_select_group(-1)
	finished = not state.result.is_empty()
	if finished or pending_battle != str(state.id):
		pending_seq = 0
		pending_move_accepted = false
		pending_action = ""
		pending_battle = ""
	if not finished and Room.local_seat>0:
		var roster := {}
		for id: String in state.units:
			var row: Array = state.roster[id]
			if row[0]==Room.local_seat and fighters[id].hp>0:
				roster[id] = str(row[4]) if row.size()>4 and not str(row[4]).is_empty() else "训练机 %02d"%(fighters[id].slot+1)
		hud.get_node("%CustomGroups").bind_roster("exercise/%s/%s" % [state.id,Room.exercise_seat_identity()],roster)
		selected.assign(selected.filter(func(id): return roster.has(id)))
	else:
		hud.get_node("%CustomGroups").suspend()
	if finished or Room.local_seat==0:
		$BattleAudio.reset_audio()
	else:
		$BattleAudio.observe(str(state.id),float(state.elapsed),fighters,views,camera)
	hud.get_node("Modal").visible = finished
	hud.get_node("Commands").visible = not finished
	hud.get_node("%Mission").text = "双人演习 · %d 席" % owner_seat
	hud.get_node("%Timer").text = "%d 秒" % ceili(Simulation.TIME_LIMIT - state.elapsed)
	hud.get_node("%Score").text = "我方 %d / 16     敌方 %d / 16" % [state.score[0], state.score[1]]
	hud.get_node("%Repair").text = "维修 ×%d" % state.repairs
	hud.get_node("%Repair").disabled = state.repairs == 0 or selected.is_empty()
	hud.get_node("%Hint").text = "已选 %d 台 · 点地面移动，点敌机集火，点己方机组单选" % selected.size()
	if pending_seq > 0 and (pending_action != "move" or pending_move_accepted) and int(state.seq.get(owner_seat,0)) >= pending_seq:
		last_receipt = pending_seq
		pending_seq = 0
		pending_move_accepted = false
		if OS.is_debug_build():
			draw_receipts.append([last_receipt,sent_at_us])
	if last_receipt > 0:
		hud.get_node("%Hint").text += " · 已执行 #%d" % last_receipt
	var rejection := Room.movement_feedback()
	if not rejection.is_empty():
		hud.get_node("%Hint").text = rejection
	if finished:
		hud.get_node("%Title").text = {0:"演习胜利", 1:"演习失利", -1:"演习平局"}[state.result.winner]
		hud.get_node("%Summary").text = "场次 %s  ·  用时 %d 秒" % [state.id, ceili(state.elapsed)]
		var lines := PackedStringArray()
		for unit in state.result.units:
			if state.roster[unit.id][0] == owner_seat:
				var row: Array = state.roster[unit.id]
				var label := str(row[4]) if row.size() > 4 and not str(row[4]).is_empty() else "训练机 %02d" % (fighters[unit.id].slot+1)
				lines.append("%s   击破 %d   助攻 %d   受修 %d" % [label, unit.kills, unit.assists, unit.received_repair])
		hud.get_node("%Report").text = "\n".join(lines)
		hud.get_node("%Report").show()
		hud.get_node("%Retry").hide()
		hud.get_node("%Workshop").show()

func _process(delta: float) -> void:
	for id in fighters:
		views[id].sync(fighters[id], Room.exercise_state.get("elapsed", 0.0), id in selected, delta)

func _unhandled_input(event: InputEvent) -> void:
	if finished or Room.local_seat == 0 or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var screen: Vector2 = event.position
	var picked := ""
	var threshold := 19.0
	for u in fighters.values():
		if u.hp <= 0:
			continue
		var dist := screen.distance_to(camera.unproject_position(Vector3(u.pos.x, 0.68, u.pos.y)))
		if dist < threshold:
			picked = u.id
			threshold = dist
	if picked.is_empty():
		var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
		if hit != null:
			_issue("move", Vector2(hit.x, hit.z), "")
	elif Room.exercise_state.roster[picked][0] == owner_seat:
		selected.assign([picked])
	elif Room.exercise_state.roster[picked][0] == 0:
		_issue("focus", Vector2.ZERO, picked)
	get_viewport().set_input_as_handled()

func _issue(action: String, target: Vector2, enemy: String) -> void:
	pending_move_accepted = false
	pending_action = action
	pending_battle = str(Room.exercise_state.get("id",""))
	sent_at_us = Time.get_ticks_usec()
	pending_seq = Room.send_exercise_order(action,selected,target,enemy)
	_refresh()

func _move_result(id: String, attempt: int, accepted: bool, _reason: String) -> void:
	if id != pending_battle or pending_action != "move" or attempt != pending_seq:
		return
	if accepted:
		pending_move_accepted = true
	else:
		pending_seq = 0
		pending_move_accepted = false
		pending_action = ""
		pending_battle = ""

func _measure() -> void:
	if draw_receipts.is_empty():
		return
	for receipt in draw_receipts:
		var seq := int(receipt[0])
		var started := int(receipt[1])
		print("PL_COMMAND_DRAW seat=",owner_seat," battle=",Room.exercise_state.get("id","")," seq=",seq," ms=",(Time.get_ticks_usec()-started)/1000.0)
	draw_receipts.clear()
