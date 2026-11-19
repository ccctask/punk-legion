extends RefCounted

const Catalog := preload("res://loadout/catalog.gd")
const Rules := preload("res://loadout/rules.gd")
const WORKSHOP := "res://loadout/workshop.tscn"
const BATTLE := "res://battle/battle.tscn"
const RANGE := "res://client/range.tscn"

# Retain accepted presets for the current session. Ownership is a fixture until M08.
static var _selection := {"head":"eye", "weapon":"cannon", "core":"boiler"}
static var _deployment := []

static func selection() -> Dictionary:
	return _selection.duplicate()

static func unit_with(selected: Dictionary, number: int) -> Dictionary:
	var prefix := "%d/" % number
	var slots:={"head":prefix+selected.head,"weapon":prefix+selected.weapon,"core":prefix+selected.core}
	if selected.has("utility"):slots.utility=prefix+selected.utility
	if selected.has("armor"):slots.armor=prefix+selected.armor
	if selected.has("survey"):slots.survey=prefix+selected.survey
	var hull:String=selected.get("chassis","crawler")
	return {
		"version": Catalog.VERSION, "chassis": prefix + ("hull" if hull=="crawler" else hull),
		"slots":slots,
	}

static func select_parts(selected: Dictionary) -> Dictionary:
	if not Catalog.CHASSIS.has(selected.get("chassis","crawler")):
		return Rules.reject("chassis","未知底盘")
	var result := Rules.validate_unit(unit_with(selected, 1), Catalog.sample_inventory(1))
	if result.ok:
		_selection = result.parts.duplicate()
		_selection.chassis=result.chassis
	return result

static func plan() -> Dictionary:
	var inventory := Catalog.sample_inventory(Rules.MAX_UNITS)
	var unit := Rules.validate_unit(unit_with(_selection, 1), inventory)
	if not unit.ok:
		return unit
	var count := mini(Rules.MAX_UNITS, floori(float(Rules.MAX_POINTS) / unit.totals.points))
	var units := []
	for number in range(1, count + 1):
		units.append(unit_with(_selection, number))
	var result := Rules.validate_squad(units, inventory)
	if result.ok:
		result["requests"] = units
	return result

static func deploy() -> bool:
	var result := plan()
	if not result.ok:
		return false
	_deployment = result.requests.duplicate(true)
	return true

static func has_deployment() -> bool:
	return not _deployment.is_empty()

static func create_battle(sim: RefCounted) -> bool:
	return sim.create_training(_deployment, Catalog.sample_inventory(Rules.MAX_UNITS))

static func return_to_workshop(tree: SceneTree) -> Error:
	_deployment.clear()
	return tree.change_scene_to_file(WORKSHOP)
