@tool
extends RefCounted

const YARD := preload("res://assets/salvage/PL_RailSalvageKit.glb")
const ARMOR := preload("res://assets/salvage/PL_HeavyEscortKit.glb")
const PAINT := preload("res://assets/base_art/enamel.tres")
static var meshes := {}

static func load_meshes() -> void:
	if not meshes.is_empty():
		return
	for source in [YARD,ARMOR]:
		var exhibition:Node3D=source.instantiate()
		for surface:MeshInstance3D in exhibition.find_children("*","MeshInstance3D",true,false):
			meshes[str(surface.name).trim_suffix("_Surface")]=surface.mesh
		exhibition.free()

static func part(module: String) -> MeshInstance3D:
	load_meshes()
	var model:=MeshInstance3D.new()
	model.mesh=meshes[module]
	model.material_override=PAINT
	return model

static func dress(view: Node3D, slot: int) -> void:
	var module: String={2:"GuardArmor",3:"MedicRig",4:"GuardArmor",5:"ChiefPlate",6:"GuardArmor",7:"MedicRig"}.get(slot,"")
	if module.is_empty():
		return
	var attachment:=part(module)
	view.get_node("Robot").add_child(attachment)
	attachment.rotation.y=PI
	attachment.scale=Vector3.ONE*1.55
	attachment.position=Vector3(0,0.88,0.06)
	view.get_node("Health").position.y=1.74 if slot==5 else 1.50
	view.get_node("OwnedName").position.y=2.27 if slot==5 else 2.12

static func jammer_coil() -> Node3D:
	var rig:=Node3D.new()
	var coil:=part("Coil")
	var bounds:=coil.get_aabb()
	rig.add_child(coil)
	coil.scale=Vector3.ONE*(0.60/maxf(bounds.size.length(),0.01))
	coil.position=-bounds.get_center()*coil.scale
	return rig
