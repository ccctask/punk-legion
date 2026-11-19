"""M09 account-owned crawlers, versioned designs and transactional equipment."""
import hashlib
import json
from pathlib import Path
import re
import uuid
import inventory
import storefront
from inventory import Fault

CATALOG = json.loads(Path(__file__).with_name("workshop_catalog.json").read_text())
HULL = CATALOG["chassis"]["crawler"]
PARTS = CATALOG["parts"]
BASE = {"core":"boiler", "head":"eye", "weapon":"cannon"}
FREE = inventory.FREE_PARTS
ROBOT_CAP = 18
SQUAD_CAP = 12
POINT_CAP = 24

def uid():
    return uuid.uuid4().hex

def create_tables(db):
    db.execute("""CREATE TABLE designs(id TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES accounts(id),
        name TEXT NOT NULL,revision INTEGER NOT NULL,version INTEGER NOT NULL,slots TEXT NOT NULL,
        UNIQUE(owner,name,revision))""")
    db.execute("""CREATE TABLE mounts(robot TEXT NOT NULL REFERENCES robots(id),slot TEXT NOT NULL,
        item TEXT NOT NULL UNIQUE REFERENCES parts(id),PRIMARY KEY(robot,slot))""")
    for row in db.execute("SELECT id,owner FROM robots"):
        initial_fit(db,row["owner"],row["id"])

def insert_part(db, owner, robot, slot, definition):
    item = uid()
    db.execute("INSERT INTO parts VALUES (?,?,?)",(item,owner,definition))
    db.execute("INSERT INTO mounts VALUES (?,?,?)",(robot,slot,item))
    return item

def initial_fit(db, owner, robot):
    for slot, definition in BASE.items():
        insert_part(db,owner,robot,slot,definition)

def complete(slots):
    return BASE.keys() <= slots.keys()

CHASSIS_PRICE = {"structure":-2,"components":-1,"energy":-1}

# Complete-unit fabrication prices. A chassis swap uses CHASSIS_PRICE separately.
BUILD_PRICES = {
    "chassis": {
        "crawler": {"structure":-3,"components":-1,"energy":-1},
        "wheel": {"structure":-3,"components":-1,"energy":-1},
        "survey_wheel": {"structure":-3,"components":-1,"energy":-1},
        "biped": {"structure":-4,"components":-2,"energy":-1},
    },
    "parts": {
        "boiler": {}, "eye": {}, "cannon": {}, "rivet_repeater": {},
        "reinforced_boiler": {"structure":-1}, "visor": {"components":-1},
        "drill": {"components":-1}, "chimney_arm": {},
        "jammer": {"structure":-2,"components":-2},
        "rivet_shield": inventory.RECIPES["rivet_shield"],
        "survey_radar": inventory.RECIPES["survey_radar"],
        "repair_arm": {"structure":-2,"components":-2},
    },
}

def hull_spec(chassis):
    if not isinstance(chassis,str) or chassis not in CATALOG["chassis"]:
        raise Fault(400,"chassis")
    return CATALOG["chassis"][chassis]

def robot_chassis(db, robot):
    row = db.execute("SELECT definition FROM robot_chassis WHERE robot=?", (robot,)).fetchone()
    return row[0] if row else "crawler"

def validate_fit(slots, partial=False, chassis="crawler"):
    hull = hull_spec(chassis)
    if not isinstance(slots,dict) or set(slots) - hull["slots"].keys() or (not partial and not complete(slots)):
        raise Fault(400,"missing_slot")
    totals = dict.fromkeys(("mass","power","supply","heat","cooling"),0)
    exclusive = set()
    for slot, definition in slots.items():
        if not isinstance(definition,str) or definition not in PARTS:
            raise Fault(400,"definition")
        part, mount = PARTS[definition], hull["slots"][slot]
        if part["kind"] != mount["kind"] or part["interface"] != mount["interface"]:
            raise Fault(400,"interface")
        if part["size"] > mount["size"]:
            raise Fault(400,"size")
        bus = part.get("exclusive")
        if bus and bus in exclusive:
            raise Fault(400,"exclusive")
        exclusive.add(bus)
        for name in totals:
            totals[name] += part.get(name,0)
    if totals["mass"] > hull["payload"]:
        raise Fault(400,"weight")
    if "core" in slots and totals["power"] > totals["supply"]:
        raise Fault(400,"power")
    if "core" in slots and totals["heat"] > totals["cooling"]:
        raise Fault(400,"heat")

