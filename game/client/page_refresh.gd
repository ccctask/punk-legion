extends Node

## A page owns requests and business state; this child only schedules a read.
signal read_due

var interval_seconds := 10.0
var active: Callable
var available: Callable
var foreground := true
var in_flight := false
var queued := false
var queued_wake := false
var terminal := false
var failures := 0
var deadline_ms := 0
var was_active := false
var lease_id := 0

func configure(is_active: Callable, can_read: Callable, seconds := 10.0) -> void:
	active = is_active
	available = can_read
	interval_seconds = maxf(1.0, seconds)
	terminal = false
	failures = 0
	lease_id += 1
	in_flight = false
	was_active = false
	queued_wake = false
	request_now()

func request_now() -> void:
	queued = true

func retry_now() -> void:
	if terminal:
		return
	deadline_ms = 0
	request_now()

func current_lease() -> int:
	return lease_id

func settled(success: bool, stop := false, lease := -1) -> void:
	if lease >= 0 and lease != lease_id:
		return
	# An initial/explicit owner read also establishes freshness. A due arriving
	# during our own in-flight read remains one queued follow-up.
	if not in_flight:
		queued = queued_wake
	in_flight = false
	terminal = stop
	failures = 0 if success else mini(failures + 1, 3)
	var delay := interval_seconds if success else float([5, 10, 20][failures - 1])
	deadline_ms = Time.get_ticks_msec() + int(delay * 1000.0)
	was_active = foreground and active.is_valid() and bool(active.call())

func defer(lease := -1) -> void:
	if lease >= 0 and lease != lease_id:
		return
	in_flight = false
	queued = true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		foreground = false
		_suspend()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		foreground = true
		queued_wake = true
		request_now()

func _process(_delta: float) -> void:
	var visible_page := foreground and active.is_valid() and bool(active.call())
	if not visible_page:
		_suspend()
		return
	if not was_active:
		was_active = true
		request_now()
	if terminal or in_flight or not available.is_valid() or not bool(available.call()):
		return
	if queued or Time.get_ticks_msec() >= deadline_ms:
		queued = false
		queued_wake = false
		in_flight = true
		lease_id += 1
		read_due.emit()

func _suspend() -> void:
	if was_active or in_flight:
		lease_id += 1
		queued_wake = true
		in_flight = false
		queued = true
	was_active = false
