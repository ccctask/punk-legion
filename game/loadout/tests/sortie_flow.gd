extends SceneTree

const Sortie := preload("res://loadout/sortie.gd")
var deadline := 0
var finished := false

func _initialize() -> void:
	deadline = Time.get_ticks_msec() + 25000
	call_deferred("run_flow")

func _process(_delta: float) -> bool:
	if not finished and Time.get_ticks_msec() > deadline:
		fail("timed out during scene transition")
	return false

func fail(message: String) -> void:
	push_error("SORTIE_FLOW_FAILED " + message)
	finished = true
	quit(1)

func run_flow() -> void:
	var online := "--with-room" in OS.get_cmdline_user_args()
	var room := root.get_node("Room")
	change_scene_to_file(Sortie.RANGE)
	await scene_changed
	if online:
		while room.local_seat == 0:
			await process_frame
		print("SORTIE_ENTERED_ROOM seat=", room.local_seat)
	current_scene.get_node("HUD").get_node("%Workshop").pressed.emit()
	await scene_changed
	if current_scene.scene_file_path != Sortie.WORKSHOP or room.local_seat != 0:
		fail("workshop entry or seat release")
		return
	var workshop := current_scene
	for node_name in ["%Core","%Tool","%Sensor"]:
		var picker: OptionButton = workshop.get_node(node_name)
		picker.select(1)
		picker.item_selected.emit(1)
	if not workshop.get_node("%Launch").disabled:
		fail("incompatible pair accepted")
		return
	var sensor: OptionButton = workshop.get_node("%Sensor")
	sensor.select(0)
	sensor.item_selected.emit(0)
	if workshop.get_node("%Launch").disabled or not "6 台" in workshop.get_node("%Squad").text:
		fail("heavy squad unavailable")
		return
	workshop.get_node("%Launch").pressed.emit()
	await scene_changed
	var battle := current_scene
	if battle.scene_file_path != Sortie.BATTLE or battle.sim.alive_ids(0).size() != 6 or battle.sim.budgets[0] != 24:
		fail("incorrect deployment")
		return
	for id in battle.sim.alive_ids(0):
		var fighter = battle.sim.units[id]
		if fighter.profile.parts.weapon != "drill" or fighter.profile.parts.core != "reinforced_boiler" or fighter.stats.max_hp != 155:
			fail("battle profile lost workshop state")
			return
	battle.get_node("HUD").get_node("%Retreat").pressed.emit()
	if not battle.get_node("HUD").get_node("%Workshop").is_visible_in_tree():
		fail("missing return action")
		return
	battle.get_node("HUD").get_node("%Workshop").pressed.emit()
	await scene_changed
	if current_scene.scene_file_path != Sortie.WORKSHOP or current_scene.get_node("%Core").selected != 1 or current_scene.get_node("%Tool").selected != 1:
		fail("selection lost on return")
		return
	current_scene.get_node("%Back").pressed.emit()
	await scene_changed
	if current_scene.scene_file_path != Sortie.RANGE:
		fail("range return")
		return
	print("SORTIE_FLOW_OK online=", online, " units=6 points=24 hp=155 weapon=drill")
	finished = true
	quit(0)
