"""Server-clock robot damage, repair, salvage and non-transferable recovery assistance."""
import hashlib
import json
import re
import time
import uuid

import inventory
import private_base
import workshop
from inventory import Fault

PRICE = {"structure":-1,"components":-1}
REPAIR_SECONDS = 30
RELIEF_INTERVAL = 600


def create_tables(db):
    db.execute("""CREATE TABLE robot_condition(robot TEXT PRIMARY KEY REFERENCES robots(id),
        state TEXT NOT NULL DEFAULT 'ready',due INTEGER,assisted INTEGER NOT NULL DEFAULT 0,aid_repair_battle TEXT)""")
    db.execute("""CREATE TABLE repair_log(id INTEGER PRIMARY KEY,robot TEXT NOT NULL REFERENCES robots(id),
        kind TEXT NOT NULL,at INTEGER NOT NULL,reference TEXT NOT NULL,UNIQUE(robot,kind,reference))""")
    db.execute("CREATE TABLE relief(owner TEXT PRIMARY KEY REFERENCES accounts(id),next_at INTEGER,voucher INTEGER NOT NULL DEFAULT 0)")
    db.execute("CREATE TABLE relief_parts(id TEXT PRIMARY KEY REFERENCES parts(id))")


def condition(db,robot):
    row = db.execute("SELECT * FROM robot_condition WHERE robot=?", (robot,)).fetchone()
    return dict(row) if row else {"robot":robot,"state":"ready","due":None,"assisted":0,"aid_repair_battle":None}


def log(db,robot,kind,reference,at=None):
    db.execute("INSERT OR IGNORE INTO repair_log(robot,kind,at,reference) VALUES (?,?,?,?)",
               (robot,kind,int(time.time()) if at is None else at,reference))


def damage(db,robot,battle,*,defensive_aid=False):
    db.execute("""INSERT INTO robot_condition(robot,state,aid_repair_battle) VALUES (?,'damaged',?)
        ON CONFLICT(robot) DO UPDATE SET state='damaged',aid_repair_battle=excluded.aid_repair_battle
        WHERE state='ready'""",(robot,battle if defensive_aid else None))
    log(db,robot,"combat_damage",battle)


def complete_due(db, owner=None):
    query = """SELECT c.robot,c.due,r.assignment FROM robot_condition c JOIN robots r ON r.id=c.robot
               WHERE c.state='repairing' AND c.due<=?"""
    args = (int(time.time()),)
    if owner is not None:
        query += " AND r.owner=?"
        args += (owner,)
    rows = db.execute(query,args).fetchall()
    for row in rows:
        db.execute("UPDATE robot_condition SET state='ready',due=NULL WHERE robot=?", (row["robot"],))
        db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?", (row["robot"],row["assignment"]))
        log(db,row["robot"],"workshop_repair",row["assignment"],row["due"])


def entry_quote(db,owner):
    row = db.execute("""SELECT amount, EXISTS(SELECT 1 FROM relief WHERE owner=? AND voucher=1)
                        FROM stocks WHERE owner=? AND resource='energy'""",(owner,owner)).fetchone()
    energy, voucher = row[0], bool(row[1])
    source = "energy" if energy > 0 else "voucher" if voucher else "unavailable"
    return {"source":source, "energy":energy, "voucher":voucher}


def consume_entry_energy(db,owner):
    source = entry_quote(db,owner)["source"]
    if source == "energy":
        return inventory.apply_stock(db,owner,{"energy":-1})
    if source == "voucher":
        db.execute("UPDATE relief SET voucher=0 WHERE owner=?",(owner,))
        return {}
    raise Fault(409,"insufficient_stock")


def bay_usage(db, owner):
    row = db.execute("SELECT layout FROM bases WHERE owner=?", (owner,)).fetchone()
    buildings = private_base.check(json.loads(row[0]))["buildings"] if row else []
    powered = sum(b["kind"] == "repair" and b["powered"] for b in buildings)
    capacity = 2 if powered else 1
    used = db.execute("""SELECT COUNT(*) FROM robot_condition c JOIN robots r ON r.id=c.robot
                         WHERE r.owner=? AND c.state='repairing'""", (owner,)).fetchone()[0]
    return {"capacity":capacity, "used":used, "available":max(0, capacity-used), "powered_stations":powered}


