extends SceneTree

const Catalog := preload("res://loadout/catalog.gd")
const Rules := preload("res://loadout/rules.gd")

func nonfinite_path(value: Variant, path: String = "$") -> String:
	if typeof(value) == TYPE_FLOAT and not is_finite(value):
		return path
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		for key: Variant in keys:
			var found := nonfinite_path(value[key], path + "." + str(key))
			if not found.is_empty(): return found
	elif value is Array:
		for index in value.size():
			var found := nonfinite_path(value[index], path + "[" + str(index) + "]")
			if not found.is_empty(): return found
	return ""

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Expected fixture and export paths")
		quit(2)
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(arguments[0])) != OK:
		push_error("FixtureParseError")
		quit(2)
		return
	var fixture: Variant = parser.data
	if not fixture is Dictionary or not fixture.get("cases") is Array or fixture.cases.size() != 4:
		push_error("MissingSamples")
		quit(2)
		return
	var catalog := {"version": Catalog.VERSION, "chassis": Catalog.CHASSIS, "parts": Catalog.PARTS}
	var invalid := nonfinite_path(catalog)
	if not invalid.is_empty():
		push_error("NonFinite:" + invalid)
		quit(2)
		return
	var control: Dictionary = catalog.duplicate(true)
	control.parts.cannon.damage = NAN
	var control_path := nonfinite_path(control)
	if control_path != "$.parts.cannon.damage":
		push_error("NonFiniteControlFailed")
		quit(2)
		return
	var samples := []
	for sample: Dictionary in fixture.cases:
		var units: Array = sample.units
		var inventory: Dictionary = sample.inventory
		samples.append({"name": sample.name, "unit": Rules.validate_unit(units[0], inventory), "squad": Rules.validate_squad(units, inventory)})
	var output := {"catalog": catalog, "samples": samples, "finite_control": {"rejected": true, "path": control_path}, "fixture_sha256": FileAccess.get_sha256(arguments[0])}
	var target := FileAccess.open(arguments[1], FileAccess.WRITE)
	if target == null:
		push_error("ExportOpenFailed")
		quit(2)
		return
	target.store_string(JSON.stringify(output, "\t", true, true) + "\n")
	target.flush()
	var status := target.get_error()
	target.close()
	if status != OK:
		push_error("ExportWriteFailed")
		quit(2)
		return
	print("CATALOG_EXPORT_COMPLETE samples=", samples.size())
	quit(0)
