"""Server-clock private-base raids. Every viewing mode consumes the same immutable encounter."""
from collections import deque
import json
import math
import random
import re
import secrets
import time
import uuid

import inventory
import private_base
import production
import service_record
import workshop
from inventory import Fault

FIRST_GRACE = 12*3600
WARNING = 3 * 3600
COOLDOWN = 24 * 3600
LOSS_RECOVERY = 48 * 3600
RADAR_WINDOW = 90 * 60
INSURANCE = {"structure":6,"components":3,"energy":2}
MAX_LOOT = 3
MAX_COMBINED = 4


def schema(db):
    db.execute("CREATE TABLE raid_clocks(owner TEXT PRIMARY KEY REFERENCES accounts(id),due INTEGER NOT NULL,await_owner INTEGER NOT NULL DEFAULT 0)")
    db.execute("CREATE INDEX raid_due ON raid_clocks(due) WHERE await_owner=0")
    db.execute("""CREATE TABLE wild_raids(id TEXT PRIMARY KEY,owner TEXT REFERENCES accounts(id),warned INTEGER,
        starts INTEGER,seed INTEGER,wealth INTEGER,budget INTEGER,layout TEXT,robot TEXT,ticket TEXT,
        guard TEXT,outcome TEXT,receipt TEXT,pressure TEXT NOT NULL)""")
    db.execute("CREATE INDEX last_settled_raid ON wild_raids(owner) WHERE outcome IS NOT NULL")
    db.execute("CREATE UNIQUE INDEX active_wild_raid ON wild_raids(owner) WHERE outcome IS NULL")
    db.execute("""CREATE TABLE facility_damage(raid TEXT PRIMARY KEY REFERENCES wild_raids(id),
        owner TEXT NOT NULL REFERENCES accounts(id), building TEXT NOT NULL, started INTEGER NOT NULL,
        due INTEGER NOT NULL)""")
    db.execute("CREATE INDEX facility_damage_owner_due ON facility_damage(owner,due)")
    db.execute("INSERT INTO raid_clocks(owner,due) SELECT id,? FROM accounts",(int(time.time())+FIRST_GRACE,))


def activate(db,owner):
    db.execute("INSERT OR IGNORE INTO raid_clocks(owner,due) VALUES (?,?)",(owner,int(time.time())+FIRST_GRACE))

def upgrade_clock(db):
    if any(r["name"]=="await_owner" for r in db.execute("PRAGMA table_info(raid_clocks)")):
        return
    db.execute("ALTER TABLE raid_clocks ADD COLUMN await_owner INTEGER NOT NULL DEFAULT 0")
    # A settled latest raid without a recorded return must keep offline protection.
    db.execute("""UPDATE raid_clocks SET await_owner=1 WHERE
        (SELECT r.outcome FROM wild_raids r WHERE r.owner=raid_clocks.owner ORDER BY r.rowid DESC LIMIT 1) IS NOT NULL""")


def wealth(db,owner,layout,stamp=None):
    stocks = dict(db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(owner,)))
    state = db.execute("SELECT stamp,lines FROM production_state WHERE owner=?", (owner,)).fetchone()
    stamp = production.now() if stamp is None else stamp
    lines = production.projected_lines(state, stocks, stamp, production.damage_intervals(db,owner,state[0] if state else stamp))
    materials = sum((amount + lines[name]["pending"]) * (2 if name == "components" else 1)
                    for name, amount in stocks.items())
    bodies = workshop.owned_robots(db,owner)
    hulls = sum(5+sum(1+workshop.PARTS[p["definition"]]["points"] for p in r["slots"].values()) for r in bodies)
    spare = sum(1+workshop.PARTS[r["definition"]]["points"] for r in db.execute(workshop.FREE,(owner,)))
    mounted=sum(1+workshop.PARTS[r[0]]["points"] for r in db.execute(
        "SELECT p.definition FROM platform_parts x JOIN parts p ON p.id=x.item WHERE x.owner=?",(owner,)))
    return materials + 4*len(layout["buildings"]) + hulls + spare + mounted


