extends VBoxContainer

signal redeem(payload: Dictionary)

const REASONS := {
	"first_win_required":"本人首次通关锈轨回收场后解锁，独行或组队获胜均可。",
	"daily_used":"今日次数已用完，UTC 次日刷新。",
	"storage_full":"结构材料仓已满，腾出空间后可回收。",
	"energy_required":"需 1 普通能源，救援凭证仅用于常规出征。",
	"unit_unavailable":"需要一台装配完整的待命机体。",
	"quote_changed":"报价已变化，请核对新收益后再确认。"
}

var quote := {}
var pending := {}
var pending_name := ""
var notice := ""
var selected_robot := ""
var waiting := false

func _ready() -> void:
	%Expand.toggled.connect(func(open:bool): %Options.visible=open)
	%Robot.item_selected.connect(func(index:int):
		selected_robot=str(%Robot.get_item_metadata(index))
		pending.clear()
		notice=""
		_render())
	%Confirm.pressed.connect(_confirm)

func refresh(overview:Dictionary, receipt:Dictionary) -> void:
	quote=overview.get("quick_salvage",{})
	%Robot.clear()
	var previous:=selected_robot
	selected_robot=""
	for unit:Dictionary in overview.robots:
		if not unit.ready: continue
		%Robot.add_item("%s · #%s" % [unit.name,str(unit.id).left(6)])
		var index:int=%Robot.item_count-1
		%Robot.set_item_metadata(index,unit.id)
		if selected_robot.is_empty() or previous==unit.id:
			selected_robot=str(unit.id)
			%Robot.select(index)
	if receipt.get("operation","")=="quick_salvage":
		pending.clear()
		var rid:=str(receipt.robot)
		var label:=rid.left(6)
		for unit:Dictionary in overview.robots:
			if unit.id==rid:
				label="%s · #%s" % [unit.name,rid.left(6)]
				break
		notice="%s 回收完成：普通能源 %d，结构材料 +%d。" % [label,int(receipt.changes.energy),int(receipt.changes.structure)]
	_render()

func set_waiting(value:bool) -> void:
	waiting=value
	_render()

func failed(reason:String, uncertain:bool) -> void:
	if uncertain:
		notice="暂未收到回执，可用原请求重试。"
	else:
		pending.clear()
		quote={}
		notice=REASONS.get(reason,"回收失败，请刷新后重试。")
	_render()

func _confirm() -> void:
	if waiting or (pending.is_empty() and (selected_robot.is_empty() or not quote.get("available",false))):
		return
	if pending.is_empty():
		pending_name=%Robot.get_item_text(%Robot.selected)
		pending={"key":Crypto.new().generate_random_bytes(16).hex_encode(),"robot":selected_robot,
			"utc_day":quote.utc_day,"structure_gain":int(quote.structure_gain)}
	redeem.emit(pending.duplicate())

func _render() -> void:
	var available:=bool(quote.get("available",false)) and not selected_robot.is_empty()
	var reason:=str(quote.get("reason",""))
	%Robot.visible=available and pending.is_empty()
	%Robot.disabled=waiting or not pending.is_empty()
	%Confirm.visible=available or not pending.is_empty()
	%Confirm.disabled=waiting
	%Notice.text=notice
	%Notice.visible=not notice.is_empty()
	if not pending.is_empty() and not waiting:
		%Confirm.text="重试原回收请求"
	else:
		%Confirm.text="确认消耗 %d 能源，回收 %d 结构材料" % [int(quote.get("energy_cost",1)),int(quote.get("structure_gain",0))]
	if not pending.is_empty():
		%Terms.text="%s · 普通能源 1 · 报价 %d 结构材料" % [pending_name,int(pending.structure_gain)]
	elif available:
		%Terms.text="每个 UTC 日可回收一次。请选择一台机体："
	else:
		%Terms.text=str(REASONS.get(reason,"请选择一台完整待命机体。" if not quote.is_empty() else "正在读取回收资格。"))
