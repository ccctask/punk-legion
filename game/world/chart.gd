extends Control

var links:Array[Dictionary]=[]

const LAND := Color("#76917b")
const COAST := Color("#455f60")
func poly(points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for point: Vector2 in points:
		vertices.append(point*size)
	draw_colored_polygon(vertices,color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),COAST)
	poly([Vector2(0,0),Vector2(1,0),Vector2(1,0.77),Vector2(.89,.71),Vector2(.84,.78),Vector2(.74,.79),Vector2(.66,.91),Vector2(.42,1),Vector2(0,1)],LAND)
	poly([Vector2(0,.24),Vector2(.13,.19),Vector2(.16,.26),Vector2(.34,.21),Vector2(.4,.12),Vector2(.61,.15),Vector2(.65,.04),Vector2(.72,0),Vector2(0,0)],Color("#546f63"))
	poly([Vector2(0,.92),Vector2(.12,.83),Vector2(.26,.85),Vector2(.33,.94),Vector2(.49,.88),Vector2(.52,1),Vector2(0,1)],Color("#637e68"))
	var river := PackedVector2Array()
	for p in [Vector2(.65,-.1),Vector2(.56,.16),Vector2(.62,.29),Vector2(.55,.43),Vector2(.62,.55),Vector2(.61,.66),Vector2(.77,.84)]:
		river.append(p*size)
	draw_polyline(river,Color("#577c81"),maxf(7,size.x*.016),true)
	for x in range(0,int(size.x),32):
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.17,.27,.24,.16))
	for y in range(0,int(size.y),32):
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.17,.27,.24,.16))
	var junction := Vector2(.43,.48)*size
	for p in [Vector2(.25,.38),Vector2(.65,.31),Vector2(.47,.73)]:
		var end: Vector2 = p*size
		draw_line(junction,end,Color("#4e5749"),4,true)
		draw_dashed_line(junction,end,Color("#cec49d"),2,6,true)
	for i in 21:
		var at := Vector2(float((i*29)%90)/100.0,float((i*47)%89)/100.0)
		if at.distance_to(Vector2(.5,.5)) < .32:
			continue
		var a := at*size
		draw_polyline(PackedVector2Array([a+Vector2(-9,4),a+Vector2(0,-6),a+Vector2(10,4)]),Color("#476456"),2,true)
	for link:Dictionary in links:
		draw_line(link.at,link.edge,Color("#282e25"),4,true)
		draw_line(link.at,link.edge,Color("#ecd49a"),2,true)
		draw_circle(link.at,3,Color("#ecd49a"))
