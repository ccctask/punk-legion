extends VBoxContainer

signal request(route:String, fields:Dictionary, read_only:bool)
signal queue_requested
const RepairQuote := preload("res://profile/repair_quote.gd")
const STATES := {"ready":"待命","damaged":"战斗损坏","repairing":"维修中","retired":"已回收"}
const EVENTS := {"combat_damage":"战斗损坏","repair_started":"进入维修队列","workshop_repair":"工坊维修完成","recycled":"机体回收","relief":"领取基础救援"}
const RECYCLE_REASON := {"parts_full":"请腾出一个部件仓位，用于收回烟囱炮臂。","keep_last_robot":"机库需要保留至少一台机体，当前机体无法回收。","robot_busy":"执行任务期间无法回收。","repair_in_progress":"正在维修，完成后可重新查看回收资格。","robot_retired":"此机体已回收，服役历史仍可查看。"}
var robot := ""
var unit_name := ""
var data := {}
var pending := {}
var busy := false

func _ready() -> void:
	$Open.pressed.connect(func(): request.emit(_route(),{},true))
	$Details/Queue.pressed.connect(func(): queue_requested.emit())
	$Details/Actions/Repair.pressed.connect(_begin.bind("repair"))
	$Details/Actions/Relief.pressed.connect(_begin.bind("relief"))
	$Details/Actions/Recycle.pressed.connect(_preview)
	$Details/Actions/Retry.pressed.connect(_retry)
	$Confirm.confirmed.connect(_begin.bind("recycle"))

func _route() -> String:
	return "/v1/robots/%s/recovery" % robot

func _file() -> String:
	return "user://recovery_%s.cfg" % robot

func bind_robot(id:String, locked:bool, current_name:String="") -> void:
	busy = locked
	unit_name=current_name if not id.is_empty() else ""
	if robot != id:
		robot = id
		data = {}
		pending = {}
		$Details.hide()
		$Details/Summary.text=""
		$Confirm.hide()
		var config := ConfigFile.new()
		if not id.is_empty() and config.load(_file()) == OK:
			pending = config.get_value("pending","action",{})
	_display()

func receive(info:Dictionary, accepted:bool) -> void:
	if info.robot != robot:
		return
	data = info
	if accepted:
		clear_intent()
	$Details.show()
	_display()

func clear_intent() -> void:
	if not pending.is_empty():
		DirAccess.remove_absolute(_file())
	pending = {}
	_display()

func _preview() -> void:
	if busy or not data.get("can_recycle",false):
		return
	if data.get("recovered_part") is Dictionary:
		$Confirm.dialog_text="烟囱炮臂 #%s 将卸下返还部件仓，其余安装件随机体封存。另返还结构材料 %d。" % [str(data.recovered_part.id).left(8),int(data["return"].get("structure",0))]
	else:
		$Confirm.dialog_text = "回收后机体退出机库，安装件一并封存。服役历史可继续查看。预计返还结构材料 %d。" % int(data["return"].get("structure",0))
	$Confirm.popup_centered()

func _begin(action:String) -> void:
	if busy or not pending.is_empty() or (action=="repair" and $Details/Actions/Repair.disabled):
		return
	var fields := {"key":Crypto.new().generate_random_bytes(16).hex_encode()}
	if action == "recycle":
		if not data.get("can_recycle",false):
			return
		fields.merge({"quote":data.quote,"confirmed":true})
	pending = {"url":_route()+"/"+action,"fields":fields}
	var config := ConfigFile.new()
	config.set_value("pending","action",pending)
	if config.save(_file()) != OK:
		pending.clear()
		$Details/Summary.text = "待处理操作保存失败，请检查设备存储。"
		return
	_retry()

func _retry() -> void:
	if not busy and not pending.is_empty():
		request.emit(pending.url,pending.fields,false)

func _display() -> void:
	if not is_node_ready():
		return
	$Open.disabled = busy or robot.is_empty()
	$Details/Actions/Retry.visible = not pending.is_empty()
	$Details/Actions/Retry.disabled = busy
	if data.is_empty():
		return
	var locked := busy or not pending.is_empty()
	var bays: Dictionary = data.bays
	var quote:=RepairQuote.read(data,data.get("repair_stock",{}))
	$Details/Actions/Repair.disabled = locked or not quote.affordable or data.state != "damaged" or int(bays.available) == 0
	$Details/Actions/Recycle.disabled = locked or not data.get("can_recycle",false)
	$Details/Actions/Relief.disabled = locked or data.state in ["retired","repairing"]
	if not data.get("can_recycle",false):
		$Confirm.hide()
	var suffix := ""
	if data.state == "repairing":
		suffix = " · %s UTC 完成" % Time.get_datetime_string_from_unix_time(int(data.due),true)
	$Details/Summary.text = "%s · #%s\n%s%s　送修 %d 秒%s" % [unit_name,robot.left(8),STATES[data.state],suffix,int(data.seconds)," · 持有一次救援出征凭证" if data.voucher else ""]
	if data.state=="damaged":
		$Details/Summary.text+="\n"+str(quote.text)
	$Details/Summary.text+="\n维修工位 · %d 台在修，%d 个空闲" % [bays.used,bays.available]
	if not data.get("can_recycle",false):
		$Details/Summary.text+="\n"+str(RECYCLE_REASON.get(data.get("recycle_reason",""),"当前回收资格正在更新。"))
	var lines := PackedStringArray()
	for event in data.recent:
		lines.append("%s UTC　%s" % [Time.get_datetime_string_from_unix_time(int(event.at),true),EVENTS.get(event.kind,event.kind)])
	$Details/Events.text = "\n".join(lines)
