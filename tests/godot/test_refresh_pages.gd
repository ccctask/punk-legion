extends "res://qa/support.gd"



# P1–P5 use actual scenes, actual authenticated Handler and this run's DB.

var accounts: Array = []

var pages: Array[Node] = []

var halted := false



func require(value: bool, message := "Actual page prerequisite") -> bool:

	assert_true(value, message)

	return value



func retire(page: Node) -> void:

	page.queue_free()

	await wait_idle_frames(3)



func control_file(name: String, value: Variant) -> void:

	var path := OS.get_environment("PILOT_PAGE_CONTROL").path_join(name)

	assert_false(FileAccess.file_exists(path), "One-shot control must not overwrite evidence")

	var temporary := path + ".writing"

	assert_false(FileAccess.file_exists(temporary))

	var file := FileAccess.open(temporary, FileAccess.WRITE)

	assert_not_null(file)

	if file:

		file.store_string(JSON.stringify(value))

		file.close()

		assert_eq(DirAccess.rename_absolute(temporary, path), OK, "Closed one-shot marker is atomically published")



func api(route: String, body: Dictionary = {}, who := 0) -> Dictionary:

	var http := HTTPRequest.new()

	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])

	if not accounts.is_empty(): headers.append("Authorization: Bearer " + str(accounts[who].token))

	var started: int = http.request(OS.get_environment("PILOT_HTTP_URL") + route, headers,

		HTTPClient.METHOD_GET if body.is_empty() else HTTPClient.METHOD_POST,

		"" if body.is_empty() else JSON.stringify(body))

	assert_eq(started, OK)

	if started != OK:

		http.queue_free()

		return {}

	var reply: Array = await http.request_completed

	assert_eq(reply[0], HTTPRequest.RESULT_SUCCESS)

	assert_eq(reply[1], 200, "Normal API precondition must succeed, never SQL funding")

	var result: Variant = JSON.parse_string(reply[3].get_string_from_utf8())

	http.queue_free()

	return result if result is Dictionary else {}



func before_each() -> void:

	if halted: return

	accounts = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PILOT_PAGE_ACCOUNTS")))

	for i in accounts.size():

		var login: Dictionary = await api("/v1/sessions", {"name":accounts[i].name,"password":accounts[i].password}, i)

		assert_true(login.has("token"))

		accounts[i].token = login.get("token", "")



func after_each() -> void:

	if get_fail_count() > 0: halted = true

	for page in pages:

		if is_instance_valid(page): page.queue_free()

	pages.clear()

	await wait_idle_frames(3)



func scene(path: String, who := 0) -> Node:

	var page: Node = load("res://" + path).instantiate()

	page.set("endpoint", OS.get_environment("PILOT_HTTP_URL"))

	page.set("token", str(accounts[who].token))

	for property: Dictionary in page.get_property_list():

		if property.name == "account": page.set("account", str(accounts[who].owner))

	add_child(page)

	pages.append(page)

	return page



func count_requests(method: String, route: String) -> int:

	var count := 0

	for row: Dictionary in fixture_events():

		if row.get("event") == "profile_request" and row.get("method") == method and row.get("route") == route and ((route == "/v1/sessions" and not row.get("has_bearer",false)) or (route != "/v1/sessions" and row.get("owner") == accounts[0].owner)):

			count += 1

	return count



func completed_requests(method: String, route: String) -> int:

	var ids: Dictionary = {}

	var completed := 0

	var rows := fixture_events()

	for row: Dictionary in rows:

		if row.get("event") == "profile_request" and row.get("method") == method and row.get("route") == route and ((route == "/v1/sessions" and not row.get("has_bearer",false)) or (route != "/v1/sessions" and row.get("owner") == accounts[0].owner)):

			ids[int(row.id)] = true

	for row: Dictionary in rows:

		if row.get("event") == "profile_response_complete" and ids.has(int(row.get("id",-1))): completed += 1

	return completed



func arm(method: String, route: String, effect: String, who := 0) -> void:

	control_file("arm.json", {"method":method,"route":route,"effect":effect,"owner":accounts[who].owner})



