extends Node3D

const Catalog := preload("res://loadout/catalog.gd")
const Rules := preload("res://loadout/rules.gd")
const Sortie := preload("res://loadout/sortie.gd")
var accepted: Dictionary = Catalog.sample_squad(1)[0]

func _ready() -> void:
	$Camera.look_at(Vector3(0.35, 0.9, 0.3))
	%Sensor.add_item("传感器 · 双目")
	%Sensor.add_item("传感器 · 战术目镜")
	%Tool.add_item("工具 · 气炮")
	%Tool.add_item("工具 · 钻头")
	%Tool.add_item("工具 · 铆钉连发器")
	%Core.add_item("核心 · 蒸汽锅炉")
	%Core.add_item("核心 · 加固锅炉")
	%Utility.add_item("功能 · 空槽")
	%Utility.add_item("功能 · 维修臂")
	%Utility.add_item("功能 · 脉冲干扰器")
	var previous := Sortie.selection()
	%Armor.add_item("前装甲 · 空槽")
	%Armor.add_item("前装甲 · 铆钉盾板")
	%Survey.add_item("测绘 · 空槽")
	%Survey.add_item("测绘 · 雷达")
	%Survey.select(int(previous.get("survey")=="survey_radar"))
	%Survey.item_selected.connect(_preview_request)
	%Armor.select(int(previous.get("armor")=="rivet_shield"))
	%Armor.item_selected.connect(_preview_request)
	for hull:String in Catalog.HULLS:
		%Hull.add_item(Catalog.HULL_LABELS[hull]+"底盘")
	%Hull.select(Catalog.HULLS.find(previous.get("chassis","crawler")))
	%Hull.item_selected.connect(_preview_request)
	%Utility.select(int(previous.has("utility")))
	%Utility.item_selected.connect(_preview_request)
	%Sensor.select(1 if previous.head == "visor" else 0)
	%Tool.select(maxi(0, ["cannon", "drill", "rivet_repeater"].find(previous.weapon)))
	%Core.select(1 if previous.core == "reinforced_boiler" else 0)
	%Sensor.item_selected.connect(_preview_request)
	%Tool.item_selected.connect(_preview_request)
	%Core.item_selected.connect(_preview_request)
	%Launch.pressed.connect(_launch, CONNECT_DEFERRED)
	%Back.pressed.connect(func(): get_tree().change_scene_to_file(Sortie.RANGE), CONNECT_DEFERRED)
	%Baseline.get_parent().visible = OS.is_debug_build()
	%Baseline.pressed.connect(_open_baseline, CONNECT_DEFERRED)
	_preview_request(0)

func _preview_request(_index: int) -> void:
	var selected := {
		"chassis": Catalog.HULLS[%Hull.selected],
		"head": ["eye", "visor"][%Sensor.selected],
		"weapon": ["cannon", "drill", "rivet_repeater"][%Tool.selected],
		"core": ["boiler", "reinforced_boiler"][%Core.selected],
	}
	if %Utility.selected>0:selected.utility=["","repair_arm","jammer"][%Utility.selected]
	%Survey.visible=Catalog.CHASSIS[selected.chassis].slots.has("survey")
	if %Survey.visible and %Survey.selected>0:selected.survey="survey_radar"
	if %Armor.selected>0:selected.armor="rivet_shield"
	var result := Sortie.select_parts(selected)
	%Launch.disabled = not result.ok
	if not result.ok:
		%Problem.text = "装配失败：%s。预览保留上一套配置。" % result.detail
		return
	accepted = Sortie.unit_with(selected, 1)
	var totals: Dictionary = result.totals
	$Robot.set_chassis(result.chassis)
	$Robot.set_repair_arm(result.parts.get("utility")=="repair_arm")
	$Robot.set_jammer(result.parts.get("utility")=="jammer")
	$Robot.set_shield(result.parts.get("armor")=="rivet_shield")
	$Robot.set_survey_radar(result.parts.get("survey")=="survey_radar")
	$Robot.head = Catalog.PARTS[result.parts.head].visual
	$Robot.weapon = Catalog.PARTS[result.parts.weapon].visual
	%Cost.text = "指挥点  %d\n载重  %d / %d\n功率  %d / %d\n热量  %d / %d" % [
		totals.points, totals.mass, totals.payload, totals.power, totals.supply, totals.heat, totals.cooling]
	%Problem.text = "战术目镜：换敌锁定 0.05 秒，持续射速由武器决定。" if selected.head=="visor" else ""
	var squad := Sortie.plan()
	%Squad.text = "出战 %d 台 · %d / %d 指挥点" % [squad.units, squad.points, Rules.MAX_POINTS]

func _launch() -> void:
	if %Launch.disabled or not Sortie.deploy():
		return
	var error := get_tree().change_scene_to_file(Sortie.BATTLE)
	if error != OK:
		%Problem.text = "试战场景加载失败 · %s" % error_string(error)

func _open_baseline() -> void:
	get_tree().set_meta(&"baseline_shadows", %BenchShadows.button_pressed)
	get_tree().set_meta(&"baseline_start_usec", Time.get_ticks_usec())
	var error := get_tree().change_scene_to_file("res://diagnostics/baseline.tscn")
	if error != OK:
		%Problem.text = "诊断场景加载失败 · %s" % error_string(error)