def fit(db, robot):
    return {r["slot"]:{"id":r["id"],"definition":r["definition"]} for r in db.execute(
        "SELECT m.slot,p.id,p.definition FROM mounts m JOIN parts p ON p.id=m.item WHERE m.robot=?", (robot,))}

def build_cost(slots, chassis="crawler"):
    price = BUILD_PRICES["chassis"][chassis].copy()
    for definition in slots.values():
        for resource, delta in BUILD_PRICES["parts"][definition].items():
            price[resource] += delta
    return price

def robot_points(robot):
    hull_points = hull_spec(robot.get("chassis", "crawler"))["points"]
    return hull_points + sum(PARTS[part["definition"]]["points"] for part in robot["slots"].values())

def deployment_for(robots, selected=None):
    ready = {r["id"]:r for r in robots if not r["task"] and r.get("state","ready")=="ready" and complete(r["slots"])}
    if selected is not None:
        if not isinstance(selected,list) or not 1 <= len(selected) <= SQUAD_CAP or not all(isinstance(i,str) for i in selected):
            raise Fault(400,"unit_limit")
        if len(set(selected)) != len(selected) or any(i not in ready for i in selected):
            raise Fault(409,"unit_unavailable")
    deployment = {"units":[], "inventory":{}, "points":0,"paints":{},"hull_numbers":{},"orders":{}}
    for rid in (ready if selected is None else selected):
        parts = ready[rid]["slots"]
        chassis = ready[rid].get("chassis","crawler")
        points = robot_points(ready[rid])
        if deployment["points"] + points > POINT_CAP or len(deployment["units"]) >= SQUAD_CAP:
            if selected is None:
                continue
            raise Fault(409,"point_limit")
        deployment["points"] += points
        deployment["orders"][rid]=ready[rid].get("orders",default_orders(parts))
        if ready[rid].get("hull_number"):
            deployment["hull_numbers"][rid]=ready[rid]["hull_number"]
        deployment["paints"][rid]=ready[rid].get("paint","base")
        deployment["units"].append({"version":CATALOG["version"],"chassis":rid,"slots":{s:p["id"] for s,p in parts.items()}})
        deployment["inventory"][rid] = chassis
        deployment["inventory"].update({p["id"]:p["definition"] for p in parts.values()})
    return deployment

def default_orders(slots):
    def part(slot):
        return slots.get(slot,{}).get("definition")
    role="support" if part("utility")=="repair_arm" else "front" if part("weapon")=="drill" else "fire"
    return dict(role=role,guard="",distance="weapon",priority="nearest",retreat=0)

def set_orders(db, owner, rid, orders):
    if not isinstance(rid,str):
        raise Fault(400,"invalid_robot")
    row=db.execute("""SELECT r.task,COALESCE(c.state,'ready') state FROM robots r
                      LEFT JOIN robot_condition c ON c.robot=r.id WHERE r.owner=? AND r.id=?""",(owner,rid)).fetchone()
    if not row or row["state"]=="retired":
        raise Fault(404,"unknown_robot")
    if row["task"]:raise Fault(409,"robot_busy")
    if orders is None:
        db.execute("DELETE FROM robot_orders WHERE robot=?",(rid,))
        return
    if not isinstance(orders,dict) or orders.keys()!={"role","guard","distance","priority","retreat"}:
        raise Fault(400,"invalid_orders")
    if orders["role"] not in ("front","fire","support") or orders["distance"] not in ("weapon","close","standoff") or orders["priority"] not in ("nearest","weakest","threat") or type(orders["retreat"]) is not int or orders["retreat"] not in (0,25,50):
        raise Fault(400,"invalid_orders")
    guard=orders["guard"]
    if not isinstance(guard,str) or guard and (guard==rid or not db.execute("""SELECT 1 FROM robots r LEFT JOIN robot_condition c ON c.robot=r.id
        WHERE r.owner=? AND r.id=? AND COALESCE(c.state,'ready')!='retired'""",(owner,guard)).fetchone()):
        raise Fault(400,"invalid_guard")
    db.execute("INSERT INTO robot_orders VALUES (?,?) ON CONFLICT(robot) DO UPDATE SET body=excluded.body",(rid,json.dumps(orders)))

