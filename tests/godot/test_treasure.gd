extends "res://qa/support.gd"

const SCENE := "res://treasure/treasure.tscn"
const Policy := preload("res://treasure/lobby_intent.gd")
const KINDS := ["create", "select", "confirm-solo", "confirm-duo", "cancel"]
var hosts: Array[SubViewport] = []
var cases: Array[String] = []
var boundary

class NetBoundary extends Node:
	signal changed
	signal acknowledged(sequence: int, error: String)
	var state: Dictionary = {}
	var message := ""
	var receiving_frames := false
	var handoffs: Array = []
	func connect_mission(host: String, port: int, admission: Dictionary) -> void:
		handoffs.append({"host": host, "port": port, "admission": admission.duplicate(true)})
	func disconnect_mission() -> void:
		state.clear()
		receiving_frames = false

func before_each() -> void:
	assert_null(get_tree().root.get_node_or_null("Treasure"), "Own only this fixture's passive transport boundary")
	boundary = NetBoundary.new()
	boundary.name = "Treasure"
	get_tree().root.add_child(boundary)

func after_each() -> void:
	for case: String in cases:
		for number: int in [1, 2, 3]:
			release(case, number)
	for host: SubViewport in hosts:
		if is_instance_valid(host): host.queue_free()
	await wait_idle_frames(3)
	if is_instance_valid(boundary): boundary.queue_free()
	await wait_idle_frames(2)
	hosts.clear()
	cases.clear()

func events(case: String, method: String = "", event: String = "request_begin") -> Array:
	var result: Array = []
	var path := OS.get_environment("PILOT_HTTP_EVENTS")
	if not FileAccess.file_exists(path): return result
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	if not text.ends_with("\n"): lines.resize(maxi(0, lines.size() - 1))
	for line: String in lines:
		if line.is_empty(): continue
		var row: Variant = JSON.parse_string(line)
		if not row is Dictionary: return [] # Final independent journal validation reports malformed complete rows.
		if row is Dictionary and row.get("case") == case and row.get("event") == event and (method.is_empty() or row.get("method") == method):
			result.append(row)
	return result

func release(case: String, number: int = 2) -> void:
	var path := OS.get_environment("PILOT_TREASURE_CONTROL").path_join(case + ".get%d.release" % number)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Release only this fixture's held read")
	if file != null:
		file.store_string("release")
		file.close()

func attempted_response(case: String, number: int) -> bool:
	return events(case, "GET", "response_attempt").any(func(row: Dictionary): return int(row.number) == number)

func panel(case: String, endpoint: String = ""):
	cases.append(case)
	var view = load(SCENE).instantiate()
	view.endpoint = OS.get_environment("PILOT_HTTP_URL") + "/treasure-case/" + case if endpoint.is_empty() else endpoint
	view.token = "public-fixture-only-not-an-account"
	var host := SubViewport.new()
	host.size = Vector2i(960, 540)
	host.disable_3d = true
	host.handle_input_locally = true
	add_child(host)
	hosts.append(host)
	host.add_child(view)
	return view

func ready_panel(case: String):
	var view = panel(case)
	assert_true(await wait_until(func(): return view.view_valid and not view.busy, 3.0), "Real first HTTP response made this view valid: " + case)
	return view

func choose_pair(view, kind: String) -> void:
	if kind != "confirm-solo": return
	var check: CheckButton = view.checks.get("r-a")
	assert_not_null(check)
	if check != null and not check.button_pressed:
		view.get_node("HUD/Lobby/Column/Scroll").ensure_control_visible(check)
		await click(check)

func refresh_held(view, case: String) -> void:
	# Schedule the production poll timer; do not call its completion callback.
	view.polling = 2.0
	assert_true(await wait_until(func(): return events(case, "GET").size() >= 2 and view.busy, 3.0), "Production poll reached a held actual GET")

func press_operation(view, kind: String) -> void:
	var name: String = {"create": "Start", "select": "Submit", "confirm-solo": "Station", "confirm-duo": "Station", "cancel": "Claim"}[kind]
	await click(view.get_node("%" + name))

func press_disabled(button: BaseButton) -> void:
	assert_true(button.disabled)
	await wait_idle_frames(2)
	var point := button.get_global_rect().get_center()
	for down: bool in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		input.position = point
		input.global_position = point
		input.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		button.get_viewport().push_input(input, true)
		await wait_idle_frames(2)
	print("TREASURE_DISABLED_POINTER target=", button.name, " point=", point)

