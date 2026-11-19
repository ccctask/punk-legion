extends SceneTree
const Mission:=preload("res://net/solo_mission.gd")
var net:Node
var due:=0
var ready:=false
var last_input:=0

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	net=root.get_node("Solo")
	net.connect_mission("127.0.0.1",int(OS.get_environment("SOLO_PORT")),{"id":OS.get_environment("TEST_MISSION_ID"),"secret":OS.get_environment("TEST_MISSION_SECRET")})
	due=Time.get_ticks_msec()+130000

func _process(_dt:float) -> bool:
	if net==null:return false
	if Time.get_ticks_msec()>due:
		push_error("operator backup checkpoint not reached")
		quit(1)
		return true
	if net.state.is_empty():return false
	var field:Dictionary=net.state
	var id:="0:"+OS.get_environment("SOLO_ROBOT")
	if "scrap" in field.nodes:
		if not ready:
			var f:=FileAccess.open(OS.get_environment("M22_GATE")+".ready",FileAccess.WRITE)
			f.store_line("ready");f.close();ready=true
		if FileAccess.file_exists(OS.get_environment("M22_GATE")) and field.outcome.is_empty():
			net.command("retreat",[id])
		if not field.outcome.is_empty():
			print("M22_PENDING_REAL_OUTCOME ",field.outcome)
			quit();return true
	elif Time.get_ticks_msec()-last_input>=300:
		last_input=Time.get_ticks_msec()
		if field.units[id].pos.distance_to(Mission.LOCATIONS.scrap)<3.2:
			net.command("collect",[id],"scrap")
		else:
			net.command("route",[id],"scrap")
	return false
