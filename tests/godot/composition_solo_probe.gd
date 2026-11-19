extends "res://net/solo.gd"

# Typed observation substitute: no socket, RPC, persistence or service claims.
var observations: Array = []
var connection_epoch := 0

func _ready() -> void:
	set_physics_process(false)

func connect_mission(host: String, port: int, admission: Dictionary) -> void:
	connection_epoch += 1
	observations.append({"event":"connect","epoch":connection_epoch,"id":admission.get("id","")})
	credentials=admission.duplicate(true)
	seat_state="connecting"

func disconnect_mission() -> void:
	observations.append({"event":"disconnect","epoch":connection_epoch})
	seat_state="offline"
	state.clear()
	receipt.clear()
	credentials.clear()

func authorized() -> bool:
	return false

func can_command(_action: String) -> bool:
	return false

func command(action: String, selected: Array, target := "", pos := Vector2.ZERO) -> void:
	observations.append({"event":"command","action":action,"selected":selected.duplicate(),"target":target})

func count_event(event: String) -> int:
	return observations.filter(func(row): return row.event==event).size()
