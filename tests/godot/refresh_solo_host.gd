extends SceneTree
# Production Solo Autoload owns the simulation, ENet and settlement.
# This QA host only verifies its actual 20Hz context and observes one stop file.
func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	if Engine.physics_ticks_per_second != 20 or not root.get_node("Solo").server:
		push_error("G host must use the actual Solo server and fixed 20Hz settings")
		quit(1)
		return
	print("REFRESH_SOLO_HOST_READY physics_hz=", Engine.physics_ticks_per_second)

func _process(_delta: float) -> bool:
	if FileAccess.file_exists(OS.get_environment("PILOT_SOLO_STOP")):
		quit(0)
	return false
