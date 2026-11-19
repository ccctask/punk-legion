extends "res://profile/tests/profile_ui.gd"

var friends: Node
var role:=OS.get_environment("FRIEND_ROLE")
var target:=OS.get_environment("FRIEND_NAME")
var frames:=OS.get_environment("FRIEND_FRAMES")
var start:=0
var last_frame:=-1

func _wait(node: Node) -> void:
	var limit:=Time.get_ticks_msec()+10000
	while node.busy and Time.get_ticks_msec()<limit:
		await process_frame
	_check(not node.busy,"好友请求超时")

func _choose(name: String, key: String, value: String) -> bool:
	var box: ItemList=friends.get_node("%"+name)
	for i in box.item_count:
		var data: Dictionary=box.get_item_metadata(i)
		if data.get(key)==value:
			box.select(i)
			box.item_selected.emit(i)
			return true
	return false

func _press_social(name: String) -> void:
	var button: Button=friends.get_node("%"+name)
	_check(not button.disabled,"按钮不可用 "+name+" "+friends.get_node("%Hint").text)
	button.pressed.emit()
	await _wait(friends)

func _capture() -> void:
	var age:=Time.get_ticks_msec()-start
	if OS.has_environment("CAMP_VIDEO_EPOCH"):
		age=int(Time.get_unix_time_from_system()*1000)-OS.get_environment("CAMP_VIDEO_EPOCH").to_int()
	var n:=floori(age*6.0/1000)
	if n>last_frame:
		var picture:=root.get_texture().get_image()
		while last_frame<n:
			last_frame+=1
			picture.save_jpg(frames.path_join("%06d.jpg"%last_frame),0.85)

func _run() -> void:
	await _panel()
	panel.get_node("%Account").text=OS.get_environment("CAMP_LOGIN")
	panel.get_node("%Password").text=OS.get_environment("CAMP_PASSWORD")
	await _press("Login")
	panel.get_node("%Friends").pressed.emit()
	friends=panel.get_node("Friends")
	await _wait(friends)
	if role=="request":
		friends.get_node("%FriendName").text=target
		await _press_social("Request")
	elif role=="friends":
		_check(_choose("Pals","name",target),"未看到申请")
		await _press_social("Accept")
		await _press_social("Visit")
		await process_frame
		var base:=panel.get_node("PrivateBase")
		_check(not base.visit_layout.is_empty() and not base.get_node("%Confirm").visible and base.get_node("Buildings").get_child_count()>0,"参观应只读且呈现实际布局")
		base.get_node("%Back").pressed.emit()
		await process_frame
	elif role=="share":
		_check(_choose("Pals","name",target),"分享好友")
		await _press_social("Share")
	elif role=="save":
		_check(friends.social.shares.size()==1 and friends.get_node("%Definition").text.contains("缺件"),"分享缺件")
		await _press_social("Save")
	elif role in ["offer-attack","offer-defend"]:
		_check(_choose("Pals","name",target),"派遣好友")
		friends.get_node("%Side").select(0 if role=="offer-attack" else 1)
		await _press_social("Offer")
	elif role=="accept-aid":
		_check(_choose("Aids","phase","offered"),"未看到提议")
		await _press_social("AgreeAid")
	elif role=="pilot":
		await _pilot()
	if not failed:print("SOCIAL_UI_PASS ",role)
	quit(1 if failed else 0)

func _pilot() -> void:
	var end:=Time.get_ticks_msec()+55000
	while Time.get_ticks_msec()<end:
		if _choose("Aids","phase","locked") and not friends.get_node("%Join").disabled:
			break
		await create_timer(0.15).timeout
	if friends.get_node("%Join").disabled:
		_check(false,"未获得援军战斗入口")
		return
	friends.get_node("%Join").pressed.emit()
	var battle:=panel.get_node("CampContest")
	var net: Node=battle.net
	var reconnected:=false
	var issued:=false
	var accepted:=false
	var foreign_rejected:=false
	var stage:=0
	var baseline:=0
	var seen:=false
	var shot:=false
	start=Time.get_ticks_msec()
	if not frames.is_empty() and DisplayServer.get_name()!="headless":
		RenderingServer.frame_post_draw.connect(_capture)
	while Time.get_ticks_msec()-start<50000:
		await create_timer(0.12).timeout
		if not net.receipt.is_empty():
			_check(seen and accepted and foreign_rejected and reconnected,"援军未完成独有机组指挥、拒绝他机及重连")
			print("SOCIAL_PILOT_RECEIPT ",net.receipt.id," ",net.receipt.reason," own_command=",accepted," retained_seat=",reconnected)
			return
		if net.state.is_empty() or not net.state.outcome.is_empty():
			continue
		var s: Dictionary=net.state
		var mine: Array=s.units.keys().filter(func(id):return s.units[id].owned)
		var allies: Array=s.units.keys().filter(func(id):return not s.units[id].owned and s.units[id].side==s.side)
		if mine.size()!=1 or allies.is_empty():
			continue
		seen=true
		if not issued:
			baseline=int(s.seq)
			net.command("move",[allies[0]],"",Vector2.ZERO)
			issued=true
			stage=Time.get_ticks_msec()
		elif not foreign_rejected and Time.get_ticks_msec()-stage>450:
			_check(int(s.seq)==baseline,"越权指挥被接受")
			foreign_rejected=true
			net.command("move",mine,"",Vector2.ZERO)
		elif foreign_rejected and int(s.seq)>baseline and not accepted:
			accepted=true
			battle.get_node("%Focus").pressed.emit()
		elif accepted and not reconnected and s.elapsed>2:
			net.disconnect_mission()
			await create_timer(0.35).timeout
			battle.get_node("%Reconnect").pressed.emit()
			reconnected=true
		elif reconnected and not shot and s.elapsed>3 and DisplayServer.get_name()!="headless" and not OS.get_environment("FRIEND_SHOT").is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("FRIEND_SHOT"))
			shot=true
	_check(false,"援军终局超时 "+str(net.message))
