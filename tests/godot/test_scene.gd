extends "res://qa/support.gd"

func snapshot() -> Dictionary:
	return {"self": "owner-a", "roomscope": {"id": "pilot-room", "code": "ABCDEFGH", "leader": "owner-a", "members": [
		{"owner": "owner-a", "name": "Copper", "robots": [], "ready": false, "points": 0}
	]}, "robots": [{"id": "robot-a", "name": "Copper", "points": 2, "ready": true},
		{"id": "robot-b", "name": "Tin", "points": 3, "ready": true}],
		"departure_quote": {"source": "energy", "energy": 5}}

func test_real_lobby_read_gate_draft_and_pointer_request() -> void:
	var panel = add_panel("res://party/lobby.tscn")
	await wait_idle_frames(2)
	for name: String in panel.SUBMIT_BUTTONS:
		assert_true(panel.get_node("%" + name).disabled, "Initial unconfirmed scene protects " + name)
	panel.refresh(snapshot())
	assert_true(panel.get_node("%Ready").disabled, "A snapshot cannot silently bypass explicit read confirmation")
	panel.set_read_available(true)
	watch_signals(panel)
	assert_eq(panel.selected, ["robot-a"])
	await click(panel.robot_buttons["robot-b"])
	assert_eq(panel.selected, ["robot-a", "robot-b"])
	panel.refresh(snapshot())
	assert_eq(panel.selected, ["robot-a", "robot-b"], "Healthy refresh preserves actual pointer-selected draft")
	await click(panel.get_node("%Ready"))
	assert_signal_emit_count(panel, "request", 0 if negative("scene") else 1, "Real pointer input produced one preparation intent")
	var emitted = get_signal_parameters(panel, "request")
	if emitted == null: return
	assert_eq(emitted[0], "/v1/party/ready")
	assert_eq(emitted[1].robots, ["robot-a", "robot-b"])
	panel.set_read_available(false)
	assert_true(panel.get_node("%Ready").disabled)
	assert_false(panel.action_available("/v1/party/ready"))
	assert_eq(panel.selected, ["robot-a", "robot-b"])
	panel.set_read_available(true)
	assert_true(panel.action_available("/v1/party/ready"))
