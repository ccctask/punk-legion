extends SceneTree
const Mission := preload("res://net/solo_mission.gd")
var last := -1
var tick := 0.0
var dropped := false
var due := 0
var started := 0
var admission := {}
var net: Node
func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	net = root.get_node("Solo")
	admission = {"id":OS.get_environment("TEST_MISSION_ID"),"secret":OS.get_environment("TEST_MISSION_SECRET")}
	started = Time.get_ticks_msec()
	_join()

func _join() -> void:
	net.connect_mission("127.0.0.1",int(OS.get_environment("SOLO_PORT")),admission)
	due = 0

func _process(delta: float) -> bool:
	if net == null:
		return false
	if Time.get_ticks_msec() - started > 310000:
		push_error("任务超时：" + str(net.message))
		quit(1)
		return true
	if due > 0:
		if Time.get_ticks_msec() >= due:
			_join()
		return false
	if not net.receipt.is_empty():
		print("SOLO_ENET_RESULT elapsed=",net.receipt.seconds," wall=",(Time.get_ticks_msec()-started)/1000.0," outcome=",net.receipt.outcome," part=",net.receipt.part," rejoined=",dropped)
		quit(0 if net.receipt.outcome == OS.get_environment("SOLO_EXPECT") else 1)
		return true
	tick += delta
	if net.state.is_empty() or tick < 0.2:
		return false
	tick = 0
	var state: Dictionary = net.state
	if not state.outcome.is_empty():
		return false
	var ids := []
	for id in state.units:
		if state.units[id].side == 0 and state.units[id].hp > 0:
			ids.append(id)
	if ids.is_empty():
		return false
	if OS.get_environment("SOLO_EXPECT") == "retreat":
		net.command("retreat",ids)
		return false
	var target: String = state.goals[0]
	if last != state.stage:
		last = state.stage
		print("SOLO_OBJECTIVE ",target," t=",snappedf(float(state.elapsed),0.1))
		net.command("route",ids,target)
	if state.stage in [0,2,4] and state.units[ids[0]].pos.distance_to(Mission.LOCATIONS[target]) < 3.3:
		net.command("collect",ids,target)
	if state.repairs > 0 and state.units[ids[0]].hp < 48:
		net.command("repair",ids)
	if not dropped and float(state.elapsed) > 3:
		dropped = true
		net.disconnect_mission()
		due = Time.get_ticks_msec()+1000
	return false