func expected_body(view, kind: String) -> Dictionary:
	match kind:
		"create": return {"event": view.overview.event.id, "friend": ""}
		"select": return {"group": view.overview.group.id, "revision": 3, "robots": ["r-z", "r-a"]}
		"confirm-solo": return {"group": view.overview.group.id, "risk": true, "robots": ["r-z", "r-a"]}
		"confirm-duo": return {"group": view.overview.group.id, "risk": true, "revision": 3}
		"cancel": return {"group": view.overview.group.id}
	return {}

func close_panel(view) -> void:
	if not view.closing: await click(view.get_node("%Back"))

func test_initial_view_has_no_writable_controls() -> void:
	var case := "initial-create"
	var view = panel(case)
	assert_true(await wait_until(func(): return not events(case, "GET").is_empty(), 3.0))
	for name: String in ["Start", "Submit", "Station", "Claim"]:
		assert_true(view.get_node("%" + name).disabled)
	assert_false(view.view_valid)
	# A disabled real control receives pointer events, but cannot create intent.
	await press_disabled(view.get_node("%Start"))
	assert_true(view.pending_intent.is_empty())
	assert_eq(events(case, "POST").size(), 0)
	release(case, 1)
	assert_true(await wait_until(func(): return view.view_valid, 3.0))
	assert_false(view.get_node("%Start").disabled)
	await close_panel(view)

func test_recheck_five_positive_branches_preserve_exact_body_and_one_write() -> void:
	for case: String in ["positive-create", "positive-select", "positive-confirm-solo", "positive-confirm-duo", "positive-cancel", "empty-create"]:
		var kind := "create" if case == "empty-create" else case.trim_prefix("positive-")
		var view = await ready_panel(case)
		await choose_pair(view, kind)
		var body := expected_body(view, kind)
		await refresh_held(view, case)
		await press_operation(view, kind)
		assert_false(view.pending_intent.is_empty(), "One real pointer-created pending intent: " + kind)
		if kind == "create":
			var captured = view.pending_intent.duplicate(true)
			await press_disabled(view.get_node("%Start"))
			assert_eq(view.pending_intent, captured, "A second disabled pointer action cannot replace the pending body")
		if kind == "cancel":
			var check: CheckButton = view.checks["r-a"]
			view.get_node("HUD/Lobby/Column/Scroll").ensure_control_visible(check)
			await click(check)
		release(case)
		assert_true(await wait_until(func(): return events(case, "POST").size() == 1 and not view.busy, 3.0))
		var writes := events(case, "POST")
		if not writes.is_empty():
			var actual: Dictionary = writes[0].body.duplicate(true)
			if actual.has("revision"):
				assert_eq(writes[0].body_field_types.get("revision"), "int", "Fixture parsed the actual wire number as an integer, not3.0")
				assert_eq(float(actual.revision), float(int(actual.revision)))
				actual.revision = int(actual.revision) # JSON readback only; independent Python also verifies raw int3.
			assert_eq(actual, body, "Exact keys/order remain original: " + kind)
		assert_true(view.pending_intent.is_empty())
		assert_eq(writes.size(), 1)
		await close_panel(view)

func test_five_failed_reads_discard_pending_and_do_not_resurrect() -> void:
	for kind: String in KINDS:
		var case := "failed-" + kind
		var view = await ready_panel(case)
		await choose_pair(view, kind)
		await refresh_held(view, case)
		await press_operation(view, kind)
		release(case)
		assert_true(await wait_until(func(): return not view.busy and not view.view_valid, 3.0))
		assert_true(view.pending_intent.is_empty())
		assert_eq(events(case, "POST").size(), 0)
		view.polling = 2.0
		assert_true(await wait_until(func(): return view.view_valid and events(case, "GET").size() >= 3, 3.0))
		assert_eq(events(case, "POST").size(), 0, "Later valid poll cannot revive a failed intent")
		await close_panel(view)

func test_five_related_context_changes_do_not_rebuild_a_different_write() -> void:
	for kind: String in KINDS:
		var case := "changed-" + kind
		var view = await ready_panel(case)
		await choose_pair(view, kind)
		await refresh_held(view, case)
		await press_operation(view, kind)
		release(case)
		assert_true(await wait_until(func(): return view.view_valid and not view.busy, 3.0))
		assert_eq(events(case, "POST").size(), 0)
		assert_true(view.pending_intent.is_empty())
		assert_false(view.get_node("%Feedback").text.is_empty())
		await close_panel(view)

