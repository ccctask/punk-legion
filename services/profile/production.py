"""M12 finite production. Seconds of partial work persist across offline intervals."""
import json
import re
import time

import inventory
from inventory import Fault

# Prototype cycles in seconds, one unit per cycle per active facility.
LINES = {"structure":("foundry",1200), "components":("workshop",1800), "energy":("core",3600)}
DEPOT = {"structure":4,"components":3,"energy":2}
OFFLINE_SECONDS = 12 * 3600
RESEARCH = {"drill":{"structure":-2,"components":-1}, "casting":{"components":-2,"energy":-1},
            "optics":{"components":-2,"energy":-1}}
DRILL_WINS = 3


def drill_recipe(db, owner):
    row = db.execute("SELECT wins FROM expedition_loot WHERE owner=?", (owner,)).fetchone()
    mastered = db.execute("SELECT 1 FROM blueprints WHERE owner=? AND recipe='drill'", (owner,)).fetchone()
    return {"wins":min(row[0], DRILL_WINS) if row else 0, "required":DRILL_WINS, "mastered":bool(mastered)}


def unlock_drill(db, owner):
    granted = db.execute("INSERT OR IGNORE INTO blueprints VALUES (?,'drill')", (owner,)).rowcount == 1
    if granted:
        db.execute("INSERT INTO technologies VALUES (?,'drill')", (owner,))
    return granted


def now():
    return int(time.time())


def init(db):
    db.execute("""CREATE TABLE IF NOT EXISTS production_state(owner TEXT PRIMARY KEY REFERENCES accounts(id),
        stamp INTEGER NOT NULL, lines TEXT NOT NULL)""")
    db.execute("""CREATE TABLE IF NOT EXISTS technologies(owner TEXT REFERENCES accounts(id), tech TEXT,
        PRIMARY KEY(owner,tech))""")


def projected_lines(row, stocks, stamp, damage=()):
    elapsed = max(0,min(OFFLINE_SECONDS,stamp-row[0])) if row else 0
    lines = json.loads(row[1]) if row else {
        k:dict(pending=0,progress=0,rate=0,capacity=v) for k,v in DEPOT.items()}
    for resource, (_,cycle) in LINES.items():
        line = lines[resource]
        free = max(0,inventory.STOCK[resource][1]-stocks[resource])
        limit = min(free,line["capacity"])
        facilities = line.get("sources", [])
        speed = line.get("speed", 1)
        stopped = [d for d in damage if d["building"] in facilities]
        # Work is integrated over the same capped offline interval as ordinary production.
        lost = sum(max(0, min(row[0]+elapsed,d["due"])-max(row[0],d["started"])) for d in stopped)
        work = (elapsed * len(facilities) - lost) * speed
        line["facilities"] = len(facilities) - sum(d["started"] <= stamp < d["due"] for d in stopped)
        line["rate"] = line["facilities"] * speed
        periods, remainder = divmod(line["progress"] + work,cycle)
        line["pending"] = min(limit,line["pending"]+periods)
        line["progress"] = remainder if line["pending"] < limit else 0
        line.update(stock=stocks[resource],free=free,cycle=cycle)
    return lines


