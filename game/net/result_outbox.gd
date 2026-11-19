extends HTTPRequest

var directory := ""
var endpoint := ""
var key_file := ""
var inflight := ""
var deliveries: Array = []
var legacy := false
var next_check := 0
var retry_at := {}

func _ready() -> void:
	directory = OS.get_environment("ROOM_OUTBOX_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("user://result-outbox")
	endpoint = OS.get_environment("ROOM_RESULTS_URL")
	key_file = OS.get_environment("ROOM_AUTH_FILE")
	timeout = 4
	request_completed.connect(_completed)
	DirAccess.make_dir_recursive_absolute(directory)

func _atomic_write(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".tmp", path) == OK

func enqueue(battle: String, tickets: Dictionary, winner: int, reports: Dictionary = {}, finished_at := 0) -> bool:
	if tickets.is_empty():
		return true
	var path := directory.path_join(battle + ".json")
	if FileAccess.file_exists(path):
		return true
	var outcome: String = {0:"win", 1:"loss", -1:"draw"}[winner]
	var rows := []
	for seat in tickets:
		var row := {"ticket":tickets[seat], "battle":battle, "outcome":outcome}
		if reports.has(seat):
			row.report = reports[seat]
			row.finished_at = finished_at
		rows.append(row)
	next_check = 0
	return _atomic_write(path, {"deliveries":rows})

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if endpoint.is_empty() or not inflight.is_empty() or now < next_check:
		return
	next_check = now + 1000
	if not FileAccess.file_exists(key_file):
		return
	var key := FileAccess.get_file_as_string(key_file).strip_edges()
	if key.is_empty():
		return
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".json") or now < int(retry_at.get(name, 0)):
			continue
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		if not record is Dictionary:
			continue
		legacy = not record.has("deliveries")
		deliveries = [record] if legacy else record.deliveries
		if deliveries.is_empty():
			continue
		var error := request(endpoint, ["Content-Type: application/json", "Authorization: Bearer " + key], HTTPClient.METHOD_POST, JSON.stringify(deliveries[0]))
		if error == OK:
			inflight = name
		else:
			retry_at[name] = now + 5000
		return

func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var name := inflight
	inflight = ""
	var path := directory.path_join(name)
	var consumed := false
	if result == HTTPRequest.RESULT_SUCCESS:
		if status == 200:
			var response: Variant = JSON.parse_string(body.get_string_from_utf8())
			consumed = response is Dictionary and response.get("receipt") is Dictionary
		elif status in [400, 404, 409]:
			var rejected_path := path + "-" + str(deliveries.size()) + ".rejected"
			consumed = _atomic_write(rejected_path, deliveries[0])
			push_warning("Result delivery rejected: %s HTTP %d" % [name, status])
	if consumed:
		deliveries.pop_front()
		if deliveries.is_empty():
			consumed = DirAccess.remove_absolute(path) == OK
		else:
			consumed = _atomic_write(path, {"deliveries":deliveries})
	if consumed:
		retry_at.erase(name)
	else:
		retry_at[name] = Time.get_ticks_msec() + 5000
