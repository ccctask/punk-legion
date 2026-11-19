extends "res://qa/support.gd"

# Actual production scheduler + actual HTTPRequest; these transport snapshots
# do not stand in for a profile, transaction, or gameplay receipt.
var contexts: Array[Dictionary] = []

func make_context(case_name: String, active := true) -> Dictionary:
	var scheduler: Node = load("res://client/page_refresh.tscn").instantiate()
	add_child_autofree(scheduler)
	var ctx := {"scheduler":scheduler,"active":active,"available":true,"busy":false,
		"case":case_name,"issued":0,"completed":0,"snapshots":[],"http":null,"closed":false}
	contexts.append(ctx)
	scheduler.read_due.connect(func(): issue(ctx))
	scheduler.configure(func(): return ctx.active, func(): return ctx.available and not ctx.busy, 10.0)
	return ctx

func issue(ctx: Dictionary) -> void:
	if ctx.closed:
		fail_test("Destroyed owner issued another read")
		return
	assert_false(ctx.busy, "Scheduler must not overlap the actual HTTP slot")
	if ctx.busy:
		return
	var request := HTTPRequest.new()
	ctx.scheduler.add_child(request)
	ctx.http = request
	ctx.busy = true
	ctx.issued += 1
	var lease: int = ctx.scheduler.current_lease()
	request.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray):
		if ctx.closed or ctx.http != request:
			return
		ctx.http = null
		ctx.busy = false
		ctx.completed += 1
		var okay := result == HTTPRequest.RESULT_SUCCESS and status == 200
		if okay:
			ctx.snapshots.append(JSON.parse_string(body.get_string_from_utf8()))
		ctx.scheduler.settled(okay, status == 401, lease)
		request.queue_free(), CONNECT_ONE_SHOT)
	var error := request.request(OS.get_environment("PILOT_HTTP_URL") + "/qa/page-refresh/" + ctx.case)
	assert_eq(error, OK, "A real GET must start")
	if error != OK:
		ctx.http = null
		ctx.busy = false
		ctx.scheduler.settled(false, false, lease)
		request.queue_free()

func refresh_event_count(case_name: String, event: String) -> int:
	var count := 0
	for row: Dictionary in fixture_events():
		if row.get("refresh_case") == case_name and row.get("event") == event:
			count += 1
	return count

func release_case(case_name: String) -> void:
	var file := FileAccess.open(OS.get_environment("PILOT_REFRESH_CONTROL").path_join("refresh-release-" + case_name), FileAccess.WRITE)
	assert_not_null(file, "This run owns its fixture release file")
	if file:
		file.store_string("release")
		file.close()

func mark_cancel(case_name: String, number: int) -> void:
	var file := FileAccess.open(OS.get_environment("PILOT_REFRESH_CONTROL").path_join("refresh-cancel-%s-%d" % [case_name, number]), FileAccess.WRITE)
	assert_not_null(file, "Cancellation is tied to this exact held request")
	if file:
		file.store_string("cancelled by this test owner")
		file.close()

func after_each() -> void:
	for ctx: Dictionary in contexts:
		ctx.closed = true
		if is_instance_valid(ctx.http):
			ctx.http.cancel_request()
	contexts.clear()

func test_activation_and_busy_due_merge_start_a_real_get() -> void:
	var ctx := make_context("ok", false)
	ctx.available = false
	for _i in 5:
		ctx.scheduler.request_now()
	await wait_idle_frames(4)
	assert_eq(ctx.issued, 0, "Hidden owner cannot start a GET")
	ctx.active = true
	await wait_idle_frames(4)
	assert_eq(ctx.issued, 0, "Available, not active, owns the busy/edit gate")
	ctx.available = true
	assert_true(await wait_until(func(): return ctx.completed == 1, 3.0))
	assert_eq(ctx.issued, 1, "All pending due signals coalesce")
	if ctx.snapshots.is_empty():
		return
	assert_eq(ctx.snapshots[0].fixture, "scheduler-transport-only")
	assert_gt(int(ctx.snapshots[0].revision), 0)

func test_focus_resume_during_real_held_get_queue_one_followup() -> void:
	var ctx := make_context("hold-a")
	assert_true(await wait_until(func(): return refresh_event_count("hold-a", "refresh_request_begin") == 1, 3.0))
	var lease: int = ctx.scheduler.current_lease()
	for _i in 4:
		ctx.scheduler.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		ctx.scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await wait_idle_frames(4)
	assert_eq(ctx.issued, 1)
	assert_eq(ctx.scheduler.current_lease(), lease, "Focus does not create overlapping leases")
	ctx.case = "ok"
	release_case("hold-a")
	assert_true(await wait_until(func(): return ctx.completed == 2, 3.0))
	await wait_idle_frames(4)
	assert_eq(ctx.issued, 2, "Exactly one queued followup after the old GET")

