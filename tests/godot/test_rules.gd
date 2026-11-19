extends "res://qa/support.gd"

const Catalog = preload("res://loadout/catalog.gd")
const Rules = preload("res://loadout/rules.gd")
const Mission = preload("res://net/party_mission.gd")

func test_loadout_ownership_interface_and_budget() -> void:
	var inventory: Dictionary = Catalog.sample_inventory(13)
	var unit: Dictionary = Catalog.sample_squad(1)[0]
	var valid: Dictionary = Rules.validate_unit(unit, inventory)
	assert_true(valid.ok)
	assert_eq(int(valid.totals.points), 999 if negative("rules") else 2, "Real production totals; altered expectation is a runner negative control")
	var foreign: Dictionary = unit.duplicate(true)
	foreign.slots.weapon = "other-owner/item"
	assert_eq(Rules.validate_unit(foreign, inventory).code, "ownership")
	var parts: Dictionary = Catalog.PARTS.duplicate(true)
	parts.cannon.interface = "incompatible-socket"
	assert_eq(Rules.validate_unit(unit, inventory, Catalog.CHASSIS, parts).code, "interface")
	var boundary: Dictionary = Rules.validate_squad(Catalog.sample_squad(12), inventory)
	assert_true(boundary.ok)
	assert_eq(int(boundary.points), 24)
	assert_eq(Rules.validate_squad(Catalog.sample_squad(13), inventory).code, "unit_limit")
	var over: Array = Catalog.sample_squad(12)
	over[0].slots.weapon = "1/drill"
	assert_eq(Rules.validate_squad(over, inventory).code, "point_limit")

func make_mission():
	var samples: Array = Catalog.sample_squad(2)
	var inventory: Dictionary = Catalog.sample_inventory(2)
	var mission := Mission.new()
	assert_true(mission.create_party("pilot-current-memory", {
		"owner-a": {"units": [samples[0]], "inventory": inventory},
		"owner-b": {"units": [samples[1]], "inventory": inventory}
	}, 2147483647, 1000.0))
	return mission

func test_all_arrived_starts_without_wait_and_rejects_foreign_orders() -> void:
	var mission = make_mission()
	assert_true(mission.resolve_assembly(1001.0, ["owner-a", "owner-b"]))
	assert_true(mission.battle_started)
	assert_true(mission.participating.has_all(["owner-a", "owner-b"]))
	assert_false(mission.party_order("owner-a", 1, "route", ["0:2/hull"], "scrap", Vector2.ZERO))
	assert_true(mission.party_order("owner-a", 1, "route", ["0:1/hull"], "scrap", Vector2.ZERO))
	assert_eq(int(mission.personalized("owner-a").seq), 1)
	assert_eq(int(mission.personalized("owner-b").seq), 0)
	assert_false(mission.party_order("owner-a", 1, "route", ["0:1/hull"], "scrap", Vector2.ZERO))

func test_explicit_assembly_deadline_and_no_online_seat() -> void:
	var mission = make_mission()
	assert_false(mission.resolve_assembly(1029.999, ["owner-a"]))
	assert_false(mission.battle_started)
	assert_true(mission.resolve_assembly(1030.0, ["owner-a"]))
	assert_true(mission.battle_started)
	assert_true(mission.participating.has("owner-a"))
	assert_false(mission.participating.has("owner-b"))
	assert_eq(mission.departures["owner-b"].cause, "not_deployed")
	var empty = make_mission()
	assert_false(empty.resolve_assembly(1029.999, []))
	assert_true(empty.resolve_assembly(1030.0, []))
	assert_false(empty.battle_started)
	assert_eq(empty.outcome, "expired")
