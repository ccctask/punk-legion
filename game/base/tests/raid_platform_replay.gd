extends "res://base/tests/base_ui.gd"

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text="platform_demo"
	panel.get_node("%Password").text="local-test-only-password"
	await _press("Login")
	panel.get_node("%Base").pressed.emit()
	base=panel.get_node("PrivateBase")
	await _wait()
	base.get_node("%Raids").pressed.emit()
	var watch:=base.get_node("RaidWatch")
	var deadline:=Time.get_ticks_msec()+10000
	while watch.data.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame
	if watch.data.get("stage")!="replay":
		quit(1)
		return
	var directory:=OS.get_environment("RAID_VIDEO_DIRECTORY")
	var log_data:={"raid":watch.data.id,"receipt_repair":watch.data.receipt.platform_repair,"samples":[],"events":[],"labels":[]}
	for f in watch.data.frames:
		for r in f.get("repairs",[]):
			log_data.events.append({"tick":f.tick,"item":r.item,"tower":r.source,"amount":r.amount})
	watch.get_node("%Replay").pressed.emit()
	var start:=Time.get_ticks_msec()
	var next:=start
	var frame:=0
	while watch.replay_at>=0:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_msec()
		if now<next:
			continue
		next=now+115
		var image:=root.get_texture().get_image()
		image.save_jpg(directory.path_join("%05d.jpg" % frame),0.9)
		var label:Label=watch.get_node("%Time")
		if label.text.contains("维修平台") and not log_data.labels.any(func(row):return row.tick==watch.last_frame):
			log_data.labels.append({"tick":watch.last_frame,"text":label.text,"lines":label.get_line_count(),"right":label.get_global_rect().end.x,"viewport":root.get_visible_rect().end.x,"pixels":str(image.get_size())})
		log_data.samples.append({"time_ms":now-start,"tick":watch.last_frame,"repair_beam":watch.get_node("Shots").get_children().any(func(b):return b.material_override!=null and not b.is_queued_for_deletion())})
		frame+=1
	var file:=FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(log_data))
	print("PLATFORM_REPLAY_PASS ",watch.data.id," frames ",frame," events ",log_data.events.size())
	quit(0 if log_data.samples.any(func(s):return s.repair_beam) else 1)