func invalid_read_case(case: String, kind: String = "create") -> void:
	var view = await ready_panel(case)
	await refresh_held(view, case)
	await press_operation(view, kind)
	release(case)
	assert_true(await wait_until(func(): return not view.view_valid and not view.busy, 3.0))
	assert_true(view.pending_intent.is_empty())
	for name: String in ["Start", "Submit", "Station", "Claim"]:
		assert_true(view.get_node("%" + name).disabled, "Invalid view disables every write branch")
	assert_eq(events(case, "POST").size(), 0)
	await close_panel(view)

func test_bad_json_200_cannot_consume_a_pending_intent() -> void:
	await invalid_read_case("bad-json-create")

func test_bad_structure_200_cannot_consume_a_pending_intent() -> void:
	await invalid_read_case("bad-structure-create")
	await invalid_read_case("bad-member-confirm-duo", "confirm-duo")

func test_actual_seven_second_get_timeout_invalidates_intent() -> void:
	var case := "timeout-create"
	var view = await ready_panel(case)
	await refresh_held(view, case)
	await press_operation(view, "create")
	assert_eq(view.get_node("HTTP").timeout, 7.0, "Production timeout not shortened for the test")
	assert_true(await wait_until(func(): return not view.view_valid and not view.busy, 9.0))
	assert_true(view.pending_intent.is_empty())
	assert_eq(events(case, "POST").size(), 0)
	await close_panel(view)

func test_back_invalidates_before_closed_and_late_response() -> void:
	var case := "closing-create"
	var view = await ready_panel(case)
	await refresh_held(view, case)
	await press_operation(view, "create")
	var observed: Array = []
	view.closed.connect(func(): observed.append({"closing": view.closing, "pending_empty": view.pending_intent.is_empty(), "request_absent": view.active_http == null}))
	await close_panel(view)
	assert_eq(observed, [{"closing": true, "pending_empty": true, "request_absent": true}], "Synchronous parent callback sees the page already retired")
	assert_true(is_instance_valid(view), "Keep the closed production scene alive across the late response")
	release(case)
	assert_true(await wait_until(func(): return attempted_response(case, 2), 3.0))
	await wait_idle_frames(4)
	assert_true(view.closing)
	assert_false(view.busy)
	assert_eq(events(case, "POST").size(), 0)

func test_old_page_late_response_does_not_mutate_fresh_page() -> void:
	var case := "old-page-create"
	var old = await ready_panel(case)
	await refresh_held(old, case)
	await press_operation(old, "create")
	await close_panel(old)
	var fresh = await ready_panel("fresh-page-create")
	var expected = fresh.overview.duplicate(true)
	release(case)
	assert_true(await wait_until(func(): return attempted_response(case, 2), 3.0))
	await wait_idle_frames(4)
	assert_eq(fresh.overview, expected)
	assert_true(fresh.view_valid)
	assert_false(fresh.busy)
	assert_eq(events(case, "POST").size(), 0)
	await close_panel(fresh)

func test_controlled_retirement_keeps_new_request_busy_until_its_response() -> void:
	# Explicit lifecycle injection, not a claim that this is a player button.
	# Both old and new responses still originate from actual HTTP sockets.
	var case := "retire-create"
	var view = await ready_panel(case)
	await refresh_held(view, case)
	await press_operation(view, "create")
	var expected = view.pending_intent.body.duplicate(true)
	var old_number: int = view.request_number
	view._retire_request()
	assert_null(view.active_http)
	view.polling = 2.0
	assert_true(await wait_until(func(): return view.busy and events(case, "GET").size() >= 3, 3.0))
	var active = view.active_http
	var number: int = view.request_number
	assert_gt(number, old_number)
	release(case, 2)
	assert_true(await wait_until(func(): return attempted_response(case, 2), 3.0))
	await wait_idle_frames(4)
	assert_true(view.busy, "Retired old response cannot complete the new held GET")
	assert_eq(view.active_http, active)
	assert_eq(view.request_number, number)
	assert_eq(events(case, "POST").size(), 0)
	release(case, 3)
	assert_true(await wait_until(func(): return not view.busy and events(case, "POST").size() == 1, 3.0))
	assert_eq(events(case, "POST")[0].body, expected)
	await close_panel(view)

