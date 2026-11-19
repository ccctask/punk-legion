extends VBoxContainer

signal request(route: String, fields: Dictionary, read_only: bool)
signal depart(ticket: String)

const RESOURCES := {"structure":"结构材料", "components":"通用零件", "energy":"能源"}
const OPERATIONS := {"starter":"初始库存", "craft":"制造", "admit":"演习入场", "reward":"演习结算","design":"保存方案","build":"制造机体","refit":"调整实装","admission_refund":"入场退费"}
const INTENTS := "user://inventory_intents"
var owner_key := ""
var pending := {}
var stock := {}
var busy := false
var selected_robot := ""

func _ready() -> void:
	%LoadStock.pressed.connect(func(): request.emit("/v1/inventory", {}, true))
	%LoadStock.hide()
	%Craft.pressed.connect(_begin.bind("craft"))
	%SurveyRadar.pressed.connect(_begin.bind("craft","survey_radar"))
	%Repeater.pressed.connect(_begin.bind("craft","rivet_repeater"))
	%Visor.pressed.connect(_begin.bind("craft","visor"))
	%Drill.pressed.connect(_begin.bind("craft","drill"))
	%Jammer.pressed.connect(_begin.bind("craft","jammer"))
	%Shield.pressed.connect(_begin.bind("craft","rivet_shield"))
	%RepairPart.pressed.connect(_begin.bind("craft","repair_arm"))
	%Admit.pressed.connect(_admit)
	%Retry.pressed.connect(_retry)

func bind_account(endpoint: String, account: String) -> void:
	owner_key = (endpoint + "/" + account).sha256_text() if not account.is_empty() else ""
	stock = {}
	pending = {}
	_recover()
	visible = not owner_key.is_empty()
	_render()

func _recover() -> void:
	if owner_key.is_empty() or not DirAccess.dir_exists_absolute(INTENTS):
		return
	for file in DirAccess.get_files_at(INTENTS):
		if file.begins_with(owner_key + "-") and file.ends_with(".cfg"):
			var saved := ConfigFile.new()
			if saved.load(INTENTS.path_join(file)) == OK:
				pending = saved.get_value("intent", "operation", {})
				return

func _intent_path() -> String:
	return INTENTS.path_join(owner_key + "-" + str(pending.fields.key) + ".cfg")

func _save() -> bool:
	if DirAccess.make_dir_recursive_absolute(INTENTS) != OK:
		return false
	var saves := ConfigFile.new()
	saves.set_value("intent", "operation", pending)
	return saves.save(_intent_path()) == OK

func _clear() -> void:
	if not pending.is_empty():
		DirAccess.remove_absolute(_intent_path())
		pending.clear()
		_recover()

func _begin(op: String, recipe := "cannon") -> void:
	if busy or not pending.is_empty():
		return
	var fields := {"key":Crypto.new().generate_random_bytes(16).hex_encode()}
	if op == "craft":
		fields.recipe = recipe
	elif not selected_robot.is_empty():
		fields.robot = selected_robot
	pending = {"route":"/v1/inventory/" + op, "fields":fields}
	if not _save():
		pending.clear()
		%Ledger.text = "待处理操作无法保存，请检查本地存储。"
		return
	_retry()

func _retry() -> void:
	if not pending.is_empty() and not busy:
		request.emit(pending.route, pending.fields, false)

func _admit() -> void:
	var ticket := str(stock.get("pending_ticket",""))
	if ticket.is_empty():
		_begin("admit")
	else:
		depart.emit(ticket)

func receive(payload: Dictionary, mutation: bool) -> void:
	stock = payload.inventory
	if mutation:
		_clear()
	_render()
	if payload.get("receipt", {}).get("operation","") == "admit" and not stock.pending_ticket.is_empty():
		depart.emit(stock.pending_ticket)

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(["stock","blueprints","recipes","parts","part_capacity","pending_ticket","ledger"]):return false
	if not value.stock is Dictionary or not value.stock.has_all(RESOURCES.keys()) or not value.recipes is Dictionary or not value.recipes.get("cannon") is Dictionary:return false
	if not value.parts is Array or not value.blueprints is Array or not value.ledger is Array:return false
	for resource: String in RESOURCES:
		if not value.stock[resource] is Dictionary or not value.stock[resource].has_all(["amount","capacity"]):return false
	return true

func reject() -> void:
	_clear()
	_render()

func set_busy(value: bool) -> void:
	busy = value
	_render()