func held_id(route: String) -> int:

	for row: Dictionary in fixture_events():

		if row.get("event") == "profile_held" and row.get("route") == route and ((route == "/v1/sessions" and not row.get("has_bearer",false)) or (route != "/v1/sessions" and row.get("owner") == accounts[0].owner)):

			var id: int = int(row.id)

			if not FileAccess.file_exists(OS.get_environment("PILOT_PAGE_CONTROL").path_join("release-" + str(id))): return id

	return -1



func wake(page: Node) -> void:

	page.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)

	page.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)



func test_p1_initial_inventory_and_production_change_without_manual_refresh() -> void:

	if halted:

		pending("Unrun after the first page failure; original evidence retained")

		return

	var profile: Node = scene("profile/profile.tscn")

	# Actual normal login button path, not assigning a successful domain snapshot.

	profile.get_node("%Endpoint").text = OS.get_environment("PILOT_HTTP_URL")

	profile.get_node("%Account").text = accounts[0].name

	profile.get_node("%Password").text = accounts[0].password

	profile.get_node("%Login").pressed.emit()

	if not require(await wait_until(func(): return not profile.busy and not profile.robots.is_empty(), 5)): return

	accounts[0].token = profile.token

	if not require(await wait_until(func(): return not profile.get_node("%Inventory").stock.is_empty(), 12), "Initial inventory is automatically fetched"): return

	await retire(profile)

	var layout: Dictionary = (await api("/v1/base")).get("base", {})

	assert_true(layout.has("revision"))

	await api("/v1/base/edit", {"revision":int(layout.get("revision",-1)),"key":"p1-foundry","action":"build","x":3,"y":2,"kind":"foundry"})

	var base: Node = scene("base/base.tscn")

	if not require(await wait_until(func(): return not base.busy and not base.layout.is_empty(), 5)): return

	base.get_node("%EconomyToggle").pressed.emit()

	if not require(await wait_until(func(): return not base.get_node("%Economy").state.is_empty(), 5)): return

	var before: int = int(base.get_node("%Economy").state.lines.structure.pending)

	control_file("clock.json", {"advance_seconds":1201})

	if not require(await wait_until(func(): return int(base.get_node("%Economy").state.get("lines",{}).get("structure",{}).get("pending",-1)) > before, 12), "Real production now injection becomes visible through automatic GET"): return

	assert_false(base.get_node("%Economy").get_node("%Refresh").visible)



func test_p2_new_entity_seen_and_draft_child_gate_preserved() -> void:

	if halted:

		pending("Unrun after the first page failure; original evidence retained")

		return

	var page: Node = scene("owned/workshop.tscn")

	if not require(await wait_until(func(): return not page.busy and not page.data.is_empty(), 5)): return

	var receipt: Dictionary = (await api("/v1/inventory/craft", {"recipe":"cannon","key":"p2-cannon"})).get("receipt",{})

	var part: String = str(receipt.get("part", ""))

	assert_ne(part, "", "Craft must create an entity UUID, not a material or recipe flag")

	if not require(await wait_until(func(): return page.data.get("available",[]).any(func(item): return item.id == part), 12), "Actual workshop automatically sees the same new UUID"): return

	page.get_node("%Name").text = "M01 unchanged draft"

	page.get_node("%Name").text_changed.emit("M01 unchanged draft")

	var selection: String = str(page.data.robots[page.get_node("%Robot").get_selected_id()].id)

	var read_before := completed_requests("GET", "/v1/workshop")

	wake(page)

	if not require(await wait_until(func(): return completed_requests("GET", "/v1/workshop") > read_before and not page.busy, 5), "Draft survives an actual completed new GET"): return

	assert_eq(page.get_node("%Name").text, "M01 unchanged draft")

	assert_eq(str(page.data.robots[page.get_node("%Robot").get_selected_id()].id), selection)

	page.get_node("%ApplyPreview").show()

	var before := count_requests("GET", "/v1/workshop")

	wake(page)

	await wait_seconds(1)

	assert_eq(count_requests("GET", "/v1/workshop"), before, "Child preview suppresses automatic reads")

	page.get_node("%ApplyPreview").hide()

	wake(page)

	if not require(await wait_until(func(): return completed_requests("GET", "/v1/workshop") == read_before + 2 and not page.busy, 5), "Returning from child restores one needed read"): return

	await wait_seconds(.3)

	assert_eq(count_requests("GET", "/v1/workshop"), before + 1)



