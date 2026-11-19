extends HFlowContainer
signal chosen(role:String)
func _ready() -> void:
	$Front.pressed.connect(func():chosen.emit("front"))
	$Fire.pressed.connect(func():chosen.emit("fire"))
	$Support.pressed.connect(func():chosen.emit("support"))
