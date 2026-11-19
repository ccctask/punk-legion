extends "res://assets/base_art/painted_asset.gd"

const NumberPlate:=preload("res://assets/steam_crawler/hull_number_plate.gd")
var hull_number:=""
var _number_plate:NumberPlate
@onready var yaw_pivot: Node3D = $Model.find_child("YawPivot",true,false)
@onready var muzzle_socket: Node3D = $Model.find_child("Muzzle",true,false)

func _ready() -> void:
	super()
	set_hull_number(hull_number)

func set_hull_number(value:String) -> void:
	hull_number=value if NumberPlate.valid(value) else ""
	if not is_node_ready():return
	if hull_number.is_empty():
		if is_instance_valid(_number_plate):_number_plate.free()
		return
	if not is_instance_valid(_number_plate):
		_number_plate=NumberPlate.new()
		_number_plate.name="HullNumberPlate"
		$Model.add_child(_number_plate)
		_number_plate.position=Vector3(0,.145,.432)
	_number_plate.show_number(hull_number)

func display_module(definition:String) -> void:
	var attachment := yaw_pivot.get_node_or_null("InstalledModule")
	if attachment:
		attachment.free()
	yaw_pivot.visible = definition in ["legacy","cannon","rivet_repeater","jammer","repair_arm"]
	yaw_pivot.get_node("YawPivot_Surface").visible = definition in ["legacy","cannon"]
	var module:Node3D
	match definition:
		"rivet_repeater":
			module = preload("res://assets/steam_crawler/rivet_repeater.tscn").instantiate()
			module.position = Vector3(.26,.21,-.09)
		"jammer":
			module = preload("res://assets/salvage/kit.gd").jammer_coil()
			module.position = Vector3(0,.365,0)
			module.rotation.y = PI
		"repair_arm":
			module = preload("res://assets/salvage/kit.gd").part("MedicRig")
			module.position = Vector3(0,.195,0)
			module.rotation.y = PI
			module.scale = Vector3.ONE*.6
	if module:
		module.name = "InstalledModule"
		yaw_pivot.add_child(module)

# glTF's authored socket points +Z. Gameplay uses Godot forward (-Z).
func muzzle_transform() -> Transform3D:
	return muzzle_socket.global_transform * Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)

