@tool
extends Node3D

const BipedModel := preload("res://assets/steam_biped/model.glb")
static var housing: Mesh
static var spindle: Mesh

func _ready() -> void:
	if not housing:
		var source := BipedModel.instantiate()
		housing = source.find_child("SM_PLSB_Mobile_Cannon", true, false).mesh
		spindle = source.find_child("SM_PLSB_Mobile_Cannon_Recoil", true, false).mesh
		source.free()
	$Housing.mesh = housing
	$Spindle.mesh = spindle
