extends RefCounted

static func aim(tower: Node3D, direction: Vector2) -> void:
	if direction.length_squared()<0.001:
		return
	var pivot: Node3D=tower.yaw_pivot
	var forward: Vector3=-tower.muzzle_transform().basis.z.normalized()
	forward.y=0
	var desired:=Vector3(direction.x,0,direction.y).normalized()
	pivot.global_rotate(Vector3.UP,forward.normalized().signed_angle_to(desired,Vector3.UP))

static func trace_to(tower: Node3D, trace: MeshInstance3D, hit: Vector2) -> void:
	var start: Vector3=tower.muzzle_transform().origin
	var target:=Vector3(hit.x,start.y,hit.y)
	var length:=start.distance_to(target)
	if length<0.01:
		trace.hide()
		return
	trace.global_position=(start+target)*0.5
	trace.look_at(target,Vector3.UP)
	trace.scale=Vector3(0.055,0.055,length)
