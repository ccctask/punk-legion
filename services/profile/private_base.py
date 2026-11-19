"""Account-owned M11 base. Layout edits and material deductions share the ledger transaction."""
import copy
import json
import re
import time
import uuid

import inventory
import production
from inventory import Fault

WIDTH, HEIGHT = 12, 9
EXPANDED_WIDTH = WIDTH + 3
ENTRANCE = (0, 4)
# Width, depth, power demand. The core supplies six units; placement order sets priority.
FACILITIES = {"core": (2,2,0), "foundry": (2,2,2), "warehouse": (2,1,0),
              "workshop": (2,2,2), "repair": (1,2,1), "turret": (1,1,2), "hangar": (2,2,0),
              "relay": (1,1,0), "research_station": (2,1,1), "radar_station": (2,1,1)}
SUPPLY = 6
POWER_RADIUS = 6
PRICE = 1


def ensure_tables(db):
    db.execute("CREATE TABLE IF NOT EXISTS base_schema(version INTEGER PRIMARY KEY CHECK(version=1))")
    db.execute("INSERT OR IGNORE INTO base_schema VALUES(1)")
    db.execute("CREATE TABLE IF NOT EXISTS bases(owner TEXT PRIMARY KEY REFERENCES accounts(id), layout TEXT NOT NULL)")
    db.execute("""CREATE TABLE IF NOT EXISTS base_snapshots
               (id TEXT PRIMARY KEY, owner TEXT REFERENCES accounts(id), revision INTEGER NOT NULL,
                layout TEXT NOT NULL, UNIQUE(owner,revision))""")


def starter():
    return {"revision":1,"buildings":[{"id":uuid.uuid4().hex,"kind":"core","x":1,"y":2}],
            "roads":[[x,4] for x in range(10)]}


def save_layout(db, owner, layout, state=None, platform=None):
    """Commit the layout and any still-editable raid defense at one server timestamp."""
    import platforms
    import raids
    stamp = int(time.time())
    raids.freeze_before_production(db, owner, stamp)
    if platform is not None and platforms.locked(db, owner, platform, stamp):
        raise Fault(409, "platform_locked")
    db.execute("UPDATE bases SET layout=? WHERE owner=?", (json.dumps(layout), owner))
    if state is None:
        state = check(layout)
    db.execute("""UPDATE wild_raids SET layout=? WHERE owner=? AND outcome IS NULL AND starts>?""",
               (json.dumps(state), owner, stamp))


def grant_rustrail(layout):
    if layout.get("rustrail_east"):
        return
    layout["rustrail_east"] = True
    layout["revision"] += 1
    return True


def on_rustrail_win(db, owner):
    ensure_tables(db)
    row = db.execute("SELECT layout FROM bases WHERE owner=?", (owner,)).fetchone()
    if row:
        layout = json.loads(row[0])
        if grant_rustrail(layout):
            save_layout(db, owner, layout)


def activate(db,owner):
    ensure_tables(db)
    row = db.execute("SELECT layout FROM bases WHERE owner=?", (owner,)).fetchone()
    if not row:
        layout = starter()
        db.execute("INSERT INTO bases VALUES (?,?)",(owner,json.dumps(layout)))
    else:
        layout = json.loads(row[0])
    production.update(db,owner,check(layout))


def activate_existing(db):
    production.init(db)
    for row in db.execute("SELECT id FROM accounts WHERE id NOT IN (SELECT owner FROM production_state)").fetchall():
        activate(db,row[0])


def neighbors(pos):
    x, y = pos
    return ((x-1,y),(x+1,y),(x,y-1),(x,y+1))


def supply_cells(building, width, height=HEIGHT):
    """Manhattan distance measured to the nearest cell of the source footprint."""
    left, top = building["x"], building["y"]
    w,h,_ = FACILITIES[building["kind"]]
    right, bottom = left+w-1, top+h-1
    return {(x,y) for y in range(height) for x in range(width)
            if max(left-x,0,x-right)+max(top-y,0,y-bottom)<=POWER_RADIUS}


