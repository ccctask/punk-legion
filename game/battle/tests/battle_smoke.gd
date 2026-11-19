extends SceneTree

const Sim := preload("res://battle/simulation.gd")
const Catalog := preload("res://loadout/catalog.gd")
var errors := PackedStringArray()

func _initialize() -> void:
	call_deferred("_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func duel() -> RefCounted:
	var battle := Sim.new()
	battle.create(Catalog.sample_squad(1), Catalog.sample_inventory(1), Catalog.sample_squad(1), Catalog.sample_inventory(1))
	return battle

func _test() -> void:
	var nav = duel()
	var friendly: String = nav.alive_ids(0)[0]
	var foe: String = nav.alive_ids(1)[0]
	nav.units[friendly].pos = Vector2(-8, 0)
	nav.units[foe].pos = Vector2(12, 7)
	nav.command_move(nav.alive_ids(0), Vector2(-2, 0))
	var reached := false
	for i in 200:
		nav.step(0.05)
		check(not nav.field.grid.is_point_solid(nav.field.cell(nav.units[friendly].pos)), "route intersects solid tile")
		if nav.units[friendly].pos.distance_to(Vector2(-2, 0)) < 0.01:
			reached = true
			break
	check(reached, "unit did not reach opposite side of obstacle")
	var allies: Array[String] = nav.alive_ids(0)
	check(nav.repair(allies) == 0 and nav.repair_charges == 2, "full hp consumed charge")
	nav.units[friendly].hp -= 4
	check(nav.repair(allies) == 4 and nav.repair_charges == 1, "effective repair mismatch")
	nav.units[friendly].hp -= 25
	check(nav.repair(allies) == 15 and nav.repair_charges == 0 and nav.repair(allies) == 0, "repair cap mismatch")
	nav.retreat()
	var summary: Dictionary = nav.result.duplicate(true)
	nav.step(10)
	nav.retreat()
	check(nav.result == summary and nav.result.reason == "retreat" and nav.result.winner == 1, "duplicate result")
	var combat = duel()
	combat.units[friendly].pos = Vector2(-1, 0)
	combat.units[foe].pos = Vector2(1, 0)
	combat.units[foe].hp = 1
	combat.command_focus(combat.alive_ids(0), foe)
	combat.step(0.05)
	check(combat.result.reason == "eliminated" and combat.result.winner == 0 and combat.units[friendly].kills == 1, "focus or kill record mismatch")
	var limit = duel()
	limit.time_limit = 0.05
	limit.step(0.05)
	check(limit.result.reason == "timeout" and limit.result.winner == -1, "timeout draw")
	var captured = duel()
	captured.units[friendly].pos = Vector2.ZERO
	captured.units[foe].pos = Vector2(13,7)
	captured.score[0] = Sim.CAPTURE_SECONDS - 0.025
	captured.step(0.05)
	check(captured.result.reason == "relay" and captured.result.winner == 0, "relay objective")
	for heavy: bool in [false,true]:
		for active: bool in [false,true]:
			var battle := Sim.new()
			check(battle.create_fixture(heavy), "fixture rejected")
			check(battle.budgets == [24,24], "wrong budget")
			check(battle.alive_ids(0).size() == (6 if heavy else 12), "wrong team count")
			if active:
				battle.command_focus(battle.alive_ids(0), battle.alive_ids(1)[0])
			for tick in 3601:
				if active and tick % 15 == 0 and not battle.alive_ids(1).is_empty():
					battle.command_focus(battle.alive_ids(0), battle.alive_ids(1)[0])
					battle.repair(battle.alive_ids(0))
				battle.step(0.05)
				if not battle.result.is_empty():
					break
			check(not battle.result.is_empty(), "fixture missing result")
			check(battle.result.winner == (0 if active else 1), "focus and repair should change the fixture outcome")
			print("FORMATION heavy=", heavy, " active=", active, " winner=", battle.result.winner, " reason=", battle.result.reason, " seconds=", battle.elapsed, " remaining=", battle.alive_ids(0).size(), "/",battle.alive_ids(1).size())
	var scene: Node = load("res://battle/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.hud.get_node("%Light").pressed.emit()
	check(scene.running and scene.selected.size() == 12, "scene launch")
	scene.hud.get_node("%Alpha").pressed.emit()
	check(scene.selected.is_empty(), "no melee robot in the cannon fixture")
	scene.hud.get_node("%Bravo").pressed.emit()
	check(scene.selected.size() == 12, "fire role selection")
	var target_screen: Vector2 = scene.camera.unproject_position(Vector3(0, 0, 0))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = target_screen
	root.push_input(click, true)
	var first: String = scene.selected[0]
	check(scene.sim.units[first].movement_goal != Sim.UNSET, "ground tap should issue a real move order")
	if DisplayServer.get_name() != "headless" and not OS.get_environment("BATTLE_CAPTURE").is_empty():
		await RenderingServer.frame_post_draw
		var saved := root.get_texture().get_image().save_png(OS.get_environment("BATTLE_CAPTURE"))
		check(saved == OK, "saving battle render")
	scene.hud.get_node("%Retreat").pressed.emit()
	check(not scene.running and scene.hud.get_node("%Report").visible and scene.sim.result.reason == "retreat", "scene report missing")
	scene.hud.get_node("%Retry").pressed.emit()
	check(scene.running and scene.sim.result.is_empty() and scene.sim.repair_charges == 2, "scene replay")
	scene.queue_free()
	await process_frame
	if errors.is_empty():
		print("BATTLE_SMOKE_PASS")
	quit(0 if errors.is_empty() else 1)
