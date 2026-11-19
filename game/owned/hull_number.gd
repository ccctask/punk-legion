extends VBoxContainer

signal changed(value:String)
signal save_requested(fields:Dictionary)

var robot:=""
var current:=""
var locked:=true

func _ready() -> void:
	$Edit.pressed.connect(func():
		$Fields.show()
		%Input.text=current
		_render()
		%Input.grab_focus())
	%Cancel.pressed.connect(_close_editor)
	%Clear.pressed.connect(func():
		%Input.text=""
		_edit(""))
	%Input.text_changed.connect(_edit)
	%Input.text_submitted.connect(func(_text:String):%Input.release_focus())
	%Save.pressed.connect(func():
		if not %Save.disabled:
			var fields:={"robot":robot,"expected":current,"value":%Input.text}
			_close_editor()
			save_requested.emit(fields))

func bind(unit:Dictionary,blocked:bool) -> void:
	if robot!=unit.id or current!=unit.get("hull_number",""):
		robot=unit.id
		current=unit.get("hull_number","")
		$Fields.hide()
		%Input.text=current
	locked=blocked or unit.task!=null or unit.get("state","ready")!="ready"
	_render()

func _valid(value:String) -> bool:
	if value.is_empty():return true
	if value.length()!=2:return false
	return value.unicode_at(0) in range(48,58) and value.unicode_at(1) in range(48,58)

func displayed() -> String:
	return %Input.text if $Fields.visible and _valid(%Input.text) else current

func _edit(_value:String) -> void:
	_render()
	changed.emit(displayed())

func _close_editor() -> void:
	%Input.release_focus()
	$Fields.hide()
	_render()
	changed.emit(current)

func _render() -> void:
	var value:String=%Input.text
	$Edit.text="编辑机身号 · "+("无号" if current.is_empty() else current)
	$Edit.disabled=locked
	$Edit.visible=not $Fields.visible
	%Input.editable=not locked
	%Clear.disabled=locked or value.is_empty()
	%Save.disabled=locked or value==current or not _valid(value)
	if not _valid(value):
		%Hint.text="请输入两位半角数字（00–99）。"
	else:
		%Hint.text="当前 %s　预览 %s · 免费" % [current if not current.is_empty() else "无号",value if not value.is_empty() else "无号"]
