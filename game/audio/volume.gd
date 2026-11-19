extends OptionButton

const Pref := preload("res://audio/preferences.gd")
var hint := ""

func _ready() -> void:
	hint=tooltip_text
	for label in ["音效 · 静音","音效 · 低","音效 · 中","音效 · 高"]:
		add_item(label)
	Pref.updates.changed.connect(_reflect)
	_reflect(Pref.level())
	item_selected.connect(_save)

func _reflect(value:int) -> void:
	select(value)
	tooltip_text=hint

func _save(index:int) -> void:
	if Pref.save_level(index)!=OK:
		select(Pref.level())
		tooltip_text="音量保存失败"
