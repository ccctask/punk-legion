extends "res://profile/tests/profile_ui.gd"

var workshop: Node

func _wait_for_panel() -> void:
	var end := Time.get_ticks_msec()+12000
	while workshop.busy and Time.get_ticks_msec() < end:
		await process_frame
	_check(not workshop.busy, "工坊请求超时")

func _action(path: String) -> void:
	var btn: Button = workshop.get_node("%"+path)
	_check(not btn.disabled,path+" 不可用")
	btn.pressed.emit()
	await _wait_for_panel()

func _open() -> void:
	panel.get_node("%Owned").pressed.emit()
	workshop = panel.get_node("Workshop")
	await _wait_for_panel()
	_check(not workshop.data.is_empty(),"服务端工坊为空")

func select_item(path: String, value: int) -> void:
	var picker: OptionButton = workshop.get_node("%"+path)
	picker.select(value)
	picker.item_selected.emit(value)

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Register")
	await _open()
	select_item("Head",1)
	select_item("Weapon",1)
	_check(workshop.get_node("%Save").disabled,"互斥方案可保存")
	select_item("Weapon",0)
	await _action("Save")
	await _action("Build")
	var first: String = workshop.data.robots[-1].id
	select_item("Mode",0)
	workshop.get_node("%BuildName").text = "同版二号"
	await _action("Build")
	var second: String = workshop.data.robots[-1].id
	_check(first != second and workshop.data.robots.size() == 3,"重复制造实体错误")
	_check(workshop.get_node("Robot").head == 1,"光带实装预览错误")
	select_item("Slot",1)
	var old_id: String = workshop.data.robots[-1].slots.head.id
	await _action("Install")
	_check(workshop.data.available[0].id == old_id and not workshop.data.robots[-1].slots.has("head"),"拆件未归还")
	await _action("Install")
	_check(workshop.data.available.is_empty() and workshop.data.robots[-1].slots.head.id == old_id,"回装错误")
	workshop.get_node("%Back").pressed.emit()
	await process_frame
	while panel.busy:
		await process_frame
	panel.get_node("%Account").text = account
	panel.get_node("%Password").text = password
	await _press("Login")
	await _open()
	select_item("Mode",1)
	select_item("Robot",2)
	_check(workshop.data.robots[2].id == second and workshop.get_node("Robot").head == 1,"重登装配未恢复")
	var deployment: Dictionary = workshop.data.deployment
	var rules := preload("res://loadout/rules.gd")
	_check(rules.validate_squad(deployment.units,deployment.inventory).ok,"真实机体编队接口不兼容")
	var path := OS.get_environment("OWNED_SCREENSHOT")
	if not path.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
	print("OWNED_UI_", "FAIL" if failed else "PASS"," robots=",first,",",second," refitted=",old_id)
	quit(1 if failed else 0)
