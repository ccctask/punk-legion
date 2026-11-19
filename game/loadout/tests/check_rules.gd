extends SceneTree

const Catalog := preload("res://loadout/catalog.gd")
const Rules := preload("res://loadout/rules.gd")
var failures := 0

func expect(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED ", label)
		failures += 1

func failure(result: Dictionary, code: String) -> void:
	expect(not result.ok and result.get("code") == code, "expected %s, got %s" % [code, result])

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var inventory := Catalog.sample_inventory(13)
	var unit: Dictionary = Catalog.sample_squad(1)[0]
	var result := Rules.validate_unit(unit, inventory)
	expect(result.ok and result.totals.points == 2 and result.totals.mass == 4, "base unit")
	unit.slots.weapon = "1/drill"
	result = Rules.validate_unit(unit, inventory)
	expect(result.ok and result.totals.points == 3 and result.parts.weapon == "drill", "compatible swap")
	unit.slots.head = "1/visor"
	failure(Rules.validate_unit(unit, inventory), "exclusive")
	unit = Catalog.sample_squad(1)[0]
	var req := unit.duplicate(true)
	req.version = 99
	failure(Rules.validate_unit(req, inventory), "version")
	req = unit.duplicate(true)
	req.points = 0
	failure(Rules.validate_unit(req, inventory), "format")
	req = unit.duplicate(true)
	req.slots.weapon = "other/player/item"
	failure(Rules.validate_unit(req, inventory), "ownership")
	req.slots.weapon = req.slots.head
	failure(Rules.validate_unit(req, inventory), "duplicate")
	req.slots.weapon = "1/visor"
	failure(Rules.validate_unit(req, inventory), "kind")
	req.slots.erase("weapon")
	failure(Rules.validate_unit(req, inventory), "missing_slot")
	req.slots.tail = "1/cannon"
	failure(Rules.validate_unit(req, inventory), "unknown_slot")

	# Small trusted definition fixtures isolate each budget and compatibility rule.
	for entry in [["interface","other","interface"],["size",3,"size"],["mass",9,"weight"],["power",9,"power"],["heat",9,"heat"]]:
		var parts := Catalog.PARTS.duplicate(true)
		parts.cannon[entry[0]] = entry[1]
		failure(Rules.validate_unit(unit, inventory, Catalog.CHASSIS, parts), entry[2])
	var squad := Catalog.sample_squad(12)
	var heavy := Rules.validate_squad(Catalog.sample_squad(6, true), inventory)
	expect(heavy.ok and heavy.points == 24 and heavy.roster[0].combat.max_hp == 155, "heavy 6 units / 24 points")
	expect(Rules.validate_squad(squad, inventory).points == 24, "boundary 24 points / 12 units")
	squad[1].slots.head = squad[0].slots.head
	failure(Rules.validate_squad(squad, inventory), "duplicate")
	squad = Catalog.sample_squad(12)
	squad[0].slots.weapon = "1/drill"
	failure(Rules.validate_squad(squad, inventory), "point_limit")
	failure(Rules.validate_squad(Catalog.sample_squad(13), inventory), "unit_limit")
	failure(Rules.validate_squad([], inventory), "format")

	var workshop = load("res://loadout/workshop.tscn").instantiate()
	root.add_child(workshop)
	workshop.get_node("%Tool").select(1)
	workshop.get_node("%Tool").item_selected.emit(1)
	expect(workshop.accepted.slots.weapon == "1/drill" and workshop.get_node("Robot").weapon == 1, "legal tool visible")
	workshop.get_node("%Sensor").select(1)
	workshop.get_node("%Sensor").item_selected.emit(1)
	expect(workshop.accepted.slots.head == "1/eye" and workshop.get_node("Robot").head == 0, "failed request preserves appearance")
	expect(not workshop.get_node("%Problem").text.is_empty(), "failure explanation")
	print("loadout failures=", failures)
	quit(1 if failures else 0)
