extends Node

# Add only as an autoload to the isolated Android diagnostic export.
# The shipped client and release export exclude tests.
var cfg:=ConfigFile.new()
var playing:Node
var stage:=-1
var previous:=0
var samples:Dictionary={}
var sync_cost:Dictionary={}
var receipt:Dictionary={}
var rejoin_at:=0
var latest_elapsed:=-1.0
var latest_packet_ms:=0
var light:=false

func _ready() -> void:
	var location:=OS.get_environment("M06_DIRECT_CFG")
	if location.is_empty():location="user://perf.cfg"
	if cfg.load(location)!=OK:
		return
	light=bool(cfg.get_value("qa","light",false))
	if cfg.get_value("qa","direct",false):
		_direct.call_deferred()
	else:
		_drive.call_deferred()

func _idle(scene:Node) -> void:
	var until:=Time.get_ticks_msec()+25000
	while scene.busy and Time.get_ticks_msec()<until:
		await get_tree().process_frame

func _drive() -> void:
	while get_tree().current_scene==null:await get_tree().process_frame
	get_tree().current_scene.get_node("HUD").get_node("%Profile").pressed.emit()
	await get_tree().scene_changed
	var panel:=get_tree().current_scene
	panel.get_node("%Account").text=cfg.get_value("qa","name")
	panel.get_node("%Password").text=cfg.get_value("qa","password")
	panel.get_node("%Login").pressed.emit()
	await _idle(panel)
	if panel.token.is_empty():
		push_error("PERF Login failed")
		return
	panel.get_node("%Base").pressed.emit()
	await _idle(panel.get_node("PrivateBase"))
	panel.get_node("PrivateBase").get_node("%Explore").pressed.emit()
	playing=panel.get_node("Expedition")
	await _idle(playing)
	playing.get_node("%PartyMode").pressed.emit()
	await _idle(playing)
	var lobby:Node=playing.get_node("%PartyPanel")
	lobby.get_node("%Create").pressed.emit()
	await _idle(playing)
	var invite:=FileAccess.open("user://perf-invite",FileAccess.WRITE)
	invite.store_string(str(lobby.data.roomscope.code))
	invite.close()
	lobby.get_node("%Ready").pressed.emit()
	await _idle(playing)
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(.2).timeout
		if not playing.busy and lobby.data.roomscope.members.size()==3 and not lobby.get_node("%Launch").disabled:
			lobby.get_node("%Launch").pressed.emit()
			break
	await _play()

func _direct() -> void:
	get_tree().change_scene_to_file("res://expedition/expedition.tscn")
	await get_tree().scene_changed
	playing=get_tree().current_scene
	playing.endpoint=cfg.get_value("qa","endpoint")
	playing.net.changed.disconnect(playing._sync)
	playing.party_mode=true
	playing.net=get_node("/root/Party")
	playing.net.changed.connect(playing._sync)
	var path:String=cfg.get_value("qa","ticket")
	var ready:=FileAccess.open(path+".ready",FileAccess.WRITE)
	ready.store_string("arena_loaded")
	ready.close()
	while not FileAccess.file_exists(path):await get_tree().create_timer(.2).timeout
	var admission:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	playing._enter_party(admission)
	await _play()

func _play() -> void:
	if not light:
		playing.net.changed.disconnect(playing._sync)
		playing.net.changed.connect(_timed_sync)
	var view:=get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(view,not light)
	RenderingServer.frame_post_draw.connect(_measure)
	var deadline:=Time.get_ticks_msec()+480000
	var unit:="0:"+str(cfg.get_value("qa","robot"))
	while Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(.2).timeout
		var now:=Time.get_ticks_msec()
		var state:Dictionary=playing.net.state
		if not state.is_empty() and float(state.elapsed)>latest_elapsed:
			latest_elapsed=state.elapsed
			latest_packet_ms=now
		var stalled:bool=latest_packet_ms>0 and now-latest_packet_ms>3500 and playing.net.receipt.is_empty()
		if (playing.net.message=="探索连接中断，可重连同一次任务" or stalled) and now>=rejoin_at:
			latest_packet_ms=now
			rejoin_at=Time.get_ticks_msec()+1800
			playing.get_node("%Reconnect").pressed.emit()
			previous=0
			print("MOBILE_PERF_REJOIN")
			continue
		if not playing.net.receipt.is_empty():
			receipt=playing.net.receipt
			_save()
			RenderingServer.frame_post_draw.disconnect(_measure)
			return
		if state.is_empty() or not state.outcome.is_empty():
			continue
		if state.units[unit].hp < state.units[unit].max_hp*.68 and state.repairs>0:
			playing.get_node("%Repair").pressed.emit()
		if stage!=state.stage:
			stage=state.stage
			print("MOBILE_PERF_STAGE ",stage)
			playing.get_node("%Route").pressed.emit()
		if stage in [0,2,4] and state.units[unit].pos.distance_to(playing.Mission.LOCATIONS[playing.goal])<3.2:
			playing.get_node("%Collect").pressed.emit()
	push_error("PERF timeout")
	_save()

func _timed_sync() -> void:
	var start:=Time.get_ticks_usec()
	playing._sync()
	if stage>=0:
		if not sync_cost.has(stage):sync_cost[stage]=[]
		sync_cost[stage].append((Time.get_ticks_usec()-start)*.001)

func _measure() -> void:
	if stage<0 or playing.net.state.is_empty() or playing.net.message=="探索连接中断，可重连同一次任务":
		previous=0
		return
	var now:=Time.get_ticks_usec()
	if previous>0:
		var rid:=get_viewport().get_viewport_rid()
		if not samples.has(stage):samples[stage]=[]
		samples[stage].append([(now-previous)*.001,0.0 if light else RenderingServer.viewport_get_measured_render_time_cpu(rid),
				0.0 if light else RenderingServer.viewport_get_measured_render_time_gpu(rid),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	previous=now

func _save() -> void:
	var out:=FileAccess.open(str(cfg.get_value("qa","output","user://perf-result.json")),FileAccess.WRITE)
	out.store_string(JSON.stringify({"stages":samples,"sync_ms":sync_cost,"outcome":receipt.get("outcome","timeout"),
			"seconds":receipt.get("seconds",0),"device":OS.get_model_name(),"renderer":RenderingServer.get_current_rendering_method()}))
	out.close()
	print("MOBILE_PERF_DONE")
	if DisplayServer.get_name()=="headless":get_tree().quit(0 if receipt.get("outcome")=="win" else 1)







