"""Optional M24 PvP, transactional reservations, match journal and personal extraction."""
from collections import Counter
import hashlib
import json
import math
import os
import secrets
import time
import uuid

import friends
import inventory
from inventory import Fault
import service_record
import treasure_combat as combat
import workshop

PERIOD=1800
OPEN=1320
PLACES=(("copper_lowland","铜管洼地",.24,.65),("old_crane_yard","旧吊车台",.82,.53),
        ("fogbell_junction","雾钟岔道",.43,.18))


def schema(db):
    db.execute("""CREATE TABLE treasure_groups(id TEXT PRIMARY KEY,event TEXT NOT NULL,leader TEXT NOT NULL,phase TEXT NOT NULL,
        opens INTEGER NOT NULL,deadline INTEGER NOT NULL,battle TEXT,revision INTEGER NOT NULL DEFAULT 0)""")
    db.execute("""CREATE TABLE treasure_members(gid TEXT REFERENCES treasure_groups(id),owner TEXT REFERENCES accounts(id),
        robots TEXT,points INTEGER NOT NULL DEFAULT 0,loadout TEXT,confirmed INTEGER NOT NULL DEFAULT 0,secret TEXT NOT NULL,side INTEGER,seq INTEGER DEFAULT 0,last_command TEXT,last_error TEXT,
        picked_up INTEGER NOT NULL DEFAULT 0,outcome TEXT,receipt TEXT,PRIMARY KEY(gid,owner))""")
    db.execute("CREATE TABLE treasure_rooms(id TEXT PRIMARY KEY,event TEXT NOT NULL,deadline REAL NOT NULL,done INTEGER DEFAULT 0,state TEXT NOT NULL)")
    db.execute("""CREATE TABLE treasure_daily_rewards(owner TEXT NOT NULL REFERENCES accounts(id),
        day INTEGER NOT NULL,battle TEXT NOT NULL REFERENCES treasure_rooms(id),PRIMARY KEY(owner,day))""")
    db.execute("CREATE INDEX treasure_active ON treasure_rooms(done,deadline)")
    db.execute("CREATE INDEX treasure_owner ON treasure_members(owner)")
    db.execute("""CREATE TABLE treasure_salvage(id INTEGER PRIMARY KEY,owner TEXT NOT NULL REFERENCES accounts(id),
        day INTEGER NOT NULL,battle TEXT NOT NULL REFERENCES treasure_rooms(id),misses INTEGER NOT NULL CHECK(misses BETWEEN 0 AND 2),
        UNIQUE(owner,day))""")
    db.execute("CREATE INDEX treasure_salvage_recent ON treasure_salvage(owner,id)")


