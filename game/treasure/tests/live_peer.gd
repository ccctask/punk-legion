extends SceneTree
const Map:=preload("res://world/world.tscn")
var folder:=OS.get_environment("TREASURE_PEER_DIR")
var net:Node
var map:Node
var current:Node
var pending_index:=0
var receipt_frames:=0
var frame_index:=0
var next_frame:=0
var next_write:=0
var waiting:=false
var shutdown:=false
var last_snapshot:={}
var what:=""
var started:=0
var until:=0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	net=root.get_node("Treasure")
	net.acknowledged.connect(func(seq:int,err:String):
		if waiting:
			waiting=false
			_output("reply"+str(pending_index),{"seq":seq,"error":err,"ms":Time.get_ticks_msec()-started,"action":what})
			pending_index+=1)
	map=Map.instantiate()
	map.endpoint=OS.get_environment("PROFILE_URL")
	map.token=OS.get_environment("TEST_TOKEN")
	root.add_child(map)
	until=Time.get_ticks_msec()+200000

func _output(name:String,value:Dictionary) -> void:
	var temp:=folder.path_join(name+".tmp")
	var f:=FileAccess.open(temp,FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
	f.close()
	DirAccess.rename_absolute(temp,folder.path_join(name+".json"))

func _process(_delta:float) -> bool:
	if not net or shutdown:return false
	if Time.get_ticks_msec()>until:
		quit(1)
		return true
	if not current and not map.world.is_empty():
		map.select(map.world.treasure.id)
		map.get_node("%Action").pressed.emit()
		current=root.get_node_or_null("TreasureContest")
		if not current:
			quit(2)
			return true
	if not current:return false
	var now:=Time.get_ticks_msec()
	if now>=next_write and not current.overview.is_empty():
		next_write=now+240
		var g:Variant=current.overview.get("group")
		var view:Dictionary=net.state.duplicate(true)
		view["lobby_phase"]=g.phase if g is Dictionary else ""
		view["lobby_ready"]=g.confirmed if g is Dictionary else false
		view["budget"]=current.get_node("%Budget").text
		view["members"]=current.get_node("%Members").text
		view["can_submit"]=current.get_node("%Submit").visible and not current.get_node("%Submit").disabled
		view["can_confirm"]=current.get_node("%Station").visible and not current.get_node("%Station").disabled
		view["revision"]=g.revision if g is Dictionary else -1
		view["rendered"]=current.attached
		view["message"]=net.message
		_output("state",view)
	if OS.get_environment("TREASURE_FRAMES")!="" and now>=next_frame:
		next_frame=now+200
		var texture:=root.get_texture()
		if texture:
			var img:=texture.get_image()
			if img:
				img.save_png(OS.get_environment("TREASURE_FRAMES").path_join("%05d.png"%frame_index))
				frame_index+=1
	if waiting:return false
	var path:=folder.path_join("order"+str(pending_index)+".json")
	if not FileAccess.file_exists(path):return false
	var parser:=JSON.new()
	var raw:=FileAccess.get_file_as_string(path)
	if raw.is_empty() or parser.parse(raw)!=OK:return false
	var data:Variant=parser.data
	if not data is Dictionary:return false
	var kind:=str(data.action)
	if kind=="quit":
		shutdown=true
		quit()
		return true
	if kind in ["create","pick","submit","confirm","friend","screenshot","reconnect"]:
		if current.busy or current.overview.is_empty():return false
		if kind=="create":
			current.get_node("%Friend").text=str(data.get("friend",""))
			current.get_node("%Start").pressed.emit()
		elif kind=="pick":
			for rid in current.checks:
				current.checks[rid].button_pressed=rid in data.robots
		elif kind=="screenshot":
			root.get_texture().get_image().save_png(folder.path_join("screen.png"))
		elif kind=="submit":
			var submit:Button=current.get_node("%Submit")
			if not submit.visible or submit.disabled:return false
			submit.pressed.emit()
		elif kind=="confirm":
			if not current.overview.group is Dictionary or current.get_node("%Station").disabled:return false
			current.get_node("%Station").pressed.emit()
		elif kind=="reconnect":current.get_node("%Reconnect").pressed.emit()
		_output("reply"+str(pending_index),{"action":kind})
		pending_index+=1
	elif not net.state.is_empty():
		var s:Dictionary=net.state
		var own:=""
		for rid in s.units:
			if s.units[rid].owner==s.owner:own=rid;break
		data.robot=own
		started=Time.get_ticks_msec()
		what=kind
		waiting=true
		net.command(data)
	return false
