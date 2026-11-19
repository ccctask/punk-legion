extends VBoxContainer

signal request(path: String, fields: Dictionary)
signal enter(admission: Dictionary)
var pump_mode := ""
var data := {}
var selected: Array = []
var local_ready := false
var initialized := false
var robot_buttons: Dictionary[String, CheckButton] = {}
var roster_room := ""
var roster_owner := ""
var match_key := ""
var cancel_requested := false
var read_available := true
var saved_disabled: Dictionary = {}
const SUBMIT_BUTTONS := ["Create","Join","Ready","Launch","Depart","Stay","Finish","CodeCopy","Match"]

func _ready() -> void:
	%Match.pressed.connect(func():
		if match_key.is_empty() and pump_mode.is_empty():
			match_key=Crypto.new().generate_random_bytes(16).hex_encode()
			_show_search()
			request.emit("/v1/party/match",{"key":match_key}))
	%CancelMatch.pressed.connect(cancel_search)
	%Create.pressed.connect(func(): request.emit("/v1/party/create",{}))
	%Join.pressed.connect(func(): request.emit("/v1/party/join",{"code":%Code.text.strip_edges()}))
	%Ready.pressed.connect(func(): request.emit("/v1/party/unready" if local_ready else "/v1/party/ready",{} if local_ready else {"robots":selected.duplicate()}))
	%Launch.pressed.connect(func():
		if read_available and not data.get("roomscope",{}).is_empty(): request.emit("/v1/party/start",{"round":data.roomscope.id}))
	%Stay.pressed.connect(func():
		if read_available and not data.get("continuation",{}).is_empty(): request.emit("/v1/party/again",{"round":data.continuation.round}))
	%Finish.pressed.connect(func():
		if read_available and not data.get("continuation",{}).is_empty(): request.emit("/v1/party/finish",{"round":data.continuation.round}))
	%Depart.pressed.connect(func(): request.emit("/v1/party/leave",{}))
	%CodeCopy.pressed.connect(func():
		if read_available and not data.get("roomscope",{}).is_empty(): DisplayServer.clipboard_set(data.roomscope.code))
	set_read_available(false)

func set_read_available(available: bool) -> void:
	if available==read_available:return
	read_available=available
	if not available:
		saved_disabled.clear()
		for button_name: String in SUBMIT_BUTTONS:
			var button:BaseButton=get_node("%"+button_name)
			saved_disabled[button_name]=button.disabled
			button.disabled=true
	else:
		for button_name: String in saved_disabled:
			get_node("%"+button_name).disabled=saved_disabled[button_name]
		saved_disabled.clear()

func enforce_read_gate() -> void:
	if read_available:return
	for button_name: String in SUBMIT_BUTTONS:get_node("%"+button_name).disabled=true

func action_available(path: String) -> bool:
	if not read_available:return false
	var names:={"create":"Create","join":"Join","ready":"Ready","unready":"Ready","start":"Launch","leave":"Depart","match":"Match"}
	var button_name:String=names.get(path.get_file(),"")
	return not button_name.is_empty() and not get_node("%"+button_name).disabled

func cancel_search() -> void:
	if match_key.is_empty():
		return
	cancel_requested=true
	_show_search()
	request.emit("/v1/party/cancel_match",{"key":match_key})

func _show_search() -> void:
	%Match.hide()
	%Invite.hide()
	%ContinueChoices.hide()
	%CancelMatch.show()
	%Room.text="正在确认取消，可再次取消以核实结果" if cancel_requested else "正在寻找锈轨队友 · 免费等待，机体仍可使用"

