extends SceneTree

# Use the running private beta profile and save two window-size captures outside the project.
func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var directory := OS.get_environment("BETA_IMAGES")
	if not ProjectSettings.has_setting("beta/protocol"):
		var protocol_override:=OS.get_environment("BETA_PROTOCOL")
		ProjectSettings.set_setting("beta/protocol",int(protocol_override) if protocol_override.is_valid_int() else 5)
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK:
		printerr("Set BETA_IMAGES to a writable output directory")
		quit(1)
		return
	if change_scene_to_file("res://beta/entry.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var base := current_scene
	await process_frame
	_click(base.get_node("%Menu"))
	await process_frame
	var diagnostic_button:Button=base.get_node("%Diagnostic")
	base.get_node("%Scroll").ensure_control_visible(diagnostic_button)
	await process_frame
	_click(diagnostic_button)
	await process_frame
	var page:Control=base.get("diagnostics")
	if page==null or page.scene_file_path!="res://beta/diagnostics.tscn":
		printerr("Base menu failed to open diagnostics")
		quit(1)
		return
	var scroll: ScrollContainer = page.get_node("ContentScroll")
	for dimensions in [Vector2i(960,540), Vector2i(640,360)]:
		root.size = dimensions
		await create_timer(0.5).timeout
		for label in ["About","Network","Contact","Status"]:
			var text: Label = page.get_node("%"+label)
			if text.get_global_rect().end.x > page.get_node("Portrait").get_global_rect().position.x:
				printerr("Text column overlaps portrait: ",label)
				quit(1)
				return
		if dimensions.x==640 and scroll.get_v_scroll_bar().max_value <= scroll.size.y:
			printerr("Small layout should scroll")
			quit(1)
			return
		root.get_texture().get_image().save_png(directory.path_join("entry-%d.png" % dimensions.x))
	scroll.ensure_control_visible(page.get_node("%Retry"))
	await process_frame
	_click(page.get_node("%Retry"))
	var deadline := Time.get_ticks_msec()+10000
	while page.get("checking") or not page.get_node("%Status").text.contains("已就绪"):
		if Time.get_ticks_msec()>=deadline:
			printerr("Compatibility check failed ",page.get_node("%Status").text)
			quit(1)
			return
		await process_frame
	scroll.ensure_control_visible(page.get_node("%Feedback"))
	await process_frame
	_click(page.get_node("%Feedback"))
	await create_timer(0.2).timeout
	if not page.get_node("%Contact").text.contains("已复制"):
		printerr("Feedback control did not receive click")
		quit(1)
		return
	scroll.ensure_control_visible(page.get_node("%Play"))
	await process_frame
	_click(page.get_node("%Play"))
	await create_timer(0.5).timeout
	if current_scene!=base or is_instance_valid(page) or not base.get_node("%Menu").is_visible_in_tree() or base.get_node("World").get_child_count()!=1:
		printerr("Diagnostics did not return to the original base")
		quit(1)
		return
	print("BETA_ENTRY_PASS 960x540 and 640x360 separated geometry; small-screen scrolling, feedback, retry, diagnostic return to same base")
	quit()

func _click(button: Button) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