def update(db, owner, layout=None):
    # Stock-only operations on pre-base accounts do not start an economic clock.
    if layout is None and not db.execute("SELECT 1 FROM sqlite_master WHERE name='production_state'").fetchone():
        return
    if layout is not None:
        init(db)
    row = db.execute("SELECT stamp,lines FROM production_state WHERE owner=?",(owner,)).fetchone()
    if not row and layout is None:
        return
    stamp = now()
    if row:
        # A late stock delivery or login can reach this clock before the background raid sweep.
        import raids
        # Internal payouts can reach this account before the bounded global raid sweep.
        raids.advance(db, owner, stamp)
        row = db.execute("SELECT stamp,lines FROM production_state WHERE owner=?",(owner,)).fetchone()
        stamp = max(stamp,row[0])
    stocks = dict(db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(owner,)))
    tech = [r[0] for r in db.execute("SELECT tech FROM technologies WHERE owner=?",(owner,))]
    damage = damage_intervals(db,owner,row[0] if row else stamp)
    lines = projected_lines(row,stocks,stamp,damage)
    if layout is not None:
        eligible = [b["kind"] for b in layout["buildings"] if b["powered"]]
        for resource,(facility,_) in LINES.items():
            line = lines[resource]
            free = line["free"]
            line["sources"] = [b["id"] for b in layout["buildings"] if b["powered"] and b["kind"] == facility]
            line["speed"] = 2 if resource=="structure" and "casting" in tech else 1
            line["facilities"] = len(line["sources"]) - sum(d["building"] in line["sources"] and
                    d["started"] <= stamp < d["due"] for d in damage)
            line["rate"] = line["facilities"] * line["speed"]
            line["capacity"] = DEPOT[resource]*(1+eligible.count("warehouse"))
            if line["pending"] >= min(free,line["capacity"]):
                line["pending"] = min(free,line["capacity"])
                line["progress"] = 0
    db.execute("INSERT OR REPLACE INTO production_state VALUES (?,?,?)",(owner,stamp,json.dumps(lines)))
    return {"lines":lines,"tech":tech,"research":RESEARCH,"offline_seconds":OFFLINE_SECONDS,
            "stations":{b["id"]:b["power_reason"] for b in (layout or {}).get("buildings",[]) if b["kind"]=="research_station"},
            "drill_recipe":drill_recipe(db, owner)}


def damage_intervals(db,owner,since):
    return db.execute("SELECT building,started,due FROM facility_damage WHERE owner=? AND due>?",
                      (owner,since)).fetchall()


def handle(db,owner,route,method,fields,layout):
    state = update(db,owner,layout)
    if route == "/v1/base/production" and method == "GET":
        return {"production":state}
    action = route.rsplit("/",1)[1]
    required = {"key","tech"} if action == "research" else {"key"}
    if action == "research" and fields.get("tech") == "optics":
        required.add("station")
    if method != "POST" or route not in ("/v1/base/production/claim","/v1/base/production/research") or fields.keys() != required:
        raise Fault(400,"invalid_parameters")
    key = fields["key"]
    if not isinstance(key,str) or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_key")
    signature = json.dumps([route,fields],sort_keys=True)
    receipt = inventory.previous(db,owner,key,signature)
    if receipt:
        return {"production":state,"receipt":receipt}
    extras = {}
    if action == "research":
        tech = fields["tech"]
        if not isinstance(tech,str) or tech not in RESEARCH:
            raise Fault(400,"unknown_tech")
        if tech in state["tech"]:
            raise Fault(409,"already_researched")
        if tech == "optics":
            station = fields["station"]
            if not isinstance(station,str) or station not in state["stations"]:
                raise Fault(409,"research_station_missing")
            if state["stations"][station] != "powered":
                raise Fault(409,"research_station_unpowered")
        elif not state["lines"]["components"]["facilities"]:
            raise Fault(409,"research_requires_workshop")
        changes = inventory.apply_stock(db,owner,RESEARCH[tech])
        if tech == "drill":
            unlock_drill(db, owner)
        else:
            db.execute("INSERT INTO technologies VALUES (?,?)",(owner,tech))
            if tech == "optics":
                db.execute("INSERT INTO blueprints VALUES (?, 'visor')",(owner,))
                extras["station"] = fields["station"]
        extras["tech"] = tech
    else:
        earned = {k:v["pending"] for k,v in state["lines"].items() if v["pending"]}
        if not earned:
            raise Fault(409,"nothing_to_claim")
        for line in state["lines"].values():
            line["pending"] = 0
        db.execute("UPDATE production_state SET lines=? WHERE owner=?",(json.dumps(state["lines"]),owner))
        changes = inventory.apply_stock(db,owner,earned)
        extras["credited_at"] = now()
    receipt = inventory.record(db,owner,key,action,signature,changes,**extras)
    return {"receipt":receipt,"production":update(db,owner,layout)}
