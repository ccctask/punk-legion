extends RefCounted

const BOUNDS := Rect2i(-14, -8, 29, 17)
const BLOCKS: Array[Rect2i] = [
	Rect2i(-5, -3, 2, 5), Rect2i(4, -1, 2, 5),
	Rect2i(-1, -6, 3, 2), Rect2i(-1, 5, 3, 2),
]
const RELAY_RADIUS := 2.5
const GEOMETRY_EPS := 0.00001
const NEIGHBORS := [Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN]
var bounds := BOUNDS
var grid := AStarGrid2D.new()
var _static_obstacles: Array[Rect2i] = []
const TURN_PATH_LIMIT := 1024

func _init(area := BOUNDS, obstacles: Array[Rect2i] = BLOCKS) -> void:
	bounds = area
	_static_obstacles=obstacles.duplicate()
	grid.region = bounds
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for obstacle in obstacles:
		grid.fill_solid_region(obstacle)

func cell(at: Vector2) -> Vector2i:
	return Vector2i(at.round()).clamp(bounds.position, bounds.end - Vector2i.ONE)

func open_cell(wanted: Vector2i) -> Vector2i:
	var center := wanted.clamp(bounds.position, bounds.end - Vector2i.ONE)
	if not grid.is_point_solid(center):
		return center
	var nearest := bounds.position
	var best := INF
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var candidate := Vector2i(x, y)
			var distance := center.distance_squared_to(candidate)
			if distance < best and not grid.is_point_solid(candidate):
				best = distance
				nearest = candidate
	return nearest

func route(at: Vector2, goal: Vector2i) -> PackedVector2Array:
	return grid.get_point_path(cell(at), open_cell(goal))

func static_capsule_exclusions(radius: float) -> Array:
	var shapes: Array = []
	if not is_finite(radius) or radius<0:return shapes
	var rectangles: Array[Rect2i]=_static_obstacles.duplicate()
	rectangles.append(bounds)
	for rectangle: Rect2i in rectangles:
		var low:=Vector2(rectangle.position)-Vector2.ONE*.5
		var high:=Vector2(rectangle.end)-Vector2.ONE*.5
		var corners: Array[Vector2]=[low,Vector2(high.x,low.y),high,Vector2(low.x,high.y)]
		for i in 4:
			# Existing segment_clear subtracts EPS; compensate conservatively.
			shapes.append({"from":corners[i],"to":corners[(i+1)%4],"radius":radius+2*GEOMETRY_EPS})
	return shapes

func map_segment_clear(start: Vector2, finish: Vector2, radius: float) -> bool:
	return segment_has_static_clearance(start,finish,radius,bounds,_static_obstacles)

func nearest_body_cell(wanted: Vector2, radius: float) -> Vector2i:
	var found:=bounds.end
	var best:=INF
	if not wanted.is_finite() or not is_finite(radius) or radius<0:return found
	for x in range(bounds.position.x,bounds.end.x):
		for y in range(bounds.position.y,bounds.end.y):
			var point:=Vector2(x,y)
			var distance:=point.distance_squared_to(wanted)
			if distance>=best or grid.is_point_solid(Vector2i(x,y)):continue
			if map_segment_clear(point,point,radius):
				found=Vector2i(x,y)
				best=distance
	return found

func _turn_segment_clear(a: Vector2, b: Vector2, radius: float, exclusions: Array) -> bool:
	return map_segment_clear(a,b,radius) and segment_clear(a,b,exclusions)

func _turn_path_clear(path: PackedVector2Array, radius: float, exclusions: Array) -> bool:
	if path.is_empty() or path.size()>TURN_PATH_LIMIT:return false
	for i in path.size():
		if not _turn_segment_clear(path[i],path[i],radius,exclusions):return false
		if i>0 and not _turn_segment_clear(path[i-1],path[i],radius,exclusions):return false
	return true

