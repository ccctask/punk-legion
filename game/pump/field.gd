extends "res://assets/salvage/yard.gd"

const PumpMission := preload("res://net/pump_mission.gd")
var sign_text := {}
var calibrated := {"valve_a": false, "valve_b": false}
var cache_taken := false

func _ready() -> void:
	Kit.load_meshes()
	for bounds in Mission.ROCKS:
		_cover(bounds)
	for key: String in PumpMission.POINTS:
		var landmark: Node3D = get_node(key)
		assert(Vector2(landmark.position.x, landmark.position.z).is_equal_approx(PumpMission.POINTS[key]), "泵站地标偏离权威目标 " + key)
		var sign: Label3D = landmark.get_node("Sign")
		labels[key] = sign
		sign_text[key] = sign.text

func set_goals(goals: Array) -> void:
	for key: String in labels:
		labels[key].modulate = Color.GOLD if key in goals else Color.LIGHT_GRAY

func update_progress(state: Dictionary) -> void:
	for valve: String in calibrated:
		var done: bool = valve in state.calibrated
		if done == calibrated[valve]:
			continue
		calibrated[valve] = done
		labels[valve].text = sign_text[valve] + (" · 已校准" if done else "")
		get_node(valve + "/Wheel").rotation.y = PI/2 if done else 0.0
	if state.cache_taken != cache_taken:
		cache_taken = state.cache_taken
		labels.cache.text = sign_text.cache + (" · 已领取" if cache_taken else "")
