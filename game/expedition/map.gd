extends Control
const Mission := preload("res://net/solo_mission.gd")
signal ordered(pos: Vector2)
var state := {}
func bounds() -> Rect2i:
	return Rect2i(-16,-10,32,20) if state.get("location")=="old_armory" else Mission.AREA

func point(pos: Vector2) -> Vector2:
	return (pos - Vector2(bounds().position)) / Vector2(bounds().size) * size
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#172d30"))
	var obstacles:Array=[] if state.has("factory") else Mission.ROCKS
	if state.get("location")=="old_armory":
		obstacles=preload("res://net/armory_mission.gd").OBSTACLES
	for rock in obstacles:
		draw_rect(Rect2(point(rock.position),Vector2(rock.size)/Vector2(bounds().size)*size),Color("#526b66"))
	if state.is_empty():
		return
	if state.has("factory"):
		var factory:Dictionary=state.factory
		var stations:Array=[]
		for key:String in ["start","checkpoint","gate"]:
			var pair:Array=factory.points[key]
			stations.append(point(Vector2(pair[0],pair[1])))
		draw_polyline(PackedVector2Array(stations),Color.DARK_GOLDENROD,2.0)
		for station:Vector2 in stations:
			draw_rect(Rect2(station-Vector2(3,3),Vector2(6,6)),Color.WHEAT)
		var cart:=point(Vector2(factory.cart[0],factory.cart[1]))
		draw_arc(cart,6,0,TAU,12,Color.GOLD,2)
	elif state.has("points"):
		for goal in state.points:
			var at:=point(state.points[goal])
			var active:bool=goal in state.goals
			draw_circle(at,5,Color.GOLD if active else Color.CADET_BLUE)
			var tag:String={"valve_a":"A","valve_b":"B","cache":"C","exit":"E","armory_cache":"箱","armory_exit":"撤","armory_breaker":"闸"}[goal]
			draw_string(ThemeDB.fallback_font,at+Vector2(5,1),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,11)
	else:
		var last := point(Vector2(-30,-18))
		for goal in ["scrap","guard","coil","boss","exit"]:
			var at := point(Mission.LOCATIONS[goal])
			draw_line(last,at,Color("#736e52"),1)
			last = at
		for goal in Mission.LOCATIONS:
			var color := Color("#efa64d") if goal in state.goals else Color("#657875")
			draw_circle(point(Mission.LOCATIONS[goal]),4,color)
	for id in state.units:
		var unit: Dictionary = state.units[id]
		if unit.hp > 0:
			draw_circle(point(unit.pos),3,Color.AQUAMARINE if unit.side==0 else Color.SALMON)
	var ping:Dictionary=state.get("suggestion",{})
	if not ping.is_empty() and state.elapsed<float(ping.until):
		var mark:=point(state.units[ping.target].pos if ping.kind=="focus" and state.units.has(ping.target) else ping.position)
		draw_line(mark-Vector2(6,0),mark+Vector2(6,0),Color.GOLD,2)
		draw_line(mark-Vector2(0,6),mark+Vector2(0,6),Color.GOLD,2)
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:
		ordered.emit(Vector2(bounds().position)+e.position/size*Vector2(bounds().size))
		accept_event()