func _without_collinear(path: PackedVector2Array, radius: float, exclusions: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point: Vector2 in path:
		if not result.is_empty() and point==result[-1]:continue
		while result.size()>=2:
			var first:=result[-1]-result[-2]
			var second:=point-result[-1]
			if absf(first.cross(second))>0.000001 or first.dot(second)<=0:break
			if not _turn_segment_clear(result[-2],point,radius,exclusions):break
			result.remove_at(result.size()-1)
		result.append(point)
	return result

static func _turn_angles_clear(before: Vector2, curve: PackedVector2Array, after: Vector2) -> bool:
	var previous:=curve[0]-before
	for i in range(1,curve.size()+1):
		var direction: Vector2=(curve[i] if i<curve.size() else after)-curve[i-1]
		if direction.is_zero_approx():continue
		if not previous.is_zero_approx() and absf(previous.angle_to(direction))>deg_to_rad(15)+0.000001:return false
		previous=direction
	return true

func _rounded_corner(a: Vector2, b: Vector2, c: Vector2, radius: float, exclusions: Array) -> PackedVector2Array:
	var incoming:=b-a
	var outgoing:=c-b
	var trim:=minf(.60,minf(incoming.length(),outgoing.length())*.45)
	if trim<0.00001 or incoming.normalized().dot(outgoing.normalized())<=-0.9999:return PackedVector2Array([b])
	var entry:=b-incoming.normalized()*trim
	var exit:=b+outgoing.normalized()*trim
	for count: int in [2,4,8,16]:
		var curve:=PackedVector2Array([entry])
		var valid:=true
		for i in range(1,count+1):
			var t:=float(i)/count
			var point:=entry.lerp(b,t).lerp(b.lerp(exit,t),t)
			if curve[-1].distance_to(point)>.12+0.000001:valid=false
			curve.append(point)
		if valid and _turn_angles_clear(a,curve,c) and _turn_path_clear(curve,radius,exclusions) and _turn_segment_clear(a,entry,radius,exclusions) and _turn_segment_clear(exit,c,radius,exclusions):return curve
	return PackedVector2Array([b])

func rounded_path(path: PackedVector2Array, radius: float, exclusions: Array) -> PackedVector2Array:
	# Input is independently owned decision data; never alter a planning tree.
	if not _turn_path_clear(path,radius,exclusions):return PackedVector2Array()
	var straight:=_without_collinear(path,radius,exclusions)
	if straight.size()<3:return straight
	var result:=PackedVector2Array([straight[0]])
	for i in range(1,straight.size()-1):
		var corner:=_rounded_corner(straight[i-1],straight[i],straight[i+1],radius,exclusions)
		if result.size()+corner.size()+straight.size()-i-1>TURN_PATH_LIMIT:return path.duplicate()
		for point: Vector2 in corner:
			if point!=result[-1]:result.append(point)
	result.append(straight[-1])
	return result if _turn_path_clear(result,radius,exclusions) else path.duplicate()

# Exclusions contain only geometry: {from:Vector2,to:Vector2,radius:float}.
# A circle has identical endpoints. No query changes the authoritative grid.
func walk_region(at: Vector2, exclusions: Array) -> Dictionary:
	var region := {"from":at,"source":Vector2i.ZERO,"parents":{},"costs":{},"exclusions":exclusions,"visited":0,"edge_checks":0}
	if not at.is_finite():
		return region
	var source := Vector2i(at.round())
	region.source = source
	if not bounds.has_point(source) or grid.is_point_solid(source):
		return region
	region.parents[source] = source
	region.costs[source] = 0.0
	var queue: Array[Vector2i] = [source]
	var cursor := 0
	var shape_buckets: Dictionary = {}
	var buckets_ready := false
	var empty_shapes: Array = []
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		region.visited += 1
		var start: Vector2 = at if current == source else Vector2(current)
		var candidates: Array = exclusions
		if current != source:
			# A trapped source never pays for a spatial index.
			if not buckets_ready:
				shape_buckets = _walk_shape_buckets(exclusions)
				buckets_ready = true
			var relative := current-bounds.position
			var key := relative.y*bounds.size.x+relative.x
			candidates = shape_buckets.get(key,empty_shapes)
		for offset: Vector2i in NEIGHBORS:
			var next := current + offset
			if region.parents.has(next) or not bounds.has_point(next) or grid.is_point_solid(next):
				continue
			region.edge_checks += 1
			if not segment_clear(start,Vector2(next),candidates):
				continue
			region.parents[next] = current
			region.costs[next] = float(region.costs[current]) + start.distance_to(Vector2(next))
			queue.append(next)
	return region

func _walk_shape_buckets(exclusions: Array) -> Dictionary:
	# Query-local broad phase only: no grid queries or exact edge checks here.
	var buckets: Dictionary = {}
	for shape: Dictionary in exclusions:
		var radius := maxf(0.0,float(shape.radius)-GEOMETRY_EPS)
		var a: Vector2 = shape.from
		var b: Vector2 = shape.to
		# Integer starts of possibly intersecting unit edges lie in [low-1,high+1].
		var min_x := maxi(bounds.position.x,ceili(minf(a.x,b.x)-radius)-1)
		var max_x := mini(bounds.end.x-1,floori(maxf(a.x,b.x)+radius)+1)
		var min_y := maxi(bounds.position.y,ceili(minf(a.y,b.y)-radius)-1)
		var max_y := mini(bounds.end.y-1,floori(maxf(a.y,b.y)+radius)+1)
		for y in range(min_y,max_y+1):
			for x in range(min_x,max_x+1):
				var key := (y-bounds.position.y)*bounds.size.x+x-bounds.position.x
				if not buckets.has(key):
					buckets[key] = []
				var candidates: Array = buckets[key]
				# Append references in input order, including repeated shapes.
				candidates.append(shape)
	return buckets

func region_path(region: Dictionary, goal: Vector2i) -> PackedVector2Array:
	if not region.parents.has(goal):
		return PackedVector2Array()
	var source: Vector2i = region.source
	var start: Vector2 = region.from
	if goal == source:
		if not segment_clear(start,Vector2(goal),region.exclusions):
			return PackedVector2Array()
		return PackedVector2Array([start,Vector2(goal)])
	var reverse: Array[Vector2] = []
	var current := goal
	while current != source:
		reverse.append(Vector2(current))
		current = region.parents[current]
	reverse.reverse()
	var path := PackedVector2Array([start])
	path.append_array(PackedVector2Array(reverse))
	return path

static func point_segment_distance_squared(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var edge := finish-start
	var length := edge.length_squared()
	if length <= 0.0000000001:
		return point.distance_squared_to(start)
	var t := clampf((point-start).dot(edge)/length,0.0,1.0)
	return point.distance_squared_to(start+edge*t)

static func segment_distance_squared(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var first := b-a
	var second := d-c
	var cross := first.cross(second)
	if absf(cross) > 0.0000000001:
		var t := (c-a).cross(second)/cross
		var s := (c-a).cross(first)/cross
		if t >= 0 and t <= 1 and s >= 0 and s <= 1:
			return 0.0
	return minf(minf(point_segment_distance_squared(a,c,d),point_segment_distance_squared(b,c,d)),minf(point_segment_distance_squared(c,a,b),point_segment_distance_squared(d,a,b)))

static func segment_clear(start: Vector2, finish: Vector2, exclusions: Array) -> bool:
	var low := Vector2(minf(start.x,finish.x),minf(start.y,finish.y))
	var high := Vector2(maxf(start.x,finish.x),maxf(start.y,finish.y))
	for shape: Dictionary in exclusions:
		var radius := maxf(0.0,float(shape.radius)-GEOMETRY_EPS)
		var a: Vector2 = shape.from
		var b: Vector2 = shape.to
		if high.x < minf(a.x,b.x)-radius or low.x > maxf(a.x,b.x)+radius or high.y < minf(a.y,b.y)-radius or low.y > maxf(a.y,b.y)+radius:
			continue
		var distance := point_segment_distance_squared(a,start,finish) if a == b else segment_distance_squared(start,finish,a,b)
		if distance < radius*radius:
			return false
	return true

static func safe_fraction(start: Vector2, finish: Vector2, exclusions: Array) -> float:
	if segment_clear(start,finish,exclusions):
		return 1.0
	if not segment_clear(start,start,exclusions):
		return 0.0
	# Prefix safety is monotone even when the complete segment exits a body again.
	var low := 0.0
	var high := 1.0
	for iteration in 18:
		var middle := (low+high)*0.5
		if segment_clear(start,start.lerp(finish,middle),exclusions):
			low = middle
		else:
			high = middle
	return low

# Read-only display clearance. Does not alter the grid or authoritative routes.
static func segment_has_static_clearance(start: Vector2, finish: Vector2, radius: float, area: Rect2i, obstacles: Array[Rect2i]) -> bool:
	if not start.is_finite() or not finish.is_finite() or not is_finite(radius) or radius<0 or not area.has_area():return false
	var low:=Vector2(area.position)-Vector2.ONE*0.5+Vector2.ONE*radius
	var high:=Vector2(area.end)-Vector2.ONE*0.5-Vector2.ONE*radius
	for point: Vector2 in [start,finish]:
		if point.x<low.x or point.y<low.y or point.x>high.x or point.y>high.y:return false
	for rectangle: Rect2i in obstacles:
		if not rectangle.has_area():continue
		var r:=Rect2(Vector2(rectangle.position)-Vector2.ONE*0.5,Vector2(rectangle.size))
		if r.has_point(start) or r.has_point(finish):return false
		var corners: Array[Vector2]=[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
		for i in 4:
			# A tiny conservative margin; never reduce the requested body radius.
			if segment_distance_squared(start,finish,corners[i],corners[(i+1)%4])<=radius*radius+0.0000000001:return false
	return true

func can_see(start: Vector2, finish: Vector2) -> bool:
	var steps := maxi(1, ceili(start.distance_to(finish) * 3.0))
	for i in range(1, steps):
		if grid.is_point_solid(cell(start.lerp(finish, float(i) / steps))):
			return false
	return true

