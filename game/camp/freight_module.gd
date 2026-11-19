extends Node3D

const Kit:=preload("res://assets/salvage/kit.gd")
@export_enum("Scrap","Cover","Track","Coil","Exit","Signal") var module:String="Scrap"
@export var dimensions:=Vector3.ONE

func _ready() -> void:
	var surface:=Kit.part(module)
	var bounds:=surface.get_aabb()
	surface.scale=dimensions/bounds.size
	surface.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*surface.scale
	surface.lod_bias=0.12
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
