extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var base:=preload("res://base/base.tscn").instantiate()
	base.endpoint=OS.get_environment("PROFILE_URL")
	base.token=OS.get_environment("RAID_UI_TOKEN")
	root.add_child(base)
	while base.busy:
		await process_frame
	base.get_node("%Raids").pressed.emit()
	var watch:=base.get_node("RaidWatch")
	while watch.data.is_empty():
		await process_frame
	var ok:bool=watch.data.stage=="warning" and watch.get_node("%Commit").visible and watch.towers.has("tower_a")
	watch.get_node("%Commit").pressed.emit()
	while watch.busy:
		await process_frame
	ok=ok and watch.guard_view!=null
	var saw_live:=false
	while watch.data.stage!="replay":
		await process_frame
		if watch.data.stage=="live":
			saw_live=true
	watch.get_node("%Replay").pressed.emit()
	await create_timer(0.15).timeout
	ok=ok and saw_live and watch.last_frame>=0 and watch.data.frames.size()>0 and not watch.data.receipt.is_empty()
	var capture:=OS.get_environment("RAID_CAPTURE")
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		ok=ok and root.get_texture().get_image().save_png(capture)==OK
	watch.get_node("%Back").pressed.emit()
	await process_frame
	await process_frame
	ok=ok and base.get_node("HUD").visible
	print("RAID_UI_PASS" if ok else "RAID_UI_FAIL", " live=",saw_live," guard/real model/replay/return")
	quit(0 if ok else 1)
