extends Node3D

signal battle_finished(summary: Dictionary)

const Simulation := preload("res://battle/simulation.gd")
const Sortie := preload("res://loadout/sortie.gd")
const Visual := preload("res://battle/unit.tscn")
const STEP := 0.05

var sim := Simulation.new()
var selected: Array[String] = []
var views := {}
var running := false
var accumulator := 0.0
var last_heavy := false
var training_round := ""
var group_name := "全队"
var feedback := ""
var feedback_until := 0.0
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	hud.get_node("%All").pressed.connect(_select_group.bind(-1))
	hud.get_node("%Alpha").pressed.connect(_select_group.bind(0))
	hud.get_node("%Bravo").pressed.connect(_select_group.bind(1))
	hud.get_node("%Support").pressed.connect(_select_group.bind(2))
	hud.get_node("%CustomGroups").recalled.connect(func(ids: Array[String]):
		selected.assign(ids)
		group_name="自定组")
	hud.get_node("%Repair").pressed.connect(_repair)
	hud.get_node("%Retreat").pressed.connect(_retreat)
	hud.get_node("%Light").pressed.connect(_start.bind(false))
	hud.get_node("%Heavy").pressed.connect(_start.bind(true))
	hud.get_node("%Retry").pressed.connect(func() -> void: _start(last_heavy))
	hud.get_node("%Workshop").pressed.connect(func() -> void: Sortie.return_to_workshop(get_tree()), CONNECT_DEFERRED)
	hud.get_node("%Retry").hide()
	hud.get_node("%Workshop").hide()
	hud.get_node("Commands").hide()
	if auto_deploy():
		_start(false)

func auto_deploy() -> bool:
	return Sortie.has_deployment()

func create_encounter(heavy: bool) -> bool:
	return Sortie.create_battle(sim) if Sortie.has_deployment() else sim.create_fixture(heavy)

func _start(heavy: bool) -> void:
	last_heavy = heavy
	$BattleAudio.reset_audio()
	var ok := create_encounter(heavy)
	if not ok:
		hud.get_node("%Summary").text = sim.last_error
		return
	for old in views.values():
		old.queue_free()
	views.clear()
	for u in sim.units.values():
		var view := Visual.instantiate()
		$Units.add_child(view)
		view.setup(u)
		views[u.id] = view
	hud.get_node("Modal").hide()
	hud.get_node("Commands").show()
	accumulator = 0.0
	training_round = Crypto.new().generate_random_bytes(12).hex_encode()
	feedback_until = 0.0
	running = true
	_select_group(-1)
	_draw_state(0)

func _select_group(group: int) -> void:
	if not running:
		return
	selected.clear()
	for id in sim.alive_ids(0):
		if group == -1 or sim.units[id].orders.role == ["front","fire","support"][group]:
			selected.append(id)
	group_name = "全队" if group == -1 else ["前排","火力","支援"][group]

func _repair() -> void:
	var restored := sim.repair(selected)
	_note("已恢复 %d 点耐久" % roundi(restored) if restored > 0 else "当前选择没有可维修的损伤")

func _retreat() -> void:
	sim.retreat()
	_finish()

func _note(text: String) -> void:
	feedback = text
	feedback_until = sim.elapsed + 2.0

func _physics_process(delta: float) -> void:
	if not running:
		return
	accumulator += delta
	while running and accumulator >= STEP and sim.result.is_empty():
		_step_encounter()
		accumulator -= STEP
	_draw_state(delta)
	if not sim.result.is_empty():
		_finish()

func _step_encounter() -> void:
	sim.step(STEP)

func _draw_state(delta: float) -> void:
	var roster := {}
	for id in sim.alive_ids(0):
		var u := sim.units[id]
		roster[id] = str(u.profile.get("name","训练机 %02d"%(u.slot+1)))
	hud.get_node("%CustomGroups").bind_roster("training/"+training_round,roster)
	for id in views:
		views[id].sync(sim.units[id], sim.elapsed, selected.has(id), delta)
	if running:
		$BattleAudio.observe("trial",sim.elapsed,sim.units,views,camera)
	for index in range(selected.size() - 1, -1, -1):
		if sim.units[selected[index]].hp <= 0:
			selected.remove_at(index)
	var left := maxi(0, ceili(sim.time_limit - sim.elapsed))
	hud.get_node("%Timer").text = "%02d:%02d" % [left / 60, left % 60]
	hud.get_node("%Score").text = "中继控制    我方 %d / 16    敌方 %d / 16" % [floori(sim.score[0]), floori(sim.score[1])]
	hud.get_node("%Repair").text = "维修 ×%d" % sim.repair_charges
	hud.get_node("%Repair").disabled = sim.repair_charges == 0 or selected.is_empty()
	hud.get_node("%Hint").text = "%s · %d 台     %s" % [group_name, selected.size(),
		feedback if sim.elapsed < feedback_until else "点地面移动 · 点敌机集火 · 点友机单选"]

func _unhandled_input(event: InputEvent) -> void:
	if not running or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var screen: Vector2 = event.position
	var picked := ""
	var threshold := 19.0
	for u in sim.units.values():
		if u.hp <= 0:
			continue
		var screen_center := camera.unproject_position(Vector3(u.pos.x, 0.68, u.pos.y))
		var dist := screen.distance_to(screen_center)
		if dist < threshold:
			threshold = dist
			picked = u.id
	if not picked.is_empty():
		if sim.units[picked].side == 0:
			selected.assign([picked])
			group_name = "机组 %02d" % (sim.units[picked].slot + 1)
		else:
			sim.command_focus(selected, picked)
			_note("集火敌机 %02d" % (sim.units[picked].slot + 1))
	else:
		var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
		if hit != null:
			var dest := Vector2(hit.x, hit.z)
			if Simulation.Field.BOUNDS.has_point(Vector2i(dest.round())):
				if sim.command_move(selected, dest):
					_note("小队移动中")
				elif sim.last_error == "movement_no_space":
					_note("附近无法容纳当前队形，请换个落点")
	get_viewport().set_input_as_handled()

func _finish() -> void:
	if not running or sim.result.is_empty():
		return
	running = false
	$BattleAudio.reset_audio()
	hud.get_node("Commands").hide()
	hud.get_node("Modal").show()
	hud.get_node("%Light").hide()
	hud.get_node("%Heavy").hide()
	hud.get_node("%Retry").show()
	hud.get_node("%Workshop").show()
	hud.get_node("%Title").text = ["中继站胜利", "任务失利"][sim.result.winner] if sim.result.winner >= 0 else "争夺平局"
	var reasons := {"relay":"完成控制","eliminated":"机组全部停机","timeout":"争夺超时","retreat":"主动撤退"}
	hud.get_node("%Summary").text = "%s  ·  %d 秒  ·  我方控制 %d 秒 / 敌方 %d 秒" % [
		reasons[sim.result.reason], ceili(sim.elapsed), floori(sim.score[0]), floori(sim.score[1])]
	var lines := PackedStringArray()
	for record in sim.result.units:
		if record.side == 0:
			lines.append("机组 %02d    击破 %d    助攻 %d    维修受益 %d    耐久 %d" % [
				sim.units[record.id].slot + 1, record.kills, record.assists, roundi(record.received_repair), ceili(record.hp)])
	hud.get_node("%Report").text = "\n".join(lines)
	hud.get_node("%Report").show()
	battle_finished.emit(sim.result.duplicate(true))
