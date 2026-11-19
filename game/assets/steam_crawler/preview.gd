extends Node3D

func _ready() -> void:
	$Camera.look_at(Vector3.UP * 0.85)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: $Robot.set_motion(false)
			KEY_2: $Robot.set_motion(true)
			KEY_3: $Robot.play_action(&"Attack")
			KEY_4: $Robot.play_action(&"Death")
			KEY_H: $Robot.head = 1 - $Robot.head
			KEY_W: $Robot.weapon = 1 - $Robot.weapon
