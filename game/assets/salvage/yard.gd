extends Node3D

const Kit := preload("res://assets/salvage/kit.gd")
const Sites := preload("res://expedition/rail_sites.gd")
# Pump's authored field inherits this name only to read the original ROCKS.
const Mission := Sites
var labels := {}

func _ready() -> void:
	Kit.load_meshes()
	for bounds in Sites.ROCKS:
		_cover(bounds)
	for row in [[-19,-29,14],[-3,1,7],[18,-22,12]]:
		var transforms:Array[Transform3D]=[]
		for i in int(row[2]):
			var x:float=row[1]+4.12*i
			transforms.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(x,-0.006,row[0])))
		_place_batch("Track",transforms,false)
	for key in Sites.LOCATIONS:
		var config: Dictionary = Sites.visual(key)
		var module:=Kit.part(config.mesh)
		module.name=key
		add_child(module)
		var pos:Vector2=Sites.LOCATIONS[key]
		module.position=Vector3(pos.x,0,pos.y)+config.offset
		module.scale=Vector3.ONE*float(config.scale)
		module.rotation.y=float(config.rotation)
		var label:=Label3D.new()
		label.text=Sites.NAMES[key]
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size=0.017
		label.position=module.position+Vector3.UP*float(config.label_height)
		add_child(label)
		labels[key]=label
	set_goals(["scrap","fuel"])

func set_goals(goals: Array) -> void:
	for key in labels:
		labels[key].visible=key in goals and key not in ["boss","guard"]

func _cover(bounds: Rect2i) -> void:
	var source:Mesh=Kit.meshes.Cover
	var box:=source.get_aabb()
	var count:=maxi(1,roundi(float(bounds.size.y)/3.3))
	var span:=float(bounds.size.y)/count
	var ratio:=Vector3((bounds.size.x-0.15)/box.size.x,2.54/box.size.y,(span-0.11)/box.size.z)
	var basis:=Basis.IDENTITY.scaled(ratio)
	var transforms:Array[Transform3D]=[]
	for i in count:
		# Integer cells occupy [center-0.5,center+0.5] on each axis.
		var pos:=Vector3(bounds.position.x+(bounds.size.x-1)*0.5,0,bounds.position.y-0.5+span*(i+0.5))
		transforms.append(Transform3D(basis.rotated(Vector3.UP,PI if i%2==1 else 0.0),pos))
	_place_batch("Cover",transforms,true)

func _place_batch(module: String, transforms: Array[Transform3D], shadows: bool) -> void:
	var batch:=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.mesh=Kit.meshes[module]
	batch.instance_count=transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i,transforms[i])
	var props:=MultiMeshInstance3D.new()
	props.multimesh=batch
	props.material_override=Kit.PAINT
	if not shadows:
		props.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(props)
