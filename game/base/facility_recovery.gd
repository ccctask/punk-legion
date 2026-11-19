extends VBoxContainer

signal repair_requested(fields:Dictionary)
signal refresh_due
const NAMES := {"workshop":"装配车间","foundry":"冶炼炉"}
var damage:Array = []
var request := {}
var stock := 0
var locked := false
var server_stamp := -1
var stamp_ticks := 0
var due_read := false
var attempts := 0

static func site(row:Dictionary) -> String:
	return "%s (%d,%d)" % [NAMES[row.kind],int(row.x),int(row.y)]

static func deadline(row:Dictionary) -> String:
	return Time.get_datetime_string_from_unix_time(int(row.due),true).substr(5,11) + " UTC"

func _ready() -> void:
	%ChooseDamage.item_selected.connect(func(_i:int): _render())
	%RepairFacility.pressed.connect(_repair)
	$Due.timeout.connect(func():
		due_read=true
		refresh_due.emit())

func update_state(rows:Array,balance:int,server_now:int) -> void:
	var previous := ""
	if %ChooseDamage.selected >= 0:previous = str(%ChooseDamage.get_selected_metadata())
	damage = rows
	stock = balance
	due_read=false
	attempts=0
	if server_now>=0 and server_now!=server_stamp:
		server_stamp=server_now
		stamp_ticks=Time.get_ticks_msec()
	%ChooseDamage.clear()
	var first_due := INF
	for row:Dictionary in damage:
		%ChooseDamage.add_item(site(row))
		var index:int = %ChooseDamage.item_count-1
		%ChooseDamage.set_item_metadata(index,row.building)
		if row.building == previous:%ChooseDamage.select(index)
		first_due = minf(first_due,float(row.due))
	$Due.stop()
	if not damage.is_empty() and server_stamp>=0:
		var now:=server_stamp+(Time.get_ticks_msec()-stamp_ticks)/1000.0
		$Due.start(maxf(1,first_due-now+0.2))
	_render()

func claim_due_read() -> bool:
	if not due_read:return false
	due_read=false
	return true

func read_failed(transient:bool) -> void:
	if not transient or damage.is_empty():return
	var delays:=[5,20]
	if attempts<delays.size():
		$Due.start(delays[attempts])
		attempts+=1
	else:
		%RepairResult.text="设施状态暂未确认，恢复基地连接后会自动更新。"
		_render()

func set_stock(balance:int) -> void:
	stock=balance
	_render()

func choose(building:String) -> bool:
	for i in damage.size():
		if damage[i].building == building:
			if not request.is_empty() and request.building != building:return false
			%ChooseDamage.select(i)
			_render()
			return true
	return false

func set_locked(value:bool) -> void:
	locked=value
	_render()

func _render() -> void:
	var offered:bool = %ChooseDamage.selected>=0
	visible = offered or not request.is_empty() or not %RepairResult.text.is_empty()
	%ChooseDamage.visible = damage.size()>1
	%ChooseDamage.disabled = locked or not request.is_empty()
	%RepairResult.visible = not %RepairResult.text.is_empty()
	%DamageSummary.visible = offered
	%RepairFacility.visible = offered or not request.is_empty()
	%RepairFacility.disabled = locked
	if offered:
		var row:Dictionary = damage[%ChooseDamage.selected]
		var price:=int(row.cost.structure)
		%DamageSummary.text = "%s · 野袭受损停工\n%s 免费修复，已有产出保留" % [site(row),deadline(row)]
		%RepairFacility.text = "立即抢修 · %d 结构" % price
		if stock<price:
			%DamageSummary.text += "\n结构材料不足，现有 %d" % stock
			%RepairFacility.disabled = true
	if not request.is_empty():
		%RepairFacility.text = "核对原抢修收据"
		%RepairFacility.disabled = locked

func _repair() -> void:
	if %RepairFacility.disabled:return
	if request.is_empty():
		if %ChooseDamage.selected<0:return
		var row:Dictionary=damage[%ChooseDamage.selected]
		request={"key":Crypto.new().generate_random_bytes(16).hex_encode(),"building":row.building,"raid":row.raid}
	%RepairResult.text="正在核对设施抢修…"
	repair_requested.emit(request.duplicate())

func finish(message:String,uncertain:=false) -> void:
	if not uncertain:request.clear()
	%RepairResult.text=message
	_render()
