extends Node

signal cue_started(kind:StringName, battle_time:float)
const Pref:=preload("res://audio/preferences.gd")
const TRACK_LOOP:=preload("res://audio/tread.wav")
const HEEL:=preload("res://audio/heel.wav")
var contacts:Dictionary={}
var last_heel:=-1.0
const LOW_HP:=0.35
var session:=""
var previous:Dictionary={}
var last_elapsed:=-1.0
var last_steam:=-10.0
var level:=0
var base_db:=PackedFloat32Array()
@onready var tread:AudioStreamPlayer=$Tread
@onready var steam:AudioStreamPlayer=$Steam
@onready var danger:AudioStreamPlayer=$Danger

func _ready() -> void:
	for voice:AudioStreamPlayer in [tread,steam,danger]:
		base_db.append(voice.volume_db)
	Pref.updates.changed.connect(_apply_level)
	_apply_level(Pref.level())

func _apply_level(value:int) -> void:
	level=value
	if value==0:
		# If the scene also pauses during mute, its first fresh observation must
		# establish a baseline instead of replaying a transition across the gap.
		previous.clear()
	var gain:=linear_to_db(maxf(float(Pref.LEVELS[value]),.001))
	var voices: Array[AudioStreamPlayer]=[tread,steam,danger]
	for i in voices.size():
		voices[i].volume_db=base_db[i]+gain
		if value==0:
			voices[i].stop()

func reset_audio() -> void:
	for voice:AudioStreamPlayer in [tread,steam,danger]:
		voice.stop()
	previous.clear()
	contacts.clear()
	last_heel=-1.0
	session=""
	last_elapsed=-1.0
	last_steam=-10.0

# Called with the same locally simulated or server-confirmed Fighters displayed by
# the views. A first observation establishes a baseline, including after reconnect.
func observe(match_id:String, elapsed:float, fighters:Dictionary, views:Dictionary, camera:Camera3D, friendly_side:int=0, baseline_only:bool=false) -> void:
	if match_id!=session:
		reset_audio()
		session=match_id
	if elapsed<=last_elapsed:return
	last_elapsed=elapsed
	var moving:=false
	var footfall:=false
	var walking_biped:=false
	var new_shot:=false
	var new_danger:=false
	for id in fighters:
		var unit=fighters[id]
		if unit.side!=friendly_side or not views.has(id):continue
		var visual:Node3D=views[id]
		var health:=float(unit.hp)/maxf(float(unit.stats.max_hp),1.0)
		var latest_shot:=float(unit.last_shot)
		var visible_here:=visual.is_visible_in_tree() and camera.is_position_in_frustum(Vector3(unit.pos.x,0.7,unit.pos.y))
		if health>0 and visible_here:
			if unit.profile.get("chassis","crawler")=="biped":
				var robot:=visual.get_node_or_null("Robot")
				var contact:int=robot.foot_contact() if unit.walking and robot else -1
				if contact>=0:
					walking_biped=true
					if contacts.get(id,-1)!=contact:
						footfall=true
				contacts[id]=contact
			elif unit.profile.get("chassis","crawler")=="crawler":
				moving=moving or unit.walking
			if previous.has(id):
				var prior:Vector2=previous[id]
				new_shot=new_shot or (latest_shot>prior.y+.0001 and latest_shot>=0 and elapsed-latest_shot<0.45)
				new_danger=new_danger or (prior.x>LOW_HP and health<=LOW_HP)
		if not visible_here or health<=0:
			contacts.erase(id)
		previous[id]=Vector2(health,latest_shot)
	if level==0 or baseline_only:return
	if walking_biped:
		if tread.stream!=HEEL:
			tread.stream=HEEL
		if footfall and elapsed-last_heel>=.16:
			last_heel=elapsed
			tread.play()
			cue_started.emit(&"heel",elapsed)
	elif moving and (tread.stream!=TRACK_LOOP or not tread.playing):
		tread.stream=TRACK_LOOP
		tread.play()
		cue_started.emit(&"tread",elapsed)
	elif not moving and tread.playing:
		tread.stop()
	if new_shot and elapsed-last_steam>=.22:
		last_steam=elapsed
		steam.play()
		cue_started.emit(&"steam",elapsed)
	if new_danger and not danger.playing:
		danger.play()
		cue_started.emit(&"danger",elapsed)