func test_hidden_cancel_reopen_invalidates_old_settled_and_defer() -> void:
	var ctx := make_context("hold-b")
	assert_true(await wait_until(func(): return refresh_event_count("hold-b", "refresh_request_begin") == 1, 3.0))
	var old_lease: int = ctx.scheduler.current_lease()
	ctx.scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	mark_cancel("hold-b", 1)
	ctx.http.cancel_request()
	ctx.http.queue_free()
	ctx.http = null
	ctx.busy = false
	await wait_idle_frames(3)
	assert_eq(ctx.issued, 1, "Focus-out stops reads even while the page stays visible")
	assert_false(ctx.scheduler.foreground)
	ctx.active = false
	await wait_idle_frames(2)
	ctx.active = true
	ctx.scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(await wait_until(func(): return refresh_event_count("hold-b", "refresh_request_begin") == 2, 3.0))
	var new_lease: int = ctx.scheduler.current_lease()
	assert_ne(new_lease, old_lease)
	ctx.scheduler.settled(true, false, old_lease)
	ctx.scheduler.defer(old_lease)
	assert_true(ctx.scheduler.in_flight, "An old completion cannot unlock the new real GET")
	assert_eq(ctx.scheduler.current_lease(), new_lease)
	release_case("hold-b")
	assert_true(await wait_until(func(): return ctx.completed == 1, 3.0))
	assert_eq(ctx.issued, 2, "Cancellation without callback cannot strand reopen")

func test_real_failure_recovers_automatically_and_401_stops_reads() -> void:
	var ctx := make_context("fail-once")
	assert_true(await wait_until(func(): return ctx.completed == 1, 3.0))
	var left: int = ctx.scheduler.deadline_ms - Time.get_ticks_msec()
	assert_between(left, 4000, 5100, "First failure respects the signed five-second backoff")
	assert_true(await wait_until(func(): return ctx.completed == 2, 7.0), "No manual refresh after a real 503")
	assert_eq(ctx.issued, 2)
	assert_eq(refresh_event_count("fail-once", "refresh_response_sent"), 2)
	var auth := make_context("unauthorized")
	assert_true(await wait_until(func(): return auth.completed == 1, 3.0))
	for _i in 3:
		auth.scheduler.request_now()
		auth.scheduler.retry_now()
	await wait_idle_frames(5)
	assert_eq(auth.issued, 1, "401 is not a reason to replay login or write operations")
	assert_true(auth.scheduler.terminal)

func test_free_component_cancels_real_http_and_never_restarts() -> void:
	var ctx := make_context("hold-c")
	assert_true(await wait_until(func(): return refresh_event_count("hold-c", "refresh_request_begin") == 1, 3.0))
	ctx.closed = true
	mark_cancel("hold-c", 1)
	ctx.scheduler.queue_free()
	await wait_idle_frames(3)
	release_case("hold-c")
	assert_true(await wait_until(func(): return refresh_event_count("hold-c", "refresh_response_attempt") == 1, 3.0))
	assert_eq(ctx.issued, 1)
	assert_eq(ctx.completed, 0, "No callback may update a destroyed owner")

func test_configure_new_context_rejects_old_completion() -> void:
	var ctx := make_context("ok")
	assert_true(await wait_until(func(): return ctx.completed == 1, 3.0))
	var old_lease: int = ctx.scheduler.current_lease()
	ctx.available = false
	ctx.scheduler.configure(func(): return ctx.active, func(): return ctx.available and not ctx.busy, 10.0)
	ctx.scheduler.settled(true, false, old_lease)
	ctx.scheduler.defer(old_lease)
	ctx.available = true
	assert_true(await wait_until(func(): return ctx.completed == 2, 3.0))
	assert_eq(ctx.issued, 2)
	assert_gt(ctx.scheduler.current_lease(), old_lease)

func test_explicit_initial_owner_get_preserves_one_foreground_wake() -> void:
	var ctx := make_context("hold-d")
	# The real owner starts its initial GET before the scheduler emits read_due.
	issue(ctx)
	assert_true(await wait_until(func(): return refresh_event_count("hold-d", "refresh_request_begin") == 1, 3.0))
	assert_false(ctx.scheduler.in_flight, "This request came from the initial owner, not read_due")
	for _i in 3:
		ctx.scheduler.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		ctx.scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await wait_idle_frames(3)
	assert_eq(ctx.issued, 1, "Initial HTTP slot still blocks a second GET")
	ctx.case = "ok"
	release_case("hold-d")
	assert_true(await wait_until(func(): return ctx.completed == 2, 3.0), "A real foreground wake survives initial GET settlement")
	await wait_idle_frames(4)
	assert_eq(ctx.issued, 2, "Only one wake GET, not one per notification")
