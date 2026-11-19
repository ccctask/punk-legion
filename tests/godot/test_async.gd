extends "res://qa/support.gd"

func open_preview(panel, robot: String) -> void:
	panel.open(OS.get_environment("PILOT_HTTP_URL"), "pilot-only-not-a-real-account", {"id": robot, "name": "Copper"}, {"id": "design-a", "name": "Starter", "revision": 1})

func test_preview_real_http_failure_and_explicit_refresh_success() -> void:
	var panel = add_panel("res://owned/apply_preview.tscn")
	await wait_idle_frames(2)
	var robot := "http-preview-timeout" if OS.get_environment("PILOT_FORCE_TIMEOUT") == "1" else "http-preview-a"
	open_preview(panel, robot)
	assert_true(await wait_until(func(): return has_http_event(robot, "request_begin"), 3.0), "Actual production HTTPRequest reached fixture")
	assert_true(await wait_until(func(): return panel.request == null, 15.0 if robot.ends_with("timeout") else 3.0), "Real HTTP completion reached the production scene")
	assert_true(has_http_event(robot, "response_sent", 500))
	assert_true(panel.get_node("%Confirm").disabled)
	assert_true(panel.get_node("%Reason").text.contains("未能读取"))
	await click(panel.get_node("%Refresh"))
	assert_true(await wait_until(func(): return panel.request == null and not panel.plan.is_empty(), 3.0))
	assert_true(has_http_event(robot, "response_sent", 200))
	if panel.plan.is_empty(): return
	assert_eq(panel.plan.robot, robot)
	assert_eq(panel.get_node("%Confirm").disabled, negative("async"), "A real matching 200 plan enables confirmation")
	watch_signals(panel)
	await click(panel.get_node("%Confirm"))
	assert_signal_emit_count(panel, "apply_requested", 1)
	assert_eq(get_signal_parameters(panel, "apply_requested")[0], {"robot": robot, "design": "design-a", "fingerprint": "pilot-fit-current"})

func test_dismiss_real_inflight_request_ignores_late_response() -> void:
	var panel = add_panel("res://owned/apply_preview.tscn")
	await wait_idle_frames(2)
	var robot := "http-preview-close"
	open_preview(panel, robot)
	assert_true(await wait_until(func(): return has_http_event(robot, "request_begin"), 3.0))
	assert_not_null(panel.request, "The real request is still held upstream")
	assert_false(has_http_event(robot, "response_attempt"))
	watch_signals(panel)
	await click(panel.get_node("%Cancel"))
	assert_signal_emit_count(panel, "dismissed", 1)
	assert_null(panel.request)
	assert_true(panel.plan.is_empty())
	assert_true(panel.target.is_empty())
	assert_false(panel.visible)
	assert_true(await wait_until(func(): return has_http_event(robot, "response_attempt"), 4.0), "Fixture attempted the late real response after UI dismissal")
	await wait_idle_frames(4)
	assert_false(panel.visible)
	assert_true(panel.plan.is_empty())
	assert_signal_not_emitted(panel, "apply_requested")