func _render() -> void:
	if not is_node_ready():
		return
	%LoadStock.disabled = busy
	%Craft.disabled = busy or stock.is_empty() or not pending.is_empty()
	%Drill.disabled = %Craft.disabled
	%SurveyRadar.disabled = true
	%Repeater.disabled = true
	%Visor.disabled = true
	%RepairPart.disabled = %Craft.disabled
	%Jammer.disabled = %Craft.disabled
	%Shield.disabled = %Craft.disabled
	%Admit.disabled = %Craft.disabled
	%Retry.visible = not pending.is_empty()
	%Retry.disabled = busy
	%Stock.text = ""
	%Ledger.text = ""
	if stock.is_empty():
		return
	var amounts := PackedStringArray()
	for name: String in RESOURCES:
		var row: Dictionary = stock.stock[name]
		amounts.append("%s %d/%d" % [RESOURCES[name], row.amount, row.capacity])
	var known: bool = "cannon" in stock.blueprints
	for button:Button in [%Repeater,%SurveyRadar]:
		var recipe:String="survey_radar" if button==%SurveyRadar else "rivet_repeater"
		var price:Dictionary=stock.recipes.get(recipe,{})
		if price.is_empty():continue
		var full:bool=stock.parts.size()>=int(stock.part_capacity)
		var affordable:bool=int(stock.stock.structure.amount)>=-int(price.structure) and int(stock.stock.components.amount)>=-int(price.components)
		button.text="制造%s（%d 结构，%d 零件）" % [preload("res://loadout/catalog.gd").LABELS[recipe],-int(price.structure),-int(price.components)]
		button.disabled=%Craft.disabled or recipe not in stock.blueprints or full or not affordable
		if full:button.text+=" · 部件仓已满"
		elif not affordable:button.text+=" · 材料不足"
	var shield: Dictionary = stock.recipes.get("rivet_shield",{})
	if shield.is_empty():
		%Shield.disabled = true
	else:
		%Shield.text = "制造铆钉盾板（%d 结构，%d 零件）" % [-int(shield.structure),-int(shield.components)]
		%Shield.disabled = %Shield.disabled or stock.parts.size()>=int(stock.part_capacity) or int(stock.stock.structure.amount)<-int(shield.structure) or int(stock.stock.components.amount)<-int(shield.components)
	var costs: Dictionary = stock.recipes.cannon
	%Craft.disabled = %Craft.disabled or not known
	%Craft.text = "制造炮臂（%d 材料，%d 零件）" % [-int(costs.structure), -int(costs.components)]
	var visor: Dictionary = stock.recipes.get("visor",{})
	if not visor.is_empty():
		var known_visor: bool = "visor" in stock.blueprints
		var full: bool = stock.parts.size()>=int(stock.part_capacity)
		var affordable := int(stock.stock.structure.amount)>=-int(visor.structure) and int(stock.stock.components.amount)>=-int(visor.components)
		%Visor.disabled = busy or not pending.is_empty() or not known_visor or full or not affordable
		%Visor.text = "制造战术目镜（%d 结构，%d 零件）" % [-int(visor.structure),-int(visor.components)]
		if not known_visor: %Visor.text += " · 需研究站配方"
		elif full: %Visor.text += " · 部件仓已满"
		elif not affordable: %Visor.text += " · 材料不足"
	var drill: Dictionary = stock.recipes.drill
	var drill_known: bool = "drill" in stock.blueprints
	%Drill.disabled = %Drill.disabled or not drill_known
	%Drill.text = ("制造钻头（%d 结构，%d 零件）" % [-int(drill.structure), -int(drill.components)]) if drill_known else "钻头制造配方未掌握 · 锈轨三胜或提前研究"
	var starter_recipes := PackedStringArray()
	for recipe: String in ["cannon","rivet_repeater","survey_radar"]:
		if recipe in stock.blueprints:
			starter_recipes.append(preload("res://loadout/catalog.gd").LABELS[recipe])
	%Stock.text = "  ·  ".join(amounts) + "\n初始配方 · %s　部件 %d/%d" % ["、".join(starter_recipes),stock.parts.size(),stock.part_capacity]
	%Admit.text = "持票返回试车台" if not stock.pending_ticket.is_empty() else "选中机体参战（1 能源）"
	var lines := PackedStringArray()
	for part in stock.parts:
		lines.append("%s  #%s" % [preload("res://loadout/catalog.gd").LABELS.get(part.definition,part.definition),part.id])
	for entry in stock.ledger:
		var changes := PackedStringArray()
		for name: String in entry.changes:
			changes.append("%s %+d" % [RESOURCES[name], int(entry.changes[name])])
		lines.append("%s　%s　#%s" % [OPERATIONS.get(entry.operation,entry.operation), "  ".join(changes),entry.id])
	%Ledger.text = "\n".join(lines)