func test_p3_external_friends_fault_foreground_and_real_login_recovery() -> void:

	if halted:

		pending("Unrun after the first page failure; original evidence retained")

		return

	var friends: Node = scene("friends/friends.tscn")

	if not require(await wait_until(func(): return not friends.busy and not friends.social.is_empty(), 5)): return

	await api("/v1/friends/request", {"friend":accounts[0].name}, 1)

	if not require(await wait_until(func(): return not friends.social.get("friends",[]).is_empty(), 5), "External account change arrives through normal polling"): return

	await retire(friends)

	var world: Node = scene("world/world.tscn")

	if not require(await wait_until(func(): return not world.busy and not world.world.is_empty(), 5)): return

	world.notification(NOTIFICATION_APPLICATION_PAUSED)

	var before := count_requests("GET", "/v1/world")

	await wait_seconds(1)

	assert_eq(count_requests("GET", "/v1/world"), before)

	arm("GET", "/v1/world", "503")

	wake(world)

	if not require(await wait_until(func(): return world.connection_failed, 5)): return

	if not require(await wait_until(func(): return not world.connection_failed and not world.busy, 8), "Read-only retry recovers from real HTTP failure"): return

	await retire(world)

	var profile: Node = scene("profile/profile.tscn")

	profile.get_node("%Endpoint").text = OS.get_environment("PILOT_HTTP_URL")

	profile.get_node("%Account").text = accounts[0].name

	profile.get_node("%Password").text = accounts[0].password

	profile.get_node("%Login").pressed.emit()

	if not require(await wait_until(func(): return not profile.busy and not profile.robots.is_empty(), 5)): return

	accounts[0].token = profile.token

	arm("GET", "/v1/profile", "401")

	wake(profile)

	if not require(await wait_until(func(): return profile.read_failed and not profile.busy, 5)): return

	assert_false(profile.get_node("%Login").disabled, "Terminal GET must not lock explicit login")

	profile.get_node("%Password").text = "incorrect-this-run-password"

	profile.get_node("%Login").pressed.emit()

	if not require(await wait_until(func(): return not profile.busy, 5)): return

	var posts := count_requests("POST", "/v1/sessions")

	wake(profile)

	await wait_seconds(1)

	assert_eq(count_requests("POST", "/v1/sessions"), posts, "Failed login must not be retried automatically")

	profile.get_node("%Password").text = accounts[0].password

	profile.get_node("%Login").pressed.emit()

	if not require(await wait_until(func(): return not profile.busy and not profile.token.is_empty() and not profile.read_failed, 5)): return

	var reads := count_requests("GET", "/v1/profile")

	wake(profile)

	if not require(await wait_until(func(): return count_requests("GET", "/v1/profile") > reads and not profile.busy, 5), "New normal session resets terminal and resumes automatic GET"): return



func test_p4_committed_unknown_store_write_never_reposted_by_refresh() -> void:

	if halted:

		pending("Unrun after the first page failure; original evidence retained")

		return

	var page: Node = scene("store/store.tscn")

	if not require(await wait_until(func(): return not page.busy and not page.data.is_empty(), 5)): return

	var before := count_requests("POST", "/v1/store/order")

	arm("POST", "/v1/store/order", "drop")

	page.get_node("%Buy").pressed.emit()

	if not require(await wait_until(func(): return held_id("/v1/store/order") > 0, 5)): return

	var pending: Dictionary = page.pending.duplicate(true)

	var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PILOT_PAGE_CONTROL").path_join("commit-" + str(held_id("/v1/store/order")) + ".json")))

	assert_eq(evidence.get("orders",[]).filter(func(order): return order.intent == pending.body.key).size(), 1, "Real committed order exists before response is dropped")

	control_file("release-" + str(held_id("/v1/store/order")), {})

	if not require(await wait_until(func(): return not page.busy, 5)): return

	assert_eq(count_requests("POST", "/v1/store/order") - before, 1)

	wake(page)

	await wait_seconds(2)

	assert_eq(page.pending, pending)

	assert_eq(count_requests("POST", "/v1/store/order") - before, 1)



