extends RefCounted

# Shared Rustrail layout only: no mission, rendering assets or mutable unit state.
const AREA := Rect2i(-36,-25,73,51)
const ROCKS: Array[Rect2i] = [Rect2i(-14,-19,4,15),Rect2i(6,-5,5,16),Rect2i(-9,9,5,9),Rect2i(21,-15,4,5)]
const LOCATIONS := {"scrap":Vector2(29,-18),"fuel":Vector2(29,-4),"guard":Vector2(-28,17),"coil":Vector2(26,18),"boss":Vector2(-23,-18),"exit":Vector2(28,-20)}
const NAMES := {"scrap":"废轨堆","fuel":"储能井","guard":"巡查哨","coil":"线圈库","boss":"熔炉首领","exit":"铁路撤离点"}
const COLLECTION_SITES := ["scrap","fuel","coil"]
const VISUALS := {
	"scrap":{"mesh":"Scrap","scale":1.23,"offset":Vector3.ZERO,"rotation":PI,"label_height":7.0},
	"fuel":{"mesh":"Fuel","scale":1.23,"offset":Vector3.ZERO,"rotation":PI,"label_height":7.0},
	"coil":{"mesh":"Coil","scale":1.23,"offset":Vector3.ZERO,"rotation":PI,"label_height":7.0},
	"guard":{"mesh":"Signal","scale":1.23,"offset":Vector3(-2.6,0,-2.4),"rotation":PI,"label_height":2.55},
	"boss":{"mesh":"ForgeGate","scale":1.23,"offset":Vector3(-2.6,0,-2.4),"rotation":PI,"label_height":2.55},
	"exit":{"mesh":"Exit","scale":1.38,"offset":Vector3.ZERO,"rotation":PI/2,"label_height":3.0},
}

static func collection_footprints() -> Array[Rect2i]:
	var footprints: Array[Rect2i] = []
	for key: String in COLLECTION_SITES:
		var center: Vector2 = LOCATIONS[key]
		footprints.append(Rect2i(Vector2i(center)-Vector2i.ONE,Vector2i(3,3)))
	return footprints

static func exit_post_footprints() -> Array[Rect2i]:
	var center: Vector2i = Vector2i(LOCATIONS["exit"])
	return [
		Rect2i(center+Vector2i(0,-2),Vector2i(1,2)),
		Rect2i(center+Vector2i(0,1),Vector2i(1,2)),
	]

static func obstacles() -> Array[Rect2i]:
	# A per-field copy keeps the four-rock alias safe for other authored maps.
	var combined: Array[Rect2i] = ROCKS.duplicate()
	combined.append_array(collection_footprints())
	combined.append_array(exit_post_footprints())
	return combined

static func visual(key: String) -> Dictionary:
	return VISUALS[key].duplicate(true)
