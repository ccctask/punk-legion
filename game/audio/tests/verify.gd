extends Node

const Mixer:=preload("res://audio/battle_audio.tscn")
const Selector:=preload("res://audio/volume.tscn")
const Pref:=preload("res://audio/preferences.gd")
const Fighter:=preload("res://battle/simulation.gd").Fighter
var heard:Array[StringName]=[]

func _ready() -> void:
	_run.call_deferred()

func _level(selector:OptionButton,index:int) -> void:
	selector.select(index)
	selector.item_selected.emit(index)

func _run() -> void:
	var settings:=Selector.instantiate() as OptionButton
	add_child(settings)
	var other:=Selector.instantiate() as OptionButton
	add_child(other)
	var initial:=settings.selected
	var repeat:=FileAccess.file_exists("user://audio-qa-first")
	if repeat:
		assert(initial==0 and other.selected==0)
	_level(settings,0)
	var quiet:=Mixer.instantiate()
	add_child(quiet)
	var camera:=Camera3D.new()
	add_child(camera)
	camera.position=Vector3(0,7,7)
	camera.look_at(Vector3.ZERO)
	var units:={}
	var views:={}
	for i in 24:
		var fighter:=Fighter.new()
		fighter.stats={"max_hp":100}
		fighter.hp=100
		fighter.side=i%2
		fighter.walking=true
		units[i]=fighter
		var visual:=Node3D.new()
		add_child(visual)
		views[i]=visual
	quiet.observe("room",0,units,views,camera)
	assert(not quiet.tread.playing)
	_level(settings,3)
	var fx:=Mixer.instantiate()
	add_child(fx)
	assert(fx.tread.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
	fx.cue_started.connect(func(kind:StringName,_time:float):heard.append(kind))
	fx.observe("room",0,units,views,camera)
	assert(heard==[&"tread"])
	units[0].hp=34
	units[0].last_shot=.20
	fx.observe("room",.20,units,views,camera)
	fx.observe("room",.20,units,views,camera)
	fx.observe("room",.22,units,views,camera)
	units[0].hp=100
	units[0].last_shot=-10
	fx.observe("room",.1,units,views,camera)
	units[0].hp=34
	units[0].last_shot=.20
	fx.observe("room",.23,units,views,camera)
	assert(heard==[&"tread",&"steam",&"danger"])
	assert(fx.tread.playing and fx.steam.playing and fx.danger.playing)
	# A second selector and both live mixers follow each commit without adding dB offsets.
	for value:int in [1,2,3,2,1,3]:
		_level(other,value)
		assert(settings.selected==value)
		for mix in [fx,quiet]:
			assert(mix.level==value)
			var gain:=linear_to_db(float(Pref.LEVELS[value]))
			assert(is_equal_approx(mix.tread.volume_db,-9.0+gain))
			assert(is_equal_approx(mix.steam.volume_db,-4.0+gain))
			assert(is_equal_approx(mix.danger.volume_db,-2.0+gain))
	# Block only the temporary settings path in the disposable QA directory.
	assert(DirAccess.make_dir_absolute(Pref.pending_path())==OK)
	_level(settings,0)
	assert(settings.selected==3 and other.selected==3 and fx.level==3)
	assert(fx.tread.playing and Pref.level()==3)
	var saved:=ConfigFile.new()
	assert(saved.load(Pref.FILE)==OK and saved.get_value("effects","level")==3)
	assert(DirAccess.remove_absolute(Pref.pending_path())==OK)
	_level(other,0)
	assert(settings.selected==0 and not fx.tread.playing and not fx.steam.playing and not fx.danger.playing)
	units[0].hp=100
	fx.observe("room",.24,units,views,camera)
	units[0].hp=25
	units[0].last_shot=.25
	fx.observe("room",.25,units,views,camera)
	_level(settings,3)
	fx.observe("room",.26,units,views,camera)
	assert(heard==[&"tread",&"steam",&"danger",&"tread"])
	units[0].hp=100
	fx.observe("room",.51,units,views,camera)
	units[0].hp=29
	units[0].last_shot=.52
	fx.observe("room",.52,units,views,camera)
	assert(heard==[&"tread",&"steam",&"danger",&"tread",&"steam",&"danger"])
	# Give the real mixer one block before testing stop and scene teardown.
	await get_tree().create_timer(.10).timeout
	fx.reset_audio()
	assert(not fx.tread.playing and not fx.steam.playing and not fx.danger.playing)
	for fighter in units.values():fighter.walking=false
	fx.observe("room",.4,units,views,camera)
	assert(heard.size()==6)
	units[1].hp=19
	units[1].last_shot=.5
	fx.observe("room",.50,units,views,camera)
	assert(heard.size()==6)
	fx.queue_free()
	quiet.queue_free()
	await get_tree().process_frame
	# WAV playbacks are released by the audio mixing thread on subsequent blocks.
	await get_tree().create_timer(.25).timeout
	_level(settings,0)
	var record:=FileAccess.open("user://audio-qa-first",FileAccess.WRITE)
	record.store_string("muted")
	record.close()
	print("AUDIO_QA_PASS persisted_previous=",repeat," actors=24 voices_peak=3 repeated_frame=quiet enemy=quiet exit=stopped")
	var report:=FileAccess.open("user://audio-qa-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"previous_process_was_muted":repeat,"heard":heard,"actors":24,"max_voices":3}))
	report.close()
	get_tree().quit()


