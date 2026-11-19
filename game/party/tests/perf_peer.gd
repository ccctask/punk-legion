extends SceneTree

func _initialize() -> void:
	var driver=load("res://party/tests/mobile_perf.gd").new()
	root.call_deferred("add_child",driver)