def check(layout):
    width = EXPANDED_WIDTH if layout.get("rustrail_east") else WIDTH
    height = HEIGHT + 2 if layout.get("factory_south") else HEIGHT
    roads = {tuple(p) for p in layout["roads"]}
    if any(not (0 <= x < width and 0 <= y < height) for x,y in roads):
        raise Fault(409,"outside_grid")
    if ENTRANCE not in roads:
        raise Fault(409,"entrance_reserved")
    reached = {ENTRANCE}
    stack = [ENTRANCE]
    while stack:
        for point in neighbors(stack.pop()):
            if point in roads and point not in reached:
                stack.append(point)
                reached.add(point)
    if reached != roads:
        raise Fault(409,"road_disconnected")
    used = set(roads)
    core = next(b for b in layout["buildings"] if b["kind"]=="core")
    core_coverage = supply_cells(core,width,height)
    coverage = core_coverage.copy()
    for relay in layout["buildings"]:
        if relay["kind"]=="relay" and not relay.get("paused") and (relay["x"],relay["y"]) in core_coverage:
            coverage.update(supply_cells(relay,width,height))
    remaining = SUPPLY
    buildings = []
    for building in layout["buildings"]:
        w,h,demand = FACILITIES[building["kind"]]
        cells = {(building["x"]+x,building["y"]+y) for x in range(w) for y in range(h)}
        if any(not (0 <= x < width and 0 <= y < height) for x,y in cells):
            raise Fault(409,"outside_grid")
        if ENTRANCE in cells:
            raise Fault(409,"entrance_reserved")
        if used & cells:
            raise Fault(409,"occupied")
        if not any(neighbor in reached for cell in cells for neighbor in neighbors(cell)):
            raise Fault(409,"building_disconnected")
        used.update(cells)
        available = core_coverage if building["kind"]=="relay" else coverage
        needs_connection = demand > 0 or building["kind"]=="relay"
        if building.get("paused",False):
            reason = "paused"
        elif needs_connection and cells.isdisjoint(available):
            reason = "out_of_range"
        elif demand > remaining:
            reason = "budget"
        else:
            reason = "powered"
        powered = reason == "powered"
        if powered:
            remaining -= demand
        buildings.append(dict(building,w=w,h=h,powered=powered,demand=demand,power_reason=reason))
    grid_order = lambda p:(p[1],p[0])
    return dict(layout,buildings=buildings,supply=SUPPLY,used=SUPPLY-remaining,
                coverage=sorted(coverage,key=grid_order),core_coverage=sorted(core_coverage,key=grid_order),
                width=width,height=height,factory_south=bool(layout.get("factory_south")),entrance=list(ENTRANCE),
                rustrail_east=bool(layout.get("rustrail_east")),
                catalog={k: dict(w=v[0],h=v[1],power=v[2]) for k,v in FACILITIES.items()},price=PRICE)


def change(layout, fields):
    mode = fields.get("action")
    x, y = fields.get("x"), fields.get("y")
    width = EXPANDED_WIDTH if layout.get("rustrail_east") else WIDTH
    height = HEIGHT + 2 if layout.get("factory_south") else HEIGHT
    if type(x) != int or type(y) != int or not (0 <= x < width and 0 <= y < height):
        raise Fault(409,"outside_grid")
    cost = {}
    if mode in ("road","erase"):
        cell = [x,y]
        if mode == "road":
            if cell in layout["roads"]:
                raise Fault(409,"occupied")
            layout["roads"].append(cell)
        else:
            if cell not in layout["roads"]:
                raise Fault(409,"road_missing")
            layout["roads"].remove(cell)
    elif mode == "build":
        kind = fields.get("kind")
        if not isinstance(kind,str) or kind not in FACILITIES or kind == "core":
            raise Fault(400,"invalid_facility")
        layout["buildings"].append(dict(id=uuid.uuid4().hex,kind=kind,x=x,y=y))
        if kind=="turret":
            layout["buildings"][-1]["module"]=None
        cost = {"structure":-PRICE}
    elif mode in ("move","power","remove"):
        building = next((b for b in layout["buildings"] if b["id"] == fields.get("building")), None)
        if building is None:
            raise Fault(404,"unknown_building")
        if mode == "remove":
            if building["kind"] != "radar_station":
                raise Fault(409,"not_removable")
            layout["buildings"].remove(building)
        elif mode == "power":
            if building["kind"] == "core":
                raise Fault(409,"core_required")
            building["paused"] = not building.get("paused",False)
        else:
            if (building["x"],building["y"]) == (x,y):
                raise Fault(409,"same_position")
            building.update(x=x,y=y)
    else:
        raise Fault(400,"invalid_edit")
    layout["revision"] += 1
    return check(layout), cost


