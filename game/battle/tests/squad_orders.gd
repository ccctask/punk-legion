extends SceneTree

const Sim:=preload("res://battle/simulation.gd")
const Solo:=preload("res://net/solo_mission.gd")
const Party:=preload("res://net/party_mission.gd")
const Camp:=preload("res://net/camp_mission.gd")
var failures:=0

func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		printerr(message)

func group(count:int,policies:Dictionary={}) -> Dictionary:
	return {"units":Sim.Catalog.sample_squad(count),"inventory":Sim.Catalog.sample_inventory(count),"orders":policies.duplicate(true),"names":{},"paints":{}}

func simple(orders:Dictionary) -> Sim:
	var sim:=Sim.new()
	sim.field=Sim.Field.new(Rect2i(-16,-16,33,33),[])
	sim.relay_objective=false
	var a:=group(2)
	var b:=group(2)
	sim.create(a.units,a.inventory,b.units,b.inventory)
	sim.apply_orders(0,{"1/hull":orders})
	sim.units["0:1/hull"].pos=Vector2.ZERO
	sim.units["0:2/hull"].pos=Vector2(-7,0)
	sim.units["1:1/hull"].pos=Vector2(2,0)
	sim.units["1:2/hull"].pos=Vector2(4,0)
	sim.units["1:2/hull"].hp=15
	for id in sim.alive_ids(1):sim.units[id].stats.damage=0.1
	return sim

func _initialize() -> void:
	var original:=simple({})
	var custom:=simple({"priority":"weakest","role":"support"})
	original.step(0.05);custom.step(0.05)
	check(original.units["0:1/hull"].impact_point==Vector2(2,0),"default targets nearest enemy")
	check(custom.units["0:1/hull"].impact_point==Vector2(4,0),"weakest targets different enemy")
	var defend:=simple({"guard":"2/hull","priority":"threat"})
	defend.units["1:2/hull"].target_id="0:2/hull"
	var u:=defend.units["0:1/hull"]
	check(defend._nearest(u).id=="1:2/hull","prioritize threat against chosen ally")
	defend.step(.05)
	check(u.action=="guard" and u.pos.x<0,"moves toward selected guard")
	defend.units["0:2/hull"].hp=0
	defend.step(.05)
	check(u.action=="engage","missing guard falls back")
	var back:=simple({"retreat":25,"distance":"standoff"})
	u=back.units["0:1/hull"]
	u.hp=10
	back.step(.05)
	check(u.action=="retreat" and u.pos.x<0,"low health disengagement")
	var ids:Array[String]=[u.id]
	back.command_focus(ids,"1:1/hull")
	back.step(.05)
	check(u.action=="focus" and u.last_shot>0,"manual focus overrides retreat")
	back.command_move(ids,Vector2(0,-4))
	back.step(.05)
	check(u.action=="move","manual move overrides retreat")
	var far:=simple({"distance":"standoff"})
	far.step(.05)
	check(far.units["0:1/hull"].action=="standoff","ranged unit seeks weapon edge")
	var close:=simple({"distance":"close"})
	close.step(.05)
	check(close.units["0:1/hull"].last_shot<0,"close preference closes before firing")
	var pinned:=simple({"guard":"2/hull","retreat":50,"distance":"close"})
	u=pinned.units["0:1/hull"]
	u.stats.move_speed=0
	u.hp=8
	pinned.step(.05)
	check(u.pos==Vector2.ZERO and u.last_shot>0,"fixed robot remains stationary and fires")
	var config:={"1/hull":{"role":"support","retreat":25,"guard":"2/hull"}}
	var expedition:=Solo.new()
	check(expedition.create("old",group(2),2000000000),"legacy solo")
	check(expedition.view().units["0:1/hull"].role=="fire","old replay role")
	var legacy:=expedition.checkpoint()
	legacy.deployment.erase("orders")
	var recovered:=Solo.new()
	check(recovered.restore(legacy) and recovered.view().units["0:1/hull"].role=="fire","legacy active checkpoint can resume")
	var camp:=Camp.new()
	var setup:={"attacker":group(2,config),"defender":group(1),"neutral":false,"turrets":[]}
	check(camp.create("camp",setup,2000000000),"camp freeze")
	check(camp.personalized("attacker").units["0:1/hull"].role=="support","camp role")
	var restore:=Camp.new()
	check(restore.restore(camp.checkpoint()) and restore.sim.units["0:1/hull"].orders.guard=="2/hull","resume frozen orders")
	var party:=Party.new()
	var friend:=group(1)
	friend.units[0].chassis="friend"
	friend.inventory.friend="crawler"
	# A separate owner's items have separate permanent IDs too.
	for slot in friend.units[0].slots:
		var old:String=friend.units[0].slots[slot]
		friend.inventory["other-"+old]=friend.inventory[old]
		friend.units[0].slots[slot]="other-"+old
	friend.orders={"friend":{"role":"front"}}
	check(party.create_party("party",{"a":group(2,config),"b":friend},2000000000),"two-seat parties")
	check(party.personalized("b").units["0:friend"].role=="front","party role carried across the merge")
	check(not party.party_order("b",1,"move",["0:1/hull"],"",Vector2.ZERO),"foreign group cannot move")
	if not failures:print("SQUAD_ORDERS_RULES_PASS same encounter targets 2m vs 4m, guard, danger, range, manual focus/move, fixed platform, legacy party and camp checkpoints.")
	quit(1 if failures else 0)
