extends "res://profile/tests/profile_ui.gd"

func _operation(node: Button) -> void:
	node.pressed.emit()
	var end := Time.get_ticks_msec() + 10000
	while panel.busy and Time.get_ticks_msec() < end:
		await process_frame
	_check(not panel.busy, "请求超时")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Register")
	var bag: Node = panel.get_node("%Inventory")
	await _operation(bag.get_node("%LoadStock"))
	if bag.stock.is_empty():
		push_error("库存未返回")
		quit(1)
		return
	_check(bag.stock.stock.energy.amount == 5, "初始能源")
	await _operation(bag.get_node("%Craft"))
	_check(bag.stock.parts.size() == 1 and bag.stock.ledger[0].operation == "craft", "制造与回执")
	_check(str(bag.get_node("%Ledger").text).contains(str(bag.stock.parts[0].id)), "UI 显示实体身份")
	bag.get_node("%Admit").pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path == "res://client/range.tscn" and root.get_node("Room").pending_ticket.length() == 43, "持票进入试车台")
	current_scene.get_node("HUD").get_node("%Profile").pressed.emit()
	await scene_changed
	panel = current_scene
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Login")
	bag = panel.get_node("%Inventory")
	await _operation(bag.get_node("%LoadStock"))
	_check(bag.stock.ledger.size() == 3 and bag.stock.stock.energy.amount == 4 and bag.stock.parts.size() == 1, "重新登录后库存和账本一致")
	if not failed:
		print("INVENTORY_UI_PASS login/craft/receipt/admit/range/relogin")
	quit(1 if failed else 0)
