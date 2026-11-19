extends RefCounted

const Frame := preload("res://assets/steam_crawler/wheel_frame.tscn")
const Surfaces := preload("res://assets/steam_crawler/wheel_surfaces.tscn")

# The four animated axle pivots and their bronze castings come from the
# published PL_SteamCrawler r07 rig. Its Move clip rotates these pivots.
static func assemble(model: Node3D) -> void:
	var frame := Frame.instantiate()
	model.add_child(frame)
	for side in ["Left", "Right"]:
		var track := "%sTrack" % side
		for casing in model.find_children("SM_Runtime_ROOT_%s_*" % track, "MeshInstance3D", true, false):
			casing.hide()
		var sign_x := -1.0 if side == "Left" else 1.0
		for index in 2:
			var pivot := model.find_child("CTRL_%s_%d" % [track, index], true, false) as Node3D
			var original := pivot.find_children("SM_Runtime_*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var axle := frame.get_node("FrontAxle" if index == 0 else "RearAxle") as Node3D
			var radius := axle.position.y
			pivot.position = Vector3(sign_x * 0.03, radius - 0.267, axle.position.z)
			original.position.x = sign_x * 0.09
			original.scale = Vector3(1.7, radius * 5.0, radius * 5.0)
			var surfaces := Surfaces.instantiate()
			pivot.add_child(surfaces)
			var tire := surfaces.get_node("Tire") as MeshInstance3D
			tire.mesh = original.mesh
			tire.scale = Vector3(3.4, radius / 0.133, radius / 0.133)
			tire.position.x = -sign_x * 0.065
			# The offset enamel mark makes the wheel rotation visible.
			var marker := surfaces.get_node("HubIndex") as MeshInstance3D
			marker.mesh = original.mesh
			marker.position = Vector3(sign_x * 0.177, radius * 0.38, 0)
