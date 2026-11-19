extends "res://battle/battle.gd"

const Catalog := preload("res://loadout/catalog.gd")
const FRAMES := 240
const WARMUP := 30
var started_usec := 0
var first_draw_usec := 0
var previous_usec := 0
var frames := 0
var visible_peak := 0
var alive_min := 24
var contact_sec := -1.0
var focus_sec := -1.0
var repair_sec := -1.0
var repair_amount := 0.0
var timings: Array[float] = []
var before_contact: Array[float] = []
var in_combat: Array[float] = []
var draw_counts: Array[float] = []

func auto_deploy() -> bool:
	return true

func create_encounter(_heavy: bool) -> bool:
	var squad := Catalog.sample_squad(12, false)
	var inventory := Catalog.sample_inventory(12)
	return sim.create(squad, inventory, squad, inventory)

func _ready() -> void:
	$Sun.shadow_enabled = get_tree().get_meta(&"baseline_shadows", true)
	if get_tree().has_meta(&"baseline_shadows"):
		get_tree().remove_meta(&"baseline_shadows")
	started_usec = get_tree().get_meta(&"baseline_start_usec", Time.get_ticks_usec())
	if get_tree().has_meta(&"baseline_start_usec"):
		get_tree().remove_meta(&"baseline_start_usec")
	super()
	# Keep the normal command bar in the render. Only the diagnostic controls run orders.
	for button: Node in hud.find_children("*", "BaseButton", true, false):
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
	%Done.pressed.connect(func(): get_tree().change_scene_to_file(Sortie.WORKSHOP), CONNECT_DEFERRED)
	RenderingServer.frame_post_draw.connect(_after_draw)

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _step_encounter() -> void:
	if focus_sec < 0 and sim.elapsed >= 1.0:
		sim.command_focus(sim.alive_ids(0), sim.alive_ids(1)[0])
		focus_sec = sim.elapsed
	if repair_sec < 0 and sim.elapsed + 0.001 >= 5.0:
		repair_amount = sim.repair(sim.alive_ids(0))
		repair_sec = sim.elapsed
	super()
	if contact_sec < 0:
		for unit in sim.units.values():
			if unit.last_shot >= 0.0:
				contact_sec = unit.last_shot
				break
	if sim.elapsed + 0.001 >= 8.0:
		running = false

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if first_draw_usec == 0:
		first_draw_usec = now
		previous_usec = now
		return
	var interval := (now - previous_usec) / 1000.0
	previous_usec = now
	var visible_now := 0
	var alive := 0
	for u in sim.units.values():
		if u.hp > 0:
			alive += 1
			var center := Vector3(u.pos.x, 0.68, u.pos.y)
			if camera.is_position_in_frustum(center):
				visible_now += 1
	visible_peak = maxi(visible_peak, visible_now)
	alive_min = mini(alive_min, alive)
	if contact_sec < 0:
		before_contact.append(interval)
	else:
		in_combat.append(interval)
	if frames >= WARMUP and frames < FRAMES:
		timings.append(interval)
		draw_counts.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames += 1
	if not running:
		RenderingServer.frame_post_draw.disconnect(_after_draw)
		_publish.call_deferred()

func _distribution(values: Array[float]) -> Dictionary:
	values.sort()
	var n := values.size()
	if n == 0:
		return {"n":0}
	return {"n":n, "p50":values[ceili(n * 0.50) - 1], "p95":values[ceili(n * 0.95) - 1]}

func _publish() -> void:
	running = false
	var report := {
		"platform":OS.get_name(), "model":OS.get_model_name(),
		"godot":Engine.get_version_info().string, "gpu":RenderingServer.get_video_adapter_name(),
		"renderer":RenderingServer.get_current_rendering_method(), "viewport":str(get_viewport().size),
		"shadows":$Sun.shadow_enabled, "msaa_3d":get_viewport().msaa_3d,
		"first_frame_ms":(first_draw_usec - started_usec) / 1000.0,
		"models":views.size(), "visible_peak":visible_peak, "alive_min":alive_min,
		"sim_seconds":sim.elapsed, "focus_sec":focus_sec, "contact_sec":contact_sec,
		"repair_hp":repair_amount, "repair_sec":repair_sec, "warmup_frames":WARMUP,
		"frame_ms":_distribution(timings), "precontact_ms":_distribution(before_contact),
		"combat_ms":_distribution(in_combat), "draw_calls":_distribution(draw_counts),
		"godot_static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))
	}
	print("PL_DEVICE_BASELINE ", JSON.stringify(report))
	var file := FileAccess.open("user://last_battle_baseline.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	var sample: Dictionary = report.frame_ms
	var frame_reading := "%d 帧 · P50 %.1f ms / P95 %.1f ms" % [sample.n, sample.p50, sample.p95] if sample.n else "暖机后样本不足"
	%Reading.text = "同屏 %d 台 · 阴影%s · 首帧 %.0f ms\n%s\n接战 %.1f 秒 · 有效维修 %.0f" % [
		visible_peak, "开" if report.shadows else "关", report.first_frame_ms, frame_reading, contact_sec, repair_amount]
	%Done.show()
