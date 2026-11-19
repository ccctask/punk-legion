extends "res://qa/support.gd"
const Mission := preload("res://net/solo_mission.gd")
var account: Dictionary
var page: Node
var net: Node
var driving := false
var tick := 0.0
var last_stage := -1
var command_rows: Array = []

func api(route: String, fields: Dictionary = {}) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var error: int = http.request(OS.get_environment("PILOT_HTTP_URL") + route,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + str(account.token)]),
		HTTPClient.METHOD_GET if fields.is_empty() else HTTPClient.METHOD_POST,
		"" if fields.is_empty() else JSON.stringify(fields))
	assert_eq(error, OK)
	if error != OK:
		http.queue_free()
		return {}
	var response: Array = await http.request_completed
	assert_eq(response[0], HTTPRequest.RESULT_SUCCESS)
	assert_eq(response[1], 200, "Fresh data only through successful normal APIs")
	var payload: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	http.queue_free()
	return payload if payload is Dictionary else {}

func evidence(name: String, value: Variant) -> void:
	var file := FileAccess.open(OS.get_environment("PILOT_LOOT_EVIDENCE").path_join(name), FileAccess.WRITE)
	assert_not_null(file)
	if file:
		file.store_string(JSON.stringify(value))
		file.close()

func command(action: String, ids: Array, target := "") -> void:
	if not net.can_command(action) or int(net.state.seq) < int(net.seq): return
	var before: int = int(net.seq)
	net.command(action, ids, target)
	if int(net.seq) > before:
		command_rows.append({"action":action,"target":target,"seq":net.seq,"stage":net.state.stage,
			"elapsed":net.state.elapsed,"wall_msec":Time.get_ticks_msec()})
		if action == "route": last_stage = int(net.state.stage)

func _process(delta: float) -> void:
	if not driving or net == null or net.state.is_empty() or not net.receipt.is_empty(): return
	tick += delta
	if tick < .2: return
	tick = 0
	var state: Dictionary = net.state
	if not state.outcome.is_empty(): return
	var ids: Array = []
	for id: String in state.units:
		if int(state.units[id].side) == 0 and float(state.units[id].hp) > 0: ids.append(id)
	if ids.is_empty(): return
	var target: String = str(state.goals[0])
	if last_stage != int(state.stage):
		command("route", ids, target)
		return
	# Same normal route/collect/repair policy as the existing real Solo peer.
	if int(state.stage) in [0,2,4] and state.units[ids[0]].pos.distance_to(Mission.LOCATIONS[target]) < 3.3:
		command("collect", ids, target)
	if int(state.repairs) > 0 and float(state.units[ids[0]].hp) < 48:
		command("repair", ids)

func after_each() -> void:
	driving = false
	if net != null: net.disconnect_mission()
	if is_instance_valid(page): page.queue_free()
	evidence("commands.json", command_rows)
	await wait_idle_frames(3)

func test_real_first_solo_win_entity_auto_visible_and_installed() -> void:
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PILOT_PAGE_ACCOUNTS")))
	account = accounts[0]
	page = load("res://owned/workshop.tscn").instantiate()
	page.endpoint = OS.get_environment("PILOT_HTTP_URL")
	page.token = account.token
	page.account = account.owner
	page.open_garage = true
	add_child(page)
	assert_true(await wait_until(func(): return not page.busy and not page.data.is_empty(), 5))
	if page.data.is_empty(): return
	var before_ids: Array = page.data.available.map(func(item): return item.id)
	var robot: Dictionary = page.data.robots[page.get_node("%Robot").get_selected_id()]
	var original_weapon: String = str(robot.slots.weapon.id)
	var start: Dictionary = await api("/v1/expedition/start", {"key":"g-first-solo-start","robots":[robot.id]})
	assert_true(start.get("expedition",{}).get("active") is Dictionary)
	if not start.get("expedition",{}).get("active") is Dictionary: return
	var admission: Dictionary = start.expedition.active
	assert_eq(start.receipt.mission, admission.id)
	net = get_tree().root.get_node("Solo")
	net.connect_mission("127.0.0.1", int(OS.get_environment("SOLO_PORT")), admission)
	driving = true
	var started: int = Time.get_ticks_msec()
	assert_true(await wait_until(func(): return not net.receipt.is_empty(), 450), "Exactly one real Solo, original 420 simulation-second limit")
	driving = false
	if net.receipt.is_empty():
		evidence("unfinished-state.json", {"wall_msec":Time.get_ticks_msec()-started,"state":net.state,"message":net.message})
		return
	var receipt: Dictionary = net.receipt.duplicate(true)
	evidence("result.json", {"wall_msec":Time.get_ticks_msec()-started,"receipt":receipt})
	assert_eq(receipt.outcome, "win")
	if receipt.outcome != "win": return
	assert_true(receipt.first)
	assert_eq(receipt.part.get("definition", ""), "drill")
	var part: String = str(receipt.part.get("id", ""))
	assert_ne(part, "")
	if part.is_empty() or receipt.outcome != "win": return
	assert_false(before_ids.has(part))
	assert_true(await wait_until(func(): return page.data.available.any(func(item): return item.id == part and item.definition == "drill"), 15), "Same already-open workshop automatically sees the real reward UUID")
	var inventory: Dictionary = (await api("/v1/inventory")).inventory
	assert_eq(inventory.parts.filter(func(item): return item.id == part and item.definition == "drill").size(), 1)
	page.get_node("%Mode").select(1)
	page.get_node("%Mode").item_selected.emit(1)
	page.get_node("%Slot").select(2)
	page.get_node("%Slot").item_selected.emit(2)
	var picker: OptionButton = page.get_node("%Item")
	var found := -1
	for i in picker.item_count:
		if picker.get_item_metadata(i) == part: found = i
	assert_gte(found, 0, "Actual item metadata contains this UUID")
	if found < 0: return
	picker.select(found)
	picker.item_selected.emit(found)
	assert_false(page.get_node("%Install").disabled, "Actual state and compatibility allow this refit")
	if page.get_node("%Install").disabled: return
	page.get_node("%Install").pressed.emit()
	assert_true(await wait_until(func(): return not page.busy and page.pending.is_empty() and page.data.robots.any(func(unit): return unit.id == robot.id and unit.slots.weapon.id == part), 5))
	inventory = (await api("/v1/inventory")).inventory
	var receipts: Array = inventory.ledger.filter(func(item): return item.operation == "refit" and item.get("installed", "") == part)
	assert_eq(receipts.size(), 1)
	if receipts.size() != 1: return
	assert_eq(receipts[0].returned, original_weapon)
	assert_eq(inventory.parts.filter(func(item): return item.id == original_weapon).size(), 1, "Original non-relief weapon returns to free inventory")
	assert_eq(inventory.parts.filter(func(item): return item.id == part).size(), 0, "Mounted drill is no longer a free inventory item")
	assert_eq(page.get_node("Robot").weapon, 1)
	var model: Node = page.get_node("Robot/Model")
	assert_true(model.find_child("ROOT_Weapon_Drill", true, false).visible)
	assert_false(model.find_child("ROOT_Weapon_Cannon", true, false).visible)
	evidence("equipped.json", {"robot":robot.id,"drill":part,"returned":original_weapon,"refit_receipt":receipts[0],"model_weapon":page.get_node("Robot").weapon})
