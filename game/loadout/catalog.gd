extends RefCounted

# Prototype balance values. Entity identifiers belong to inventory; definitions are shared.
const VERSION := 1
const LABELS := {"survey":"测绘接口","survey_radar":"测绘雷达","armor":"前装甲","rivet_shield":"铆钉盾板","utility":"功能接口 AUX","":"空槽","jammer":"脉冲干扰器","repair_arm":"维修臂","core":"动力","head":"传感器","weapon":"工具","boiler":"锅炉","reinforced_boiler":"加固锅炉","eye":"双目","visor":"战术目镜","chimney_arm":"烟囱炮臂","rivet_repeater":"铆钉连发器","cannon":"气炮","drill":"钻头"}
const HULL_LABELS := {"crawler":"履带","biped":"双足","wheel":"轻型轮式","survey_wheel":"侦察轮式"}
const HULLS := ["crawler","biped","wheel","survey_wheel"]
const CHASSIS := {
	"crawler": {
		"payload": 6,
		"points": 2,
		"max_hp": 70,
		"move_speed": 3.6,
		"slots": {
			"core": {
				"kind": "core",
				"interface": "boiler",
				"size": 2
			},
			"head": {
				"kind": "sensor",
				"interface": "optic",
				"size": 2
			},
			"weapon": {
				"kind": "tool",
				"interface": "arm",
				"size": 2
			},
			"utility": {
				"kind": "service",
				"interface": "aux",
				"size": 1,
				"optional": true
			},
			"armor": {"kind":"armor","interface":"front_plate","size":1,"optional":true}
		},
		"body_radius": 0.6
	},
	"biped": {
		"payload": 5,
		"points": 3,
		"max_hp": 58,
		"move_speed": 4.6,
		"slots": {
			"core": {
				"kind": "core",
				"interface": "boiler",
				"size": 2
			},
			"head": {
				"kind": "sensor",
				"interface": "optic",
				"size": 2
			},
			"weapon": {
				"kind": "tool",
				"interface": "arm",
				"size": 2
			},
			"utility": {
				"kind": "service",
				"interface": "aux",
				"size": 1,
				"optional": true
			}
		},
		"body_radius": 0.48
	},
	"survey_wheel": {
		"payload":4, "points":2, "max_hp":38, "move_speed":5.4, "body_radius":0.48,
		"slots": {
			"core":{"kind":"core","interface":"boiler","size":2},
			"head":{"kind":"sensor","interface":"optic","size":2},
			"weapon":{"kind":"tool","interface":"arm","size":2},
			"survey":{"kind":"survey","interface":"survey_mount","size":1,"optional":true}
		}
	},
	"wheel": {
		"payload": 4, "points": 2, "max_hp": 42, "move_speed": 5.4, "body_radius": 0.48,
		"slots": {
			"core": {"kind":"core","interface":"boiler","size":2},
			"head": {"kind":"sensor","interface":"optic","size":2},
			"weapon": {"kind":"tool","interface":"arm","size":2}
		}
	}
}
const PARTS := {
	"survey_radar":{"kind":"survey","interface":"survey_mount","size":1,"mass":1,"power":1,"heat":0,"points":1},
	"rivet_shield": {"kind":"armor","interface":"front_plate","size":1,"mass":2,"points":1,"power":0,"heat":0,"front_half_angle":60.0,"direct_damage_ratio":0.6,"turn_degrees_per_second":180.0},
	"jammer": {"kind": "service", "interface": "aux", "size": 1, "mass": 1, "power": 1, "heat": 1, "points": 1, "jam_range": 6, "jam_delay": 1, "jam_protection": 4, "jam_interval": 5, "jam_charges": 4},
	"repair_arm": {"kind": "service", "interface": "aux", "size": 1, "mass": 1, "power": 1, "heat": 1, "points": 1, "repair_amount": 10, "repair_range": 5, "repair_interval": 6, "repair_charges": 4, "repair_trigger": 8, "repair_quiet": 6, "repair_critical_ratio": 0.35},
	"boiler": {"kind":"core", "interface":"boiler", "size":2, "mass":1, "power":0, "heat":0, "supply":6, "cooling":4, "points":0},
	"reinforced_boiler": {"kind":"core", "interface":"boiler", "size":2, "mass":2, "power":0, "heat":0, "supply":7, "cooling":5, "points":1, "hp_bonus":85, "speed_penalty":1.2},
	"eye": {"kind":"sensor", "interface":"optic", "size":1, "mass":1, "power":1, "heat":0, "points":0, "visual":0},
	"visor": {"kind":"sensor", "interface":"optic", "size":2, "mass":2, "power":2, "heat":1, "points":1, "exclusive":"precision_bus", "visual":1},
	"chimney_arm": {"kind":"tool", "interface":"arm", "size":2, "mass":2, "power":3, "heat":2, "points":1, "visual":2, "blast_radius":2.0, "blast_delay":0.8, "damage":10, "range_m":5.0, "attack_interval":2.0},
	"rivet_repeater": {"kind":"tool", "interface":"arm", "size":1, "mass":1, "power":2, "heat":1, "points":0, "visual":3, "damage":3, "range_m":3.5, "attack_interval":0.4},
	"cannon": {"kind":"tool", "interface":"arm", "size":2, "mass":2, "power":3, "heat":2, "points":0, "visual":0, "damage":9, "range_m":5.0, "attack_interval":1.0},
	"drill": {"kind":"tool", "interface":"arm", "size":2, "mass":2, "power":3, "heat":2, "points":1, "exclusive":"precision_bus", "visual":1, "damage":18, "range_m":1.65, "attack_interval":0.85},
}

# Trusted fixtures until ownership is supplied by the inventory service.
static func sample_inventory(count: int = 2) -> Dictionary:
	var inventory := {}
	for number in count:
		var prefix := str(number + 1) + "/"
		inventory[prefix + "hull"] = "crawler"
		for hull:String in HULLS:
			if hull!="crawler":inventory[prefix + hull] = hull
		for part_id: String in PARTS:
			inventory[prefix + part_id] = part_id
	return inventory

static func sample_squad(count: int = 2, heavy: bool = false) -> Array:
	var units := []
	for number in count:
		var prefix := str(number + 1) + "/"
		units.append({
			"version": VERSION, "chassis": prefix + "hull",
			"slots": {"core": prefix + ("reinforced_boiler" if heavy else "boiler"), "head": prefix + "eye", "weapon": prefix + ("drill" if heavy else "cannon")},
		})
	return units
