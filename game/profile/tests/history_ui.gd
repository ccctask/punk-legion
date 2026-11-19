extends SceneTree

var panel:Node
var history:Node
var output:=OS.get_environment("CAREER_OUT")
var phase:=OS.get_environment("CAREER_PHASE")

func _initialize() -> void:
	run.call_deferred()

func wait_response() -> void:
	await process_frame
	while panel.busy: await process_frame

func check(ok:bool, message:String) -> void:
	if not ok:
		push_error(message)
		quit(1)

func shot(label:String) -> void:
	if output.is_empty():return
	panel.get_node("Scroll").ensure_control_visible(history.get_node("Summary"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))

func choose_robot(target:String) -> void:
	var idx:int=panel.robots.find_custom(func(row:Dictionary):return str(row.id)==target)
	check(idx>=0,"missing robot")
	var control:OptionButton=panel.get_node("%Robots")
	control.select(idx)
	control.item_selected.emit(idx)
	await wait_response()
	check(history.robot==target,"selected machine changed")

func read_counts(target:String, battles:int, kills:int, repaired:float, label:String) -> void:
	await choose_robot(target)
	if not history.opened:
		history.get_node("Open").pressed.emit()
		await wait_response()
	check(history.totals=={"battles":battles,"kills":kills,"output":repaired} or (
		int(history.totals.get("battles",-1))==battles and int(history.totals.get("kills",-1))==kills and
		float(history.totals.get("output",-1))==repaired),"unexpected service totals")
	check(history.get_node("Summary").text=="累计参战 %d 场\n击败敌机 %d 台\n为友机实际恢复耐久 %s" % [battles,kills,str(repaired).trim_suffix(".0")],"display")
	check(history.get_child_count()==2,"unexpected individual record controls")
	await shot(phase+"-"+label)

func run() -> void:
	change_scene_to_file("res://profile/profile.tscn")
	await scene_changed
	panel=current_scene
	history=panel.get_node("%History")
	panel.get_node("%Endpoint").text=OS.get_environment("PROFILE_URL")
	panel.get_node("%Account").text=OS.get_environment("SERVICE_TEST_NAME")
	panel.get_node("%Password").text=OS.get_environment("SERVICE_TEST_PASS")
	panel.get_node("%Login").pressed.emit()
	await wait_response()
	if not phase.is_empty():
		var starter:=OS.get_environment("CAREER_STARTER")
		var veteran:=OS.get_environment("CAREER_VETERAN")
		await read_counts(starter,0,0,0,"starter")
		await read_counts(veteran,0 if phase=="fresh" else 1,0 if phase=="fresh" else 1,0 if phase=="fresh" else 4.5,"veteran")
		await read_counts(starter,0,0,0,"switch-back")
	else:
		history.get_node("Open").pressed.emit()
		await wait_response()
		check(history.totals.has_all(["battles","kills","output"]),"totals")
	print("SERVICE_UI_PASS ",phase)
	quit(0)