def edit_status(db, owner, key):
    if not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_key")
    row = db.execute("SELECT layout FROM bases WHERE owner=?",(owner,)).fetchone()
    if not row:
        raise Fault(404,"unknown_base")
    import plaques
    base = check(json.loads(row["layout"]))
    base["plaque"] = plaques.inscription(db,owner)
    receipt = db.execute("SELECT body FROM receipts WHERE owner=? AND business_key=? AND operation='base_edit'",
                         (owner,key)).fetchone()
    return {"key":key,"base":attach_damage(db,owner,base),"receipt":json.loads(receipt["body"]) if receipt else None}


def damage_view(building, raid, started, due):
    return dict(building=building["id"],kind=building["kind"],x=building["x"],y=building["y"],
                raid=raid,started=started,due=due,cost={"structure":1})


def attach_damage(db,owner,state):
    buildings = {b["id"]:b for b in state["buildings"]}
    stamp = production.now()
    state["server_now"] = stamp
    state["facility_damage"] = [
        damage_view(buildings[d["building"]],d["raid"],d["started"],d["due"]) for d in db.execute(
            "SELECT * FROM facility_damage WHERE owner=? AND started<=? AND due>? ORDER BY building",
            (owner,stamp,stamp)) if d["building"] in buildings]
    return state


def repair_facility(db,owner,fields,state):
    if fields.keys() != {"key","raid","building"} or not all(isinstance(v,str) for v in fields.values()):
        raise Fault(400,"invalid_parameters")
    key = fields["key"]
    if not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_key")
    signature = json.dumps(["facility_repair",fields],sort_keys=True)
    receipt = inventory.previous(db,owner,key,signature)
    if not receipt:
        stamp = production.now()
        matched = db.execute("""UPDATE facility_damage SET due=? WHERE owner=? AND raid=? AND building=?
                             AND started<=? AND due>?""",
                             (stamp,owner,fields["raid"],fields["building"],stamp,stamp)).rowcount
        if not matched:
            raise Fault(409,"facility_not_damaged")
        changes = inventory.apply_stock(db,owner,{"structure":-1})
        receipt = inventory.record(db,owner,key,"facility_repair",signature,changes,
                                   building=fields["building"],raid=fields["raid"])
    return {"receipt":receipt,"base":attach_damage(db,owner,state),"production":production.update(db,owner,state)}


