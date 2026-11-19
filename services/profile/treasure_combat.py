"""M24 authoritative combat and personal extraction on a fixed 250 ms simulation step."""
import math
import random

import workshop

STEP = 0.25
DURATION = 180
CARRY = 2
HOME = [[-7.0, 0.0], [7.0, 0.0]]


def unit(row, owner, side, index):
    parts = {slot: workshop.PARTS[part["definition"]] for slot,part in row["slots"].items()}
    core, weapon = parts["core"], parts["weapon"]
    chassis = row.get("chassis","crawler")
    hull = workshop.hull_spec(chassis)
    hp = hull["max_hp"] + core.get("hp_bonus",0)
    pos = [HOME[side][0]+(index//4-1)*0.85, (index%4-1.5)*0.9]
    return dict(owner=owner, side=side, name=row["name"], paint=row["paint"], hull_number=row.get("hull_number",""), pos=pos, target=pos,
                heading=[1.0 if side==0 else -1.0,0.0], damage_dealt=0,
                hp=hp, max_hp=hp, chassis=chassis, body_radius=hull["body_radius"], speed=hull["move_speed"]-core.get("speed_penalty",0),
                damage=weapon["damage"], reach=weapon["range_m"], interval=weapon["attack_interval"],
                parts={k:p["definition"] for k,p in row["slots"].items()},
                service_charges=workshop.PARTS["repair_arm"]["repair_charges"] if row["slots"].get("utility",{}).get("definition")=="repair_arm" else 0,
                jam_charges=workshop.PARTS["jammer"]["jam_charges"] if row["slots"].get("utility",{}).get("definition")=="jammer" else 0,
                last_service=-10, last_damage=0, orders=row.get("orders",workshop.default_orders(row["slots"])), manual_move=False, focus="", aim_target="", aim_due=0, next_shot=0, shot=-10, impact=pos, events=[], contributors=[])


SEALED = ("crate1", "crate4")
PICKUP_RANGE = 1.7
SURVEY_RANGE = 5.0


def fresh(seed, units, start, *, swap_sealed=False):
    rng=random.Random(seed)
    items={}
    for index, resource in enumerate(("components","structure","energy","structure","components")):
        pos=[0.0,0.0] if index==0 else [
            (-1 if index<=2 else 1)*rng.uniform(1.5,2.6),
            (-1 if index%2 else 1)*rng.uniform(1.9,3.2)]
        items["crate"+str(index)]=dict(resource=resource,pos=pos,bearer="",removed=False)
    if swap_sealed:
        items["crate1"]["resource"], items["crate4"]["resource"] = items["crate4"]["resource"], items["crate1"]["resource"]
    state = dict(start=start,tick=0,units=units,items=items,discoveries=[[], []])
    survey(state)
    return state


def survey(state):
    """Detect ground cargo; each side retains its own knowledge for the entire room."""
    for key in SEALED:
        item = state["items"][key]
        if item["removed"] or item["bearer"]:
            continue
        for unit in state["units"].values():
            known = state["discoveries"][unit["side"]]
            if key in known or unit["hp"] <= 0 or unit.get("out"):
                continue
            radius = SURVEY_RANGE if unit["parts"].get("survey") == "survey_radar" else PICKUP_RANGE
            if math.dist(unit["pos"], item["pos"]) <= radius:
                known.append(key)


def tactics(rid,u,living):
    orders=u.get("orders",{})
    if u.get("manual_move") and math.dist(u["pos"],u["target"])>0.01:return
    u["manual_move"]=False
    others=[(key,v) for key,v in living if u["side"]!=v["side"]]
    if any(key==u["focus"] for key,_ in others):return
    if not any(orders.get(k) for k in ("retreat","guard")) and orders.get("distance","weapon")=="weapon":return
    threat=min((v for _,v in others),key=lambda foe:math.dist(foe["pos"],u["pos"]),default=None)
    distance=math.dist(threat["pos"],u["pos"]) if threat else math.inf
    desired=0
    if threat and u["hp"]*100<=u["max_hp"]*orders.get("retreat",0):
        desired=max(6,min(8,threat["reach"]+1.5))
    elif threat and orders.get("distance")=="standoff":
        desired=0.78*u["reach"]
    if 0<desired and distance<desired:
        dx,dy=(a-b for a,b in zip(u["pos"],threat["pos"]))
        if distance<0.001:dx,dy,distance=(-1 if u["side"]==0 else 1),0,1
        u["target"]=[max(-9,min(9,x+axis/distance*desired)) for x,axis in zip(threat["pos"],(dx,dy))]
        return
    buddy=next((v for key,v in living if key==orders.get("guard") and v["side"]==u["side"]),None)
    if buddy and math.dist(u["pos"],buddy["pos"])>4:u["target"]=list(buddy["pos"])
    elif threat and orders.get("distance")=="close" and min(1.8,u["reach"])<distance<=7:u["target"]=list(threat["pos"])

def repair_candidates(rid,tech,living,seconds):
    arm=workshop.PARTS["repair_arm"]
    allies=[]
    for other,unit in living:
        if other==rid or unit["side"]!=tech["side"] or not 0<unit["hp"]<unit["max_hp"] or math.dist(tech["pos"],unit["pos"])>arm["repair_range"]:
            continue
        missing=unit["max_hp"]-unit["hp"]
        critical=unit["hp"]<=unit["max_hp"]*arm["repair_critical_ratio"]
        recent=seconds-unit.get("last_damage",0)<arm["repair_quiet"]
        if missing+1e-6<arm["repair_trigger"] and not critical and recent:
            continue
        allies.append((2 if critical else int(recent),missing,other,unit))
    return allies


def select_target(rid, unit, living):
    orders=unit.get("orders",{})
    def rank(pair):
        other, enemy=pair
        priority=0
        if orders.get("priority")=="weakest":
            priority=enemy["hp"]/enemy["max_hp"]
        elif orders.get("priority")=="threat":
            priority=(-1000 if enemy["focus"] in (rid,orders.get("guard") or rid) else 0)-enemy["damage"]/enemy["interval"]
        return other!=unit["focus"],priority,math.dist(unit["pos"],enemy["pos"]),other
    legal=(pair for pair in living if pair[1]["side"]!=unit["side"] and in_range(unit,pair[1]))
    return min(legal,key=rank,default=("",None))[0]


def in_range(unit, enemy):
    return math.dist(unit["pos"],enemy["pos"])<=unit["reach"]+enemy.get("body_radius",0.6)-0.6


def prepare_weapon(rid, unit, living, seconds):
    target="" if unit.get("manual_move") else select_target(rid,unit,living)
    if target!=unit["aim_target"]:
        unit["aim_target"]=target
        delay=0.05 if unit["parts"].get("head")=="visor" else 0.25
        unit["aim_due"]=seconds+delay


def disrupt(living,seconds):
    jammer=workshop.PARTS["jammer"]
    arm=workshop.PARTS["repair_arm"]
    for rid,emitter in living:
        if not emitter.get("jam_charges",0) or seconds-emitter.get("last_jam",-10)<jammer["jam_interval"]:continue
        enemies=[(math.dist(emitter["pos"],u["pos"]),other,u) for other,u in living if u["side"]!=emitter["side"] and seconds>=u.get("protected_until",0)]
        if not enemies:continue
        distance,other,target=min(enemies,key=lambda entry:entry[:2])
        if distance>jammer["jam_range"]:continue
        weapon_due=max(seconds,target["next_shot"])
        armed=weapon_due>seconds or bool(target["aim_target"])
        if target["aim_target"]:weapon_due=max(weapon_due,target["aim_due"])
        repair_due=seconds
        needs_repair=target.get("service_charges",0) and repair_candidates(other,target,living,seconds)
        if needs_repair:
            repair_due=max(seconds,target["last_service"]+arm["repair_interval"])
        if not armed or not target.get("weapon_delayed"):
            target["weapon_not_before"]=max(target.get("weapon_not_before",0),weapon_due+jammer["jam_delay"])
            target["weapon_delayed"]=armed
        if not needs_repair or not target.get("repair_delayed"):
            target["repair_not_before"]=max(target.get("repair_not_before",0),repair_due+jammer["jam_delay"])
            target["repair_delayed"]=bool(needs_repair)
        target["protected_until"]=seconds+jammer["jam_protection"]
        emitter["last_jam"]=seconds
        emitter["jam_charges"]-=1
        event=dict(at=seconds,actor=rid,target=other,amount=jammer["jam_protection"])
        emitter["events"].append(dict(event,kind="jam_applied"))
        target["events"].append(dict(event,kind="jam_received"))


def turn_towards(unit, bearing, seconds):
    if bearing == (0,0):
        return
    angle = math.atan2(bearing[1],bearing[0])
    if unit["parts"].get("armor") == "rivet_shield":
        old = math.atan2(unit["heading"][1],unit["heading"][0])
        delta = (angle-old+math.pi) % math.tau - math.pi
        limit = math.radians(workshop.PARTS["rivet_shield"]["turn_degrees_per_second"]) * seconds
        angle = old + max(-limit,min(limit,delta))
    unit["heading"] = [math.cos(angle),math.sin(angle)]


def step(state):
    living=[(rid,u) for rid,u in state["units"].items() if u["hp"]>0 and not u.get("out")]
    seconds=state["tick"]*STEP
    bearings={}
    for rid,u in living:
        tactics(rid,u,living)
        p=u["pos"]; target=u["target"]; d=math.dist(p,target)
        if d:
            bearings[rid]=(target[0]-p[0],target[1]-p[1])
            ratio=min(1,STEP*u["speed"]/d)
            u["pos"]=[a+(b-a)*ratio for a,b in zip(p,target)]
    for rid,u in living:
        prepare_weapon(rid,u,living,seconds)
        if rid not in bearings and u["aim_target"]:
            enemy=state["units"][u["aim_target"]]["pos"]
            bearings[rid]=(enemy[0]-u["pos"][0],enemy[1]-u["pos"][1])
    disrupt(living,seconds)
    volleys={}
    for rid,u in living:
        target=u["aim_target"]
        due=max(seconds,u["next_shot"],u["aim_due"],u.get("weapon_not_before",0))
        if target and due<=seconds+STEP:
            volleys.setdefault(due,[]).append((rid,target))
    impacts={}
    for rid,u in state["units"].items():
        due=u.get("blast_due")
        if due is not None and due<=seconds+STEP:
            del u["blast_due"]
            if not u.get("out"):
                impacts.setdefault(max(seconds,due),[]).append(rid)
    if seconds in volleys:
        fire(state["units"],volleys.pop(seconds),seconds)
    arm=workshop.PARTS["repair_arm"]
    for rid,tech in living:
        if tech["hp"]<=0 or not tech.get("service_charges",0) or seconds-tech["last_service"]<arm["repair_interval"] or seconds<tech.get("repair_not_before",0):
            continue
        allies=repair_candidates(rid,tech,living,seconds)
        if not allies:continue
        _,_,other,ally=max(allies,key=lambda candidate:candidate[:2])
        amount=min(arm["repair_amount"],ally["max_hp"]-ally["hp"])
        ally["hp"]+=amount
        tech["service_charges"]-=1
        tech["last_service"]=seconds
        tech["repair_delayed"]=False
        event=dict(at=seconds,actor=rid,target=other,amount=amount)
        tech["events"].append(dict(event,kind="field_repair_output"))
        ally["events"].append(dict(event,kind="field_repair_received"))
    last=seconds
    for at in sorted(volleys.keys() | impacts.keys() | {seconds+STEP}):
        for rid,bearing in bearings.items():
            u=state["units"][rid]
            if u["hp"]>0:
                turn_towards(u,bearing,at-last)
        fire(state["units"],volleys.get(at,[]),at,impacts.get(at,[]))
        last=at
    survey(state)
    state["tick"]+=1


def fire(units, batch, at, impacts=()):
    # Equal deadlines fire simultaneously. A robot disabled at an earlier deadline cannot fire back.
    hits=[(actor,target) for actor,target in batch if units[actor]["hp"]>0 and units[target]["hp"]>0]
    damage_batch=[]
    for actor,target in hits:
        attacker=units[actor]
        interval = attacker["interval"]
        if attacker.get("parts",{}).get("weapon") != "rivet_repeater":
            interval = math.ceil(interval / STEP) * STEP
        attacker.update(shot=at,weapon_delayed=False,impact=list(units[target]["pos"]),
                        next_shot=at+interval)
        if attacker.get("parts",{}).get("weapon")=="chimney_arm":
            attacker["blast_due"]=at+workshop.PARTS["chimney_arm"]["blast_delay"]
        else:
            damage_batch.append((actor,target,False))
    for actor in impacts:
        attacker=units[actor]
        radius=workshop.PARTS["chimney_arm"]["blast_radius"]
        for target,victim in units.items():
            if victim["side"]!=attacker["side"] and victim["hp"]>0 and not victim.get("out") and math.dist(attacker["impact"],victim["pos"])<=radius:
                damage_batch.append((actor,target,True))
    for actor,target,area in damage_batch:
        victim=units[target]
        attacker=units[actor]
        damage=attacker["damage"]
        if damage > 0 and not area and victim.get("parts",{}).get("armor")=="rivet_shield":
            shield=workshop.PARTS["rivet_shield"]
            dx,dy=(a-b for a,b in zip(attacker["pos"],victim["pos"]))
            length=math.hypot(dx,dy)
            projection=victim["heading"][0]*dx+victim["heading"][1]*dy
            threshold=math.cos(math.radians(shield["front_half_angle"]))
            if length and projection/length+1e-6 >= threshold:
                reduced=damage*shield["direct_damage_ratio"]
                damage=max(1,math.floor(reduced+.5)) if damage==math.floor(damage) else reduced
        damage=min(victim["hp"],damage)
        if damage<=0:
            continue
        attacker["damage_dealt"]=attacker.get("damage_dealt",0)+damage
        victim["hp"]-=damage
        victim["last_damage"]=at
        if actor not in victim["contributors"]:
            victim["contributors"].append(actor)
        if victim["hp"]==0:
            victim["events"].append(dict(kind="disabled",actor=actor,target=target,amount=1,at=at))
            units[actor]["events"].append(dict(kind="kill",actor=actor,target=target,amount=1,at=at))
            for helper in victim["contributors"]:
                if helper!=actor and not units[helper].get("out"):
                    units[helper]["events"].append(dict(kind="assist",actor=helper,target=target,amount=1,at=at))