func test_admission_clears_pending_before_passive_transport_handoff() -> void:
	var case := "admission-confirm-duo"
	var view = await ready_panel(case)
	await refresh_held(view, case)
	await press_operation(view, "confirm-duo")
	release(case)
	assert_true(await wait_until(func(): return view.attached, 3.0))
	assert_true(view.pending_intent.is_empty())
	assert_eq(events(case, "POST").size(), 0)
	assert_eq(boundary.handoffs.size(), 1, "Only the scene handoff is asserted; no ENet session is created")

func test_unknown_post_only_reads_current_fact_and_never_reposts() -> void:
	var case := "unknown-create"
	var view = await ready_panel(case)
	await press_operation(view, "create")
	assert_true(await wait_until(func(): return events(case, "POST").size() == 1 and events(case, "GET").size() >= 2, 9.0))
	assert_false(view.view_valid, "The production recovery read is held after the dropped write response")
	release(case)
	view.polling = 2.0
	assert_true(await wait_until(func(): return view.view_valid and view.overview.group != null, 3.0))
	assert_eq(events(case, "POST").size(), 1)
	assert_false(events(case, "POST", "simulated_commit_response_withheld").is_empty())
	assert_eq(view.overview.group.phase, "forming", "Observed fixture state is not a recovered operation receipt")
	await close_panel(view)

func test_recheck_sync_start_error_retires_request_before_recovery() -> void:
	print("TREASURE_SYNC_BEGIN case=test_recheck_sync_start_error_retires_request_before_recovery")
	var view = panel("sync-create", "ftp://127.0.0.1")
	await wait_idle_frames(3)
	assert_engine_error("Invalid URL scheme: 'ftp://'.")
	assert_engine_error_count(1) # GUT9.6.1 counts all test errors, including handled ones; this is total, not remaining.
	assert_false(view.view_valid)
	assert_false(view.busy)
	assert_null(view.active_http)
	assert_true(view.pending_intent.is_empty())
	assert_true(view.get_node("%Start").disabled)
	print("TREASURE_SYNC_END case=test_recheck_sync_start_error_retires_request_before_recovery")
	# Configuration-fault injection only; not a normal player's endpoint.
	view.endpoint = OS.get_environment("PILOT_HTTP_URL") + "/treasure-case/sync-create"
	view.polling = 2.0
	assert_true(await wait_until(func(): return view.view_valid and not view.busy, 3.0))
	assert_false(view.get_node("%Start").disabled)
	assert_eq(events("sync-create", "POST").size(), 0)
	await close_panel(view)

func samples() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PILOT_TREASURE_SAMPLES")))

func test_policy_related_fields_and_legal_empty_view_contract() -> void:
	var policy = Policy.new()
	for kind: String in KINDS:
		var view: Dictionary = samples()[kind]
		var action := "confirm" if kind.begins_with("confirm-") else kind
		var intent: Dictionary = policy.capture(action, view, ["r-z", "r-a"], "")
		assert_false(intent.is_empty())
		var changed := view.duplicate(true)
		if kind == "create": changed.played = true
		elif kind == "cancel": changed.group.id = "other-group"
		elif kind == "select": changed.group.members[1].name = "Other member"
		else: changed.roster[0].points = 3
		assert_eq(policy.revalidate(intent, changed, ["r-z", "r-a"], "").decision, "discard", "Relevant field cannot silently become a new body: " + kind)
	var empty: Dictionary = samples()["create"]
	empty.roster = []
	assert_true(policy.valid_view(empty), "Legal empty roster/null group/null last remains valid")
	assert_false(policy.capture("create", empty, [], "").is_empty())
	var cancel: Dictionary = samples()["cancel"]
	var pending: Dictionary = policy.capture("cancel", cancel, ["r-z"], "")
	cancel.group.phase = "queued"
	assert_eq(policy.revalidate(pending, cancel, [], "").decision, "send")

func test_policy_body_is_deep_snapshot_and_keeps_original_robot_order() -> void:
	var policy = Policy.new()
	var view: Dictionary = samples()["select"]
	var original := view.duplicate(true)
	var ids := ["r-z", "r-a"]
	var intent: Dictionary = policy.capture("select", view, ids, "")
	ids.reverse()
	view.group.revision = 99
	assert_eq(intent.body.robots, ["r-z", "r-a"])
	assert_eq(intent.body.revision, 3)
	var decision: Dictionary = policy.revalidate(intent, original, ids, "")
	assert_eq(decision.decision, "send", "Selection set equivalence does not reorder captured body")
	assert_eq(decision.body.robots, ["r-z", "r-a"])
	decision.body.robots.clear()
	assert_eq(intent.body.robots, ["r-z", "r-a"], "Returned body cannot mutate the captured intent")