func test_recheck_p5_committed_base_unknown_write_reconciles_original_receipt() -> void:

	if halted:

		pending("Unrun after the first page failure; original evidence retained")

		return

	var page: Node = scene("base/base.tscn")

	if not require(await wait_until(func(): return not page.busy and not page.layout.is_empty(), 5)): return

	# Use actual preview->confirm owner methods and normal placement validation.

	page.get_node("%Mode").select(0)

	page.get_node("%Type").select(1) # warehouse, one cell above the starter road

	page.pick(Vector2i(5,3))

	if not require(await wait_until(func(): return not page.busy and not page.preview.is_empty(), 5)): return

	var before := count_requests("POST", "/v1/base/edit")

	var stock_before: int = int((await api("/v1/inventory")).get("inventory",{}).get("stock",{}).get("structure",{}).get("amount",-1))

	var price: int = int(page.layout.price)

	var old_revision: int = int(page.layout.revision)

	var preview: Dictionary = page.preview.duplicate(true)

	arm("POST", "/v1/base/edit", "drop")

	page._confirm()

	if not require(await wait_until(func(): return held_id("/v1/base/edit") > 0, 5)): return

	var submitted: Dictionary = page.submitted.duplicate(true)

	wake(page)

	await wait_seconds(1)

	assert_eq(page.submitted, submitted)

	assert_eq(page.preview, preview)

	assert_eq(int(page.layout.revision), old_revision)

	assert_eq(count_requests("POST", "/v1/base/edit") - before, 1)

	var committed: Dictionary = await api("/v1/base/edits/" + str(submitted.key))

	if not require(committed.get("receipt") is Dictionary, "Real original-key receipt exists before unknown response"): return

	assert_eq(int(committed.get("base",{}).get("revision",-1)), old_revision + 1)

	assert_eq(int(committed.get("receipt",{}).get("revision",-1)), old_revision + 1)

	assert_eq(int(committed.get("receipt",{}).get("changes",{}).get("structure",0)), -price)

	var stock_after: int = int((await api("/v1/inventory")).get("inventory",{}).get("stock",{}).get("structure",{}).get("amount",-1))

	assert_eq(stock_after, stock_before - price, "The one real save fee is charged exactly once")

	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PILOT_PAGE_CONTROL").path_join("commit-" + str(held_id("/v1/base/edit")) + ".json")))

	var receipts: Array = proof.get("receipts",[]).filter(func(item): return item.key == submitted.key)

	assert_eq(receipts.size(), 1)

	if receipts.size() != 1: return

	assert_eq(receipts[0].id, committed.get("receipt",{}).get("id",""))

	var checks_before := count_requests("GET", "/v1/base/edits/" + str(submitted.key))
	control_file("release-" + str(held_id("/v1/base/edit")), {})
	if not require(await wait_until(func(): return completed_requests("GET", "/v1/base/edits/" + str(submitted.key)) > checks_before and not page.busy and page.submitted.is_empty() and int(page.layout.revision) == old_revision + 1, 5), "Actual owner automatically reconciles the original key before retiring intent"): return
	var final_receipt: Dictionary = (await api("/v1/base/edits/" + str(submitted.key))).get("receipt", {})
	assert_eq(final_receipt.get("id", ""), receipts[0].id)
	assert_eq(int(final_receipt.get("changes",{}).get("structure",0)), -price)
	var final_inventory: Dictionary = (await api("/v1/inventory")).get("inventory", {})
	assert_eq(final_inventory.get("ledger",[]).filter(func(item): return item.operation == "base_edit" and item.id == receipts[0].id).size(), 1)
	assert_eq(int(final_inventory.get("stock",{}).get("structure",{}).get("amount",-1)), stock_before - price)
	assert_eq(count_requests("POST", "/v1/base/edit") - before, 1, "Reconciliation is GET by original key, not another edit")

	assert_eq(int(page.layout.revision), int(committed.get("base",{}).get("revision",-1)))