def route_to_core(layout):
    origin = tuple(layout["entrance"])
    roads = {tuple(cell) for cell in layout["roads"]}
    core = next(b for b in layout["buildings"] if b["kind"]=="core")
    cells = {(x,y) for x in range(core["x"],core["x"]+core["w"]) for y in range(core["y"],core["y"]+core["h"])}
    queue = deque([(origin,[origin])])
    seen = {origin}
    while queue:
        pos,path = queue.popleft()
        for other in private_base.neighbors(pos):
            if other in cells:
                return [(origin[0]-2,origin[1]),(origin[0]-1,origin[1]),*path,other]
            if other in roads and other not in seen:
                seen.add(other)
                queue.append((other,path+[other]))
    raise ValueError("frozen layout has no route to its core")


def enemy_roster(seed, budget):
    if budget >= 5 and seed % 4 == 0:
        return ["swarm"] * 3 + ["patrol"] * (budget - 3)
    heavy = min(budget // 4, (budget - 2) // 2) if budget >= 4 and seed % 2 else 0
    return ["patrol"] * (budget - 2 * heavy) + ["dismantler"] * heavy


def simulate(layout,seed,budget,guard=None):
    rng = random.Random(seed)
    path = route_to_core(layout)
    foes = []
    for i, kind in enumerate(enemy_roster(seed, budget)):
        patrol_hp = 8 + budget // 2 + rng.randrange(4)
        heavy = kind == "dismantler"
        hp = patrol_hp * 2 if heavy else patrol_hp
        born = (i // 2) * 2
        if kind == "swarm":
            hp = patrol_hp // 2
            born = 0
        foes.append({"id":i, "hp":hp, "stride":2 if heavy else 1, "step":-1, "born":born})
    towers=[]
    medics=[]
    arm=workshop.PARTS["repair_arm"]
    for b in layout["buildings"]:
        if b["kind"]!="turret" or not b["powered"]:
            continue
        module=b.get("module",{"definition":"legacy"})
        if not module:
            continue
        t={"id":b["id"],"p":[b["x"],b["y"]],"angle":0.0}
        if module["definition"]=="repair_arm":
            medics.append(dict(t,charges=arm["repair_charges"],next=0,item=module["id"]))
        elif module["definition"] in ("legacy","cannon","rivet_repeater"):
            towers.append(dict(t,definition=module["definition"],next_shot=0.0))
    guard_pos = path[-1]
    guard_weapon = workshop.PARTS[guard["slots"]["weapon"]["definition"]] if guard else {}
    delayed = "blast_delay" in guard_weapon
    landing = None
    next_launch = 0
    guard_damage = 0
    leaks = 0
    kills = []
    frames = []
    last_arrival = max(f['born'] + (len(path)-1)*f['stride'] for f in foes)
    for tick in range(last_arrival+1):
        shots = []
        for foe in foes:
            age = tick - foe["born"]
            if foe["hp"]>0 and age>=0 and age%foe["stride"]==0:
                foe["step"] += 1
        active = [f for f in foes if f["hp"]>0 and f["step"]>=0]
        def fire(source,origin,target,power):
            target["hp"] -= power
            shots.append({"source":source,"origin":origin,"target":path[target["step"]],"enemy":target["id"]})
            if target["hp"]<=0 and source=="guard":
                kills.append((tick,target["id"]))
        delayed_shots = []

        def strike(at, source, origin, candidates):
            target = max((foe for foe in candidates if foe["hp"] > 0),
                         key=lambda foe: foe["step"], default=None)
            if target is not None:
                fire(source, origin, target, workshop.PARTS["rivet_repeater"]["damage"])
                shots[-1]["at"] = at

        def rapid_fire(source, origin, candidates, due):
            at = max(float(tick), due)
            while at < tick + 1:
                if at == tick:
                    strike(at, source, origin, candidates)
                else:
                    delayed_shots.append((at, source, origin, candidates))
                at = round(at + workshop.PARTS["rivet_repeater"]["attack_interval"], 3)
            return at

        for tower in towers:
            rapid = tower["definition"] == "rivet_repeater"
            reach = workshop.PARTS["rivet_repeater"]["range_m"] if rapid else 5
            targets = [f for f in active if f["hp"]>0 and math.dist(tower["p"],path[f["step"]])<=reach]
            if not targets:
                continue
            target = max(targets,key=lambda f:f["step"])
            x,y = tower["p"]
            ex,ey = path[target["step"]]
            desired = math.atan2(ex-x,ey-y)
            delta = (desired-tower["angle"]+math.pi)%(2*math.pi)-math.pi
            tower["angle"] += max(-1.25,min(1.25,delta))
            if abs(delta)<=1.25:
                muzzle = [x+0.4*math.sin(desired),y+0.4*math.cos(desired)]
                if rapid:
                    # Traverse once per raid frame, then fire at the aligned target.
                    tower["next_shot"] = rapid_fire(tower["id"], muzzle, [target], tower["next_shot"])
                elif math.dist(muzzle,(ex,ey))<=5:
                    fire(tower["id"],muzzle,target,6)
        if landing and tick >= landing["due"]:
            for foe in active:
                if foe["hp"]>0 and math.dist(path[foe["step"]],landing["target"])<=landing["radius"]:
                    fire("guard",landing["target"],foe,guard_weapon["damage"])
            landing=None
        rapid_guard = guard and guard["slots"]["weapon"]["definition"] == "rivet_repeater"
        if guard and (rapid_guard or tick>=next_launch):
            targets = [f for f in active if f["hp"]>0 and math.dist(guard_pos,path[f["step"]])<=guard_weapon["range_m"]]
            if targets:
                target=max(targets,key=lambda f:f["step"])
                if delayed:
                    landing=dict(source="guard",target=path[target["step"]],radius=guard_weapon["blast_radius"],due=tick+guard_weapon["blast_delay"])
                    next_launch=tick+guard_weapon["attack_interval"]
                elif rapid_guard:
                    next_launch = rapid_fire("guard", guard_pos, targets, next_launch)
                else:
                    fire("guard",guard_pos,target,guard_weapon["damage"])
        for event in sorted(delayed_shots, key=lambda entry: entry[0]):
            strike(*event)
        for f in active:
            if f["hp"]>0 and f["step"]==len(path)-1:
                f["hp"]=0
                leaks+=1
                if guard:
                    guard_damage+=1
        repairs=[]
        for t in medics:
            if guard and guard_damage and t["charges"] and tick>=t["next"] and math.dist(t["p"],guard_pos)<=arm["repair_range"]:
                amount=min(guard_damage,arm["repair_amount"])
                guard_damage-=amount
                t["charges"]-=1
                t["next"]=tick+arm["repair_interval"]
                repairs.append(dict(source=t["id"],item=t["item"],origin=t["p"],target=guard_pos,amount=amount))
        frames.append({"tick":tick,"foes":[[f["id"],*path[f["step"]]] for f in active if f["hp"]>0],
                       "shots":shots,"towers":{t["id"]:t["angle"] for t in towers},"leaks":leaks})
        if repairs:
            frames[-1]["repairs"]=repairs
        if landing:
            frames[-1]["marks"]=[landing]
        if all(f["hp"]<=0 for f in foes):
            break
    return {"frames":frames,"duration":len(frames),"outcome":"loss" if leaks>=2 else "win",
            "kills":kills,"guard_damage":guard_damage,"leaks":leaks}


def _loot_preview(db, owner, repair_cost=0):
    # Retain the stock query's iteration order for the seeded settlement draw.
    rows = db.execute("SELECT resource,amount FROM stocks WHERE owner=?", (owner,))
    exposed = {resource: max(0, amount - INSURANCE[resource]) for resource, amount in rows}
    limit = min(sum(exposed.values()), MAX_LOOT, MAX_COMBINED - repair_cost)
    return {"exposed": exposed, "max_loot": limit}


def damage_facility(db, row, settled):
    frozen = json.loads(row["layout"])
    path = route_to_core(frozen)
    layout = json.loads(db.execute("SELECT layout FROM bases WHERE owner=?", (row["owner"],)).fetchone()[0])
    current = {b["id"]:b for b in layout["buildings"]}
    candidates = [b for b in frozen["buildings"] if b["kind"] in ("foundry","workshop")
                  and b["powered"] and b["id"] in current]
    if not candidates:
        return None
    def distance(building):
        cells = [(building["x"]+i,building["y"]+j) for i in range(building["w"]) for j in range(building["h"])]
        return min(abs(x-px)+abs(y-py) for x,y in cells for px,py in path), building["id"]
    target = current[min(candidates,key=distance)["id"]]
    due = settled + 600
    db.execute("INSERT INTO facility_damage VALUES (?,?,?,?,?)",
               (row["id"],row["owner"],target["id"],settled,due))
    return private_base.damage_view(target,row["id"],settled,due)


def _settle(db,row,sim,stamp):
    loss = sim["outcome"]=="loss"
    recovery_seconds = LOSS_RECOVERY if loss else COOLDOWN
    repair_cost = 2 if row["robot"] and sim["guard_damage"] else 0
    # Mark the clock inside this transaction before receipt and inventory hooks advance production.
    db.execute("UPDATE raid_clocks SET due=?,await_owner=1 WHERE owner=?",(stamp+recovery_seconds,row["owner"]))
    facility = damage_facility(db,row,row["starts"]+sim["duration"]) if loss else None
    changes = {}
    if loss:
        preview = _loot_preview(db, row["owner"], repair_cost + int(facility is not None))
        bag = [resource for resource,count in preview["exposed"].items() for _ in range(count)]
        random.Random(row["seed"]).shuffle(bag)
        for k in bag[:preview["max_loot"]]:
            changes[k]=changes.get(k,0)-1
    if row["ticket"]:
        robot = row["robot"]
        events = [{"at":t,"kind":"kill","actor":robot,"target":f"wild-{i}","amount":1} for t,i in sim["kills"]]
        repairs=[(frame["tick"],e) for frame in sim["frames"] for e in frame.get("repairs",[])]
        events.extend(dict(at=t,kind="field_repair_received",actor=e["source"],target=robot,amount=e["amount"]) for t,e in repairs)
        events.sort(key=lambda e:e["at"])
        if repair_cost:
            events.append({"at":sim["duration"],"kind":"condition","actor":"combat","target":robot,"amount":sim["guard_damage"]})
        service_record.finish_mission(db,row["ticket"],row["id"],sim["outcome"],events,sim["duration"])
    actual = inventory.apply_stock(db,row["owner"],changes)
    receipt = inventory.record(db,row["owner"],"wild/"+row["id"],"wild_raid",row["id"],actual,
        raid=row["id"],outcome=sim["outcome"],repair_cost=repair_cost,facility_damage=facility,leaks=sim["leaks"],
        settled_for=row["starts"]+sim["duration"],processed=stamp,recovery_seconds=recovery_seconds,seed=row["seed"],
        platform_repair=sum(e["amount"] for f in sim["frames"] for e in f.get("repairs",[])))
    db.execute("UPDATE wild_raids SET outcome=?,receipt=? WHERE id=?",(sim["outcome"],json.dumps(receipt),row["id"]))


def recovery_pressure(db,owner,value,due):
    base=min(12,2+value//30)
    reasons=[]
    last=db.execute("""SELECT id,outcome,robot FROM wild_raids WHERE owner=? AND outcome IS NOT NULL
                       ORDER BY rowid DESC LIMIT 1""",(owner,)).fetchone()
    if base>2 and last and last["outcome"]=="loss":
        reasons.append("previous_loss")
        if base>3 and last["robot"]:
            # A late read may already have completed the repair. Use its effective time,
            # and require the original defense injury to still be outstanding at warning time.
            wounded=db.execute("""SELECT 1 FROM repair_log injury
                JOIN robots r ON r.id=injury.robot
                WHERE r.owner=? AND injury.robot=? AND injury.kind='combat_damage' AND injury.reference=?
                AND injury.at<=? AND NOT EXISTS (
                    SELECT 1 FROM repair_log healed WHERE healed.robot=injury.robot AND healed.id>injury.id
                    AND healed.kind IN ('workshop_repair','relief','recycled') AND healed.at<=?)
                AND NOT EXISTS (SELECT 1 FROM robot_condition c WHERE c.robot=injury.robot
                    AND c.state='repairing' AND c.due<=?)""",(owner,last["robot"],last["id"],due,due,due)).fetchone()
            if wounded:
                reasons.append("guard_recovery")
    return dict(base=base,reduction=len(reasons),reasons=reasons)


def _freeze_warning(db, owner, due):
    base = db.execute("SELECT layout FROM bases WHERE owner=?",(owner,)).fetchone()
    if not base:
        return
    layout = private_base.check(json.loads(base[0]))
    value = wealth(db,owner,layout,due)
    pressure = recovery_pressure(db,owner,value,due)
    starts = due+WARNING
    db.execute("""INSERT INTO wild_raids(id,owner,warned,starts,seed,wealth,budget,layout,pressure)
        VALUES (?,?,?,?,?,?,?,?,?)""",(uuid.uuid4().hex,owner,due,starts,secrets.randbelow(2**31),
        value,pressure["base"]-pressure["reduction"],json.dumps(layout),json.dumps(pressure)))
    db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(starts,owner))


def freeze_before_production(db, owner, stamp):
    due = db.execute("""SELECT due FROM raid_clocks WHERE owner=? AND await_owner=0 AND due<=?
        AND NOT EXISTS (SELECT 1 FROM wild_raids WHERE owner=raid_clocks.owner AND outcome IS NULL)""",
        (owner,stamp)).fetchone()
    if due:
        _freeze_warning(db,owner,due[0])


def advance(db,owner,stamp=None,active=False):
    stamp = int(time.time()) if stamp is None else stamp
    activate(db,owner)
    due,waiting = db.execute("SELECT due,await_owner FROM raid_clocks WHERE owner=?",(owner,)).fetchone()
    if waiting:
        if active:
            db.execute("UPDATE raid_clocks SET await_owner=0,due=? WHERE owner=?",
                       (stamp+COOLDOWN if due<=stamp else due,owner))
        return
    if due>stamp:
        return
    row = db.execute("SELECT * FROM wild_raids WHERE owner=? AND outcome IS NULL",(owner,)).fetchone()
    if not row:
        _freeze_warning(db,owner,due)
        row = db.execute("SELECT * FROM wild_raids WHERE owner=? AND outcome IS NULL",(owner,)).fetchone()
    if row and stamp>=row["starts"]:
        sim = simulate(json.loads(row["layout"]),row["seed"],row["budget"],json.loads(row["guard"]) if row["guard"] else None)
        if stamp >= row["starts"]+sim["duration"]:
            _settle(db,row,sim,stamp)
        else:
            db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(row["starts"]+sim["duration"],owner))


def scheduled_owners(db, stamp):
    return [row[0] for row in db.execute(
        "SELECT owner FROM raid_clocks WHERE due<=? AND await_owner=0 ORDER BY due LIMIT 64",(stamp,))]


def due_accounts(db):
    stamp = int(time.time())
    for owner in scheduled_owners(db,stamp):
        advance(db,owner,stamp)


def stage(db,owner):
    row = db.execute("SELECT outcome,starts FROM wild_raids WHERE owner=? ORDER BY rowid DESC LIMIT 1",(owner,)).fetchone()
    if not row:
        return "protected"
    if row["outcome"]:
        return "replay"
    return "warning" if int(time.time())<row["starts"] else "live"


def radar(db, owner, station_id):
    """Observe a single committed schedule, including power at the selected station."""
    base = db.execute("SELECT layout FROM bases WHERE owner=?", (owner,)).fetchone()
    buildings = private_base.check(json.loads(base[0]))["buildings"] if base else []
    station = next((b for b in buildings if b["id"]==station_id and b["kind"]=="radar_station"), None)
    if not station:
        raise Fault(404,"unknown_station")
    now = int(time.time())
    result = {"station_id":station_id,"server_now":now,"next_refresh":0}
    if not station["powered"]:
        result.update(stage="unpowered",power_reason=station["power_reason"])
        return {"radar":result}
    current = db.execute("SELECT id,starts,budget,layout FROM wild_raids WHERE owner=? AND outcome IS NULL", (owner,)).fetchone()
    if current:
        if now < current["starts"]:
            result.update(stage="warning",raid_id=current["id"],starts=current["starts"],budget=current["budget"],
                          approach_path=route_to_core(json.loads(current["layout"])),loot_preview=_loot_preview(db,owner),
                          next_refresh=current["starts"])
        else:
            result.update(stage="live",raid_id=current["id"],next_refresh=now+5)
    else:
        clock = db.execute("SELECT due,await_owner FROM raid_clocks WHERE owner=?", (owner,)).fetchone()
        if not clock or clock["await_owner"]:
            result.update(stage="resting")
        else:
            until_warning = clock["due"] - now
            if until_warning > RADAR_WINDOW:
                result.update(stage="quiet",next_refresh=now+60)
            elif until_warning > 0:
                minutes = (until_warning+59)//60
                result.update(stage="signal",minutes=minutes,next_refresh=clock["due"]-(minutes-1)*60)
            else:
                result.update(stage="pending",next_refresh=now+2)
    return {"radar":result}


def handle(db,owner,method,route,fields):
    stamp = int(time.time())
    advance(db,owner,stamp,active=True)
    live = db.execute("SELECT * FROM wild_raids WHERE owner=? AND outcome IS NULL",(owner,)).fetchone()
    if method=="POST":
        if route!="/v1/base/raids/guard" or fields.keys()!={"raid","robot"} or not live or fields["raid"]!=live["id"] or stamp>=live["starts"]:
            raise Fault(409,"raid_locked")
        if not isinstance(fields["robot"],str) or not re.fullmatch(r"[a-f0-9]{32}",fields["robot"]):
            raise Fault(400,"invalid_robot")
        if live["robot"] and live["robot"]!=fields["robot"]:
            raise Fault(409,"guard_already_bound")
        if not live["robot"]:
            ticket = service_record.start_mission(db,owner,fields["robot"],live["id"])
            snap = db.execute("SELECT snapshot FROM robot_sorties WHERE ticket=?",(ticket,)).fetchone()[0]
            db.execute("UPDATE robots SET task='guard' WHERE assignment=?",(ticket,))
            db.execute("UPDATE wild_raids SET robot=?,ticket=?,guard=? WHERE id=?",(fields["robot"],ticket,snap,live["id"]))
    elif method!="GET" or route!="/v1/base/raids":
        raise Fault(404,"unknown_route")
    row = db.execute("SELECT * FROM wild_raids WHERE owner=? ORDER BY rowid DESC LIMIT 1",(owner,)).fetchone()
    due = db.execute("SELECT due FROM raid_clocks WHERE owner=?",(owner,)).fetchone()[0]
    result = {"now":stamp,"due":due,"stage":"protected","insurance":INSURANCE,"loot_cap":MAX_LOOT,
        "combined_cap":MAX_COMBINED,"eligible":[{"id":r["id"],"name":r["name"]} for r in workshop.owned_robots(db,owner)
        if r["state"]=="ready" and not r["task"] and workshop.complete(r["slots"])]}
    if row:
        guard = json.loads(row["guard"]) if row["guard"] else None
        result.update(id=row["id"],layout=json.loads(row["layout"]),seed=row["seed"],wealth=row["wealth"],
                      budget=row["budget"],pressure=json.loads(row["pressure"]),starts=row["starts"],guard=guard,
                      enemy_roster=enemy_roster(row["seed"],row["budget"]))
        if not row["outcome"] and stamp<row["starts"]:
            result["stage"]="warning"
            result["approach_path"] = [list(cell) for cell in route_to_core(result["layout"])]
            result["loot_preview"] = _loot_preview(db, owner)
        else:
            sim = simulate(result["layout"],row["seed"],row["budget"],guard)
            result["frames"]=sim["frames"] if row["outcome"] else sim["frames"][:stamp-row["starts"]+1]
            result["stage"]="replay" if row["outcome"] else "live"
            if row["receipt"]:
                result["receipt"]=json.loads(row["receipt"])
    return {"raid":result}
