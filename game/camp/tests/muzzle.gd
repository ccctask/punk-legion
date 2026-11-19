extends SceneTree
const Tower:=preload("res://assets/base_art/turret.tscn")
const Mount:=preload("res://camp/turret_mount.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var tower:=Tower.instantiate()
	root.add_child(tower)
	var trace:=MeshInstance3D.new()
	trace.mesh=BoxMesh.new()
	root.add_child(trace)
	var maximum:=0.0
	for heading: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2(-1,-0.3)]:
		Mount.aim(tower,heading)
		var gun: Transform3D=tower.muzzle_transform()
		var dir:=Vector3(heading.x,0,heading.y).normalized()
		var alignment:=(-gun.basis.z.normalized()).dot(dir)
		if alignment<0.999:
			push_error("Muzzle aim alignment "+str(alignment))
			quit(1)
			return
		var hit:=gun.origin+dir*5.1
		Mount.trace_to(tower,trace,Vector2(hit.x,hit.z))
		var actual:=trace.global_transform*Vector3(0,0,0.5)
		var end:=trace.global_transform*Vector3(0,0,-0.5)
		maximum=maxf(maximum,maxf(actual.distance_to(gun.origin),end.distance_to(hit)))
	if maximum>0.001:
		push_error("Trace failed "+str(maximum))
		quit(1)
		return
	print("CAMP_MUZZLE_PASS max_endpoint_error=",maximum)
	quit(0)
