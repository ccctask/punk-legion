extends Node3D

const Paint := preload("res://assets/base_art/enamel.tres")

@export_range(0.05,1.0,0.05) var lod_bias := 1.0

func _ready() -> void:
	for node in $Model.find_children("*","MeshInstance3D",true,false):
		node.material_override = Paint
		node.lod_bias=lod_bias
