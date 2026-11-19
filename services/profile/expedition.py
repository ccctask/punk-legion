"""Solo expedition persistence; combat and reports are accepted only from the Godot authority."""
import json
import hashlib
import os
from pathlib import Path
import re
import secrets
import time
import uuid

import inventory
import production
from inventory import Fault
import service_record
import recovery
import pump
import factory
import armory
import workshop

TTL = 1200
CAP = 420


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS expeditions(id TEXT PRIMARY KEY,owner TEXT REFERENCES accounts(id),
        secret TEXT NOT NULL,expires INTEGER NOT NULL,deployment TEXT NOT NULL,tickets TEXT NOT NULL,
        result TEXT,receipt TEXT,entry_receipt TEXT NOT NULL REFERENCES receipts(id))""")
    db.execute("CREATE UNIQUE INDEX IF NOT EXISTS active_expedition ON expeditions(owner) WHERE result IS NULL")
    db.execute("""CREATE INDEX IF NOT EXISTS personal_expedition_history ON expeditions(owner,json_extract(receipt,'$.debrief.activity'))
                  WHERE result IS NOT NULL""")
    db.execute("""CREATE INDEX IF NOT EXISTS won_rustrail_by_owner ON expeditions(owner)
                  WHERE result='win' AND receipt IS NOT NULL""")
    db.execute("CREATE TABLE IF NOT EXISTS expedition_loot(owner TEXT PRIMARY KEY,wins INTEGER,pity INTEGER)")
    db.execute("CREATE TABLE IF NOT EXISTS expedition_first_parts(owner TEXT PRIMARY KEY REFERENCES accounts(id))")
    db.execute("""CREATE UNIQUE INDEX IF NOT EXISTS daily_quick_salvage ON receipts(owner,json_extract(body,'$.utc_day'))
                  WHERE operation='quick_salvage'""")
    db.execute("CREATE TABLE IF NOT EXISTS expedition_deliveries(mission TEXT PRIMARY KEY, signature TEXT NOT NULL)")


def public(row):
    return {"id":row["id"],"secret":row["secret"],"expires":row["expires"],
            "location":json.loads(row["deployment"]).get("location","rustrail")} if row else None


def party_seat(db,mission):
    return (db.execute("SELECT 1 FROM sqlite_master WHERE name='party_members'").fetchone() and
            db.execute("SELECT 1 FROM party_members WHERE mission=?",(mission,)).fetchone())


def quick_quote(db,owner,ready):
    day=time.strftime("%Y-%m-%d",time.gmtime(time.time()))
    used=db.execute("""SELECT 1 FROM receipts WHERE owner=? AND operation='quick_salvage'
                       AND json_extract(body,'$.utc_day')=?""",(owner,day)).fetchone()
    unlocked=db.execute("SELECT 1 FROM expeditions WHERE owner=? AND result='win' AND receipt IS NOT NULL AND id NOT IN (SELECT mission FROM pump_entries) AND id NOT IN (SELECT mission FROM factory_entries) AND id NOT IN (SELECT mission FROM armory_entries) LIMIT 1",(owner,)).fetchone()
    stocks=dict(db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(owner,)))
    gain=min(2,inventory.STOCK["structure"][1]-stocks["structure"])
    reason=""
    if not unlocked:
        reason="first_win_required"
    elif used:
        reason="daily_used"
    elif gain<=0:
        reason="storage_full"
    elif stocks["energy"]<1:
        reason="energy_required"
    elif not ready:
        reason="unit_unavailable"
    return dict(unlocked=bool(unlocked),used=bool(used),utc_day=day,energy_cost=1,
                structure_gain=gain,available=not reason,reason=reason)


def quick_salvage(db,owner,fields):
    if (fields.keys()!={"key","robot","utc_day","structure_gain"}
        or not isinstance(fields["key"],str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",fields["key"])
        or not isinstance(fields["robot"],str) or not isinstance(fields["utc_day"],str)
        or type(fields["structure_gain"]) is not int):
        raise Fault(400,"invalid_parameters")
    signature=json.dumps(["quick_salvage",fields],sort_keys=True)
    previous=inventory.previous(db,owner,fields["key"],signature)
    if previous:
        return previous
    robots=workshop.owned_robots(db,owner)
    eligible=any(r["id"]==fields["robot"] and r["task"] is None and r["state"]=="ready" and workshop.complete(r["slots"]) for r in robots)
    quote=quick_quote(db,owner,eligible)
    if not quote["available"]:
        raise Fault(409,quote["reason"])
    if fields["utc_day"]!=quote["utc_day"] or fields["structure_gain"]!=quote["structure_gain"]:
        raise Fault(409,"quote_changed")
    changes=inventory.apply_stock(db,owner,{"energy":-quote["energy_cost"],"structure":quote["structure_gain"]})
    return inventory.record(db,owner,fields["key"],"quick_salvage",signature,changes,robot=fields["robot"],utc_day=quote["utc_day"])


def recent_personal_report(db,owner,activity):
    row=db.execute("""SELECT receipt FROM expeditions WHERE owner=? AND result IS NOT NULL
                      AND json_extract(receipt,'$.debrief.activity')=? ORDER BY rowid DESC LIMIT 1""",(owner,activity)).fetchone()
    return json.loads(row[0]) if row else {}


def ready_to_deploy(robot):
    return robot["task"] is None and robot["state"]=="ready" and workshop.complete(robot["slots"])


def overview(db,owner):
    robots=workshop.owned_robots(db,owner)
    active=db.execute("SELECT * FROM expeditions WHERE owner=? AND result IS NULL",(owner,)).fetchone()
    loot=db.execute("SELECT wins,pity FROM expedition_loot WHERE owner=?",(owner,)).fetchone()
    result = {"active":public(active) if active is None or not party_seat(db,active["id"]) else None,"robots":[{"id":r["id"],"name":r["name"],"task":r["task"],
            "ready":ready_to_deploy(r),
            "points":workshop.robot_points(r),"chassis":r["chassis"],"weapon":r["slots"].get("weapon",{}).get("definition","")} for r in robots],
            "last":recent_personal_report(db,owner,"solo"), "wins":loot[0] if loot else 0,"pity":loot[1] if loot else 0,
            "drill_recipe":production.drill_recipe(db, owner),
            "pending_drill":bool(db.execute("SELECT 1 FROM expedition_first_parts WHERE owner=?",(owner,)).fetchone())}
    result["old_armory"] = armory.quote(db,owner)
    result["old_armory"]["last"] = recent_personal_report(db,owner,armory.LOCATION)
    result["quick_salvage"]=quick_quote(db,owner,any(r["ready"] for r in result["robots"]))
    return result


def start(db,owner,fields):
    key=fields.get("key")
    is_armory = "location" in fields and fields["location"] == armory.LOCATION
    expected = {"key","robots","location"} if is_armory else {"key","robots"}
    if fields.keys()!=expected or not isinstance(key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_parameters")
    signature=json.dumps(["expedition",fields],sort_keys=True)
    prior=inventory.previous(db,owner,key,signature)
    if prior:
        return prior
    if db.execute("SELECT 1 FROM expeditions WHERE owner=? AND result IS NULL",(owner,)).fetchone():
        raise Fault(409,"expedition_active")
    if is_armory and not armory.quote(db,owner)["unlocked"]:
        raise Fault(403,"requires_south_land")
    owned=workshop.owned_robots(db,owner)
    deployment=workshop.deployment_for(owned,fields["robots"])
    deployment["names"]={r["id"]:r["name"] for r in owned if r["id"] in fields["robots"]}
    if is_armory:
        deployment["location"] = armory.LOCATION
    changes=recovery.consume_entry_energy(db,owner)
    mission=uuid.uuid4().hex
    tickets={rid:service_record.start_mission(db,owner,rid,mission) for rid in fields["robots"]}
    # Energy is always spent when available; only the voucher path spends no stock.
    entry=inventory.record(db,owner,key,"expedition_start",signature,changes,mission=mission,
                           vouchers_used=int("energy" not in changes))
    db.execute("INSERT INTO expeditions VALUES (?,?,?,?,?,?,NULL,NULL,?)",(mission,owner,secrets.token_urlsafe(32),
        int(time.time())+TTL,json.dumps(deployment),json.dumps(tickets),entry["id"]))
    if is_armory:
        db.execute("INSERT INTO armory_entries VALUES (?,?)",(mission,factory.day()))
    return entry


def personal_debrief(db,mission,activity,outcome,cause,participated,credited,reports):
    # Both the immutable departure receipt and each booked sortie belong to this personal mission.
    entry=json.loads(db.execute("""SELECT body FROM receipts WHERE id=? AND owner=? AND operation='expedition_start'""",
        (mission["entry_receipt"],mission["owner"])).fetchone()[0])
    if entry["mission"]!=mission["id"]:
        raise Fault(409,"departure_receipt_mismatch")
    resources={}
    for name in inventory.STOCK:
        cost=-entry["changes"].get(name,0)
        received=credited.get(name,0)
        resources[name]=dict(credited=received,cost=cost,net=received-cost)
    robots=[]
    repair_total=dict.fromkeys(recovery.PRICE,0)
    if participated:
        for robot,ticket in json.loads(mission["tickets"]).items():
            row=db.execute("""SELECT s.name,
                       EXISTS(SELECT 1 FROM repair_log l WHERE l.robot=s.robot
                              AND l.kind='combat_damage' AND l.reference=s.battle) AS damaged
                       FROM robot_sorties s JOIN admissions a ON a.ticket=s.ticket
                       WHERE a.owner=? AND s.ticket=? AND s.robot=? AND s.battle=? AND s.result_digest IS NOT NULL""",
                       (mission["owner"],ticket,robot,mission["id"])).fetchone()
            if not row:
                raise Fault(409,"report_identity")
            price={r:-delta for r,delta in recovery.PRICE.items()} if row["damaged"] else {}
            for r,quantity in price.items():
                repair_total[r]+=quantity
            robots.append(dict(id=robot,name=row["name"],kills=sum(e["kind"]=="kill" for e in reports[robot]),
                               repair_output=sum(e["amount"] for e in reports[robot] if e["kind"]=="field_repair_output"),
                               damaged=bool(row["damaged"]),repair_cost=price))
    return dict(mission=mission["id"],activity=activity,cause=cause,reason=outcome if participated else "not_deployed",
                participated=participated,resources=resources,vouchers_used=entry["vouchers_used"],robots=robots,
                repair_total=repair_total,entry_receipt=entry["id"])



def settle(db,row,outcome,collected,reports,seconds,commanded=None,participated=True,cause=None):
    if commanded is not None and type(commanded) is not bool:
        raise Fault(400,"invalid_command_proof")
    tickets=json.loads(row["tickets"])
    if not isinstance(reports,dict) or reports.keys()!=tickets.keys() or type(seconds) not in (int,float) or not 0<=seconds<=CAP or outcome not in ("win","defeat","retreat","expired"):
        raise Fault(400,"invalid_expedition_result")
    if not isinstance(collected,list) or not all(isinstance(i,str) for i in collected) or len(collected)!=len(set(collected)):
        raise Fault(400,"invalid_salvage")
    for values in reports.values():
        if not isinstance(values,list) or len(values)>254 or any(not isinstance(e,dict) or type(e.get("at")) not in (int,float) or type(e.get("amount")) not in (int,float) for e in values):
            raise Fault(400,"invalid_events")
    pump_entry = db.execute("SELECT day FROM pump_entries WHERE mission=?",(row["id"],)).fetchone()
    factory_entry = db.execute("SELECT day FROM factory_entries WHERE mission=?",(row["id"],)).fetchone()
    armory_entry = db.execute("SELECT day FROM armory_entries WHERE mission=?",(row["id"],)).fetchone()
    if armory_entry:
        if seconds > 300 or set(collected) - {"armory_cache"} or (outcome=="win" and collected!=["armory_cache"]):
            raise Fault(400,"invalid_armory_result")
    elif set(collected)-{"scrap","fuel","coil"}:
        raise Fault(400,"invalid_salvage")
    if factory_entry and (collected or seconds>300):
        raise Fault(400,"invalid_factory_result")
    if pump_entry and (collected or seconds>300):
        raise Fault(400,"invalid_pump_result")
    if type(participated) is not bool or (not participated and (outcome not in ('retreat','expired') or seconds or collected or commanded or any(reports.values()))):
        raise Fault(400,'invalid_participation')
    allowed=("not_deployed",)
    if participated:
        allowed={"win":("factory_gate",) if factory_entry else ("extracted",),"retreat":("voluntary_retreat",),
                 "expired":("session_expired",),"defeat":("defeat","squad_disabled")}[outcome]
    timed_activity=bool(pump_entry or factory_entry or armory_entry)
    if participated and seconds >= (300 if timed_activity else CAP) and outcome == ("expired" if timed_activity else "defeat"):
        allowed+=("time_limit",)
    if cause is None:
        cause=allowed[0]
    if cause not in allowed:
        raise Fault(400,"invalid_terminal_cause")
    # Decode numeric event values consistently across JSON emitted by Godot and Python.
    normalized={k:[dict(e,at=float(e["at"]),amount=float(e["amount"])) for e in values] for k,values in reports.items()}
    signature=hashlib.sha256(json.dumps([outcome,collected,normalized,float(seconds),participated,cause],sort_keys=True).encode()).hexdigest()
    if row["result"]:
        prior=db.execute("SELECT signature FROM expedition_deliveries WHERE mission=?",(row["id"],)).fetchone()
        if (timed_activity or row["result"]!="expired") and prior and prior[0]!=signature:
            raise Fault(409,"result_conflict")
        return json.loads(row["receipt"])
    owner=row["owner"]
    for robot,ticket in tickets.items():
        if participated:
            service_record.finish_mission(db,ticket,row["id"],outcome,reports[robot],seconds)
        else:
            service_record.release_unplayed(db,ticket,row["id"])
    if timed_activity:
        if armory_entry:
            module, activity, family, entry = armory, armory.LOCATION, "armory", armory_entry
        elif factory_entry:
            module, activity, family, entry = factory, factory.ACTIVITY, "factory", factory_entry
        else:
            module, activity, family, entry = pump, "pump_ruin", "pump", pump_entry
        reward=module.reward(db,owner,row["id"],entry["day"],outcome,participated)
        changes=reward.pop("changes")
        receipt=inventory.record(db,owner,family+"/"+row["id"],family+"_result",outcome,changes,mission=row["id"],
              activity=activity,outcome=outcome,participated=participated,seconds=seconds,**reward,
              debrief=personal_debrief(db,row,activity,outcome,cause,participated,changes,reports))
        db.execute("UPDATE expeditions SET result=?,receipt=? WHERE id=?",(outcome,json.dumps(receipt),row["id"]))
        db.execute("INSERT INTO expedition_deliveries VALUES (?,?)",(row["id"],signature))
        return receipt
    drops={}
    if outcome in ("win","retreat"):
        for item in collected:
            resource={"scrap":"structure","fuel":"energy","coil":"components"}[item]
            drops[resource]=drops.get(resource,0)+1
    part=None
    first=False
    rare=False
    converted=False
    unlocked_now = False
    if outcome=="win":
        old=db.execute("SELECT wins,pity FROM expedition_loot WHERE owner=?",(owner,)).fetchone()
        wins,pity=tuple(old) if old else (0,0)
        first=wins==0
        rare=pity>=2 or (not first and secrets.randbelow(5)==0)
        definition="reinforced_boiler" if rare else ("drill" if first else "cannon")
        free=db.execute("SELECT COUNT(*) FROM ("+workshop.FREE+")",(owner,)).fetchone()[0]
        if free<inventory.PART_CAP:
            part={"id":uuid.uuid4().hex,"definition":definition}
            db.execute("INSERT INTO parts VALUES (?,?,?)",(part["id"],owner,definition))
        elif first:
            db.execute("INSERT OR IGNORE INTO expedition_first_parts VALUES (?)",(owner,))
        else:
            converted=True
        db.execute("INSERT OR REPLACE INTO expedition_loot VALUES (?,?,?)",(owner,wins+1,0 if rare and part else min(2,pity+1)))
        if wins+1 == production.DRILL_WINS:
            unlocked_now = production.unlock_drill(db, owner)
        drops["structure"]=drops.get("structure",0)+(3 if first else 2)+(1 if converted else 0)
    changes=inventory.apply_stock(db,owner,drops)
    receipt=inventory.record(db,owner,"solo/"+row["id"],"expedition_result",outcome,changes,mission=row["id"],
        debrief=personal_debrief(db,row,"party" if party_seat(db,row["id"]) else "solo",outcome,cause,participated,changes,reports),
        outcome=outcome,participated=participated,seconds=seconds,part=part,first=first,rare=bool(rare and part),converted=converted,
        pending_drill=bool(first and part is None),nodes=collected,credited_at=int(time.time()),
        drill_recipe=dict(production.drill_recipe(db, owner), unlocked_now=unlocked_now),
        commanded=commanded if commanded is not None else bool(collected and not party_seat(db,row['id'])))
    db.execute("UPDATE expeditions SET result=?,receipt=? WHERE id=?",(outcome,json.dumps(receipt),row["id"]))
    if outcome == "win":
        import private_base
        private_base.on_rustrail_win(db, owner)
    db.execute("INSERT INTO expedition_deliveries VALUES (?,?)",(row["id"],signature))
    return receipt


def expire(db):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE name='expeditions'").fetchone():
        return
    due=db.execute("SELECT * FROM expeditions WHERE expires<=? AND result IS NULL",(int(time.time()),)).fetchall()
    if not due:
        return
    schema(db)
    for row in due:
        if party_seat(db,row['id']):
            continue
        # The Godot authority writes terminal evidence before reporting success to the player.
        # Its volume is mounted read-only into this service; clients cannot supply these files.
        directory=os.environ.get("SOLO_SPOOL_DIR")
        checkpoint={}
        if directory:
            final=Path(directory)/(row["id"]+".result.json")
            progress=Path(directory)/(row["id"]+".progress.json")
            if final.is_file():
                record=json.loads(final.read_text(encoding="utf-8"))
                payload=record["result"]
                if payload["id"]==row["id"] and record["finished_at"]<=row["expires"]:
                    settle(db,row,payload["outcome"],payload["nodes"],payload["reports"],payload["seconds"],payload.get("commanded"),cause=payload.get("cause"))
                    continue
            if progress.is_file():
                checkpoint=json.loads(progress.read_text(encoding="utf-8"))
        reports=checkpoint.get("reports",{r:[] for r in json.loads(row["tickets"])})
        settle(db,row,"expired",[],reports,checkpoint.get("seconds",0),checkpoint.get("commanded"),participated=checkpoint.get("id")==row["id"])


def internal(db,route,fields):
    schema(db)
    mission=fields.get("id")
    if not isinstance(mission,str):
        raise Fault(400,"invalid_mission")
    row=db.execute("SELECT * FROM expeditions WHERE id=?",(mission,)).fetchone()
    if not row or party_seat(db,mission):
        raise Fault(404,"unknown_mission")
    if route.endswith("/open"):
        if fields.keys()!={"id","secret"} or not isinstance(fields["secret"],str) or not secrets.compare_digest(row["secret"],fields["secret"]):
            raise Fault(403,"invalid_mission")
        if row["result"]:
            return {"receipt":json.loads(row["receipt"])}
        return {"deployment":json.loads(row["deployment"]),"expires":row["expires"]}
    if fields.keys()-{"commanded","cause"}!={"id","outcome","nodes","reports","seconds"} or not isinstance(fields["reports"],dict):
        raise Fault(400,"invalid_parameters")
    return {"receipt":settle(db,row,fields["outcome"],fields["nodes"],fields["reports"],fields["seconds"],fields.get("commanded"),cause=fields.get("cause"))}


def handle(db,owner,method,route,fields):
    schema(db)
    if method=="GET" and route=="/v1/expedition":
        return {"expedition":overview(db,owner)}
    if method=="POST" and route=="/v1/expedition/start":
        receipt=start(db,owner,fields)
        return {"expedition":overview(db,owner),"receipt":receipt}
    if method=="POST" and route=="/v1/expedition/quick-salvage":
        receipt=quick_salvage(db,owner,fields)
        return {"expedition":overview(db,owner),"receipt":receipt}
    if method=="POST" and route=="/v1/expedition/claim-armory":
        receipt=armory.claim(db,owner,fields)
        return {"expedition":overview(db,owner),"receipt":receipt}
    if method=="POST" and route=="/v1/expedition/claim-first":
        key=fields.get("key")
        if fields.keys()!={"key"} or not isinstance(key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",key):
            raise Fault(400,"invalid_parameters")
        receipt=inventory.previous(db,owner,key,"claim_first_drill")
        if not receipt:
            if not db.execute("DELETE FROM expedition_first_parts WHERE owner=?",(owner,)).rowcount:
                raise Fault(409,"nothing_to_claim")
            if db.execute("SELECT COUNT(*) FROM ("+workshop.FREE+")",(owner,)).fetchone()[0]>=inventory.PART_CAP:
                raise Fault(409,"parts_full")
            rid=uuid.uuid4().hex
            db.execute("INSERT INTO parts VALUES (?,?,'drill')",(rid,owner))
            receipt=inventory.record(db,owner,key,"expedition_claim","claim_first_drill",{},part={"id":rid,"definition":"drill"})
        return {"expedition":overview(db,owner),"receipt":receipt}
    raise Fault(404,"unknown_route")
