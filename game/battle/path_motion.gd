extends RefCounted

# Pure value mathematics. Simulation owns units, collisions and all writes.
const POINT_LIMIT := 1024
const EPS := 0.00000001
const POSITION_EPS := 0.00001 # Vector2 path/position values use native coordinate precision.

static func profile(points: PackedVector2Array, incoming: Vector2, maximum: float, brake: float, omega: float = TAU, geometry_prefix: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	if points.size()<2 or points.size()>POINT_LIMIT or not incoming.is_finite() or not is_finite(maximum) or maximum<=0 or not is_finite(brake) or brake<=0 or not is_finite(omega) or omega<=0:return {"valid":false}
	if geometry_prefix.size()>2:return {"valid":false}
	for point: Vector2 in geometry_prefix:
		if not point.is_finite():return {"valid":false}
	var geometry:=points.duplicate()
	var lengths: Array[float] = []
	var corners: Array[float] = []
	for point: Vector2 in points:
		if not point.is_finite():return {"valid":false}
		corners.append(maximum)
	if not geometry_prefix.is_empty():
		geometry[0]=geometry_prefix[-1]
		if geometry[0]==points[1] or Geometry2D.get_closest_point_to_segment(points[0],geometry[0],points[1]).distance_squared_to(points[0])>.0000000001:return {"valid":false}
	for i in range(1,points.size()):
		var length:=points[i-1].distance_to(points[i])
		if not is_finite(length) or length<=EPS:return {"valid":false}
		lengths.append(length)
	for i in range(points.size()-1):
		var before: Vector2=incoming if i==0 else geometry[i]-geometry[i-1]
		if i==0 and geometry_prefix.size()==2:before=geometry_prefix[-1]-geometry_prefix[-2]
		var after:=geometry[i+1]-geometry[i]
		if before.is_zero_approx():continue
		var theta:=absf(before.angle_to(after))
		if theta<=EPS:continue
		if theta>=PI-.0001:
			corners[i]=0.0
			continue
		var span:=clampf((before.length()+after.length())*.5,.0001,.60)
		corners[i]=minf(maximum,omega/(theta/span))
	var limits: Array[float] = []
	for i in lengths.size():
		var limit:=maximum
		if geometry[i].distance_to(geometry[i+1])<=.12+.000001:
			# A zero node means stop AT that vertex, never freeze its whole edge.
			if corners[i]>0:limit=minf(limit,corners[i])
			if corners[i+1]>0:limit=minf(limit,corners[i+1])
		limits.append(limit)
	var nodes: Array[float] = []
	nodes.resize(points.size())
	nodes[-1]=0.0
	for i in range(lengths.size()-1,-1,-1):
		var node_cap:=maximum if i==0 and points[0]!=geometry[0] else corners[i]
		nodes[i]=minf(node_cap,minf(limits[i],sqrt(nodes[i+1]*nodes[i+1]+2*brake*lengths[i])))
	return {"valid":true,"nodes":nodes,"limits":limits,"start_limit":nodes[0]}

static func advance_segment(speed: float, limit: float, end_limit: float, distance: float, time_left: float, accel: float, brake: float) -> Dictionary:
	for number: float in [speed,limit,end_limit,distance,time_left,accel,brake]:
		if not is_finite(number):return {"valid":false}
	if speed<0 or limit<=0 or end_limit<0 or distance<0 or time_left<0 or accel<=0 or brake<=0 or speed>limit+EPS:return {"valid":false}
	# An endpoint ceiling may be looser than this chord's ceiling; it is not a requested speed.
	end_limit=minf(end_limit,limit)
	if speed*speed>end_limit*end_limit+2*brake*(distance+POSITION_EPS):return {"valid":false}
	var remaining:=distance
	var available:=time_left
	var velocity:=minf(speed,limit)
	var elapsed:=0.0
	var events:=0
	var phases: Array = []
	for _phase in 3:
		if remaining==0 or available==0:break
		var rate:=0.0
		var speed_event:=INF
		var brake_event:=INF
		var gap:=velocity*velocity-end_limit*end_limit-2*brake*remaining
		if velocity>end_limit+EPS and gap>=-EPS*maxf(1,velocity*velocity):
			rate=-brake
		elif velocity<limit-EPS:
			rate=accel
			speed_event=(limit-velocity)/accel
			var a:=.5*accel*(1+accel/brake)
			var b:=velocity*(1+accel/brake)
			var c:=(velocity*velocity-end_limit*end_limit)/(2*brake)-remaining
			# Stable positive root of a*t²+b*t+c=0.
			var root:=sqrt(maxf(0,b*b-4*a*c))
			brake_event=(-2*c/(b+root)) if b+root>0 else 0.0
		else:
			if velocity<=0:return {"valid":false}
			brake_event=maxf(0,(remaining-(velocity*velocity-end_limit*end_limit)/(2*brake))/velocity)
		var waypoint_time:=INF
		if rate>0:
			waypoint_time=2*remaining/(velocity+sqrt(velocity*velocity+2*rate*remaining))
		elif rate<0:
			var discriminant:=velocity*velocity-2*brake*remaining
			if discriminant>=-EPS:
				var denominator:=velocity+sqrt(maxf(0,discriminant))
				if denominator>0:waypoint_time=2*remaining/denominator
		else:
			waypoint_time=remaining/velocity
		var duration:=minf(available,waypoint_time)
		if rate>0:duration=minf(duration,minf(speed_event,brake_event))
		elif rate==0:duration=minf(duration,brake_event)
		if not is_finite(duration) or duration<=0:return {"valid":false}
		var initial:=velocity
		var moved:=velocity*duration+.5*rate*duration*duration
		velocity=clampf(velocity+rate*duration,0,limit)
		if not is_finite(moved) or not is_finite(velocity):return {"valid":false}
		if is_finite(waypoint_time) and waypoint_time<=duration+EPS*maxf(1,waypoint_time):
			moved=remaining
			velocity=minf(velocity,end_limit)
		if moved<0 or moved>remaining+EPS*maxf(1,distance):return {"valid":false}
		remaining=maxf(0,remaining-moved)
		phases.append({"speed":initial,"rate":rate,"time":duration,"distance":moved})
		available=maxf(0,available-duration)
		elapsed+=duration
		events+=1
	if remaining>EPS and available>EPS:return {"valid":false}
	return {"valid":true,"time":elapsed,"distance":distance-remaining,"speed":velocity,"reached":remaining==0,"events":events,"phases":phases}

static func time_for_distance(phases: Array, distance: float) -> float:
	if phases.size()>3 or not is_finite(distance) or distance<0:return -1.0
	var total:=0.0
	for row: Variant in phases:
		if not row is Dictionary or not row.has_all(["speed","rate","time","distance"]):return -1.0
		for key: String in ["speed","rate","time","distance"]:
			if not (row[key] is float or row[key] is int) or not is_finite(float(row[key])):return -1.0
		if float(row.speed)<0 or float(row.time)<0 or float(row.distance)<0:return -1.0
		var expected:=float(row.speed)*float(row.time)+.5*float(row.rate)*float(row.time)*float(row.time)
		var ending:=float(row.speed)+float(row.rate)*float(row.time)
		if not is_finite(expected) or not is_finite(ending) or absf(expected-float(row.distance))>.00001*maxf(1,float(row.distance)) or ending < -EPS:return -1.0
		total+=float(row.distance)
		if not is_finite(total):return -1.0
	if distance>total+.00001*maxf(1,total):return -1.0
	var remaining:=minf(distance,total)
	var elapsed:=0.0
	for row: Dictionary in phases:
		if remaining>=float(row.distance):
			remaining-=float(row.distance)
			elapsed+=float(row.time)
			continue
		if remaining==0:return elapsed
		var speed:=float(row.speed)
		var rate:=float(row.rate)
		var duration:=0.0
		if absf(rate)<=EPS:
			if speed<=0:return -1.0
			duration=remaining/speed
		else:
			var discriminant:=speed*speed+2*rate*remaining
			if discriminant < -EPS:return -1.0
			var denominator:=speed+sqrt(maxf(0,discriminant))
			if denominator<=0:return -1.0
			duration=2*remaining/denominator
		if not is_finite(duration) or duration<0 or duration>float(row.time)+.000001:return -1.0
		return elapsed+minf(duration,float(row.time))
	return elapsed
