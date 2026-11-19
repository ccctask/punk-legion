extends VBoxContainer

signal save_orders(orders:Variant)

const ROLES:={"front":"前排","fire":"火力","support":"支援"}
const DISTANCE:={"weapon":"武器有效射程","close":"贴近交战","standoff":"保持射程边缘"}
const PRIORITY:={"nearest":"最近敌机","weakest":"耐久比例最低","threat":"优先威胁护卫对象或本人"}
const RETREAT:={0:"持续交战",25:"耐久≤25%回撤",50:"耐久≤50%回撤"}
const Sim:=preload("res://battle/simulation.gd")
var signature:=""
var current_robot:=""

func _ready() -> void:
	for pair in [[$Body/Role,ROLES],[$Body/Distance,DISTANCE],[$Body/Priority,PRIORITY],[$Body/Retreat,RETREAT]]:
		for key in pair[1]:
			pair[0].add_item(pair[1][key])
			pair[0].set_item_metadata(pair[0].item_count-1,key)
	$Toggle.pressed.connect(func():$Body.visible=not $Body.visible)
	$Body/Save.pressed.connect(func():save_orders.emit({"role":$Body/Role.get_selected_metadata(),"guard":$Body/Guard.get_selected_metadata(),
		"distance":$Body/Distance.get_selected_metadata(),"priority":$Body/Priority.get_selected_metadata(),"retreat":$Body/Retreat.get_selected_metadata()}))
	$Body/Default.pressed.connect(func():save_orders.emit(null))

func bind(robot:Dictionary,roster:Array,locked:bool) -> void:
	var definitions:={}
	for slot:String in robot.slots:definitions[slot]=robot.slots[slot].definition
	var orders:Dictionary=robot.get("orders",Sim.default_orders(definitions))
	var guards:={}
	for candidate:Dictionary in roster:
		if candidate.id!=robot.id:guards[candidate.id]=candidate.name
	var stamp:=JSON.stringify([robot.id,orders,guards])
	for pick in [$Body/Role,$Body/Distance,$Body/Priority,$Body/Retreat,$Body/Guard,$Body/Save,$Body/Default]:
		pick.disabled=locked or robot.task!=null
	$Body/Default.disabled=$Body/Default.disabled or not robot.get("custom_orders",false)
	$Toggle.text="战前职责 · "+str(ROLES[orders.role])+("（自定）" if robot.get("custom_orders",false) else "（推荐）")
	if signature==stamp:return
	signature=stamp
	if current_robot!=robot.id:$Body.hide()
	current_robot=robot.id
	$Body/Guard.clear()
	$Body/Guard.add_item("自由行动")
	$Body/Guard.set_item_metadata(0,"")
	for rid in guards:
		$Body/Guard.add_item("护卫 · "+str(guards[rid])+" #"+str(rid).left(6))
		$Body/Guard.set_item_metadata($Body/Guard.item_count-1,rid)
	for pair in [[$Body/Role,"role"],[$Body/Guard,"guard"],[$Body/Distance,"distance"],[$Body/Priority,"priority"],[$Body/Retreat,"retreat"]]:
		pair[0].select(0)
		for i in pair[0].item_count:
			if pair[0].get_item_metadata(i)==orders[pair[1]]:pair[0].select(i)
