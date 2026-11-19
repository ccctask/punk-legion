"""Account-owned robot deployment snapshots, settlement proofs and career totals."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import time
import uuid

import inventory
import recovery
import workshop
from inventory import Fault


def create_tables(db):
    db.execute("""CREATE TABLE robot_sorties(ticket TEXT PRIMARY KEY REFERENCES admissions(ticket),
        robot TEXT NOT NULL REFERENCES robots(id), snapshot TEXT, name TEXT NOT NULL,
        battle TEXT, outcome TEXT, result_digest TEXT, expires INTEGER, void_reason TEXT,
        UNIQUE(robot,battle))""")
    db.execute("CREATE INDEX sortie_expiration ON robot_sorties(expires) WHERE result_digest IS NULL AND void_reason IS NULL")
    db.execute("""CREATE TABLE robot_career(robot TEXT PRIMARY KEY REFERENCES robots(id),
        battles INTEGER NOT NULL, kills INTEGER NOT NULL, output REAL NOT NULL)""")


def _void(db,row,reason):
    key = "void/"+row["ticket"]
    admission = db.execute("""SELECT body FROM receipts WHERE owner=? AND operation='admit'
        AND json_extract(body,'$.ticket')=?""",(row["owner"],row["ticket"])).fetchone()
    if admission and json.loads(admission["body"])["changes"].get("energy") == -1:
        changes = inventory.apply_stock(db,row["owner"],{"energy":1})
    else:
        db.execute("UPDATE relief SET voucher=1 WHERE owner=?", (row["owner"],))
        changes = {}
    inventory.record(db,row["owner"],key,"admission_refund",reason,changes,reason=reason)
    db.execute("UPDATE robot_sorties SET snapshot=NULL,void_reason=? WHERE ticket=?", (reason,row["ticket"]))
    db.execute("UPDATE admissions SET battle=?,outcome='void' WHERE ticket=?", ("void_"+row["ticket"],row["ticket"]))
    db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?", (row["robot"],row["ticket"]))


def expire(db):
    rows = db.execute("""SELECT s.*,a.owner FROM robot_sorties s JOIN admissions a USING(ticket)
        WHERE s.expires<=? AND s.result_digest IS NULL AND s.void_reason IS NULL""",(int(time.time())-5,)).fetchall()
    for row in rows:
        if not terminal_pending(row):
            _void(db,row,"room_expired")


def terminal_pending(row):
    # Profile reads the room's atomically renamed durable manifest through a read-only mount.
    # Losing access is not evidence that a room crashed without recording a terminal state.
    directory = os.environ.get("ROOM_OUTBOX_DIR")
    if not directory:
        return True
    path = Path(directory)/f"{row['battle']}.json"
    try:
        if not Path(directory).is_dir():
            return True
        manifest = json.loads(path.read_text(encoding="utf8"))
        for entry in manifest.get("deliveries",[]):
            finished = entry.get("finished_at",int(path.stat().st_mtime))
            if (entry.get("ticket") == row["ticket"] and entry.get("battle") == row["battle"]
                and entry.get("report",{}).get("robot") == row["robot"]
                and type(finished) in (int,float) and row["expires"]-600 <= finished <= row["expires"]):
                return True
        return False
    except FileNotFoundError:
        return False
    except (OSError,ValueError,TypeError,AttributeError):
        return True


def cancel(db,owner,robot,ticket):
    if not isinstance(ticket,str):
        return False
    row = db.execute("""SELECT s.*,a.owner FROM robot_sorties s JOIN admissions a USING(ticket)
        WHERE ticket=? AND s.robot=? AND a.owner=?""",(ticket,robot,owner)).fetchone()
    if not row:
        return False
    if row["void_reason"]:
        return True
    if row["battle"] or row["result_digest"]:
        raise Fault(409,"active_sortie")
    _void(db,row,"cancelled")
    return True


def attach(db, owner, ticket, robot):
    if db.execute("SELECT 1 FROM robot_sorties WHERE ticket=?", (ticket,)).fetchone():
        return
    row = db.execute("SELECT name,task FROM robots WHERE id=? AND owner=?", (robot,owner)).fetchone()
    if not row:
        raise Fault(404,"unknown_robot")
    if row["task"]:
        raise Fault(409,"robot_busy")
    hangar = workshop.owned_robots(db,owner)
    workshop.deployment_for(hangar,[robot])
    unit = next(r for r in hangar if r["id"] == robot)
    slots = unit["slots"]
    workshop.validate_fit({s:p["definition"] for s,p in slots.items()},chassis=unit["chassis"])
    snapshot = {"chassis":unit["chassis"],"id":robot, "name":row["name"], "version":workshop.CATALOG["version"], "slots":slots,"hull_number":unit["hull_number"],"paint":unit["paint"],"orders":unit["orders"]}
    db.execute("INSERT INTO robot_sorties(ticket,robot,snapshot,name) VALUES (?,?,?,?)", (ticket,robot,json.dumps(snapshot),row["name"]))
    db.execute("UPDATE robots SET task='expedition',assignment=? WHERE id=?", (ticket,robot))


def deploy(db, fields):
    tickets = fields.get("tickets")
    if not isinstance(tickets,dict) or not tickets or set(tickets)-{"1","2"} or not all(isinstance(t,str) for t in tickets.values()) or len(set(tickets.values())) != len(tickets):
        raise Fault(400,"invalid_tickets")
    snapshots = {}
    existing = set()
    for seat,ticket in tickets.items():
        row = db.execute("SELECT snapshot,result_digest,battle,void_reason FROM robot_sorties WHERE ticket=?", (ticket,)).fetchone()
        if not ticket.startswith("owned_") or not row or row["result_digest"] is not None or row["void_reason"]:
            raise Fault(409,"ticket_unavailable")
        snapshots[seat] = json.loads(row["snapshot"])
        if row["battle"]:
            existing.add(row["battle"])
    if len(existing)>1:
        raise Fault(409,"incompatible_battles")
    battle = next(iter(existing),uuid.uuid4().hex)
    for ticket in tickets.values():
        db.execute("UPDATE robot_sorties SET battle=?,expires=COALESCE(expires,?) WHERE ticket=?", (battle,int(time.time())+600,ticket))
    return {"snapshots":snapshots,"battle":battle}


def settle(db, fields):
    if not isinstance(fields.get("ticket"),str):
        raise Fault(400,"invalid_ticket")
    row = db.execute("SELECT * FROM robot_sorties WHERE ticket=?", (fields["ticket"],)).fetchone()
    base = {k:v for k,v in fields.items() if k != "finished_at"}
    if not row:
        return inventory.settle(db,base)
    if fields["ticket"].startswith("mission_"):
        raise Fault(409,"not_room_admission")
    if row["void_reason"]:
        raise Fault(409,"ticket_void")
    report = fields.get("report")
    if base.keys() != {"ticket","battle","outcome","report"} or fields["battle"] != row["battle"] or not isinstance(report,dict) or report.keys() != {"robot","events"} or report["robot"] != row["robot"]:
        raise Fault(409,"report_identity")
    if "finished_at" in fields:
        stamp = fields["finished_at"]
        if type(stamp) not in (float,int) or not row["expires"]-600 <= stamp <= row["expires"]:
            raise Fault(409,"terminal_outside_lease")
    if row["result_digest"] is not None and _report_digest(report) != row["result_digest"]:
        raise Fault(409,"report_conflict")
    receipt = inventory.settle(db,{k:v for k,v in base.items() if k != "report"})
    if row["result_digest"] is not None:
        return receipt
    _store_report(db,row,fields["battle"],fields["outcome"],report,181)
    return receipt


def start_mission(db,owner,robot,mission):
    """Reserve one owned robot for an expedition. Its caller owns fees, timeout and rewards."""
    if not isinstance(mission,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",mission):
        raise Fault(400,"invalid_mission")
    ticket = "mission_"+mission+"_"+robot
    prior = db.execute("SELECT owner FROM admissions WHERE ticket=?", (ticket,)).fetchone()
    if prior:
        if prior["owner"] != owner:
            raise Fault(404,"unknown_robot")
        return ticket
    db.execute("INSERT INTO admissions VALUES (?,?,?,'mission')",(ticket,owner,ticket))
    attach(db,owner,ticket,robot)
    db.execute("UPDATE robot_sorties SET battle=? WHERE ticket=?", (mission,ticket))
    return ticket


def release_unplayed(db,ticket,mission):
    row = db.execute("SELECT * FROM robot_sorties WHERE ticket=? AND battle=?", (ticket,mission)).fetchone()
    if not row or not ticket.startswith("mission_") or row["result_digest"] is not None:
        raise Fault(409,"report_identity")
    db.execute("UPDATE robot_sorties SET snapshot=NULL,void_reason='not_deployed' WHERE ticket=?", (ticket,))
    db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?", (row["robot"],ticket))


def finish_mission(db,ticket,mission,outcome,events,elapsed=None,*,defensive_aid=False):
    row = db.execute("SELECT * FROM robot_sorties WHERE ticket=? AND battle=?", (ticket,mission)).fetchone()
    if not row or not ticket.startswith("mission_") or row["void_reason"] or outcome not in ("win","loss","draw","defeat","retreat","expired"):
        raise Fault(409,"report_identity")
    robot = row["robot"]
    seconds = elapsed if elapsed is not None else max((e["at"] for e in events),default=0)
    report = {"robot":robot,"events":[{"at":0,"kind":"deployment","actor":robot,"target":"","amount":0},
              *events,{"at":seconds,"kind":"result","actor":robot,"target":outcome,"amount":0}]}
    if row["result_digest"] is not None:
        if _report_digest(report) != row["result_digest"]:
            raise Fault(409,"report_conflict")
        return
    _store_report(db,row,mission,outcome,report,420,defensive_aid=defensive_aid)


def _report_digest(report):
    # Treat equivalent JSON number encodings from multiple transports identically.
    events=report["events"]
    if not isinstance(events,list) or len(events)>256:
        raise Fault(400,"invalid_events")
    canonical=[]
    for event in events:
        if not isinstance(event,dict) or any(type(event.get(k)) not in (float,int) for k in ("at","amount")):
            raise Fault(400,"invalid_event")
        canonical.append(dict(event,at=float(event["at"]),amount=float(event["amount"])))
    encoded=json.dumps(dict(report,events=canonical),sort_keys=True,separators=(",",":"))
    return hashlib.sha256(encoded.encode()).hexdigest()


def _store_report(db,row,battle,outcome,report,time_limit,*,defensive_aid=False):
    events = report["events"]
    if not isinstance(events,list) or not 2 <= len(events) <= 256:
        raise Fault(400,"invalid_events")
    kills = 0
    output = 0
    previous = 0
    robot = row["robot"]
    for index,event in enumerate(events):
        if not isinstance(event,dict) or event.keys() != {"at","kind","actor","target","amount"}:
            raise Fault(400,"invalid_event")
        at,kind,actor,target,amount = (event[k] for k in ("at","kind","actor","target","amount"))
        if not all(isinstance(v,str) and len(v)<=96 for v in (kind,actor,target)) or not all(type(n) in (int,float) and math.isfinite(n) for n in (at,amount)) or at < previous or at > time_limit or not 0 <= amount <= 10000:
            raise Fault(400,"invalid_event")
        previous = at
        if index == 0:
            valid = kind == "deployment" and actor == robot and at == 0
        elif index == len(events)-1:
            valid = kind == "result" and actor == robot and target == outcome
        elif kind in ("kill","assist"):
            valid = actor == robot and bool(target) and amount == 1
        elif kind == "disabled":
            valid = target == robot and bool(actor)
        elif kind == "condition":
            valid = actor == "combat" and target == robot and amount>0
        elif kind=="jam_applied":
            valid=actor==robot and bool(target) and target!=robot and amount==workshop.PARTS["jammer"]["jam_protection"] and json.loads(row["snapshot"])["slots"].get("utility",{}).get("definition")=="jammer"
        elif kind=="jam_received":
            valid=target==robot and bool(actor) and actor!=robot and amount==workshop.PARTS["jammer"]["jam_protection"]
        elif kind == "field_repair_received":
            valid = target == robot and bool(actor) and amount > 0
        elif kind == "field_repair_output":
            valid = (actor == robot and bool(target) and target != robot and amount > 0 and
                     json.loads(row["snapshot"])["slots"].get("utility",{}).get("definition")=="repair_arm")
        else:
            valid = False
        if not valid:
            raise Fault(400,"invalid_event")
        if kind == "kill":
            kills += 1
        elif kind == "field_repair_output":
            output += amount
    db.execute("""UPDATE robot_sorties SET battle=?,outcome=?,result_digest=?,snapshot=NULL
                  WHERE ticket=?""",(battle,outcome,_report_digest(report),row["ticket"]))
    db.execute("""INSERT INTO robot_career VALUES(?,1,?,?) ON CONFLICT(robot) DO UPDATE SET
                  battles=battles+1,kills=kills+excluded.kills,output=output+excluded.output""",
               (robot,kills,output))
    db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?", (robot,row["ticket"]))
    if any(e["kind"] in ("disabled","condition") for e in events):
        recovery.damage(db,robot,battle,defensive_aid=defensive_aid)


def history(db,owner,route):
    match=re.fullmatch(r"/v1/robots/([0-9a-f]{32})/history",route)
    if not match:
        raise Fault(404,"unknown_route")
    robot=match[1]
    totals=db.execute("""SELECT COALESCE(c.battles,0) battles,COALESCE(c.kills,0) kills,
                        COALESCE(c.output,0) output FROM robots r LEFT JOIN robot_career c ON c.robot=r.id
                        WHERE r.id=? AND r.owner=?""",(robot,owner)).fetchone()
    if not totals:
        raise Fault(404,"unknown_robot")
    return {"history":{"robot":robot,"totals":dict(totals)}}
