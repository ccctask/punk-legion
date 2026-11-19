extends HBoxContainer

signal recalled(ids: Array[String])

# The battle screen may be recreated during reconnect. Keep only the current
# seat's two groups in process memory, never in the account or device save.
static var current_seat := ""
static var members := [[],[]]
static var titles := ["一组","二组"]
static var seat_numbers := {}
var roster := {}
var seat := ""

func _ready() -> void:
	%Slot.add_item("一组")
	%Slot.add_item("二组")
	%Slot.item_selected.connect(_edit_slot)
	$Edit.pressed.connect(_open)
	$Recall1.pressed.connect(_recall.bind(0))
	$Recall2.pressed.connect(_recall.bind(1))
	%Save.pressed.connect(_save)
	%Cancel.pressed.connect($Editor.hide)
	%Clear.pressed.connect(func():
		for check: CheckButton in %Roster.get_children():
			check.button_pressed = false)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			$Editor.hide())
	_refresh()

func suspend() -> void:
	seat = ""
	roster.clear()
	$Editor.hide()
	_refresh()

func bind_roster(context: String, rows: Dictionary) -> void:
	if context.is_empty():
		suspend()
		return
	if current_seat != context:
		current_seat = context
		members = [[],[]]
		titles = ["一组","二组"]
		seat_numbers.clear()
		$Editor.hide()
	if seat == context and roster == rows:
		return
	seat = context
	roster = rows.duplicate()
	for id in roster:
		if not seat_numbers.has(id):
			seat_numbers[id] = seat_numbers.size()+1
	if $Editor.visible:
		var checked := []
		for check: CheckButton in %Roster.get_children():
			if check.button_pressed:
				checked.append(check.get_meta("unit_id"))
		_draw_roster(checked)
	_refresh()

func _available(slot: int) -> Array[String]:
	var ids: Array[String] = []
	if seat == current_seat:
		for id in members[slot]:
			if roster.has(id):
				ids.append(id)
	return ids

func _refresh() -> void:
	$Edit.disabled = seat.is_empty() or seat != current_seat
	for slot in 2:
		var button: Button = [$Recall1,$Recall2][slot]
		var count := _available(slot).size()
		button.text = "%s·%d" % [str(titles[slot]).left(3),count]
		button.tooltip_text = "%s（%d 台可用）" % [titles[slot],count]
		button.disabled = count == 0

func _recall(slot: int) -> void:
	var ids := _available(slot)
	if not ids.is_empty():
		recalled.emit(ids)

func _open() -> void:
	if current_seat != seat or seat.is_empty():
		return
	_edit_slot(%Slot.selected)
	var viewport_size := get_viewport_rect().size
	$Editor.popup_centered_clamped(Vector2i(minf(360,viewport_size.x-16),minf(390,viewport_size.y-16)),0.95)

func _edit_slot(slot: int) -> void:
	%GroupName.text = titles[slot]
	_draw_roster(members[slot])

func _draw_roster(checked: Array) -> void:
	for child in %Roster.get_children():
		%Roster.remove_child(child)
		child.queue_free()
	for id: String in roster:
		var label: String = roster[id]
		var check := CheckButton.new()
		if roster.values().count(label)>1:
			label += " · #%02d"%int(seat_numbers[id])
		check.text = label
		check.tooltip_text = id
		check.set_meta("unit_id",id)
		check.custom_minimum_size.y = 42
		check.button_pressed = id in checked
		%Roster.add_child(check)

func _save() -> void:
	if seat.is_empty() or current_seat != seat:
		return
	var slot: int = %Slot.selected
	var ids: Array[String] = []
	for check: CheckButton in %Roster.get_children():
		var id: String = check.get_meta("unit_id")
		if check.button_pressed and roster.has(id):
			ids.append(id)
	members[slot] = ids
	var title: String = %GroupName.text.strip_edges().left(6)
	titles[slot] = ["一组","二组"][slot] if title.is_empty() else title
	_refresh()
	$Editor.hide()
