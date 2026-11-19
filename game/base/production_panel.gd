extends VBoxContainer

signal request(action: String, path: String, fields: Dictionary)
const NAMES := {"structure":"结构材料","components":"通用零件","energy":"能源"}
const TECH := ["drill","casting"]
var station := ""
var state := {}
var waiting := false
var keys := {}

func _ready() -> void:
	%Refresh.pressed.connect(func(): request.emit("production","/v1/base/production",{}))
	%Refresh.hide()
	%Claim.pressed.connect(_operate.bind("claim"))
	%Study.pressed.connect(_operate.bind("research"))
	%Research.add_item("钻头制造配方")
	%Research.add_item("精密铸造 · 冶炼倍速")
	%Research.item_selected.connect(func(_index): _render())

func select_station(id: String) -> void:
	station=id
	for control in [%Research,%Claim,%Lines]:
		control.visible=station.is_empty()
	%Refresh.text="重新连接"
	_render()

func _operate(action: String) -> void:
	var tech: String = TECH[%Research.selected] if station.is_empty() else "optics"
	var operation := action + (tech+station if action == "research" else "")
	if not keys.has(operation):
		keys[operation] = Crypto.new().generate_random_bytes(16).hex_encode()
	var fields := {"key":keys[operation]}
	if action == "research":
		fields.tech = tech
		if tech=="optics": fields.station=station
	request.emit(action,"/v1/base/production/" + action,fields)

func receive(data: Dictionary) -> void:
	state = data.production
	if data.has("receipt"):
		var receipt: Dictionary = data.receipt
		keys.erase(str(receipt.operation)+str(receipt.get("tech",""))+str(receipt.get("station","")))
	_render()

func set_wait(value: bool) -> void:
	waiting = value
	_render()

func _render() -> void:
	if not is_node_ready():
		return
	%Refresh.disabled = waiting
	%Claim.disabled = true
	%Study.disabled = true
	if state.is_empty():
		return
	var rows := PackedStringArray()
	var available := 0
	for resource: String in NAMES:
		var line: Dictionary = state.lines[resource]
		var hourly := float(line.rate)*3600.0/float(line.cycle)
		rows.append("%s　%d 线 · %.1f/时\n可领 %d/%d　库存 %d · 余 %d" % [NAMES[resource],line.facilities,hourly,line.pending,line.capacity,line.stock,line.free])
		var stopped:int=line.get("sources",[]).size()-int(line.facilities)
		if stopped>0:
			rows.append("野袭停工 %d 线 · 已有产出可领" % stopped)
		available += int(line.pending)
	%Lines.text = "\n".join(rows) + "\n离线计产上限 %d 小时" % int(state.offline_seconds/3600)
	%Claim.disabled = waiting or available == 0
	var tech: String = TECH[%Research.selected] if station.is_empty() else "optics"
	var amounts := PackedStringArray()
	var affordable := true
	for resource: String in state.research[tech]:
		var needed := absi(int(state.research[tech][resource]))
		amounts.append("%s %d" % [NAMES[resource],needed])
		affordable = affordable and int(state.lines[resource].stock) >= needed
	var mastered: bool = tech in state.tech
	%Study.text = "研究"
	%Cost.text = "已研究" if mastered else ("费用 · " + "、".join(amounts))
	if tech == "optics":
		var reason := str(state.get("stations",{}).get(station,"missing"))
		var power := str({"powered":"已供电","paused":"已暂停供能","budget":"供电预算不足","out_of_range":"超出供电范围"}.get(reason,"站房已移除"))
		%Cost.text = "光学研究站 · %s\n战术目镜配方\n" % power
		if mastered:
			%Cost.text += "配方已掌握，可到指挥官档案的仓库制造单件，再到机库装配。"
		else:
			%Cost.text += "首次研究："+"、".join(amounts)
			if not affordable: %Cost.text += "\n库存材料不足。"
		%Study.text = "已掌握" if mastered else "研究战术目镜"
		%Study.disabled = waiting or mastered or not affordable or reason!="powered"
		return
	if tech == "drill":
		var recipe: Dictionary = state.drill_recipe
		mastered = recipe.mastered
		%Study.text = "已掌握" if mastered else "提前研究"
		%Cost.text = "钻头制造配方已掌握。\n指挥官档案 → 仓库与账本\n先点「查看库存」，\n再点「制造钻头」。" if mastered else (
			"锈轨个人通关 %d/%d\n达标免费掌握钻头配方。\n提前研究费用\n%s" % [recipe.wins, recipe.required, "、".join(amounts)])
		if not mastered:
			if int(state.lines.components.facilities) == 0:
				%Cost.text += "\n装配车间受损，修复后可研究。" if not state.lines.components.get("sources",[]).is_empty() else "\n提前研究需要已供电的装配车间。"
			elif not affordable:
				%Cost.text += "\n库存材料不足。"
	%Study.disabled = waiting or mastered
	if tech == "drill":
		%Study.disabled = %Study.disabled or not affordable or int(state.lines.components.facilities) == 0
