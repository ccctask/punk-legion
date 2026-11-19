extends Node3D

func set_goals(_goals:Array) -> void:
	pass

func apply_state(frame:Dictionary) -> void:
	var pos:Array=frame.cart
	$FreightLine/Trolley.position=Vector3(pos[0],0,pos[1])
