extends SceneTree
func _initialize():
	call_deferred("check")
func check():
	var packed = load("res://assets/steam_crawler/robot.tscn")
	var a = packed.instantiate()
	var b = packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	b.head = 1
	b.weapon = 1
	b.set_motion(true)
	var pa = a.find_child("AnimationPlayer", true, false)
	var pb = b.find_child("AnimationPlayer", true, false)
	var ok = pa.current_animation == "Idle" and pb.current_animation == "Move"
	for id in ["ROOT_Head_Eye", "ROOT_Head_Visor", "ROOT_Weapon_Cannon", "ROOT_Weapon_Drill"]:
		ok = ok and a.find_child(id,true,false).visible != b.find_child(id,true,false).visible
	var t = b.find_child("ROOT_LeftTrack",true,false)
	pb.advance(0.15)
	var baseline = t.transform
	b.play_action("Death")
	pb.advance(3.5)
	b.set_motion(false)
	pb.advance(0.15)
	print("clips=",pb.get_animation_list()," dual_instances=",ok," rest_after_death=",baseline.is_equal_approx(t.transform))
	quit(0 if ok and baseline.is_equal_approx(t.transform) else 1)