def owned_robots(db, owner):
    fleet=[]
    for r in db.execute(
        """SELECT r.id,r.name,r.task,COALESCE(h.definition,'crawler') chassis,o.body AS saved_orders,COALESCE(n.value,'') hull_number,COALESCE(p.paint,'base') paint,COALESCE(c.state,'ready') state FROM robots r
        LEFT JOIN hull_numbers n ON n.robot=r.id LEFT JOIN robot_chassis h ON h.robot=r.id LEFT JOIN robot_orders o ON o.robot=r.id LEFT JOIN robot_paint p ON p.robot=r.id
        LEFT JOIN robot_condition c ON c.robot=r.id WHERE r.owner=? AND COALESCE(c.state,'ready')!='retired'
        ORDER BY r.rowid""",(owner,)):
        robot=dict(r)
        saved=robot.pop("saved_orders")
        robot["slots"]=fit(db,r["id"])
        robot["orders"]=json.loads(saved) if saved else default_orders(robot["slots"])
        robot["custom_orders"]=bool(saved)
        fleet.append(robot)
    return fleet

def view(db, owner):
    import pump
    robots = owned_robots(db,owner)
    favorites={r[0] for r in db.execute("SELECT f.robot FROM favorite_robots f JOIN robots r ON r.id=f.robot WHERE r.owner=?", (owner,))}
    for unit in robots:
        unit["favorite"]=unit["id"] in favorites
    deployment = deployment_for(robots)
    designs = []
    positions=storefront.positions(db,owner)
    capacity=storefront.capacity(db,owner)
    for r in db.execute("SELECT id,name,revision,version,slots,chassis FROM designs WHERE owner=? ORDER BY rowid",(owner,)):
        slots = json.loads(r["slots"])
        place=positions.get(r["name"])
        designs.append({**dict(r),"slots":slots,"cost":build_cost(slots,r["chassis"]),"position":place,"active":place is not None and place<=capacity})
    stocks = {r[0]:r[1] for r in db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(owner,))}
    buildable_weapons = [recipe for recipe, in db.execute(
        "SELECT recipe FROM blueprints WHERE owner=? ORDER BY recipe",(owner,))
        if recipe in PARTS and PARTS[recipe]["kind"]=="tool"]
    return {"chassis_cost":CHASSIS_PRICE,"robots":robots,"designs":designs,"available":[dict(r) for r in db.execute(FREE,(owner,))],
            "build_prices":BUILD_PRICES,"buildable_weapons":buildable_weapons,"recovered_arm":pump.recovered_arm(db,owner),
            "stock":stocks,"deployment":deployment,"hangar_capacity":ROBOT_CAP,"part_capacity":inventory.PART_CAP,
            "design_capacity":capacity,"design_used":sum(v<=capacity for v in positions.values())}

def label(value):
    if not isinstance(value,str) or not 1 <= len(value.strip()) <= 24 or not value.isprintable():
        raise Fault(400,"invalid_name")
    return value.strip()

