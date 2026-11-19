extends Node3D

func set_powered(active:bool) -> void:
	set_process(active)
	$DishMount/Receiver/Beacon.visible=active

func _process(delta:float) -> void:
	$DishMount.rotate_y(delta*0.85)