def repair_price(aid_repair_battle):
    return {"components":-1} if aid_repair_battle else PRICE


def repair_stock(db, owner):
    rows = db.execute("SELECT resource,amount FROM stocks WHERE owner=?", (owner,))
    return {resource: amount for resource, amount in rows if resource in PRICE}


def bay_view(db, owner):
    robots = [dict(row) for row in db.execute("""SELECT r.id,r.name,r.task,c.state,c.due,c.aid_repair_battle
              FROM robots r JOIN robot_condition c ON c.robot=r.id
              WHERE r.owner=? AND c.state IN ('damaged','repairing') ORDER BY c.due IS NULL,c.due,r.rowid""", (owner,))]
    for robot in robots:
        robot["price"] = repair_price(robot["aid_repair_battle"])
    return dict(bay_usage(db, owner), robots=robots, server_now=int(time.time()), price=PRICE,
                repair_stock=repair_stock(db, owner), seconds=REPAIR_SECONDS)


def snapshot(db,owner,robot):
    row = db.execute("SELECT id,name,task FROM robots WHERE id=? AND owner=?",(robot,owner)).fetchone()
    if not row:
        raise Fault(404,"unknown_robot")
    c = condition(db,robot)
    reason = ""
    if c["state"]=="retired":
        reason="robot_retired"
    elif c["state"]=="repairing":
        reason="repair_in_progress"
    elif row["task"]:
        reason="robot_busy"
    elif db.execute("""SELECT COUNT(*) FROM robots r LEFT JOIN robot_condition c ON c.robot=r.id
        WHERE r.owner=? AND COALESCE(c.state,'ready')!='retired'""",(owner,)).fetchone()[0]<=1:
        reason="keep_last_robot"
    mounts = workshop.fit(db,robot)
    weapon = mounts.get("weapon",{})
    return_part = weapon if weapon.get("definition") == "chimney_arm" else None
    if return_part and not reason:
        used = db.execute("SELECT COUNT(*) FROM ("+inventory.FREE_PARTS+")",(owner,)).fetchone()[0]
        if used >= inventory.PART_CAP:
            reason = "parts_full"
    stock = repair_stock(db,owner)
    stored = stock["structure"]
    payout = {} if reason or c["assisted"] or stored >= inventory.STOCK["structure"][1] else {"structure":1}
    quote = json.dumps([robot,c["state"],row["task"],mounts,reason,payout],sort_keys=True)
    recent = [dict(r) for r in db.execute("SELECT kind,at,reference FROM repair_log WHERE robot=? ORDER BY id DESC LIMIT 12",(robot,))]
    available = db.execute("SELECT next_at,voucher FROM relief WHERE owner=?",(owner,)).fetchone()
    return {**c,"price":repair_price(c["aid_repair_battle"]),"repair_stock":stock,"seconds":REPAIR_SECONDS,"recent":recent,"bays":bay_usage(db,owner),
            "can_recycle":not reason,"recycle_reason":reason,"return":payout,"recovered_part":return_part,
            "quote":hashlib.sha256(quote.encode()).hexdigest(),
            "voucher":bool(available and available["voucher"]),"relief_at":available["next_at"] if available else 0}


