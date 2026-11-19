extends SceneTree
var net: Node
var elapsed_wait := 0.0
var sent := false
func _initialize() -> void:
	call_deferred("_start")
func _start() -> void:
	net = root.get_node("Solo")
	net.connect_mission("127.0.0.1",int(OS.get_environment("SOLO_PORT")),{"id":OS.get_environment("TEST_MISSION_ID"),"secret":OS.get_environment("TEST_MISSION_SECRET")})
func _process(delta: float) -> bool:
	elapsed_wait += delta
	if elapsed_wait > 25:
		push_error("checkpoint probe timeout")
		quit(1)
		return true
	if net==null or net.state.is_empty():
		return false
	if not net.receipt.is_empty():
		print("CHECKPOINT_RESUME_PASS")
		quit(0 if net.receipt.outcome=="retreat" else 1)
		return true
	var s: Dictionary=net.state
	var id := "0:"+OS.get_environment("SOLO_ROBOT")
	var path := OS.get_environment("SOLO_EXPECTED_FILE")
	if OS.get_environment("SOLO_PHASE")=="before":
		if not sent:
			net.command("route",[id],"scrap")
			sent=true
		if s.elapsed>=2.5:
			var record := FileAccess.open(path,FileAccess.WRITE)
			record.store_var({"elapsed":s.elapsed,"pos":s.units[id].pos})
			record.close()
			net.disconnect_mission()
			quit()
			return true
	elif not sent:
		var file := FileAccess.open(path,FileAccess.READ)
		var prior: Dictionary=file.get_var()
		file.close()
		if absf(float(s.elapsed)-float(prior.elapsed))>1.5 or prior.pos.distance_to(s.units[id].pos)>5:
			push_error("server restarted mission instead of restoring saved progress")
			quit(1)
			return true
		net.command("retreat",[id])
		sent=true
	return false
