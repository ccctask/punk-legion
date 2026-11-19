extends "res://profile/tests/profile_ui.gd"

var shop:Node
var page:Node
var chassis:Node

func _wait(node:Node) -> void:
	var until:=Time.get_ticks_msec()+7000
	while node.busy and Time.get_ticks_msec()<until:
		await process_frame
	_check(not node.busy,"界面超时")

func _open() -> void:
	panel.get_node("%Owned").pressed.emit()
	shop=panel.get_node("Workshop")
	await _wait(shop)
	shop.get_node("%Shop").pressed.emit()
	page=shop.get_node("HUD/TestStore")
	await _wait(page)
	chassis=shop.get_node("Robot/Model").find_child("SM_Runtime_ROOT_Chassis_0",true,false)

func _act(id:String) -> void:
	page.get_node("%"+id).pressed.emit()
	await _wait(page)

func _pay(kind:String) -> void:
	page.get_node("%Result").select(page.RESULTS.keys().find(kind))
	await _act("Commit")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text=account
	panel.get_node("%Password").text=password
	await _press("Register")
	await _open()
	_check(page.data.capacity==6 and chassis.material_override==null,"默认免费涂装与位置")
	page.get_node("%Styles").select(1)
	page.get_node("%Styles").item_selected.emit(1)
	_check(chassis.material_override!=null and page.get_node("%Equip").disabled,"未购买时仅预览涂装")
	await _act("Buy")
	await _pay("cancel")
	_check(page.data.orders[0].state=="cancelled","取消")
	await _act("Buy")
	await _pay("fail")
	_check(page.data.orders[0].state=="failed","失败")
	await _act("Buy")
	await _pay("paid")
	_check(page.data.orders[0].state=="paid" and page.get_node("%Equip").disabled,"延迟发货")
	await _pay("retry")
	await _act("Equip")
	_check(page.data.robots[0].paint=="mint" and chassis.material_override!=null,"涂装发放实装")
	var capture:=OS.get_environment("STORE_CAPTURE")
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture)
	page.get_node("%Back").pressed.emit()
	await process_frame
	await _wait(shop)
	shop.get_node("%Back").pressed.emit()
	await process_frame
	await _wait(panel)
	await _panel()
	panel.get_node("%Account").text=account
	panel.get_node("%Password").text=password
	await _press("Login")
	await _open()
	_check(page.data.robots[0].paint=="mint" and chassis.material_override!=null,"重登保留")
	await _pay("refund")
	_check(page.data.robots[0].paint=="base" and "mint" not in page.data.styles and chassis.material_override==null,"退款撤权")
	if not failed:
		print("STORE_UI_PASS range/register/workshop/preview/cancel/fail/paid/retry/equip/relogin/refund")
	quit(1 if failed else 0)
