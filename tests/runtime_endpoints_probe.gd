extends Node
## Opt-in observer installed only in temporary release test projects.

const Endpoints := preload("res://client/endpoints.gd")

func _ready() -> void:
	if not OS.get_environment("QA_ENDPOINTS_EVIDENCE").is_empty():
		call_deferred("_run")

func _record(value:String) -> void:
	var file:=FileAccess.open(OS.get_environment("QA_ENDPOINTS_EVIDENCE"),FileAccess.WRITE)
	file.store_line(value)
	file.close()

func _check(condition:bool, message:String) -> bool:
	if not condition:
		_record("ENDPOINTS_FAIL "+message)
		get_tree().quit(1)
	return condition

func _run() -> void:
	var mode:=OS.get_environment("QA_ENDPOINTS_MODE")
	if not _check(Endpoints.development()==(mode=="debug"),"wrong template"):
		return
	if mode=="debug":
		for pair in [["room",24871],["solo",24872],["party",24873]]:
			if not _check(Endpoints.transport(pair[0])=={"host":"127.0.0.1","port":pair[1]},str(pair)):
				return
		if not _check(Endpoints.parse_room("[::1]:3021",24567)=={"host":"::1","port":3021},"IPv6") or not _check(Endpoints.transport("room","","127.0.0.1:3021").port==3021,"explicit port"):
			return
		if not _check(not Endpoints.valid_url("http://::1") and not Endpoints.valid_url("https://user@host"),"invalid URLs"):
			return
	else:
		while get_tree().current_scene==null:
			await get_tree().process_frame
		var room:=get_tree().root.get_node("Room")
		var hud:=get_tree().current_scene.get_node("HUD")
		if mode=="configured":
			var until:=Time.get_ticks_msec()+7000
			while room.local_seat==0 and Time.get_ticks_msec()<until:
				await get_tree().process_frame
			if not _check(room.local_seat>0 and not hud.get_node("%HostInput").editable,"normal range did not join"):
				return
			for service in ["solo","party"]:
				if not _check(Endpoints.transport(service).port==int(OS.get_environment("EXPECT_"+service.to_upper())),service):
					return
		else:
			if not _check(hud.get_node("%StatusLabel").text==Endpoints.issue("room") and room.local_seat==0,"range missing configuration message"):
				return
			if not _check(Endpoints.transport("solo").is_empty() and Endpoints.transport("party").is_empty(),"invalid UDP field leaked into release"):
				return
		hud.get_node("%Profile").pressed.emit()
		await get_tree().scene_changed
		var profile:=get_tree().current_scene
		if not _check(not profile.get_node("%Endpoint").editable,"release profile editable"):
			return
		profile.get_node("%Login").pressed.emit()
		if mode=="configured":
			var until:=Time.get_ticks_msec()+5000
			while profile.busy and Time.get_ticks_msec()<until:
				await get_tree().process_frame
			if not _check(profile.get_node("%Message").text=="账号或密码有误","configured HTTP did not answer"):
				return
		elif not _check(profile.get_node("%Message").text==Endpoints.issue("profile") and not profile.busy,"missing HTTP configuration message"):
			return
	_record("ENDPOINTS_OK "+mode)
	get_tree().quit()