def operate(db,owner,robot,action,fields):
    key = fields.get("key")
    expected = {"key","quote","confirmed"} if action=="recycle" else {"key"}
    if fields.keys() != expected or not isinstance(key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_parameters")
    sign = json.dumps([robot,action,fields],sort_keys=True)
    old = inventory.previous(db,owner,key,sign)
    if old:
        return old
    view = snapshot(db,owner,robot)
    if action=="recycle" and not view["can_recycle"]:
        raise Fault(409,view["recycle_reason"])
    task = db.execute("SELECT task FROM robots WHERE id=?",(robot,)).fetchone()[0]
    if task or view["state"] in ("retired","repairing"):
        raise Fault(409,"unit_unavailable")
    changes = {}
    if action == "repair":
        if view["state"] != "damaged":
            raise Fault(409,"repair_not_needed")
        if view["bays"]["available"] == 0:
            raise Fault(409,"repair_queue_full")
        changes = inventory.apply_stock(db,owner,view["price"])
        assignment = uuid.uuid4().hex
        db.execute("UPDATE robots SET task='repair',assignment=? WHERE id=?",(assignment,robot))
        db.execute("UPDATE robot_condition SET state='repairing',aid_repair_battle=NULL,due=? WHERE robot=?",(int(time.time())+REPAIR_SECONDS,robot))
        log(db,robot,"repair_started",assignment)
    elif action == "recycle":
        if fields["confirmed"] is not True or fields["quote"] != view["quote"]:
            raise Fault(409,"recycle_preview_changed")
        changes = inventory.apply_stock(db,owner,view["return"])
        if view["recovered_part"]:
            db.execute("DELETE FROM mounts WHERE robot=? AND item=?",(robot,view["recovered_part"]["id"]))
        db.execute("""INSERT INTO robot_condition(robot,state) VALUES (?,'retired')
            ON CONFLICT(robot) DO UPDATE SET state='retired',aid_repair_battle=NULL""",(robot,))
        log(db,robot,"recycled",key)
    elif action == "relief":
        _relieve(db,owner,robot,view)
        log(db,robot,"relief",key)
    else:
        raise Fault(404,"unknown_route")
    return inventory.record(db,owner,key,action,sign,changes,robot=robot)


def _relieve(db,owner,robot,view):
    if int(time.time()) < view["relief_at"]:
        raise Fault(409,"relief_cooldown")
    fleet = workshop.owned_robots(db,owner)
    if any(r["task"] for r in fleet):
        raise Fault(409,"finish_active_tasks")
    stock = dict(db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(owner,)))
    ready = workshop.deployment_for(fleet)["units"]
    can_fuel = stock["energy"] > 0 or view["voucher"]
    if ready:
        if can_fuel or robot not in [u["chassis"] for u in ready]:
            raise Fault(409,"relief_not_needed")
    elif any(r["state"]=="damaged" and workshop.complete(r["slots"])
             and all(stock[k]>=-delta for k,delta in repair_price(condition(db,r["id"])["aid_repair_battle"]).items())
             for r in fleet):
        raise Fault(409,"use_workshop_repair")
    elif not ready and stock["structure"]>=3 and stock["components"]>=1 and stock["energy"]>=1 and len(fleet)<workshop.ROBOT_CAP:
        raise Fault(409,"use_workshop_build")
    if not ready:
        mounted = workshop.fit(db,robot)
        definitions = dict(workshop.BASE)
        definitions.update({s:p["definition"] for s,p in mounted.items()})
        try:
            workshop.validate_fit(definitions,chassis=workshop.robot_chassis(db,robot))
        except Fault:
            if "core" in mounted:
                raise
            definitions["core"] = "reinforced_boiler"
            workshop.validate_fit(definitions,chassis=workshop.robot_chassis(db,robot))
        for slot,definition in definitions.items():
            if slot in mounted:
                continue
            item = workshop.insert_part(db,owner,robot,slot,definition)
            db.execute("INSERT INTO relief_parts VALUES (?)",(item,))
        db.execute("""INSERT INTO robot_condition(robot,state,assisted) VALUES (?,'ready',1)
            ON CONFLICT(robot) DO UPDATE SET state='ready',assisted=1,aid_repair_battle=NULL""",(robot,))
    db.execute("""INSERT INTO relief VALUES (?,?,?) ON CONFLICT(owner) DO UPDATE SET next_at=excluded.next_at,
        voucher=MAX(voucher,excluded.voucher)""",(owner,int(time.time())+RELIEF_INTERVAL,int(not can_fuel)))