def handle(db, owner, method, route, fields):
    ensure_tables(db)
    row = db.execute("SELECT layout FROM bases WHERE owner=?", (owner,)).fetchone()
    if row:
        layout = json.loads(row[0])
    else:
        layout = starter()
        db.execute("INSERT INTO bases VALUES (?,?)",(owner,json.dumps(layout)))
    if not layout.get("rustrail_east") and db.execute(
            "SELECT 1 FROM sqlite_master WHERE name='expeditions'").fetchone():
        won = db.execute("""SELECT 1 FROM expeditions WHERE owner=? AND result='win' AND id NOT IN (SELECT mission FROM pump_entries) AND id NOT IN (SELECT mission FROM factory_entries) AND id NOT IN (SELECT mission FROM armory_entries)
                            AND receipt IS NOT NULL LIMIT 1""", (owner,)).fetchone()
        if won and grant_rustrail(layout):
            # This read-side recognition may update the home, never the current raid.
            db.execute("UPDATE bases SET layout=? WHERE owner=?", (json.dumps(layout), owner))
    state = check(layout)
    if route.startswith("/v1/base/plaques"):
        import plaques
        return plaques.handle(db,owner,method,route,fields)
    if route.startswith("/v1/base/platforms/"):
        import platforms
        return platforms.handle(db,owner,method,route,fields,layout)
    if route.startswith("/v1/base/production"):
        return production.handle(db,owner,route,method,fields,state)
    economy = production.update(db,owner,state)
    if route == "/v1/base/facility-repair" and method == "POST":
        return repair_facility(db,owner,fields,state)
    if route == "/v1/base" and method == "GET":
        latest = db.execute("SELECT id FROM base_snapshots WHERE owner=? ORDER BY revision DESC LIMIT 1",(owner,)).fetchone()
        import raids
        import plaques
        state["plaque"] = plaques.inscription(db,owner)
        return {"base":attach_damage(db,owner,state), "production":economy, "latest_snapshot":latest[0] if latest else "",
                "raid_stage":raids.stage(db,owner)}
    if route.startswith("/v1/base/snapshots/") and method == "GET":
        row = db.execute("SELECT layout FROM base_snapshots WHERE owner=? AND id=?", (owner,route.rsplit("/",1)[1])).fetchone()
        if not row:
            raise Fault(404,"unknown_snapshot")
        return {"snapshot":json.loads(row[0])}
    if route not in ("/v1/base/preview","/v1/base/edit","/v1/base/freeze") or method != "POST":
        raise Fault(404,"unknown_route")
    preview = route.endswith("/preview")
    freeze = route.endswith("/freeze")
    required = {"revision"}
    if not preview:
        required.add("key")
    if not freeze:
        required.update(("action","x","y"))
        if fields.get("action") == "build":
            required.add("kind")
        if fields.get("action") in ("move","power","remove"):
            required.add("building")
    if fields.keys() != required:
        raise Fault(400,"invalid_parameters")
    if not preview:
        key = fields["key"]
        if not isinstance(key,str) or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",key):
            raise Fault(400,"invalid_key")
        signature = json.dumps([route,fields],sort_keys=True)
        original = inventory.previous(db,owner,key,signature)
        if original:
            return {"base":attach_damage(db,owner,check(layout)),"receipt":original}
    if type(fields["revision"]) != int or fields["revision"] != layout["revision"]:
        raise Fault(409,"stale_layout")
    if freeze:
        saved = db.execute("SELECT id FROM base_snapshots WHERE owner=? AND revision=?", (owner,layout["revision"])).fetchone()
        ident = saved[0] if saved else uuid.uuid4().hex
        if not saved:
            db.execute("INSERT INTO base_snapshots VALUES (?,?,?,?)",(ident,owner,layout["revision"],json.dumps(check(layout))))
        receipt = inventory.record(db,owner,key,"base_freeze",signature,{},snapshot=ident,revision=layout["revision"])
        return {"base":attach_damage(db,owner,check(layout)),"receipt":receipt}
    edited = copy.deepcopy(layout)
    state,cost = change(edited,fields)
    changes = inventory.apply_stock(db,owner,cost) if not preview else cost
    if preview:
        stock = db.execute("SELECT amount FROM stocks WHERE owner=? AND resource='structure'",(owner,)).fetchone()
        if stock[0] < -cost.get("structure",0):
            raise Fault(409,"insufficient_stock")
        return {"preview":attach_damage(db,owner,state), "cost":cost}
    save_layout(db, owner, edited, state)
    economy = production.update(db,owner,state)
    receipt = inventory.record(db,owner,key,"base_edit",signature,changes,revision=edited["revision"])
    return {"base":attach_damage(db,owner,state),"receipt":receipt,"production":economy}
