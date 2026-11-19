extends Node3D

const MODELS := {
	"radar_station":preload("res://base/radar_station.tscn"),
	"research_station":preload("res://base/optics_station.tscn"),
	"relay":preload("res://base/power_relay.tscn"),
	"core":preload("res://assets/base_art/ArcDynamo.tscn"),
	"foundry":preload("res://assets/base_art/CoalFoundry.tscn"),
	"warehouse":preload("res://assets/base_art/BinDepot.tscn"),
	"repair":preload("res://assets/base_art/HookGantry.tscn"),
	"workshop":preload("res://assets/base_art/workshop.tscn"),
	"turret":preload("res://assets/base_art/turret.tscn"),
	"hangar":preload("res://assets/base_art/hangar.tscn")
}
const LABEL_HEIGHT := {"radar_station":2.0,"research_station":1.94,"relay":1.45,"core":2.32,"foundry":2.15,"warehouse":1.59,"repair":2.13,"workshop":2.36,"turret":1.48,"hangar":1.9}

func configure(row: Dictionary, label: String) -> void:
	var building: Node3D = MODELS[row.kind].instantiate()
	add_child(building)
	$Mark.position.y = LABEL_HEIGHT[row.kind]
	$Mark.text = label + ("" if row.powered else " · 停电")
	if row.kind=="radar_station":
		set_meta("building_id",row.id)
		building.set_powered(row.powered)
	if row.kind=="turret":
		var mounted: Variant=row.get("module",{"definition":"legacy"})
		var definition:=str(mounted.definition) if mounted is Dictionary else ""
		building.display_module(definition)
		$Mark.text=str({"":"空底座","rivet_repeater":"连发器平台","cannon":"气炮平台","legacy":"哨戒炮塔","jammer":"干扰平台","repair_arm":"维修平台"}.get(definition,label))+("" if row.powered else " · 停电")
	if not row.powered:
		$Mark.modulate = Color.SALMON


func update_radar_power(powered:bool) -> void:
	$RadarStation.set_powered(powered)
	$Mark.text="雷达远征站" if powered else "雷达远征站 · 停电"
	$Mark.modulate=Color(1,0.95,0.79) if powered else Color.SALMON
