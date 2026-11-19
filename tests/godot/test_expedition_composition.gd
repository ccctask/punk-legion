extends "res://qa/support.gd"

const SoloProbe = preload("res://qa/composition_solo_probe.gd")
const PartyProbe = preload("res://qa/composition_party_probe.gd")
const PAGE = "res://expedition/expedition.tscn"
var failed := false
var observations: Array = []
var config: Dictionary
var solo
var party
var viewport: SubViewport

func need(ok: bool, label: String) -> bool:
	assert_true(ok,label)
	if not ok:failed=true
	return ok

func native_gate() -> bool:
	if failed:return false
	# Public GUT read-only API. Never clear errors or mark them handled.
	if not get_errors().is_empty():return need(false,"no native error before further business input")
	return true

func event(kind: String, fields: Dictionary = {}) -> void:
	var row=fields.duplicate(true)
	row.event=kind
	row.frame=Engine.get_process_frames()
	observations.append(row)
	print("COMPOSITION ",JSON.stringify(row))

func qa(action: String, fields: Dictionary = {}) -> Dictionary:
	if action!="release" and not native_gate():return {}
	var http=HTTPRequest.new()
	http.timeout=4
	add_child(http)
	var body=fields.duplicate(true)
	body.action=action
	var error=http.request(config.url+"/qa",PackedStringArray(["Content-Type: application/json","X-QA-Control: "+config.control]),HTTPClient.METHOD_POST,JSON.stringify(body))
	if not need(error==OK,"control request starts"):
		http.queue_free()
		return {}
	var response: Array=await http.request_completed
	http.queue_free()
	if not need(response[0]==HTTPRequest.RESULT_SUCCESS and response[1]==200,"control response succeeds"):return {}
	var json=JSON.new()
	if not need(json.parse(response[3].get_string_from_utf8())==OK and json.data is Dictionary,"control dictionary"):return {}
	return json.data

func until(predicate: Callable, label: String, seconds := 3.0) -> bool:
	var stop=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<stop:
		if not native_gate():return false
		if predicate.call():return true
		await get_tree().create_timer(.02).timeout
	return need(false,label)

func held() -> Dictionary:
	var deadline=Time.get_ticks_msec()+4000
	while Time.get_ticks_msec()<deadline:
		var status=await qa("status")
		if failed:return {}
		if status.held!=null:return status
		await get_tree().create_timer(.02).timeout
	need(false,"same actual HTTP arrived/held within bound")
	return {}

