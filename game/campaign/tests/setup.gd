extends "res://campaign/tests/campaign_base.gd"

func _run() -> void:
	_setup_capture()
	await _login(true)
	await _base()
	for row in [[0,3,2],[0,5,2],[2,7,2],[1,5,5]]:
		_select(base,"%Type",row[0])
		await _pick_cell(row[1],row[2])
		await _click_button(base,"%Confirm",base)
	_note("两座冶炼厂、一座装配车间、一座仓库已建造 "+str(base.layout.revision))
	_select(base,"%Mode",1)
	await _pick_cell(5,5)
	await _pick_cell(7,5)
	await _click_button(base,"%Confirm",base)
	await _snap("m11-layout")
	await _click_button(base,"%EconomyToggle",base)
	var econ:Node=base.get_node("%Economy")
	_select(econ,"%Research",1)
	await _click_button(econ,"%Study",base)
	if not "casting" in econ.state.tech or econ.state.lines.structure.rate!=4:
		_fail("冶炼未达预期速率："+str(econ.state));return
	_note("结构产线 "+str(econ.state.lines.structure))
	await _return_to_profile()
	var inv:Node=panel.get_node("%Inventory")
	await _click_button(inv,"%LoadStock",panel)
	await _click_button(inv,"%Craft",panel)
	await _open_shop()
	shop.get_node("%Name").text="黄铜远征式"
	await _click_button(shop,"%Save",shop)
	await _make("黄铜编队后备")
	await _leave_shop()
	await _click_button(inv,"%LoadStock",panel)
	var left:int=inv.stock.stock.structure.amount
	if left!=2:
		_fail("领产出前应剩 2 结构，实有 "+str(left));return
	_note("SETUP_PASS 领取前结构2，下一台实机要3。身份 "+account)
	quit(0)