def apply_plan(db, owner, design, robot):
    if not isinstance(design,str) or not isinstance(robot,str):
        raise Fault(400,"invalid_parameters")
    saved=db.execute("SELECT name,revision,chassis,slots FROM designs WHERE owner=? AND id=?",(owner,design)).fetchone()
    if not saved:
        raise Fault(404,"unknown_design")
    unit=next((r for r in owned_robots(db,owner) if r["id"]==robot),None)
    if not unit:
        raise Fault(409,"unit_unavailable")
    desired=json.loads(saved["slots"])
    validate_fit(desired,chassis=saved["chassis"])
    free=db.execute(FREE+" ORDER BY p.rowid",(owner,)).fetchall()
    first={}
    for row in free:
        first.setdefault(row["definition"],row["id"])
    relief={r[0] for r in db.execute("SELECT item FROM mounts JOIN relief_parts ON id=item WHERE robot=?",(robot,))}
    rows=[]
    bag_after=len(free)
    for slot in hull_spec(saved["chassis"])["slots"]:
        mounted=unit["slots"].get(slot,{})
        current=mounted.get("definition","")
        current_id=mounted.get("id","")
        wanted=desired.get(slot,"")
        item=""
        if current==wanted:
            action="keep" if current_id else "empty"
        elif not wanted:
            action="remove"
        else:
            item=first.get(wanted,"")
            action=("replace" if current_id else "install") if item else "missing"
        disposition="keep" if current_id else "none"
        if current_id and action in ("replace","remove"):
            disposition="discard" if current_id in relief else "bag"
        bag_after+=int(disposition=="bag")-int(bool(item))
        rows.append(dict(slot=slot,current=current,current_id=current_id,wanted=wanted,item=item,
                         action=action,disposition=disposition))
    reason=""
    if storefront.positions(db,owner).get(saved["name"],999999)>storefront.capacity(db,owner):
        reason="inactive_design"
    elif unit["task"] or unit["state"]!="ready":
        reason="unit_unavailable"
    elif unit["chassis"]!=saved["chassis"]:
        reason="different_chassis"
    elif any(row["action"]=="missing" for row in rows):
        reason="design_part_missing"
    elif bag_after>inventory.PART_CAP:
        reason="parts_full"
    elif all(row["action"] in ("keep","empty") for row in rows):
        reason="unchanged_fit"
    # Bind the physical moves, not unrelated free bag contents.
    binding=[owner,robot,design,saved["revision"],unit["chassis"],saved["chassis"],reason,rows]
    fingerprint=hashlib.sha256(json.dumps(binding,sort_keys=True).encode()).hexdigest()
    return dict(robot=robot,robot_name=unit["name"],design=design,design_name=saved["name"],revision=saved["revision"],
                chassis=unit["chassis"],design_chassis=saved["chassis"],can_apply=not reason,reason=reason,
                fingerprint=fingerprint,slots=rows,bag_used=len(free),bag_after=bag_after,bag_capacity=inventory.PART_CAP)


def apply_design(db, owner, fields, signature):
    plan=apply_plan(db,owner,fields["design"],fields["robot"])
    reviewed="fingerprint" in fields
    if reviewed and fields["fingerprint"]!=plan["fingerprint"]:
        raise Fault(409,"fit_changed")
    if not plan["can_apply"] and (reviewed or plan["reason"]!="unchanged_fit"):
        raise Fault(409,plan["reason"])
    installed={}
    for row in plan["slots"]:
        if row["action"] in ("keep","empty"):
            continue
        slot=row["slot"]
        db.execute("DELETE FROM mounts WHERE robot=? AND slot=?",(plan["robot"],slot))
        if row["disposition"]=="discard":
            db.execute("DELETE FROM relief_parts WHERE id=?",(row["current_id"],))
            db.execute("DELETE FROM parts WHERE id=?",(row["current_id"],))
        if row["item"]:
            installed[slot]=row["item"]
            db.execute("INSERT INTO mounts VALUES (?,?,?)",(plan["robot"],slot,row["item"]))
    return inventory.record(db,owner,fields["key"],"apply",signature,{},robot=plan["robot"],design=plan["design"],installed=installed)


