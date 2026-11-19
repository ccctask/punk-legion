extends Node3D

@export var finish:Material
func _ready() -> void:
	$Deck.material_override=finish