func refresh(next: Dictionary) -> void:
	var room:Dictionary=next.roomscope
	var room_id:String=room.get("id","")
	if roster_room!=room_id or roster_owner!=next.self:
		for button:CheckButton in robot_buttons.values():
			%Select.remove_child(button)
			button.queue_free()
		robot_buttons.clear()
		selected.clear()
		initialized=false
		roster_room=room_id
		roster_owner=next.self
	data=next
	var in_room:=not room.is_empty()
	%ContinueChoices.visible=not in_room and not next.get("continuation",{}).is_empty()
	%Invite.visible=not in_room
	%Members.visible=in_room
	%Select.visible=in_room
	%Quote.visible=in_room
	match_key=str(next.get("match_key","")) if next.get("matching",false) and not in_room and pump_mode.is_empty() else ""
	if match_key.is_empty():
		cancel_requested=false
	%Match.visible=not in_room and pump_mode.is_empty()
	%CancelMatch.hide()
	if not in_room:
		%Room.text="本场奖励已入账。留队后可换机，准备好再出发。" if %ContinueChoices.visible else "寻找锈轨队友，或通过邀请码组队"
		if not match_key.is_empty():
			_show_search()
		%Roster.text=""
		selected.clear()
		initialized=false
		return
	var lines:=PackedStringArray()
	local_ready=false
	var all_ready: bool=room.members.size()>=(1 if room.get("mode","")=="solo" else 2)
	for member in room.members:
		var picks:=PackedStringArray()
		var roles:Array=member.get("roles",[])
		for i in member.get("robot_names",[]).size():
			var role:=str({"front":"前排","fire":"火力","support":"支援"}.get(roles[i],"")) if i<roles.size() else ""
			picks.append(str(member.robot_names[i])+("·"+role if not role.is_empty() else ""))
		var readiness := "已准备 · %d 台 %d 点 · %s" % [member.robots.size(),member.points,", ".join(picks)] if member.ready else "选机中"
		lines.append("%s%s · %s" % [member.name," (队长)" if member.owner==room.leader else "",readiness])
		all_ready=all_ready and member.ready
		if member.owner==data.self:
			local_ready=member.ready
			if local_ready:selected=member.robots.duplicate()
	%Room.text="单人行动 · 1 人" if room.get("mode","")=="solo" else "邀请码 %s · %d/3 人" % [room.code,room.members.size()]
	%CodeCopy.visible=room.get("mode","")!="solo"
	var available_ids: Array = []
	for robot: Dictionary in data.robots:
		if robot.ready:
			available_ids.append(robot.id)
	selected = selected.filter(func(id): return id in available_ids)
	%Roster.text="\n".join(lines)
	var old_ids:=robot_buttons.keys()
	for index in data.robots.size():
		var robot:Dictionary=data.robots[index]
		var id:String=robot.id
		old_ids.erase(id)
		if not initialized and not local_ready and robot.ready and selected.is_empty():
			selected.append(id)
		var b:CheckButton=robot_buttons.get(id)
		if b==null:
			b=CheckButton.new()
			b.mouse_filter=Control.MOUSE_FILTER_PASS
			b.toggled.connect(_toggle.bind(id))
			robot_buttons[id]=b
			%Select.add_child(b)
		if b.get_index()!=index:
			%Select.move_child(b,index)
		var caption:="%s · %s · %d 点%s" % [robot.name,id.left(6),robot.points,"" if robot.ready else " · 不可出战"]
		if b.text!=caption:
			b.text=caption
		var locked:bool=local_ready or not robot.ready
		if b.disabled!=locked:
			b.disabled=locked
		if b.button_pressed!=(id in selected):
			b.set_pressed_no_signal(id in selected)
	for id in old_ids:
		var obsolete:=robot_buttons[id]
		%Select.remove_child(obsolete)
		obsolete.queue_free()
		robot_buttons.erase(id)
	initialized=true
	%Ready.text="取消准备" if local_ready else "准备"
	%Launch.visible=room.leader==data.self
	%Launch.disabled=not all_ready
	_render_quote()
	if room.has("admission"):
		enter.emit(room.admission)

func _toggle(enabled: bool, id: String) -> void:
	if enabled:
		if not selected.has(id):selected.append(id)
	else:
		selected.erase(id)
	_render_quote()

func _render_quote() -> void:
	var personal_points := 0
	for robot: Dictionary in data.robots:
		if robot.id in selected:
			personal_points += int(robot.points)
	var count := selected.size()
	var points := personal_points
	for member: Dictionary in data.roomscope.members:
		if member.owner != data.self and member.ready:
			count += member.robots.size()
			points += int(member.points)
	var issues := PackedStringArray()
	if selected.is_empty():
		issues.append("请先选择可出战机体")
	var coop:bool=data.roomscope.get("mode","")=="coop"
	var limit:=12 if coop else 24
	var slots:=6 if coop else 12
	if not pump_mode.is_empty():
		count=selected.size()
		points=personal_points
	if count > slots:
		issues.append("台数超出 %d 台" % (count-slots))
	if points > limit:
		issues.append("预算超出 %d 点" % (points-limit))
	var payment: Dictionary = data.departure_quote
	var price: String = {"energy":"出发消耗 1 能源（持有 %d）" % payment.energy,
		"voucher":"出发使用 1 张救援凭证", "unavailable":"没有能源或救援凭证，暂不能出发"}[payment.source]
	var lines := PackedStringArray(["本人 %d 台 %d 点 · 全队预计 %d/12 台 %d/24 点" % [selected.size(),personal_points,count,points],price+" · 准备免费"])
	if not pump_mode.is_empty():
		lines[0]="本人 %d/%d 台 · %d/%d 指挥点" % [count,slots,points,limit]
	if not issues.is_empty():
		lines.append("，".join(issues))
	%Quote.text = "\n".join(lines)
	%Ready.disabled = not local_ready and not issues.is_empty()
	enforce_read_gate()
