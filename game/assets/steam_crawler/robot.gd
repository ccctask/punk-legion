@tool
extends Node3D

@export_enum("Eye", "Visor") var head: int = 0:
	set(value):
		head = value
		if is_node_ready():
			_apply_variants()

@export_enum("Cannon", "Drill", "Chimney", "Rivet Repeater") var weapon: int = 0:
	set(value):
		weapon = value
		if is_node_ready():
			_apply_variants()

@onready var _model: Node3D = $Model
@onready var _player: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
var _moving := false
var paint := "base"
const MINT := preload("res://store/mint.tres")

const Biped := preload("res://assets/steam_biped/assembly.gd")
var biped: Biped
const WHEELS := ["wheel", "survey_wheel"]
var chassis := "crawler"
var _survey_equipped := false
var _survey_radar: Node3D
var _repair := false
var _has_shield := false
var _shield: Node3D
var _has_head := true
var _has_weapon := true
const NumberPlate := preload("res://assets/steam_crawler/hull_number_plate.gd")
var hull_number := ""
var _number_plate:NumberPlate

func set_hull_number(value:String) -> void:
	if value==hull_number and is_instance_valid(_number_plate):
		return
	hull_number=value if NumberPlate.valid(value) else ""
	if not is_node_ready():return
	if hull_number.is_empty():
		if is_instance_valid(_number_plate):_number_plate.free()
		return
	if not is_instance_valid(_number_plate):
		_number_plate=NumberPlate.new()
		_number_plate.name="HullNumberPlate"
		var socket:Node3D=biped.model.find_child("ROOT_PLSB_Torso",true,false) if biped else _model.find_child("ROOT_Boiler",true,false)
		socket.add_child(_number_plate)
		_number_plate.position=Vector3(-.23,.13,.42) if biped else Vector3(-.25,.16,.39)
		_number_plate.rotation_degrees=Vector3(-9,-20 if biped else -32,0)
	_number_plate.show_number(hull_number)

func set_slots_present(has_head:bool,has_weapon:bool) -> void:
	_has_head=has_head
	_has_weapon=has_weapon
	if is_node_ready():
		_apply_variants()

func set_chassis(kind:String) -> void:
	var previous := chassis
	chassis=kind if kind in ["biped", "wheel", "survey_wheel"] else "crawler"
	if not is_node_ready():
		return
	if chassis=="biped":
		if not biped:
			biped=Biped.new()
			biped.name="Biped"
			add_child(biped)
			biped.assemble(_model)
			_model.free()
			_model=null
		_player=biped.player
	else:
		var rebuild := biped != null or (previous in WHEELS and chassis not in WHEELS)
		if biped:
			biped.free()
			biped=null
		if rebuild:
			if is_instance_valid(_model):
				_model.free()
			_model=preload("res://assets/steam_crawler/model.glb").instantiate()
			_model.name="Model"
			_model.rotation.y=PI
			add_child(_model)
		if chassis in WHEELS and not _model.has_node("WheelFrame"):
			preload("res://assets/steam_crawler/wheel_assembly.gd").assemble(_model)
		_player=_model.find_child("AnimationPlayer",true,false)
	_apply_paint()
	for clip in [&"Idle",&"Move"]:
		_player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	_apply_variants()
	set_repair_arm(_repair)
	set_jammer(_jammer)
	set_survey_radar(_survey_equipped)
	set_shield(_has_shield)
	set_hull_number(hull_number)
	set_motion(_moving)

func set_shield(equipped: bool) -> void:
	_has_shield = equipped
	if not is_node_ready():
		return
	if chassis != "crawler":
		if is_instance_valid(_shield):
			_shield.hide()
		return
	if equipped and not is_instance_valid(_shield):
		var socket := _model.find_child("ROOT_FrontArmor",true,false)
		var casting := socket.find_child("SM_Runtime_ROOT_FrontArmor_12",true,false) as MeshInstance3D
		_shield = preload("res://assets/steam_crawler/rivet_shield.tscn").instantiate()
		_shield.get_node("Plate").mesh = casting.mesh
		socket.add_child(_shield)
	if is_instance_valid(_shield):
		_shield.visible = equipped

func foot_contact() -> int:
	if chassis=="biped" and _player.current_animation==&"Move":
		return floori(_player.current_animation_position) % 2
	return -1

var _repair_arm: MeshInstance3D
var _jammer:=false
var _coil:Node3D

func set_survey_radar(equipped:bool) -> void:
	_survey_equipped = equipped
	if not is_node_ready():
		return
	var installed := equipped and chassis == "survey_wheel"
	if installed and not is_instance_valid(_survey_radar):
		_survey_radar = preload("res://assets/steam_crawler/survey_radar.tscn").instantiate()
		var mast := preload("res://assets/salvage/kit.gd").part("Signal")
		mast.scale = Vector3(.18,.23,.18)
		_survey_radar.add_child(mast)
		var socket := _model.find_child("ROOT_Boiler",true,false) as Node3D
		socket.add_child(_survey_radar)
		_survey_radar.position = Vector3(.4,.31,-.23)
	if is_instance_valid(_survey_radar):
		_survey_radar.visible = installed

