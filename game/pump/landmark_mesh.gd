@tool
extends MeshInstance3D

const Kit := preload("res://assets/salvage/kit.gd")

@export_enum("Fuel", "Coil", "Scrap", "Exit", "Track") var module: String = "Fuel":
	set(value):
		module = value
		if is_inside_tree():
			_bind()

func _ready() -> void:
	_bind()

func _bind() -> void:
	Kit.load_meshes()
	mesh = Kit.meshes[module]
	material_override = Kit.PAINT
