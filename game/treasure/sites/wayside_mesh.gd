@tool
extends MeshInstance3D

const SOURCE := preload("res://treasure/sites/PL_TreasureWaysideKit.glb")
const ENAMEL := preload("res://assets/base_art/enamel.tres")
static var shapes := {}
@export_enum("CopperManifold","FogBell") var module := "CopperManifold":
	set(value):
		module=value
		if is_inside_tree():
			_bind()

func _ready() -> void:
	_bind()

func _bind() -> void:
	if shapes.is_empty():
		var exhibit := SOURCE.instantiate()
		for piece:MeshInstance3D in exhibit.find_children("*","MeshInstance3D",true,false):
			shapes[str(piece.name).trim_suffix("_Surface")]=piece.mesh
		exhibit.free()
	mesh=shapes[module]
	material_override=ENAMEL
	lod_bias=0.3
