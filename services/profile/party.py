"""Transactional party lobby and per-account settlement for M15 expeditions."""
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import time
import uuid
import expedition
import pump
import factory
import recovery
import workshop
from inventory import Fault

MATCH_SECONDS = 15

def schema(db):
    expedition.schema(db)
    db.execute("""CREATE TABLE IF NOT EXISTS parties(id TEXT PRIMARY KEY, code TEXT UNIQUE, leader TEXT NOT NULL,
        phase TEXT NOT NULL, created INTEGER NOT NULL)""")
    db.execute("""CREATE TABLE IF NOT EXISTS party_members(group_id TEXT REFERENCES parties(id), owner TEXT REFERENCES accounts(id),
        selected TEXT NOT NULL, stamp TEXT NOT NULL, points INTEGER NOT NULL, mission TEXT UNIQUE, joined INTEGER NOT NULL,
        PRIMARY KEY(group_id,owner))""")


def continuity_schema(db):
    schema(db)
    db.execute("""CREATE TABLE IF NOT EXISTS party_rounds(
        round TEXT PRIMARY KEY REFERENCES parties(id), team TEXT NOT NULL REFERENCES parties(id),
        previous TEXT UNIQUE REFERENCES parties(id), finished INTEGER)""")
    db.execute("""CREATE TABLE IF NOT EXISTS party_declines(
        round TEXT REFERENCES parties(id), owner TEXT REFERENCES accounts(id), PRIMARY KEY(round,owner))""")
    db.execute("INSERT OR IGNORE INTO party_rounds(round,team) SELECT id,id FROM parties")