func set_jammer(equipped:bool) -> void:
	_jammer=equipped
	if not is_node_ready():return
	if biped:
		biped.jammer_rig.visible=equipped
	if not is_instance_valid(_coil) and equipped and chassis=="crawler":
		_coil=preload("res://assets/salvage/kit.gd").jammer_coil()
		add_child(_coil)
	if is_instance_valid(_coil):
		_coil.visible=equipped and chassis=="crawler"
		_coil.position=Vector3(0,0.99,0.18)

func set_repair_arm(equipped:bool) -> void:
	_repair=equipped
	if biped:
		biped.service_rig.visible=equipped
	if equipped and chassis=="crawler" and not is_instance_valid(_repair_arm):
		_repair_arm=preload("res://assets/salvage/kit.gd").part("MedicRig")
		add_child(_repair_arm)
		_repair_arm.rotation.y=PI
		_repair_arm.scale=Vector3.ONE*1.55
		_repair_arm.position=Vector3(0,0.88,0.06)
	if is_instance_valid(_repair_arm):
		_repair_arm.visible=equipped and chassis=="crawler"

func set_paint(style:String) -> void:
	if style==paint:
		return
	paint=style if style=="mint" else "base"
	_apply_paint()

func _apply_paint() -> void:
	if biped:
		biped.tint(MINT if paint=="mint" else null)
		return
	for item:Node in _model.find_children("SM_Runtime_ROOT_*","MeshInstance3D",true,false):
		if item.name.begins_with("SM_Runtime_ROOT_Chassis_") or item.name.begins_with("SM_Runtime_ROOT_FrontArmor_") or item.name.begins_with("SM_Runtime_ROOT_Head_"):
			(item as MeshInstance3D).material_override=MINT if paint=="mint" else null

func _ready() -> void:
	set_chassis(chassis)

func set_weapon_definition(definition:String) -> void:
	weapon=int(preload("res://loadout/catalog.gd").PARTS.get(definition,{}).get("visual",0))

func _apply_stack(cannon:Node3D) -> void:
	var mount:=cannon.get_parent()
	var stack:=mount.get_node_or_null("ChimneyLauncher") as Node3D
	if weapon==2 and not stack:
		stack=Node3D.new()
		stack.name="ChimneyLauncher"
		mount.add_child(stack)
		stack.transform=cannon.transform
		# Pair the existing toy cannon castings on the original animated weapon mount.
		for i in 2:
			var tube:=cannon.duplicate() as Node3D
			stack.add_child(tube)
			tube.transform=Transform3D.IDENTITY
			tube.position=Vector3(-0.25+i*0.32,0.04,-i*0.14)
			tube.rotation=Vector3(deg_to_rad(-72+i*9),0,deg_to_rad(9-i*12))
			tube.scale=Vector3(0.86,0.84,1.54-i*0.36)
			tube.show()
	if stack:stack.visible=_has_weapon and weapon==2

func _apply_repeater(cannon:Node3D, offset:Vector3) -> void:
	var mount := cannon.get_parent()
	var rig := mount.get_node_or_null("RivetRepeater") as Node3D
	if weapon == 3 and not rig:
		rig = preload("res://assets/steam_crawler/rivet_repeater.tscn").instantiate()
		mount.add_child(rig)
		rig.transform = cannon.transform.translated_local(offset)
	if rig:
		rig.visible = _has_weapon and weapon == 3

func _apply_variants() -> void:
	if biped:
		_apply_stack(biped.chimney_source)
		_apply_repeater(biped.cannon, Vector3.ZERO)
		biped.configure(head,weapon,_has_head,_has_weapon,_repair)
		return
	(_model.find_child("ROOT_Head_Eye", true, false) as Node3D).visible = _has_head and head == 0
	(_model.find_child("ROOT_Head_Visor", true, false) as Node3D).visible = _has_head and head == 1
	var cannon:=_model.find_child("ROOT_Weapon_Cannon",true,false) as Node3D
	_apply_stack(cannon)
	_apply_repeater(cannon, Vector3(.235,.07,-.05))
	cannon.visible = _has_weapon and weapon == 0
	(_model.find_child("ROOT_Weapon_Drill", true, false) as Node3D).visible = _has_weapon and weapon == 1

# Completely off-camera rigs keep their animation clock without evaluating skin poses.
# The original idle processing mode and exact clip time are restored before the rig returns.
var _pose_paused := false
var _pending_pose_time := 0.0
var _prior_callback := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

func update_pose_visibility(in_view:bool,delta:float) -> void:
	if not in_view:
		if not _pose_paused:
			_prior_callback=_player.callback_mode_process
			_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			_pose_paused=true
		_pending_pose_time+=delta
	elif _pose_paused:
		_advance_hidden_pose()
		_player.callback_mode_process=_prior_callback
		_pose_paused=false

func _advance_hidden_pose() -> void:
	if _pending_pose_time>0:
		_player.advance(_pending_pose_time)
		_pending_pose_time=0.0

func set_motion(moving: bool) -> void:
	_moving = moving
	if _player:
		var requested: StringName = &"Move" if moving else &"Idle"
		if _player.current_animation != requested:
			if _pose_paused:_advance_hidden_pose()
			_player.play(requested)

func play_action(clip: StringName) -> void:
	if clip in [&"Attack", &"Death"]:
		if _pose_paused:_advance_hidden_pose()
		_player.play(clip)
