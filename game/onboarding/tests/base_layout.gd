extends "res://campaign/tests/campaign_base.gd"

func _layout(stage:String,viewport:String) -> void:
	var guide:Node=base.get_node("%Guide")
	var scroll:ScrollContainer=guide.get_parent().get_parent()
	for target in ["Next","Go","Daily","Solo","Party","Return"]:
		var control:Control=guide.get_node("Content/"+target)
		scroll.ensure_control_visible(control)
		await create_timer(.12).timeout
		var box:=control.get_global_rect()
		var clip:=scroll.get_global_rect()
		if box.position.x<clip.position.x-1 or box.end.x>minf(clip.end.x,root.get_visible_rect().end.x)+1 or box.end.y>clip.end.y+1 or box.position.y<clip.position.y-1:
			_fail("裁切 %s %s %s control=%s scroll=%s viewport=%s" % [viewport,stage,target,box,clip,root.get_visible_rect()]);return
	await _snap(viewport+"-"+stage,guide.get_node("Content/Next"))
	_note("%s %s %s / %s" % [viewport,stage,guide.get_node("Content/Next").text,guide.get_node("Content/Daily").text])

func _run() -> void:
	_setup_capture()
	await _login(true)
	await _base()
	for size_px in [Vector2i(800,450),Vector2i(960,540)]:
		root.size=size_px
		await create_timer(.4).timeout
		await _layout("new",str(size_px.x))
	await _return_to_profile()
	panel.get_node("%RobotName").text="砂糖维修员"
	await _press("Rename")
	await _base()
	for size_px in [Vector2i(800,450),Vector2i(960,540)]:
		root.size=size_px
		await create_timer(.4).timeout
		await _layout("fit",str(size_px.x))
	await _go("Solo")
	exp_screen=panel.get_node("Expedition")
	await _mission()
	exp_screen.get_node("%Leave").pressed.emit()
	await process_frame
	await _wait(base)
	base.refresh()
	await _wait(base)
	await create_timer(.4).timeout
	if not base.get_node("%Guide/Content/Daily").text.contains("可收工"):_fail("日常未完成");return
	for size_px in [Vector2i(800,450),Vector2i(960,540)]:
		root.size=size_px
		await create_timer(.4).timeout
		await _layout("daily",str(size_px.x))
	_note("BASE_LAYOUT_PASS")
	quit(0)
