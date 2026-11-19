extends Node3D

func set_goals(goals:Array) -> void:
	$Armory/Breaker/Label.visible="armory_breaker" in goals
	$Armory/Cache/Label.visible="armory_cache" in goals
	$Armory/Gate/Label.visible="armory_exit" in goals