def event(now=None):
    now=time.time() if now is None else now
    epoch=int(os.environ.get("TREASURE_EPOCH","0"))
    start=epoch+int((now-epoch)//PERIOD)*PERIOD
    seed=int.from_bytes(hashlib.sha256(("M24:"+str(start)).encode()).digest()[:4],"big")
    site,place,x,y=PLACES[seed%len(PLACES)]
    return dict(id="cache_"+str(start),type="treasure",site=site,name=place,x=x,y=y,seed=seed,opens=start,
                cutoff=start+OPEN-20,closes=start+OPEN,next=start+PERIOD,active=start<=now<start+OPEN-20)


def membership(db,owner):
    return db.execute("""SELECT g.*,m.robots,m.confirmed,m.secret,m.side,m.outcome,m.receipt FROM treasure_groups g
        JOIN treasure_members m ON m.gid=g.id WHERE m.owner=? AND g.phase IN ('forming','queued','matched')
        AND m.outcome IS NULL ORDER BY g.rowid DESC LIMIT 1""",(owner,)).fetchone()


def group_members(db,gid):
    return db.execute("""SELECT m.*,a.name FROM treasure_members m JOIN accounts a ON a.id=m.owner
        WHERE gid=? ORDER BY m.rowid""",(gid,)).fetchall()


def cancel(db,gid):
    db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE assignment LIKE ?",("trq:"+gid+":%",))
    db.execute("UPDATE treasure_groups SET phase='cancelled' WHERE id=?",(gid,))


def salvage_quote(db,owner,day):
    recent=db.execute("SELECT misses FROM treasure_salvage WHERE owner=? ORDER BY id DESC LIMIT 1",(owner,)).fetchone()
    misses=recent[0] if recent else 0
    used=db.execute("SELECT 1 FROM treasure_salvage WHERE owner=? AND day=?",(owner,day)).fetchone()
    return dict(day=day,available=not used,misses=misses,guaranteed=misses==2,
                definition="reinforced_boiler",chance_percent=100 if misses==2 else 20)


def salvage_roll():
    return secrets.randbelow(5)==0


def part_space(db,owner):
    used=db.execute("SELECT COUNT(*) FROM ("+workshop.FREE+")",(owner,)).fetchone()[0]
    return max(0,inventory.PART_CAP-used)


def award_salvage(db,owner,day,battle,cargo):
    quote=salvage_quote(db,owner,day)
    misses=quote["misses"]
    result=dict(day=day,status="ineligible",misses=misses,part_id="")
    if not cargo:
        return result
    if not quote["available"]:
        return dict(result,status="already_used")
    if quote["guaranteed"] or salvage_roll():
        if part_space(db,owner)==0:
            result.update(status="parts_full",misses=2)
        else:
            part_id=uuid.uuid4().hex
            db.execute("INSERT INTO parts VALUES (?,?,?)",(part_id,owner,quote["definition"]))
            result.update(status="awarded",misses=0,part_id=part_id)
    else:
        result.update(status="miss",misses=misses+1)
    db.execute("INSERT INTO treasure_salvage(owner,day,battle,misses) VALUES (?,?,?,?)",(owner,day,battle,result["misses"]))
    return result


def overview(db,owner):
    e=event(); g=membership(db,owner)
    last=db.execute("""SELECT m.receipt FROM treasure_members m JOIN treasure_groups g ON g.id=m.gid
        WHERE owner=? AND m.receipt IS NOT NULL ORDER BY g.rowid DESC LIMIT 1""",(owner,)).fetchone()
    played=db.execute("""SELECT 1 FROM treasure_members m JOIN treasure_groups g ON g.id=m.gid
        WHERE owner=? AND g.event=? AND m.receipt IS NOT NULL""",(owner,e["id"])).fetchone()
    now=int(time.time())
    day=now//86400
    if g and g["battle"]:
        started=db.execute("SELECT json_extract(state,'$.start') FROM treasure_rooms WHERE id=?",(g["battle"],)).fetchone()[0]
        day=int(started//86400)
    salvage=dict(salvage_quote(db,owner,day),part_space=part_space(db,owner))
    result=dict(event=e,server_time=now,salvage=salvage,roster=[dict(id=r["id"],name=r["name"],points=workshop.deployment_for([r],[r["id"]])["points"]) for r in workshop.owned_robots(db,owner)
                if r["state"]=="ready" and not r["task"] and workshop.complete(r["slots"])],group=None,
                played=bool(played),last=json.loads(last[0]) if last else None)
    if g:
        rows=group_members(db,g["id"])
        unit_cap,point_cap=capacity(len(rows))
        members=[]
        for row in rows:
            ids=json.loads(row["robots"]) if row["robots"] else []
            names={r["id"]:r["name"] for r in db.execute("SELECT id,name FROM robots WHERE owner=?",(row["owner"],)) if r["id"] in ids}
            members.append(dict(name=row["name"],mine=row["owner"]==owner,robots=ids,names=names,points=row["points"],confirmed=bool(row["confirmed"])))
        result["group"]=dict(id=g["id"],phase=g["phase"],deadline=g["deadline"],revision=g["revision"],point_cap=point_cap,
                             unit_cap=unit_cap,confirmed=bool(g["confirmed"]),members=members)
        if g["battle"]:
            result["admission"]=dict(id=g["battle"],secret=g["secret"])
    return result


def occupied(db,owner,event_id):
    return membership(db,owner) or db.execute("""SELECT 1 FROM treasure_members m JOIN treasure_groups g ON g.id=m.gid
        WHERE g.event=? AND m.owner=? AND g.phase IN ('matched','done')""",(event_id,owner)).fetchone()


def create(db,owner,body):
    e=event()
    if set(body)!={"event","friend"} or body["event"]!=e["id"] or not e["active"]:raise Fault(409,"treasure_closed")
    owners=[owner]
    if body["friend"]:
        other=friends.member(db,body["friend"])
        friends.relation(db,owner,other)
        owners.append(other)
    if any(occupied(db,o,e["id"]) for o in owners):raise Fault(409,"treasure_already_entered")
    gid=uuid.uuid4().hex
    db.execute("INSERT INTO treasure_groups(id,event,leader,phase,opens,deadline,battle) VALUES (?,?,?,'forming',?,?,NULL)",(gid,e["id"],owner,e["opens"],min(e["cutoff"],int(time.time())+120)))
    db.executemany("INSERT INTO treasure_members(gid,owner,secret) VALUES (?,?,?)",[(gid,o,secrets.token_urlsafe(32)) for o in owners])


def match(db,g,other):
    battle=uuid.uuid4().hex; units={}
    for side,group in enumerate((other,g)):
        slot=0
        for row in group_members(db,group["id"]):
            owner=row["owner"]
            selected=json.loads(row["robots"])
            db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE owner=? AND assignment LIKE ?",(owner,"trq:"+group["id"]+":%"))
            roster=workshop.owned_robots(db,owner)
            workshop.deployment_for(roster,selected)
            for r in roster:
                if r["id"] in selected:
                    service_record.start_mission(db,owner,r["id"],battle)
                    units[r["id"]]=combat.unit(r,owner,side,slot)
                    slot+=1
            db.execute("UPDATE treasure_members SET side=? WHERE gid=? AND owner=?",(side,group["id"],owner))
        db.execute("UPDATE treasure_groups SET phase='matched',battle=? WHERE id=?",(battle,group["id"]))
    now=time.time(); deadline=min(g["opens"]+OPEN,now+combat.DURATION)
    matched=event(g["opens"])
    state=combat.fresh(matched["seed"],units,now,swap_sealed=bool(secrets.randbits(1)))
    state["site"]=matched["site"]
    db.execute("INSERT INTO treasure_rooms VALUES (?,?,?,0,?)",(battle,g["event"],deadline,json.dumps(state)))


def capacity(member_count):
    if member_count==1:
        return workshop.SQUAD_CAP, workshop.POINT_CAP
    return 6,12


def proposal(db,owner,ids,member_count):
    units,points=capacity(member_count)
    if not isinstance(ids,list) or not 1<=len(ids)<=units:
        raise Fault(400,"unit_limit")
    deployment=workshop.deployment_for(workshop.owned_robots(db,owner),ids)
    if deployment["points"]>points:
        raise Fault(409,"point_limit")
    fingerprint=hashlib.sha256(json.dumps(deployment,sort_keys=True).encode()).hexdigest()
    return deployment["points"],fingerprint


def current_revision(g,revision):
    if type(revision) is not int or revision!=g["revision"]:
        raise Fault(409,"stale_roster")


def select(db,owner,body):
    g=membership(db,owner)
    if not g or set(body)!={"group","revision","robots"} or body["group"]!=g["id"] or g["phase"]!="forming":
        raise Fault(409,"cannot_select")
    rows=group_members(db,g["id"])
    if len(rows)!=2:
        raise Fault(409,"cannot_select")
    current_revision(g,body["revision"])
    points,signature=proposal(db,owner,body["robots"],len(rows))
    before=next(row for row in rows if row["owner"]==owner)
    if before["loadout"]==signature:
        return
    db.execute("UPDATE treasure_members SET confirmed=0 WHERE gid=?",(g["id"],))
    db.execute("UPDATE treasure_members SET robots=?,points=?,loadout=? WHERE gid=? AND owner=?",
               (json.dumps(body["robots"]),points,signature,g["id"],owner))
    db.execute("UPDATE treasure_groups SET revision=revision+1 WHERE id=?",(g["id"],))


def confirm(db,owner,body):
    g=membership(db,owner)
    if not g or body.get("risk") is not True or body.get("group")!=g["id"]:
        raise Fault(409,"explicit_confirmation_required")
    rows=group_members(db,g["id"])
    if len(rows)==1:
        if set(body)!={"group","risk","robots"}:
            raise Fault(409,"explicit_confirmation_required")
        if g["confirmed"]:
            if json.loads(g["robots"])!=body["robots"]:
                raise Fault(409,"already_confirmed")
            return
        points,signature=proposal(db,owner,body["robots"],1)
        db.execute("UPDATE treasure_members SET robots=?,points=?,loadout=? WHERE gid=? AND owner=?",
                   (json.dumps(body["robots"]),points,signature,g["id"],owner))
    else:
        if set(body)!={"group","risk","revision"}:
            raise Fault(409,"explicit_confirmation_required")
        current_revision(g,body["revision"])
        if any(not row["robots"] for row in rows):
            raise Fault(409,"roster_incomplete")
        if g["confirmed"]:
            return
    db.execute("UPDATE treasure_members SET confirmed=1 WHERE gid=? AND owner=?",(g["id"],owner))
    selected=group_members(db,g["id"])
    if any(not row["confirmed"] for row in selected):
        return
    for row in selected:
        ids=json.loads(row["robots"])
        _,signature=proposal(db,row["owner"],ids,len(selected))
        if signature!=row["loadout"]:
            raise Fault(409,"loadout_changed")
        db.executemany("UPDATE robots SET task='expedition',assignment=? WHERE owner=? AND id=?",
                       [("trq:"+g["id"]+":"+rid,row["owner"],rid) for rid in ids])
    db.execute("UPDATE treasure_groups SET phase='queued' WHERE id=?",(g["id"],))
    other=db.execute("SELECT * FROM treasure_groups WHERE event=? AND phase='queued' AND id!=? ORDER BY rowid LIMIT 1",(g["event"],g["id"])).fetchone()
    if other:match(db,g,other)


def handle(db,owner,method,route,body):
    if method=="POST":
        if route=="/v1/treasure/create":create(db,owner,body)
        elif route=="/v1/treasure/select":select(db,owner,body)
        elif route=="/v1/treasure/confirm":confirm(db,owner,body)
        elif route=="/v1/treasure/cancel":
            g=membership(db,owner)
            if not g or set(body)!={"group"} or body["group"]!=g["id"] or g["phase"]=="matched":raise Fault(409,"cannot_cancel")
            cancel(db,g["id"])
        else:raise Fault(404,"unknown_route")
    elif method!="GET" or route!="/v1/treasure":raise Fault(404,"unknown_route")
    return {"treasure":overview(db,owner)}


def finish(db,room,state,m,outcome):
    if m["outcome"]:return
    owner=m["owner"]; cargo=[]
    for key,item in state["items"].items():
        if item["bearer"]==owner:
            item["removed"]=True
            if outcome=="extracted":cargo.append(key)
    credits=Counter(state["items"][k]["resource"] for k in cargo)
    cargo_changes=inventory.apply_stock(db,owner,credits)
    day=int(state["start"]//86400)
    claimed=db.execute("SELECT 1 FROM treasure_daily_rewards WHERE owner=? AND day=?",(owner,day)).fetchone() is not None
    eligible=bool(m["picked_up"])
    credited=0
    changes=dict(cargo_changes)
    if eligible and not claimed:
        db.execute("INSERT INTO treasure_daily_rewards VALUES(?,?,?)",(owner,day,room["id"]))
        credited=inventory.apply_stock(db,owner,{"components":1})["components"]
        changes["components"]=changes.get("components",0)+credited
    seconds=state["tick"]*combat.STEP
    for rid,u in state["units"].items():
        if u["owner"]!=owner:continue
        u["out"]=True
        events=list(u["events"])
        if 0<u["hp"]<u["max_hp"]:
            events.append(dict(kind="condition",actor="combat",target=rid,amount=u["max_hp"]-u["hp"],at=seconds))
        service_record.finish_mission(db,"mission_"+room["id"]+"_"+rid,room["id"],"win" if outcome=="extracted" else "loss",events,seconds)
        # The receipt and career totals are now committed with this room tick.
        # A finished seat never needs its private event stream for recovery.
        u["events"].clear()
    receipt=inventory.record(db,owner,"tr:"+room["id"],"treasure_result",outcome,changes,battle=room["id"],outcome=outcome,cargo=cargo,
        cargo_changes=cargo_changes,salvage=award_salvage(db,owner,day,room["id"],cargo),
        participation=dict(eligible=eligible,already_claimed=claimed,credited=credited,day=day))
    db.execute("UPDATE treasure_members SET outcome=?,receipt=? WHERE gid=? AND owner=?",(outcome,json.dumps(receipt),m["gid"],owner))


def advance(db,room,state,members,now):
    target=int((min(now,room["deadline"])-state["start"])/combat.STEP)
    while state["tick"]<target:
        combat.step(state)
    for m in members:
        if m["outcome"]:continue
        alive=any(u["owner"]==m["owner"] and u["hp"]>0 for u in state["units"].values())
        if not alive or now>=room["deadline"]:finish(db,room,state,m,"defeated" if not alive else "expired")


def participants(db,battle):
    return db.execute("""SELECT m.* FROM treasure_members m JOIN treasure_groups g ON g.id=m.gid WHERE g.battle=?""",(battle,)).fetchall()


def save(db,room,state):
    done=all(m["outcome"] for m in participants(db,room["id"]))
    db.execute("UPDATE treasure_rooms SET state=?,done=? WHERE id=?",(json.dumps(state),int(done),room["id"]))
    if done:db.execute("UPDATE treasure_groups SET phase='done' WHERE battle=?",(room["id"],))


def expire(db):
    now=time.time()
    for row in db.execute("SELECT id FROM treasure_groups WHERE phase IN ('forming','queued') AND deadline<=?",(now,)).fetchall():cancel(db,row[0])
    for room in db.execute("SELECT * FROM treasure_rooms WHERE done=0 AND deadline<=?",(now,)).fetchall():
        state=json.loads(room["state"])
        advance(db,room,state,participants(db,room["id"]),now)
        save(db,room,state)


def command(db,room,state,m,body):
    owner=m["owner"]; action=body.get("action"); rid=body.get("robot")
    if not isinstance(rid,str):return "invalid_robot"
    u=state["units"].get(rid)
    if not u or u["owner"]!=owner or u["hp"]<=0 or u.get("out"):return "unit_unavailable"
    group=body.get("robots",[rid])
    if not isinstance(group,list) or not 1<=len(group)<=12 or any(not isinstance(i,str) for i in group) or len(set(group))!=len(group) or rid not in group:
        return "invalid_robot"
    if any(i not in state["units"] or state["units"][i]["owner"]!=owner or state["units"][i]["hp"]<=0 or state["units"][i].get("out") for i in group):
        return "unit_unavailable"
    if len(group)>1 and action not in ("move","focus"):return "invalid_robot"
    if action=="move":
        pos=body.get("pos")
        if not isinstance(pos,list) or len(pos)!=2 or not all(type(v) in (int,float) and math.isfinite(v) and abs(v)<=9 for v in pos):return "invalid_position"
        for i in group:state["units"][i].update(target=pos,manual_move=True,focus="",aim_target="")
    elif action=="focus":
        target=body.get("target")
        if not isinstance(target,str) or target not in state["units"] or state["units"][target]["side"]==u["side"]:return "invalid_target"
        enemy=state["units"][target]
        for i in group:
            fighter=state["units"][i]
            if target!=fighter["aim_target"] and enemy["hp"]>0 and not enemy.get("out") and combat.in_range(fighter,enemy):
                fighter["aim_target"]=""
            fighter.update(focus=target,target=fighter["pos"],manual_move=False)
    elif action=="take":
        key=body.get("item"); swap=body.get("replace","")
        if not isinstance(key,str) or not isinstance(swap,str):return "invalid_item"
        item=state["items"].get(key)
        if not item or item["removed"] or item["bearer"]:return "item_taken"
        if math.dist(u["pos"],item["pos"])>combat.PICKUP_RANGE:return "out_of_reach"
        carried=[k for k,v in state["items"].items() if v["bearer"]==owner and not v["removed"]]
        if len(carried)>=combat.CARRY:
            if swap not in carried:return "bag_full"
            state["items"][swap].update(bearer="",pos=list(u["pos"]))
        # Resolve immediate pickup and discovery of cargo dropped by a swap at this position.
        combat.survey(state)
        item["bearer"]=owner
        if not m["picked_up"]:
            db.execute("UPDATE treasure_members SET picked_up=1 WHERE gid=? AND owner=?",(m["gid"],owner))
    elif action=="extract":
        living=[v for v in state["units"].values() if v["owner"]==owner and v["hp"]>0]
        if any(math.dist(v["pos"],combat.HOME[m["side"]])>2.2 for v in living):return "return_to_exit"
        finish(db,room,state,m,"extracted")
    else:return "unknown_command"
    return ""


def personalized(room,state,m,now,err=""):
    units={rid:{k:v for k,v in u.items() if k in ("owner","side","name","paint","hull_number","pos","hp","max_hp","out","focus","parts","chassis","heading","shot","impact","last_service","protected_until","last_jam","orders")} for rid,u in state["units"].items()}
    known = state["discoveries"][m["side"]]
    items = {key: dict(item,resource="unknown") if key in combat.SEALED and key not in known else item.copy()
             for key,item in state["items"].items()}
    return dict(id=room["id"],site=state["site"],units=units,items=items,tick=state["tick"],side=m["side"],owner=m["owner"],
            seq=m["seq"],deadline=room["deadline"],now=now,error=err,outcome=m["outcome"],receipt=json.loads(m["receipt"]) if m["receipt"] else None)


def frames(db,body):
    seats=body.get("seats")
    if not isinstance(body.get("id"),str) or not isinstance(seats,list) or not 1<=len(seats)<=4 or not all(isinstance(s,str) for s in seats):
        raise Fault(400,"invalid_seats")
    room=db.execute("SELECT * FROM treasure_rooms WHERE id=?",(body["id"],)).fetchone()
    if not room:raise Fault(404,"unknown_battle")
    members=participants(db,room["id"])
    by_secret={r["secret"]:r for r in members}
    if any(s not in by_secret for s in seats):raise Fault(403,"invalid_seat")
    state=json.loads(room["state"]);tick=state["tick"];now=time.time()
    if not room["done"]:
        advance(db,room,state,members,now)
        if tick!=state["tick"] or now>=room["deadline"]:
            save(db,room,state)
            by_secret={r["secret"]:r for r in participants(db,room["id"])}
    return {"frames":[personalized(room,state,by_secret[s],now) for s in seats]}


def internal(db,verb,body):
    if not isinstance(body.get("id"),str) or not isinstance(body.get("secret"),str):raise Fault(400,"invalid_reference")
    room=db.execute("SELECT * FROM treasure_rooms WHERE id=?",(body["id"],)).fetchone()
    if not room:raise Fault(404,"unknown_battle")
    members=participants(db,room["id"])
    m=next((m for m in members if secrets.compare_digest(m["secret"].encode(),body["secret"].encode())),None)
    if not m:raise Fault(403,"invalid_seat")
    state=json.loads(room["state"]); before=state["tick"]; now=time.time()
    if not room["done"]:advance(db,room,state,members,now)
    def seat():
        return db.execute("SELECT * FROM treasure_members WHERE gid=? AND owner=?",(m["gid"],m["owner"])).fetchone()
    m=seat()
    err=""
    if verb=="command" and not m["outcome"]:
        seq=body.get("seq"); signature=json.dumps(body.get("order"),sort_keys=True)
        if type(seq) not in (int,float) or not math.isfinite(seq) or int(seq)!=seq or seq<1 or not isinstance(body.get("order"),dict):raise Fault(400,"invalid_command")
        if seq==m["seq"] and signature==m["last_command"]:err=m["last_error"]
        elif seq!=m["seq"]+1:err="command_out_of_sequence"
        else:
            err=command(db,room,state,m,body["order"])
            db.execute("UPDATE treasure_members SET seq=?,last_command=?,last_error=? WHERE gid=? AND owner=?",(int(seq),signature,err,m["gid"],m["owner"]))
        m=seat()
    if not room["done"] and (before!=state["tick"] or verb=="command" or now>=room["deadline"]):save(db,room,state)
    return {"state":personalized(room,state,m,now,err)}
