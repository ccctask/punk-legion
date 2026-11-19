extends Node3D

const Model := preload("res://assets/steam_biped/model.glb")
const Kit := preload("res://assets/salvage/kit.gd")
var model: Node3D
var player: AnimationPlayer
var cabin: Node3D
var cannon: Node3D
var visor: Node3D
var drill: Node3D
var chimney_source:Node3D
var service_rig: Node3D
var jammer_rig: Node3D

# The release authors named the socket axes in Blender's mechanical connector
# frame. Meshes below use model-space +Z forward. Align once in torso space.
func _mount(socket_name: String, part: Node3D, offset: Vector3, size: float) -> void:
	var socket := model.find_child(socket_name,true,false) as Node3D
	socket.add_child(part)
	part.transform=socket.transform.affine_inverse() * Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE*size),socket.position+offset)

func assemble(crawler: Node3D) -> void:
	model=Model.instantiate()
	add_child(model)
	rotation.y=PI
	player=model.find_child("AnimationPlayer",true,false)
	cabin=model.find_child("ROOT_PLSB_Cabin",true,false)
	cannon=model.find_child("ROOT_PLSB_Cannon",true,false)
	visor=crawler.find_child("ROOT_Head_Visor",true,false).duplicate()
	chimney_source=crawler.find_child("ROOT_Weapon_Cannon",true,false).duplicate()
	_mount("SOCKET_PLSB_Cannon_v1",chimney_source,Vector3(-.144,0,.12),1.25)
	chimney_source.hide()
	drill=crawler.find_child("ROOT_Weapon_Drill",true,false).duplicate()
	_mount("SOCKET_PLSB_Cabin_v1",visor,Vector3(0,.10,0),1.30)
	_mount("SOCKET_PLSB_Cannon_v1",drill,Vector3(-.144,0,.12),1.20)
	service_rig=Kit.part("MedicRig")
	_mount("SOCKET_PLSB_BackBoiler_v1",service_rig,Vector3(-.19,.26,0),.91)
	jammer_rig=Kit.jammer_coil()
	_mount("SOCKET_PLSB_BackBoiler_v1",jammer_rig,Vector3(-.19,.26,0),1.20)
	jammer_rig.hide()

func configure(head:int, weapon:int, has_head:bool, has_weapon:bool, repair:bool) -> void:
	cabin.visible=has_head and head==0
	visor.visible=has_head and head==1
	cannon.visible=has_weapon and weapon==0
	drill.visible=has_weapon and weapon==1
	service_rig.visible=repair

func tint(material:Material) -> void:
	for surface in ["SM_PLSB_Mobile_Torso","SM_PLSB_Mobile_Waist","SM_PLSB_Mobile_Cabin"]:
		(model.find_child(surface,true,false) as MeshInstance3D).material_override=material
