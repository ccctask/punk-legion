extends "res://base/tests/base_ui.gd"

func _ready_garage(garage: Node) -> void:
	var limit := Time.get_ticks_msec()+8000
	while garage.busy and Time.get_ticks_msec()<limit:
		await process_frame
	_check(not garage.busy,"等候机库服务")

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text=account
	panel.get_node("%Password").text=password
	await _press("Register")
	panel.get_node("%Base").pressed.emit()
	base=panel.get_node("PrivateBase")
	await _wait()
	var which: int=base.TYPES.find("hangar")
	base.get_node("%Type").select(which)
	await _click(3,2)
	_check(not base.preview.is_empty(),"机库投影预览")
	base.get_node("%Confirm").pressed.emit()
	await _wait()
	var file:=OS.get_environment("HANGAR_CAPTURE")
	if not file.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(file)
	await _click(3,2)
	var garage:=panel.get_node("Workshop")
	await _ready_garage(garage)
	_check(garage.get_node("%Mode").selected==1 and garage.get_node("%Hint").text.contains("待命"),"军营进入本人机库")
	var initial: String=garage.data.robots[0].id
	garage.get_node("%Mode").select(0)
	garage.get_node("%Mode").item_selected.emit(0)
	garage.get_node("%Name").text="军营制式"
	garage.get_node("%Save").pressed.emit()
	await _ready_garage(garage)
	garage.get_node("%BuildName").text="驻地二号"
	garage.get_node("%Build").pressed.emit()
	await _ready_garage(garage)
	_check(garage.data.robots.size()==2 and garage.data.hangar_capacity==18,"军营制造第二台实体，沿用机库容量")
	var original_exists: bool=garage.data.robots.any(func(r):return r.id==initial)
	_check(original_exists,"旧机体编号保留")
	garage.get_node("%Back").pressed.emit()
	await process_frame
	await _wait()
	_check(base.visible and base.get_node("HUD").visible,"从机库返回原基地")
	if not failed:
		print("HANGAR_UI_PASS build preview, projected facility tap, real garage, save design, manufacture second robot, return to base")
	quit(1 if failed else 0)
