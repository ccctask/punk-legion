extends RefCounted

const Catalog := preload("res://loadout/catalog.gd")
const MAX_UNITS := 12
const MAX_POINTS := 24

static func reject(code: String, detail: String) -> Dictionary:
	return {"ok": false, "code": code, "detail": detail}

# Only request is client input. Inventory, chassis and parts are authority-owned.
static func validate_unit(request: Variant, inventory: Dictionary, chassis: Dictionary = Catalog.CHASSIS, parts: Dictionary = Catalog.PARTS, workshop_partial := false) -> Dictionary:
	if not request is Dictionary:
		return reject("format", "装配方案格式错误")
	# JSON responses decode integral version numbers as floats in Godot.
	if typeof(request.get("version")) not in [TYPE_INT,TYPE_FLOAT] or request.version != Catalog.VERSION:
		return reject("version", "装配规则版本不兼容")
	if request.size() != 3 or not request.has_all(["chassis", "slots"]) or not request.slots is Dictionary:
		return reject("format", "装配方案字段错误")
	if not request.chassis is String or not inventory.has(request.chassis):
		return reject("ownership", "未持有该底盘")
	var definition: Variant = inventory[request.chassis]
	if not chassis.has(definition):
		return reject("chassis", "该实体不能用作底盘")
	var hull: Dictionary = chassis[definition]
	var slots: Dictionary = request.slots
	for mount: Variant in slots:
		if not hull.slots.has(mount):
			return reject("unknown_slot", "底盘无此插槽")
	var missing := ""
	for mount: String in hull.slots:
		if not slots.has(mount) and not hull.slots[mount].get("optional",false):
			missing = str(Catalog.LABELS.get(mount,mount))
			if not workshop_partial:
				return reject("missing_slot", "缺少必装插槽 " + mount)
			break

	var used := { }
	used[request.chassis] = true
	var exclusive := {}
	var resolved := {}
	var totals := {"mass":0, "power":0, "heat":0, "supply":0, "cooling":0, "points":int(hull.points), "payload":int(hull.payload)}
	for mount: String in hull.slots:
		if not slots.has(mount):
			continue
		var entity: Variant = slots[mount]
		if not entity is String or not inventory.has(entity):
			return reject("ownership", "未持有 " + mount + " 插槽的部件")
		if used.has(entity):
			return reject("duplicate", "同一实体被重复装配")
		used[entity] = true
		var part_id: Variant = inventory[entity]
		if not parts.has(part_id):
			return reject("definition", "库存部件无可用定义")
		var part: Dictionary = parts[part_id]
		var socket: Dictionary = hull.slots[mount]
		if part.kind != socket.kind:
			return reject("kind", "部件类别不匹配 " + mount)
		if part.interface != socket.interface:
			return reject("interface", "安装接口不匹配 " + mount)
		if part.size > socket.size:
			return reject("size", "部件超过插槽尺寸 " + mount)
		var bus: String = part.get("exclusive", "")
		if not bus.is_empty():
			if exclusive.has(bus):
				return reject("exclusive", "两个部件争用精密控制总线")
			exclusive[bus] = true
		for key in ["mass", "power", "heat", "supply", "cooling", "points"]:
			totals[key] += int(part.get(key, 0))
		resolved[mount] = part_id

	if totals.mass > totals.payload:
		return reject("weight", "整机超过底盘载重")
	if resolved.has("core") and totals.power > totals.supply:
		return reject("power", "核心供电不足")
	if resolved.has("core") and totals.heat > totals.cooling:
		return reject("heat", "核心散热不足")
	if not missing.is_empty():
		return reject("missing_slot", "缺少" + missing)
	var core: Dictionary = parts[resolved.core]
	var tool: Dictionary = parts[resolved.weapon]
	var combat := {
		"body_radius": float(hull.get("body_radius",0.6)),
		"max_hp": int(hull.max_hp) + int(core.get("hp_bonus", 0)),
		"move_speed": float(hull.move_speed) - float(core.get("speed_penalty", 0.0)),
		"damage": int(tool.damage), "range_m": float(tool.range_m),
		"attack_interval": float(tool.attack_interval),
	}
	return {"ok":true, "chassis":definition, "entity_id":request.chassis, "totals":totals, "parts":resolved, "entities":used.keys(), "combat":combat}

static func validate_squad(units: Variant, inventory: Dictionary, point_limit: int = MAX_POINTS, unit_limit: int = MAX_UNITS) -> Dictionary:
	if not units is Array or units.is_empty():
		return reject("format", "编队至少需要一台机体")
	if units.size() > unit_limit:
		return reject("unit_limit", "出战台数超过上限")
	var used := {}
	var points := 0
	var roster := []
	for request: Variant in units:
		var result := validate_unit(request, inventory)
		if not result.ok:
			return result
		for entity: String in result.entities:
			if used.has(entity):
				return reject("duplicate", "同一实体被多个机体占用")
			used[entity] = true
		points += int(result.totals.points)
		roster.append(result)
	if points > point_limit:
		return reject("point_limit", "编队指挥点超过上限")
	return {"ok":true, "points":points, "units":units.size(), "roster":roster}