def operate(db, owner, action, fields):
    expected = {"design":{"name","version","slots"}, "build":{"design","name"}, "refit":{"robot","slot","item","expected"},
                "hull-number":{"robot","value","expected"},"chassis":{"robot","chassis","expected"},"remove":{"design"},"apply":{"design","robot"},"orders":{"robot","orders"}}
    if action=="apply" and "fingerprint" in fields:
        if not isinstance(fields["fingerprint"],str) or not re.fullmatch(r"[0-9a-f]{64}",fields["fingerprint"]):
            raise Fault(400,"invalid_parameters")
        expected["apply"].add("fingerprint")
    if action=="design" and "chassis" in fields:
        expected["design"].add("chassis")
    if action=="design" and "replace" in fields:
        expected["design"].add("replace")
    if action not in expected or fields.keys() != expected[action] | {"key"}:
        raise Fault(400,"invalid_parameters")
    key = fields["key"]
    if not isinstance(key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_key")
    signature = json.dumps([action,fields],sort_keys=True)
    prior = inventory.previous(db,owner,key,signature)
    if prior:
        return prior
    changes = {}
    if action=="hull-number":
        robot, value, previous = (fields[k] for k in ("robot","value","expected"))
        if not isinstance(robot,str) or not all(isinstance(v,str) and (v=="" or re.fullmatch(r"[0-9]{2}",v)) for v in (value,previous)):
            raise Fault(400,"invalid_hull_number")
        row=db.execute("""SELECT r.task,COALESCE(c.state,'ready') state,COALESCE(n.value,'') current
                          FROM robots r LEFT JOIN robot_condition c ON c.robot=r.id
                          LEFT JOIN hull_numbers n ON n.robot=r.id WHERE r.owner=? AND r.id=?""",(owner,robot)).fetchone()
        if not row:
            raise Fault(404,"unknown_robot")
        if row["task"] or row["state"]!="ready":
            raise Fault(409,"number_robot_unavailable")
        if row["current"]!=previous:
            raise Fault(409,"number_changed")
        if value==previous:
            raise Fault(409,"unchanged_number")
        if value:
            db.execute("INSERT INTO hull_numbers VALUES (?,?) ON CONFLICT(robot) DO UPDATE SET value=excluded.value",(robot,value))
        else:
            db.execute("DELETE FROM hull_numbers WHERE robot=?",(robot,))
        details={"robot":robot,"previous":previous,"value":value}
    elif action=="chassis":
        robot = fields["robot"]
        chassis = fields["chassis"]
        hull_spec(chassis)
        if not isinstance(robot,str) or not isinstance(fields["expected"],str):
            raise Fault(400,"invalid_parameters")
        unit = next((r for r in owned_robots(db,owner) if r["id"]==robot),None)
        if not unit or unit["task"] or unit["state"]!="ready":
            raise Fault(409,"unit_unavailable")
        if unit["chassis"] != fields["expected"]:
            raise Fault(409,"fit_changed")
        if unit["chassis"] == chassis:
            raise Fault(409,"unchanged_fit")
        validate_fit({s:p["definition"] for s,p in unit["slots"].items()},partial=True,chassis=chassis)
        changes = inventory.apply_stock(db,owner,CHASSIS_PRICE)
        db.execute("INSERT INTO robot_chassis VALUES (?,?) ON CONFLICT(robot) DO UPDATE SET definition=excluded.definition",(robot,chassis))
        details = {"robot":robot,"previous":unit["chassis"],"chassis":chassis}
    elif action=="orders":
        set_orders(db,owner,fields["robot"],fields["orders"])
        details={"robot":fields["robot"]}
    elif action == "design":
        name = label(fields["name"])
        if type(fields["version"]) is not int or fields["version"] != CATALOG["version"]:
            raise Fault(400,"version")
        slots = fields["slots"]
        chassis = fields.get("chassis","crawler")
        validate_fit(slots,chassis=chassis)
        if "replace" in fields and not isinstance(fields["replace"],str):
            raise Fault(400,"invalid_parameters")
        storefront.allocate(db,owner,name,fields.get("replace"))
        revision = db.execute("SELECT COALESCE(MAX(revision),0)+1 FROM designs WHERE owner=? AND name=?",(owner,name)).fetchone()[0]
        design = uid()
        db.execute("INSERT INTO designs(id,owner,name,revision,version,slots,chassis) VALUES (?,?,?,?,?,?,?)",(design,owner,name,revision,CATALOG["version"],json.dumps(slots),chassis))
        details = {"design":design,"revision":revision}
    elif action=="apply":
        return apply_design(db,owner,fields,signature)
    elif action in ("build","remove"):
        if not isinstance(fields["design"],str):
            raise Fault(400,"invalid_parameters")
        r = db.execute("SELECT slots,name,chassis FROM designs WHERE owner=? AND id=?",(owner,fields["design"])).fetchone()
        if not r:
            raise Fault(404,"unknown_design")
        if action=="remove":
            db.execute("DELETE FROM design_positions WHERE owner=? AND name=?",(owner,r["name"]))
            return inventory.record(db,owner,key,action,signature,{},design=fields["design"])
        if storefront.positions(db,owner).get(r["name"],999999)>storefront.capacity(db,owner):
            raise Fault(409,"inactive_design")
        slots = json.loads(r[0])
        chassis = r["chassis"]
        validate_fit(slots,chassis=chassis)
        name = label(fields["name"])
        if len(owned_robots(db,owner)) >= ROBOT_CAP:
            raise Fault(409,"hangar_full")
        # A build fabricates its own components. Locked tools cannot be fabricated by a saved design.
        if not db.execute("SELECT 1 FROM blueprints WHERE owner=? AND recipe=?",(owner,slots["weapon"])).fetchone():
            raise Fault(403,"blueprint_locked")
        changes = inventory.apply_stock(db,owner,build_cost(slots,chassis))
        robot = uid()
        db.execute("INSERT INTO robots VALUES (?,?,?,NULL,NULL)",(robot,owner,name))
        if chassis != "crawler":
            db.execute("INSERT INTO robot_chassis VALUES (?,?)",(robot,chassis))
        installed = {s:insert_part(db,owner,robot,s,p) for s,p in slots.items()}
        details = {"robot":robot,"design":fields["design"],"installed":installed}
    else:
        robot, slot, item, expected_item = (fields[k] for k in ("robot","slot","item","expected"))
        if not all(isinstance(v,str) for v in (robot,slot,item,expected_item)):
            raise Fault(400,"invalid_parameters")
        r = db.execute("SELECT task FROM robots WHERE id=? AND owner=?",(robot,owner)).fetchone()
        if not r:
            raise Fault(404,"unknown_robot")
        if slot not in hull_spec(robot_chassis(db,robot))["slots"]:
            raise Fault(400,"invalid_parameters")
        if r["task"]:
            raise Fault(409,"robot_busy")
        if db.execute("SELECT 1 FROM robot_condition WHERE robot=? AND state='retired'",(robot,)).fetchone():
            raise Fault(409,"unit_unavailable")
        mounted = fit(db,robot)
        old = mounted.get(slot,{}).get("id","")
        if old != expected_item:
            raise Fault(409,"fit_changed")
        if old == item:
            raise Fault(409,"unchanged_fit")
        selected = {s:p["definition"] for s,p in mounted.items() if s != slot}
        if item:
            replacement = db.execute(FREE + " AND p.id=?",(owner,item)).fetchone()
            if not replacement:
                raise Fault(409,"item_unavailable")
            selected[slot] = replacement["definition"]
        elif db.execute("SELECT COUNT(*) FROM (" + FREE + ")",(owner,)).fetchone()[0] >= inventory.PART_CAP:
            raise Fault(409,"parts_full")
        validate_fit(selected,partial=True,chassis=robot_chassis(db,robot))
        db.execute("DELETE FROM mounts WHERE robot=? AND slot=?",(robot,slot))
        if old and db.execute("DELETE FROM relief_parts WHERE id=?",(old,)).rowcount:
            db.execute("DELETE FROM parts WHERE id=?",(old,))
            old = ""
        if item:
            db.execute("INSERT INTO mounts VALUES (?,?,?)",(robot,slot,item))
        details = {"robot":robot,"slot":slot,"returned":old,"installed":item}
    return inventory.record(db,owner,key,action,signature,changes,**details)