func pointer(button: BaseButton, label: String) -> void:
	if not native_gate():return
	var ancestor=button.get_parent()
	while ancestor!=null and ancestor!=viewport:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await wait_idle_frames(2)
	if not need(button.is_visible_in_tree() and not button.disabled,"visible enabled input "+label):return
	var rect=button.get_global_rect()
	event("pointer",{"label":label,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	await click(button)
	if not native_gate():return

func sessions() -> void:
	solo=SoloProbe.new()
	party=PartyProbe.new()
	solo.name="BorrowedSolo"
	party.name="BorrowedParty"
	add_child_autofree(solo)
	add_child_autofree(party)

func page(path: String, case_id: String, configured := true, cooperative := false):
	if not native_gate():return null
	var node=load(path).instantiate()
	node.endpoint=config.url+"/case/"+case_id
	node.token=config.token
	if cooperative:node.start_in_party=true
	if path=="res://pump/outing.tscn":
		node.pump_mode="coop"
		node.window_id="current-ui-window"
	if configured and not need(node.configure_sessions(solo,party),"configure before add_child"):
		node.free()
		return null
	viewport.add_child(node)
	return node

func links(session, node) -> int:
	var count:=0
	for row in session.get_signal_connection_list("changed"):
		if row.callable.get_object()==node:count+=1
	return count

func ready_page(node) -> bool:
	return is_instance_valid(node) and not node.busy and (not node.lobby.is_empty() or node.party_mode and node.lobby_read_confirmed)

func dispose(node) -> void:
	if is_instance_valid(node):node.queue_free()
	await wait_idle_frames(2)

func c1() -> void:
	sessions()
	if not need(not get_tree().root.has_node("Solo") and not get_tree().root.has_node("Party"),"no same-name Autoload"):return
	var node=page(PAGE,"c1")
	if not await until(func():return ready_page(node),"initial real GET"):return
	if not need(node.net==solo and links(solo,node)==1 and links(party,node)==0,"explicit initial ownership"):return
	if not need(not node.configure_sessions(party,solo) and node.solo_session==solo and node.party_session==party,"in-tree reconfigure rejected without replacement"):return
	await pointer(node.get_node("%PartyMode"),"Solo to Party")
	if not await until(func():return not node.busy and node.party_mode and node.lobby_read_confirmed,"party real GET"):return
	if not need(node.net==party and links(solo,node)==0 and links(party,node)==1,"one subscription moves to Party"):return
	await pointer(node.get_node("%PartyMode"),"Party to Solo")
	if not await until(func():return ready_page(node) and not node.party_mode,"solo real GET after switch"):return
	if not need(links(solo,node)==1 and links(party,node)==0 and solo.count_event("disconnect")==0 and party.count_event("disconnect")==0,"mode switching does not add disconnect"):return
	await pointer(node.get_node("%Back"),"configured Back")
	if not need(node.lobby_closing and links(solo,node)==0 and solo.count_event("disconnect")==1,"close releases current session once"):return
	await dispose(node)
	if not need(is_instance_valid(solo) and is_instance_valid(party),"page does not free borrowed sessions"):return

func c2() -> void:
	sessions()
	var before=await qa("status")
	for path in [PAGE,"res://factory/outing.tscn","res://pump/outing.tscn","res://armory/outing.tscn"]:
		var node=page(path,"c2",false)
		await wait_idle_frames(3)
		if not need(node.get_node("%LobbyReadBanner").is_visible_in_tree() and not node.get_node("%LobbyReadStatus").text.is_empty(),"missing configuration has player feedback "+path):return
		if not need(not node.is_processing() and not node.is_processing_unhandled_input(),"unconfigured frame/input disabled"):return
		var count: Array=[]
		node.closed.connect(func():count.append(true))
		await pointer(node.get_node("%Back"),"unconfigured Back "+path)
		if not need(count.size()==1,"Back works without session"):return
		await dispose(node)
	var after=await qa("status")
	if not need(before.request_count==after.request_count and solo.observations.is_empty() and party.observations.is_empty(),"unconfigured base and derived pages issue no HTTP/session actions"):return

func c3() -> void:
	for cooperative in [false,true]:
		sessions()
		await qa("reset")
		var id="c3party" if cooperative else "c3solo"
		var route="/v1/party" if cooperative else "/v1/expedition"
		await qa("hold",{"case":id,"route":route})
		var node=page(PAGE,id,true,cooperative)
		if not await until(func():return node.busy,"GET active"):return
		var status=await held()
		if failed:return
		var generation: int=node.http_generation
		var net=party if cooperative else solo
		var closed: Array=[]
		node.closed.connect(func():closed.append({"closing":node.lobby_closing,"generation":node.http_generation,"callback_valid":node.http_callback.is_valid(),"links":links(net,node),"disconnects":net.count_event("disconnect")}))
		await pointer(node.get_node("%Back"),"held "+route+" Back")
		if not need(closed.size()==1,"closed signal observed"):return
		var at: Dictionary=closed[0]
		if not need(at.closing and at.generation>generation and not at.callback_valid and at.links==0 and at.disconnects==1,"resources invalid before closed listeners"):return
		await qa("release",{"request_id":int(status.held.request_id),"case":id,"route":route,"closing":node.lobby_closing,"prior_generation":generation,"generation":node.http_generation,"frame":Engine.get_process_frames()})
		await wait_idle_frames(3)
		var after=await qa("status")
		if not need(after.posts.is_empty() and node.lobby.is_empty() and net.count_event("connect")==0,"late real GET cannot update/queue POST/join"):return
		await dispose(node)

func c4() -> void:
	sessions()
	await qa("reset")
	var old=page(PAGE,"c4")
	if not await until(func():return ready_page(old),"old page ready"):return
	var bag: Dictionary={}
	old.closed.connect(func():
		bag.before=solo.count_event("disconnect")
		bag.page=page(PAGE,"c4")
		if failed:return
		# Observation connection identity only, not a real ENet claim.
		solo.connect_mission("observer",0,{"id":"new-owner"})
		old.queue_free())
	await pointer(old.get_node("%Back"),"synchronous same-session reopen")
	await wait_idle_frames(3)
	if not need(bag.has("page"),"new page created in closed callback"):return
	if not await until(func():return ready_page(bag.page),"reopened actual GET"):return
	if not need(bag.before==1 and solo.count_event("disconnect")==1 and solo.credentials.get("id")=="new-owner" and links(solo,bag.page)==1,"old exit cannot disconnect new borrowed connection"):return
	var emitted: Array=[]
	bag.page.closed.connect(func():emitted.append(true))
	await dispose(bag.page)
	if not need(solo.count_event("disconnect")==2 and emitted.is_empty(),"direct parent free releases once without closed notification"):return

func c5() -> void:
	sessions()
	await qa("reset")
	var node=page(PAGE,"c5")
	if not await until(func():return ready_page(node),"real account lobby"):return
	var before_start=await qa("proof",{"label":"before-start"})
	await qa("hold",{"case":"c5","route":"/v1/expedition/start"})
	await pointer(node.get_node("%Start"),"real solo Start")
	if not await until(func():return node.busy,"start in flight"):return
	var status=await held()
	if failed:return
	var committed=await qa("proof",{"label":"before-back"})
	if not need(committed.missions.size()==1 and committed.receipts.size()==1,"actual Handler committed before Back"):return
	var expected_stocks: Dictionary=before_start.stocks.duplicate()
	expected_stocks.energy-=1
	if not need(committed.stocks==expected_stocks,"independent stocks show one normal energy fee"):return
	for proof: Dictionary in [before_start,committed]:
		if not need(proof.wild_raid_count==0 and proof.raid_clock.size()==1 and proof.raid_clock[0].due>proof.utc,"fresh account raid grace, no competing stock loss"):return
	var mission: String=committed.missions[0].id
	var generation: int=node.http_generation
	await pointer(node.get_node("%Back"),"busy solo Back after commit")
	if not need(node.lobby_closing and node.http_generation>generation and solo.count_event("connect")==0,"closed old page does not join committed result"):return
	await qa("release",{"request_id":int(status.held.request_id),"case":"c5","route":"/v1/expedition/start","closing":node.lobby_closing,"prior_generation":generation,"generation":node.http_generation,"frame":Engine.get_process_frames()})
	await dispose(node)
	var reopened=page(PAGE,"c5")
	if not await until(func():return not reopened.busy and reopened.active.get("id","")==mission,"new GET recovers same committed active"):return
	var after=await qa("proof",{"label":"after-new-get"})
	if not need(after.missions==committed.missions and after.receipts==committed.receipts and after.robots==committed.robots and after.stocks==committed.stocks,"same task/entry receipt/occupation/stocks after local cancellation"):return
	var receipt_json=JSON.new()
	if not need(receipt_json.parse(after.receipts[0].body)==OK and receipt_json.data.changes.get("energy",0)==-1,"normal real single entry fee"):return
	var posts=(await qa("status")).posts
	if not need(posts.size()==1 and posts[0].route=="/v1/expedition/start","exactly one committed POST, no cancel/finish/retry"):return
	await pointer(reopened.get_node("%Back"),"recovered page normal Back")
	await dispose(reopened)

func c6() -> void:
	sessions()
	await qa("reset")
	remove_child(solo)
	remove_child(party)
	solo.name="Solo"
	party.name="Party"
	get_tree().root.add_child(solo)
	get_tree().root.add_child(party)
	var base=load("res://base/base.tscn").instantiate()
	base.endpoint=config.url+"/case/c6"
	base.token=config.token
	viewport.add_child(base)
	if not await until(func():return not base.busy,"actual base ready"):return
	for pair in [["Explore",PAGE],["Armory","res://armory/outing.tscn"],["Factory","res://factory/outing.tscn"]]:
		await pointer(base.get_node("%"+pair[0]),"base "+pair[0])
		var node=viewport.get_children().filter(func(n):return n!=base and n.scene_file_path==pair[1])
		if not need(node.size()==1,"base creates actual "+pair[0]):return
		var area=node[0]
		if not await until(func():return ready_page(area),"derived initial HTTP"):return
		if not need(area.solo_session==solo and area.party_session==party and not base.visible,"base injection precedes ready"):return
		if pair[0]=="Factory":await pointer(area.get_node("%PartyPanel").get_node("%Create"),"Factory mapped Create")
		if pair[0]=="Armory":
			await pointer(area.get_node("%Claim"),"Armory mapped claim")
			if not await until(func():return not area.busy,"claim response"):return
			await pointer(area.get_node("%Start"),"Armory mapped start")
		if not await until(func():return not area.busy,"derived POST settled"):return
		await pointer(area.get_node("%Back"),"return actual base "+pair[0])
		if not await until(func():return base.visible and not base.busy,"base UI restored"):return
	await pointer(base.get_node("%WorldMap"),"base non-expedition WorldMap")
	var maps=viewport.get_children().filter(func(n):return n.scene_file_path=="res://world/world.tscn")
	if not need(maps.size()==1,"non-expedition path creates actual World"):return
	var world=maps[0]
	if not await until(func():return not world.busy and not world.world.is_empty(),"world fresh snapshot"):return
	for kind in ["party","pump_ruin"]:
		var candidates: Array=world.world.nodes.filter(func(n):return n.type==kind)
		if not need(not candidates.is_empty(),"current fresh world contains "+kind):return
		await pointer(world.pins[candidates[0].id],"world actual "+kind+" pin")
		await pointer(world.get_node("%Action" if kind=="party" else "%PumpCoop"),"world open "+kind)
		var areas=viewport.get_children().filter(func(n):return n!=base and n!=world and n.has_method("configure_sessions"))
		if not need(areas.size()==1,"world created one exploration"):return
		var area=areas[0]
		if not await until(func():return ready_page(area),"world-created lobby GET"):return
		if not need(area.solo_session==solo and area.party_session==party and not world.visible,"world injection before ready"):return
		if kind=="pump_ruin":await pointer(area.get_node("%PartyPanel").get_node("%Create"),"Pump mapped Create")
		if not await until(func():return not area.busy,"Pump request complete"):return
		await pointer(area.get_node("%Back"),"world return "+kind)
		if not await until(func():return world.visible and not world.busy,"world restored"):return
	await pointer(world.get_node("%Back"),"return World to base")
	await dispose(base)
	get_tree().root.remove_child(solo)
	get_tree().root.remove_child(party)
	solo.free()
	party.free()

func test_six_group_real_composition_contract() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("G3_PRIVATE_CONFIG")))
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,960)
	viewport.handle_input_locally=true
	add_child_autofree(viewport)
	for group in ["C1","C2","C3","C4","C5","C6"]:
		if not native_gate():return
		event("group_start",{"group":group})
		match group:
			"C1":await c1()
			"C2":await c2()
			"C3":await c3()
			"C4":await c4()
			"C5":await c5()
			"C6":await c6()
		native_gate()
		event("group_end",{"group":group,"passed":not failed})
		var file=FileAccess.open(OS.get_environment("G3_SCENE_REPORT"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"events":observations,"failed":failed}))
		file.close()
		if failed:return