def matchmaking_schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS party_searches(owner TEXT NOT NULL REFERENCES accounts(id),
        intent TEXT NOT NULL, until INTEGER NOT NULL, PRIMARY KEY(owner,intent))""")
    db.execute("CREATE UNIQUE INDEX IF NOT EXISTS one_party_search ON party_searches(owner) WHERE until>0")

def matchmaking(db,owner,op,intent):
    if not isinstance(intent,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",intent):
        raise Fault(400,"invalid_parameters")
    now=int(time.time())
    if op=="cancel_match":
        # Cancellation can reach the server before the first search packet.
        db.execute("""INSERT INTO party_searches VALUES(?,?,0) ON CONFLICT(owner,intent)
                      DO UPDATE SET until=0""",(owner,intent))
        return
    group=current(db,owner)
    if group and group_activity(db,group["id"]):
        raise Fault(409,"wrong_activity")
    prior=db.execute("SELECT until FROM party_searches WHERE owner=? AND intent=?",(owner,intent)).fetchone()
    if group:
        db.execute("INSERT OR IGNORE INTO party_searches VALUES(?,?,0)",(owner,intent))
        return
    if prior and prior[0]<=now:
        return
    if prior:
        db.execute("UPDATE party_searches SET until=? WHERE owner=? AND intent=?",(now+MATCH_SECONDS,owner,intent))
        return
    db.execute("UPDATE party_searches SET until=0 WHERE owner=? AND until<=?",(owner,now))
    if db.execute("SELECT 1 FROM party_searches WHERE owner=? AND until>?",(owner,now)).fetchone():
        db.execute("INSERT INTO party_searches VALUES(?,?,0)",(owner,intent))
        return
    first=db.execute("""SELECT s.owner FROM party_searches s WHERE s.until>0 AND s.until>? AND NOT EXISTS(
        SELECT 1 FROM party_members m JOIN parties p ON p.id=m.group_id
        WHERE m.owner=s.owner AND p.phase IN ('lobby','active'))
        ORDER BY s.rowid LIMIT 1""",(now,)).fetchone()
    if first is None:
        db.execute("INSERT INTO party_searches VALUES(?,?,?)",(owner,intent,now+MATCH_SECONDS))
        return
    gid=new_party(db,first[0])
    db.execute("UPDATE party_searches SET until=0 WHERE owner=? AND until>0",(first[0],))
    db.execute("INSERT INTO party_searches VALUES(?,?,0)",(owner,intent))
    db.executemany("INSERT INTO party_members VALUES(?,?,'[]','',0,NULL,?)",[(gid,member,now) for member in (first[0],owner)])

def new_party(db,leader,team=None,previous=None):
    gid=uuid.uuid4().hex
    for _ in range(4):
        code=secrets.token_hex(4).upper()
        if db.execute("INSERT OR IGNORE INTO parties VALUES(?,?,?,'lobby',?)",
                      (gid,code,leader,int(time.time()))).rowcount:
            db.execute("INSERT INTO party_rounds(round,team,previous) VALUES(?,?,?)",(gid,team or gid,previous))
            return gid
    raise Fault(503,"code_unavailable")

def continuation(db,owner):
    return db.execute("""SELECT r.round,r.team,p.code,here.leader FROM party_rounds r
        JOIN parties p ON p.id=r.team JOIN parties here ON here.id=r.round
        JOIN party_members m ON m.group_id=r.round AND m.owner=?
        WHERE r.finished>=? AND r.round NOT IN (SELECT gid FROM pump_groups) AND r.round NOT IN (SELECT gid FROM factory_groups) AND NOT EXISTS(SELECT 1 FROM party_declines d WHERE d.round=r.round AND d.owner=m.owner)
        AND NOT EXISTS(SELECT 1 FROM party_rounds successor JOIN parties s ON s.id=successor.round
            WHERE successor.previous=r.round AND s.phase!='lobby')
        ORDER BY r.finished DESC,here.rowid DESC LIMIT 1""",(owner,int(time.time())-3600)).fetchone()

def members(db, group):
    return list(db.execute("""SELECT m.*,a.name FROM party_members m JOIN accounts a ON a.id=m.owner
                             WHERE group_id=? ORDER BY joined,m.rowid""",(group,)))

def current(db,owner):
    return db.execute("""SELECT p.* FROM parties p JOIN party_members m ON p.id=m.group_id
                       WHERE m.owner=? AND p.phase IN ('lobby','active') ORDER BY p.rowid DESC LIMIT 1""",(owner,)).fetchone()

def fit(db,owner,ids):
    d=workshop.deployment_for(workshop.owned_robots(db,owner),ids)
    return d,hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()

def group_activity(db,gid):
    row=pump.group(db,gid)
    if row:return dict(row,activity="pump_ruin")
    row=db.execute("SELECT * FROM factory_groups WHERE gid=?",(gid,)).fetchone()
    if row:return dict(row,activity=factory.ACTIVITY,event=factory.EVENT)
    return None


def state(db,owner,activity_kind="party"):
    g=current(db,owner)
    activity=group_activity(db,g["id"]) if g else None
    if (activity["activity"] if activity else "party")!=activity_kind:g=None
    personal=expedition.overview(db,owner)
    out={"self":owner,"departure_quote":recovery.entry_quote(db,owner),"roomscope":{},"robots":personal["robots"],"drill_recipe":personal["drill_recipe"],
         "last":expedition.recent_personal_report(db,owner,activity_kind)}
    if activity_kind=="party":
        search=db.execute("SELECT intent FROM party_searches WHERE owner=? AND until>?",(owner,int(time.time()))).fetchone() if not g else None
        out.update(matching=bool(search),match_key=search[0] if search else "")
    if activity_kind=="pump_ruin":out["event"]=pump.quote(db,owner)
    if activity_kind==factory.ACTIVITY:out["event"]=factory.quote(db,owner)
    offer=continuation(db,owner) if not g and activity_kind=="party" else None
    out["continuation"]=dict(offer) if offer else {}
    if not g:return out
    rows=members(db,g["id"])
    room={"id":g["id"],"code":g["code"],"leader":g["leader"],"phase":g["phase"],"members":[],"points":0,"count":0}
    identity=db.execute("SELECT r.team,p.code FROM party_rounds r JOIN parties p ON p.id=r.team WHERE r.round=?",(g["id"],)).fetchone()
    if activity:room.update(activity=activity["activity"],mode=activity["mode"],event=activity["event"])
    room.update(team=identity["team"],code=identity["code"])
    for r in rows:
        ids=json.loads(r["selected"])
        units={unit["id"]:unit for unit in workshop.owned_robots(db,r["owner"])}
        room["members"].append({"robot_names":[units.get(robot,{}).get("name",robot[:6]) for robot in ids],
            "roles":[units[robot]["orders"]["role"] for robot in ids if robot in units],
            "owner":r["owner"],"name":r["name"],"robots":ids,"ready":bool(r["stamp"]),"points":r["points"]})
        room["count"]+=len(ids); room["points"]+=r["points"]
        if r["mission"] and r["owner"]==owner:
            record=db.execute("SELECT secret,receipt FROM expeditions WHERE id=?",(r["mission"],)).fetchone()
            room["admission"]={"id":g["id"],"secret":record["secret"],"owner":owner}
            if record["receipt"]: room["receipt"]=json.loads(record["receipt"])
    out["roomscope"]=room
    return out

def handle(db,owner,method,route,fields,activity_kind="party"):
    schema(db)
    # Abandoned, unstarted codes are disposable; no robotic reservations exist yet.
    db.execute("UPDATE parties SET phase='closed' WHERE phase='lobby' AND created<?",(int(time.time())-3600,))
    if method=="GET" and route=="/v1/party":return {"party":state(db,owner,activity_kind)}
    op=route.rsplit("/",1)[-1]
    if op in ("match","cancel_match") and activity_kind=="party":
        if method!="POST" or fields.keys()!={"key"}:
            raise Fault(400,"invalid_parameters")
        matchmaking(db,owner,op,fields["key"])
        return {"party":state(db,owner)}
    allowed={"create":set(),"join":{"code"},"ready":{"robots"},"unready":set(),"start":set(),"leave":set(),"again":{"round"},"finish":{"round"}}
    if activity_kind!="party":
        allowed["create"]={"mode","event"} if activity_kind=="pump_ruin" else {"mode"}
        del allowed["again"]
    if op=="start" and "round" in fields:allowed["start"]={"round"}
    if method!="POST" or op not in allowed or fields.keys()!=allowed[op]:raise Fault(400,"invalid_parameters")
    g=current(db,owner)
    activity=group_activity(db,g["id"]) if g else None
    creating=None
    if activity and activity["activity"]=="pump_ruin" and g["phase"]=="lobby" and op in ("create","join"):
        live=pump.event()
        if activity["event"]!=live["id"] or not live["active"]:
            db.execute("UPDATE parties SET phase='closed' WHERE id=?",(g["id"],))
            g=None
            activity=None
    if activity_kind==factory.ACTIVITY and op in ("create","join","ready","start"):
        factory.require_access(db,owner)
    if activity_kind!="party" and op=="create":
        if fields["mode"] not in ("solo","coop"): raise Fault(400,"invalid_mode")
        creating=pump.require_window(fields["event"]) if activity_kind=="pump_ruin" else {"id":factory.EVENT}
    if g and op!="finish" and (activity["activity"] if activity else "party")!=activity_kind: raise Fault(409,"wrong_activity")
    if op=="finish":
        round_id=fields["round"]
        if not isinstance(round_id,str) or not re.fullmatch(r"[0-9a-f]{32}",round_id):
            raise Fault(400,"invalid_parameters")
        if (group_activity(db,round_id) or {}).get("activity","party")!=activity_kind:raise Fault(409,"wrong_activity")
        finished=db.execute("""SELECT 1 FROM party_members m JOIN expeditions e ON e.id=m.mission
            WHERE m.group_id=? AND m.owner=? AND e.receipt IS NOT NULL""",(round_id,owner)).fetchone()
        if not finished:
            raise Fault(409,"continuation_unavailable")
        db.execute("INSERT OR IGNORE INTO party_declines VALUES(?,?)",(round_id,owner))
        return {"finished_round":round_id,"party":state(db,owner,activity_kind)}
    if op=="again":
        offer=continuation(db,owner)
        if not offer or offer["round"]!=fields["round"]:
            raise Fault(409,"continuation_unavailable")
        successor=db.execute("SELECT round FROM party_rounds WHERE previous=?",(offer["round"],)).fetchone()
        if g and (not successor or successor[0]!=g["id"]):raise Fault(409,"already_in_party")
        gid=successor[0] if successor else new_party(db,owner,offer["team"],offer["round"])
        if not g and len(members(db,gid))>=3:raise Fault(409,"party_full")
        db.execute("INSERT OR IGNORE INTO party_members VALUES(?,?,'[]','',0,NULL,?)",(gid,owner,int(time.time())))
        if owner==offer["leader"]:db.execute("UPDATE parties SET leader=? WHERE id=?",(owner,gid))
    elif op in ("create","join"):
        if op=="create" and not g:
            gid=new_party(db,owner)
            if activity_kind==factory.ACTIVITY:
                db.execute("INSERT INTO factory_groups VALUES(?,?,?)",(gid,fields["mode"],secrets.randbits(31)))
            elif creating:db.execute("INSERT INTO pump_groups VALUES(?,?,?,?)",(gid,creating["id"],creating["seed"],fields["mode"]))
        elif op=="join":
            if not isinstance(fields["code"],str):raise Fault(400,"invalid_parameters")
            found=db.execute("""SELECT current.* FROM parties permanent JOIN party_rounds r ON r.team=permanent.id
                JOIN parties current ON current.id=r.round WHERE permanent.code=? AND current.phase='lobby'
                ORDER BY current.rowid DESC LIMIT 1""",(fields["code"].strip().upper(),)).fetchone()
            if not found or found["phase"]!="lobby":raise Fault(404,"unknown_code")
            target=group_activity(db,found["id"])
            if (target or {}).get("activity","party")!=activity_kind:raise Fault(409,"wrong_activity")
            if target:
                if activity_kind==factory.ACTIVITY:factory.require_friend(db,owner,found["leader"])
                else:pump.require_window(target["event"])
                if target["mode"]!="coop":raise Fault(409,"party_full")
            gid=found["id"]
            if g and g["id"]!=gid:raise Fault(409,"already_in_party")
            if not g and len(members(db,gid))>=(2 if activity_kind==factory.ACTIVITY else 3):raise Fault(409,"party_full")
        else:
            if creating and (activity["mode"]!=fields["mode"] or activity["event"]!=creating["id"]):
                raise Fault(409,"already_in_party")
            return {"party":state(db,owner,activity_kind)}
        db.execute("INSERT OR IGNORE INTO party_members VALUES(?,?,'[]','',0,NULL,?)",(gid,owner,int(time.time())))
    elif not g:
        if op!="leave":raise Fault(404,"no_party")
    elif g["phase"]!="lobby":
        if op!="start":raise Fault(409,"party_started")
    elif op=="leave":
        db.execute("""INSERT OR IGNORE INTO party_declines SELECT previous,? FROM party_rounds
            WHERE round=? AND previous IS NOT NULL""",(owner,g["id"]))
        db.execute("DELETE FROM party_members WHERE group_id=? AND owner=?",(g["id"],owner))
        left=members(db,g["id"])
        if not left:db.execute("UPDATE parties SET phase='closed' WHERE id=?",(g["id"],))
        elif owner==g["leader"]:db.execute("UPDATE parties SET leader=? WHERE id=?",(left[0]["owner"],g["id"]))
    elif op in ("ready","unready"):
        ids=fields.get("robots",[])
        d,stamp=fit(db,owner,ids) if op=="ready" else ({"points":0},"")
        others=[r for r in members(db,g["id"]) if r["owner"]!=owner]
        if activity and op=="ready":pump.validate_squad(activity["mode"],d)
        if not activity and (sum(r["points"] for r in others)+d["points"]>24 or sum(len(json.loads(r["selected"])) for r in others)+len(ids)>12):
            raise Fault(409,"team_budget")
        db.execute("UPDATE party_members SET selected=?,stamp=?,points=? WHERE owner=? AND group_id=?",(json.dumps(ids),stamp,d["points"],owner,g["id"]))
    elif op=="start":
        if fields.get("round",g["id"])!=g["id"]:raise Fault(409,"round_changed")
        rows=members(db,g["id"])
        if g["leader"]!=owner:raise Fault(403,"leader_only")
        window=pump.require_window(activity["event"]) if activity_kind=="pump_ruin" else None
        opened_day=factory.day() if activity_kind==factory.ACTIVITY else None
        minimum=1 if activity and activity["mode"]=="solo" else 2
        if len(rows)<minimum or any(not r["stamp"] for r in rows):raise Fault(409,"not_ready")
        for r in rows:
            ids=json.loads(r["selected"]);deployment,stamp=fit(db,r["owner"],ids)
            if opened_day:
                factory.require_access(db,r["owner"])
                factory.require_friend(db,r["owner"],owner)
            if activity:pump.validate_squad(activity["mode"],deployment)
            if stamp!=r["stamp"]:raise Fault(409,"changed_fit")
            receipt=expedition.start(db,r["owner"],{"key":"party_"+secrets.token_hex(20),"robots":ids})
            if opened_day:db.execute("INSERT INTO factory_entries VALUES(?,?)",(receipt["mission"],opened_day))
            if window:db.execute("INSERT INTO pump_entries VALUES(?,?)",(receipt["mission"],window["utc_day"]))
            db.execute("UPDATE party_members SET mission=? WHERE owner=? AND group_id=?",(receipt["mission"],r["owner"],g["id"]))
        db.execute("UPDATE parties SET phase='active' WHERE id=?",(g["id"],))
    if op in ("create","join","again"):
        db.execute("UPDATE party_searches SET until=0 WHERE owner=? AND until>0",(owner,))
    return {"party":state(db,owner,activity_kind)}

def open_mission(db,fields):
    gid=fields.get("id");secret=fields.get("secret")
    if not isinstance(gid,str) or not re.fullmatch(r"[0-9a-f]{32}",gid) or not isinstance(secret,str) or not re.fullmatch(r"[A-Za-z0-9_-]{43}",secret):
        raise Fault(400,"invalid_parameters")
    rows=list(db.execute("""SELECT e.*,a.name AS commander FROM party_members m JOIN expeditions e ON e.id=m.mission
                          JOIN accounts a ON a.id=m.owner
                          WHERE m.group_id=? ORDER BY m.joined,m.rowid""",(gid,)))
    who=next((r for r in rows if secrets.compare_digest(r["secret"],secret)),None)
    if not who:raise Fault(403,"invalid_mission")
    if who["receipt"]:return {"receipt":json.loads(who["receipt"])}
    activity=group_activity(db,gid)
    metadata={}
    if activity:
        table="factory_entries" if activity["activity"]==factory.ACTIVITY else "pump_entries"
        day=db.execute(f"SELECT day FROM {table} WHERE mission=?",(who["id"],)).fetchone()[0]
        metadata=dict(activity=activity["activity"],event=activity["event"],seed=activity["seed"],mode=activity["mode"],utc_day=day)
    return metadata | {"owner":who["owner"],"leader":db.execute("SELECT leader FROM parties WHERE id=?",(gid,)).fetchone()[0],"expires":min(r["expires"] for r in rows),
            "join_order":[r["owner"] for r in rows],"names":{r["owner"]:r["commander"] for r in rows},
            "squads":{r["owner"]:json.loads(r["deployment"]) for r in rows}}

def settle_group(db,gid,results):
    rows=members(db,gid)
    if not rows or results.keys()!={r["owner"] for r in rows}:raise Fault(400,"missing_party_result")
    receipts={}
    for body in results.values():
        if not isinstance(body,dict) or body.keys()-{"commanded","cause"}!={"outcome","nodes","reports","seconds","participated"}:
            raise Fault(400,"invalid_party_result")
    for r in rows:
        e=db.execute("SELECT * FROM expeditions WHERE id=?",(r["mission"],)).fetchone()
        body=results[r["owner"]]
        receipts[r["owner"]]=expedition.settle(db,e,body["outcome"],body["nodes"],body["reports"],body["seconds"],body.get("commanded"),participated=body["participated"],cause=body.get("cause"))
    db.execute("UPDATE parties SET phase='finished' WHERE id=?",(gid,))
    db.execute("UPDATE party_rounds SET finished=COALESCE(finished,?) WHERE round=?",(int(time.time()),gid))
    return receipts

def internal(db,route,fields):
    schema(db)
    if route.endswith("/open"):return open_mission(db,fields)
    if fields.keys()!={"id","results"} or not isinstance(fields["results"],dict):raise Fault(400,"invalid_parameters")
    return {"receipts":settle_group(db,fields["id"],fields["results"])}


def expire(db):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE name='parties'").fetchone():
        return
    due=db.execute("""SELECT p.id,MIN(e.expires) AS deadline FROM parties p JOIN party_members m ON p.id=m.group_id
        JOIN expeditions e ON e.id=m.mission WHERE p.phase='active' GROUP BY p.id HAVING deadline<=?""",(int(time.time()),)).fetchall()
    for gid,deadline in due:
        directory=os.environ.get("PARTY_SPOOL_DIR")
        checkpoint={}
        if directory:
            final=Path(directory)/(gid+".result.json")
            progress=Path(directory)/(gid+".progress.json")
            if final.is_file():
                frozen=json.loads(final.read_text(encoding="utf-8"))
                if frozen["id"]==gid and 0<frozen["finished_at"]<=deadline:
                    settle_group(db,gid,frozen["results"])
                    continue
            if progress.is_file():
                saved=json.loads(progress.read_text(encoding="utf-8"))
                if saved["id"]==gid:checkpoint=saved["results"]
        results={}
        retained=("win","defeat","retreat") if group_activity(db,gid) else ("retreat",)
        for member in members(db,gid):
            owner=member["owner"]
            result=dict(checkpoint.get(owner,{"participated":False,"nodes":[],"seconds":0,"reports":{r:[] for r in json.loads(member["selected"])}}))
            if result.get("outcome") not in (*retained,"expired"):
                result["outcome"]="expired"
                result.pop("cause",None)
            results[owner]=result
        settle_group(db,gid,results)
