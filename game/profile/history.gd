extends VBoxContainer

signal request(route: String, fields: Dictionary, read_only: bool)

var robot := ""
var opened := false
var totals: Dictionary = {}

func _ready() -> void:
	$Open.pressed.connect(refresh)

func select_robot(id: String, busy: bool) -> void:
	if robot != id:
		robot = id
		totals.clear()
		$Summary.hide()
		if robot.is_empty():
			opened = false
	$Open.disabled = robot.is_empty() or busy

func refresh() -> void:
	if robot.is_empty() or $Open.disabled:
		return
	opened = true
	totals.clear()
	$Summary.hide()
	request.emit("/v1/robots/%s/history" % robot, {}, true)

func receive(data: Dictionary) -> bool:
	if data.get("robot") != robot or not data.get("totals") is Dictionary:
		return false
	var values: Dictionary = data.totals
	if not values.has_all(["battles","kills","output"]):
		return false
	totals = values.duplicate()
	$Summary.text = "累计参战 %d 场\n击败敌机 %d 台\n为友机实际恢复耐久 %s" % [
		int(totals.battles), int(totals.kills), str(float(totals.output)).trim_suffix(".0")]
	$Summary.show()
	return true
