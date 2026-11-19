extends RefCounted

# Tactical cameras show a machine at a few dozen pixels. Reuse its assembled
# rest silhouette for the shadow pass. The original meshes still render and animate.
static var silhouettes: Dictionary = {}

static func install(robot: Node3D, variant: Vector2i) -> void:
	var parts := robot.get_node("Model").find_children("*", "MeshInstance3D", true, false)
	if not silhouettes.has(variant):
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		var to_robot := robot.global_transform.affine_inverse()
		for part: MeshInstance3D in parts:
			if not part.is_visible_in_tree():
				continue
			var relative := to_robot * part.global_transform
			for surface in part.mesh.get_surface_count():
				var arrays := part.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				# Frozen GLBs already contain geometric LODs. Shadows occupy fewer pixels
				# than the colored body, so use the smallest authored/imported index buffer.
				var source := RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface)
				var levels: Array = source.get("lods",[])
				if not levels.is_empty():
					var encoded: PackedByteArray = levels.back().index_data
					if points.size() <= 65536:
						faces.resize(encoded.size() >> 1)
						for i in faces.size():
							faces[i] = encoded.decode_u16(i * 2)
					else:
						faces = encoded.to_int32_array()
				var offset := vertices.size()
				vertices.append_array(relative * points)
				if faces.is_empty():
					for vertex in points.size():
						indices.append(offset + vertex)
				else:
					for vertex in faces:
						indices.append(offset + vertex)
		if indices.is_empty():
			return
		var combined := ArrayMesh.new()
		var data := []
		data.resize(Mesh.ARRAY_MAX)
		data[Mesh.ARRAY_VERTEX] = vertices
		data[Mesh.ARRAY_INDEX] = indices
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
		silhouettes[variant] = combined
	for part: MeshInstance3D in parts:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow := robot.get_node_or_null("TacticalShadow") as MeshInstance3D
	if shadow != null:
		shadow.mesh = silhouettes[variant]
		return
	shadow = MeshInstance3D.new()
	shadow.name = "TacticalShadow"
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.mesh = silhouettes[variant]
	robot.add_child(shadow)


