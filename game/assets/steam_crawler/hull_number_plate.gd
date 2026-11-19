extends MeshInstance3D

# Enamel number tiles use one unlit vertex-colour surface. Identical numbers
# share a mesh across robots. All dimensions below are local metres.
const GLYPHS := [
	["111","101","101","101","111"], ["010","110","010","010","111"],
	["111","001","111","100","111"], ["111","001","111","001","111"],
	["101","101","111","001","001"], ["111","100","111","001","111"],
	["111","100","111","101","111"], ["111","001","011","010","010"],
	["111","101","111","101","111"], ["111","101","111","001","111"]
]
const BRASS := Color("#bf8750")
const ENAMEL := Color("#192f32")
const IVORY := Color("#ffedb5")
const PIXEL := 0.032
static var numbers := {}
static var material:StandardMaterial3D

static func valid(value:String) -> bool:
	return value.length()==2 and value.unicode_at(0) in range(48,58) and value.unicode_at(1) in range(48,58)

func show_number(value:String) -> void:
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not numbers.has(value):
		numbers[value]=_tile(value)
	mesh=numbers[value]

static func _face(surface:SurfaceTool, points:PackedVector2Array, depth:float, color:Color) -> void:
	for n in range(1,points.size()-1):
		for index:int in [0,n,n+1]:
			var point:=points[index]
			surface.set_color(color)
			surface.add_vertex(Vector3(point.x,point.y,depth))

static func _enamel(surface:SurfaceTool,x:float,y:float,z:float,color:Color) -> void:
	var cut:=0.024
	_face(surface,[Vector2(-x+cut,y),Vector2(x-cut,y),Vector2(x,y-cut),Vector2(x,-y+cut),
		Vector2(x-cut,-y),Vector2(-x+cut,-y),Vector2(-x,-y+cut),Vector2(-x,y-cut)],z,color)

static func _tile(value:String) -> ArrayMesh:
	if not material:
		material=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo=true
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	_enamel(surface,.156,.107,0,BRASS)
	_enamel(surface,.145,.096,.0015,ENAMEL)
	for digit in 2:
		var rows:Array=GLYPHS[value.unicode_at(digit)-48]
		for row in 5:
			var column:=0
			while column<3:
				if rows[row][column]=="0":
					column+=1
					continue
				var start:=column
				while column<3 and rows[row][column]=="1":column+=1
				var left:=(-3.5+digit*4+start)*PIXEL
				var right:=left+(column-start)*PIXEL
				var top:=(2.5-row)*PIXEL
				_face(surface,[Vector2(left,top),Vector2(right,top),Vector2(right,top-PIXEL),Vector2(left,top-PIXEL)],.003,IVORY)
	surface.index()
	return surface.commit()
