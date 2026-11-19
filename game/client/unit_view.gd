extends Node3D

@onready var visual: Node3D = $Robot
@onready var ring: MeshInstance3D = $Ring
@onready var tag: Label3D = $Tag

var destination := Vector3.ZERO
var moving := false


func configure(id: int, is_local: bool, point: Vector2) -> void:
	tag.text = "%02d" % id
	tag.modulate = Color("#ffe899") if is_local else Color("#a7f3e5")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tag.modulate
	ring.material_override = material
	set_destination(point)
	position = destination
	visual.call("set_motion", false)


func set_destination(point: Vector2) -> void:
	destination = Vector3(point.x, 0.0, point.y)


func _process(delta: float) -> void:
	var offset := destination - position
	var in_motion := offset.length_squared() > 0.0004
	if in_motion != moving:
		moving = in_motion
		visual.call("set_motion", moving)
	if not in_motion:
		position = destination
		return
	position = position.lerp(destination, 1.0 - exp(-20.0 * delta))
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-12.0 * delta))
