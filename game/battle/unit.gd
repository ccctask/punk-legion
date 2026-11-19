extends Node3D

const Simulation := preload("res://battle/simulation.gd")
const FRIEND := Color("#55cfbe")
const ENEMY := Color("#f08b57")
const SELECTED := Color("#ffe071")
const MotionTrack := preload("res://battle/motion_track.gd")

const BLAST:=preload("res://loadout/catalog.gd").PARTS.chimney_arm
const BlastWarning:=preload("res://battle/blast_warning.tscn")
var blast:MeshInstance3D
var ring_material := StandardMaterial3D.new()
var _health_material: StandardMaterial3D
var selected := false
var _last_shot := -10.0
var _disabled := false
var _dead_age := 0.0
@onready var ring:MeshInstance3D=$Ring
@onready var health_bar:MeshInstance3D=$Health
@onready var shot:MeshInstance3D=$Shot
@onready var tag:Label3D=$Interference
@onready var _owned_name:Label3D=$OwnedName
var _last_heading := Vector2.ZERO
var _last_hp := -1.0
var _selection_initialized := false
@onready var robot: Node3D = $Robot
@onready var _network_motion: MotionTrack = $MotionTrack
var _saved_interpolation_mode := -1
var network_motion: MotionTrack:
	get:return _network_motion

func configure_network_motion(delay: float, max_gap: float, capacity: int, guard: Callable) -> bool:
	if not _network_motion.configure(delay,max_gap,capacity,guard):
		clear_network_motion()
		return false
	if _saved_interpolation_mode<0:_saved_interpolation_mode=physics_interpolation_mode
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	return true

func clear_network_motion() -> void:
	if is_instance_valid(_network_motion):_network_motion.clear()
	if _saved_interpolation_mode>=0:
		physics_interpolation_mode=_saved_interpolation_mode
		_saved_interpolation_mode=-1

func network_motion_observation() -> Dictionary:
	return _network_motion.observation() if is_instance_valid(_network_motion) else {}

func _exit_tree() -> void:
	clear_network_motion()

func set_paint(style:String) -> void:
	robot.set_paint(style)

func setup(u: Simulation.Fighter) -> void:
	robot.set_chassis(u.profile.get("chassis","crawler"))
	robot.set_repair_arm(u.profile.parts.get("utility")=="repair_arm")
	robot.set_jammer(u.profile.parts.get("utility")=="jammer")
	robot.set_shield(u.profile.parts.get("armor")=="rivet_shield")
	robot.set_survey_radar(u.profile.parts.get("survey")=="survey_radar")
	robot.head = 1 if u.profile.parts.head == "visor" else 0
	robot.set_weapon_definition(u.profile.parts.weapon)
	if u.profile.parts.weapon=="chimney_arm":
		blast=BlastWarning.instantiate()
		blast.hide()
		get_parent().add_child(blast)
		blast.scale=Vector3(BLAST.blast_radius,1,BLAST.blast_radius)
		tree_exiting.connect(blast.queue_free)
	if u.profile.parts.core == "reinforced_boiler":
		robot.scale *= 1.20
	if robot.chassis=="crawler" and not OS.get_cmdline_user_args().has("--original-combat-shadows"):
		preload("res://battle/tactical_shadow.gd").install(robot, Vector2i(robot.head, robot.weapon))
		$Ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		$Health.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	$Ring.material_override = ring_material
	var team_mat := ring_material.duplicate() as StandardMaterial3D
	team_mat.albedo_color = FRIEND if u.side == 0 else ENEMY
	_health_material = team_mat.duplicate() as StandardMaterial3D
	health_bar.material_override = _health_material
	$Shot.material_override = team_mat
	_set_selected_information(false)

func _set_selected_information(enabled: bool) -> void:
	# Only the existing information nodes use this layer; Shot keeps team_mat.
	_health_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
	_health_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED if enabled else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	_health_material.no_depth_test = enabled
	_health_material.render_priority = 1 if enabled else 0
	_owned_name.no_depth_test = enabled
	_owned_name.render_priority = 3 if enabled else 0
	_owned_name.outline_render_priority = 2 if enabled else -1

func sync(u: Simulation.Fighter, age: float, is_selected: bool, delta: float, visual_heading: Vector2 = Vector2.ZERO) -> void:
	if blast:
		blast.visible=u.last_shot>=0 and age>=u.last_shot and age<u.last_shot+float(BLAST.blast_delay)
		if blast.visible:blast.position=Vector3(u.impact_point.x,0.15,u.impact_point.y)
	if _disabled and not visible:
		return
	var world_pos:=Vector3(u.pos.x,0.12,u.pos.y)
	if position!=world_pos:
		position=world_pos
	if u.hp<=0:
		clear_network_motion()
		if not _disabled:
			_set_selected_information(false)
			_disabled=true
			robot.play_action(&"Death")
			ring.hide()
			health_bar.hide()
			shot.hide()
			tag.hide()
		_dead_age+=delta
		if _dead_age>=0.5:
			hide()
			robot.update_pose_visibility(false,0)
		return
	var color:Color=SELECTED if is_selected else (FRIEND if u.side==0 else ENEMY)
	if u.last_service>=0 and age-u.last_service<0.6:color=Color.LIME_GREEN
	if age<u.protected_until:color=Color("b58cff")
	if u.last_jam>=0 and age-u.last_jam<0.55:color=Color("5edcf4")
	if ring_material.albedo_color!=color:
		ring_material.albedo_color=color
	if not _selection_initialized or selected!=is_selected:
		_selection_initialized=true
		selected=is_selected
		_set_selected_information(selected)
		ring.scale=Vector3.ONE*(1.3 if selected else 1.0)
	var showing_interference:=age<u.protected_until or age-u.last_jam<0.6
	if tag.visible!=showing_interference:tag.visible=showing_interference
	if showing_interference:
		var receiving:=age<u.protected_until
		var caption:=("干扰保护 %.1fs" % (u.protected_until-age)) if receiving else "发出脉冲"
		var tint:=Color("d4b2ff") if receiving else Color("77edff")
		if tag.text!=caption:tag.text=caption
		if tag.modulate!=tint:tag.modulate=tint
	if u.hp!=_last_hp:
		_last_hp=u.hp
		health_bar.scale.x=0.8*maxf(0.01,u.hp/float(u.stats.max_hp))
	var attacking:=age-u.last_shot<=0.32
	var shown_heading:=u.last_heading
	if not attacking and u.profile.parts.get("armor")!="rivet_shield" and visual_heading.is_finite() and visual_heading.length_squared()>0.01:
		shown_heading=visual_heading
	if shown_heading!=_last_heading and shown_heading.length_squared()>0.01:
		_last_heading=shown_heading
		robot.rotation.y=atan2(-shown_heading.x,-shown_heading.y)
	if _last_shot != u.last_shot:
		_last_shot = u.last_shot
		robot.play_action(&"Attack")
	elif not attacking:
		robot.set_motion(u.walking)
	var show_trace := blast==null and age - u.last_shot < 0.13
	if shot.visible!=show_trace:shot.visible=show_trace
	if show_trace:
		var trace := u.impact_point - u.pos
		shot.position = Vector3(trace.x * 0.5, 0.68, trace.y * 0.5)
		shot.rotation.y = atan2(trace.x, trace.y)
		shot.scale = Vector3(0.055, 0.055, maxf(0.02, trace.length()))


