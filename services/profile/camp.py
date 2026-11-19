"""M19 camp combat ownership, reservations, garrisons and bounded production."""
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import uuid

import inventory
import friends
import service_record
import workshop
import world_calendar as calendar
from inventory import Fault

NODE = calendar.LIVE_CAMP
MAX_CAMPS = 2
CAPACITY = 8
SECONDS_PER_UNIT = 900
EXTRACTOR_SECONDS = 720
EXTRACTOR_COST = 2
# Common integer denominator preserves the exact fraction when the production rate changes.
WORK_PER_UNIT = 3600
RESERVATION = 60
ROUND_LIMIT = 180
ATTACK_ENERGY = 1


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS camp_estates(node TEXT PRIMARY KEY, revision INTEGER NOT NULL,
                neutral_alive INTEGER NOT NULL, accrued INTEGER NOT NULL, since INTEGER NOT NULL,
                extractor INTEGER NOT NULL DEFAULT 0, progress INTEGER NOT NULL DEFAULT 0)""")
    db.execute("""CREATE TABLE IF NOT EXISTS camp_garrisons(robot TEXT PRIMARY KEY REFERENCES robots(id),
                node TEXT NOT NULL, turret INTEGER NOT NULL)""")
    db.execute("""CREATE TABLE IF NOT EXISTS camp_contests(id TEXT PRIMARY KEY, node TEXT, grant_id TEXT,
                attacker TEXT, defender TEXT, attack_key TEXT NOT NULL, defense_key TEXT NOT NULL,
                revision INTEGER NOT NULL, selected TEXT NOT NULL, phase TEXT NOT NULL, expires INTEGER NOT NULL,
                snapshot TEXT, tickets TEXT, result TEXT, signature TEXT, UNIQUE(attacker,grant_id))""")
    db.execute("CREATE UNIQUE INDEX IF NOT EXISTS one_camp_fight ON camp_contests(node) WHERE phase='live'")


def state(db,node=NODE):
    db.execute("INSERT OR IGNORE INTO camp_estates(node,revision,neutral_alive,accrued,since) VALUES (?,0,1,0,?)",(node,calendar.now()))
    estate=db.execute("""SELECT e.*,w.owner FROM camp_estates e JOIN world_camps w ON w.node=e.node
                         WHERE e.node=?""",(node,)).fetchone()
    if estate is None:
        raise Fault(404,"unknown_node")
    return estate


def production_at(estate,now):
    if not estate["owner"]:
        return 0,0
    period = EXTRACTOR_SECONDS if estate["extractor"] else SECONDS_PER_UNIT
    work = estate["progress"] + max(0,now-estate["since"]) * (WORK_PER_UNIT//period)
    complete,progress = divmod(work,WORK_PER_UNIT)
    due = estate["accrued"] + complete
    return (CAPACITY,0) if due>=CAPACITY else (due,progress)


def stock(db,estate):
    return production_at(estate,calendar.now())[0]


def extractor_quote(db,owner,estate,battle):
    resource=calendar.CAMP_RESOURCES[estate["node"]]
    if estate["owner"]!=owner:
        reason="not_camp_owner"
    elif battle:
        reason="camp_busy"
    elif estate["extractor"]:
        reason="extractor_built"
    else:
        amount=db.execute("SELECT amount FROM stocks WHERE owner=? AND resource=?",(owner,resource)).fetchone()[0]
        reason="insufficient_stock" if amount<EXTRACTOR_COST else ""
    return dict(built=bool(estate["extractor"]),cost={resource:EXTRACTOR_COST},base_seconds=SECONDS_PER_UNIT,
                built_seconds=EXTRACTOR_SECONDS,can_build=not reason,reason=reason)


def build_extractor(db,owner,body,node):
    if (body.keys()!={"key","revision"} or not isinstance(body["key"],str)
            or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",body["key"]) or type(body["revision"])!=int or body["revision"]<0):
        raise Fault(400,"invalid_parameters")
    signature=f"camp_extractor/{node}/{body['revision']}"
    prior=inventory.previous(db,owner,body["key"],signature)
    if prior:
        return prior
    estate=state(db,node)
    if estate["revision"]!=body["revision"]:
        raise Fault(409,"stale_ownership")
    quote=extractor_quote(db,owner,estate,live(db,node))
    if not quote["can_build"]:
        raise Fault(409,quote["reason"])
    now=calendar.now()
    due,progress=production_at(estate,now)
    changes=inventory.apply_stock(db,owner,{resource:-cost for resource,cost in quote["cost"].items()})
    db.execute("UPDATE camp_estates SET extractor=1,accrued=?,progress=?,since=? WHERE node=?",(due,progress,now,node))
    return inventory.record(db,owner,body["key"],"camp_extractor",signature,changes,node=node,revision=estate["revision"])


def stationed(db,node=NODE):
    return {r[0]:bool(r[1]) for r in db.execute("SELECT robot,turret FROM camp_garrisons WHERE node=?",(node,))}


def live(db,node=NODE):
    return db.execute("SELECT * FROM camp_contests WHERE node=? AND phase='live'",(node,)).fetchone()


def admission(row,owner):
    return {"id":row["id"],"secret":row["attack_key"] if owner==row["attacker"] else row["defense_key"],"expires":row["expires"]}


def defense_alerts(db,owner):
    sites=calendar.CAMP_SITES
    keys=",".join("?" for _ in sites)
    rows=db.execute(f"""SELECT c.node,c.id FROM world_camps w JOIN camp_contests c ON c.node=w.node
                        WHERE w.node IN ({keys}) AND w.owner=? AND c.defender=w.owner
                        AND c.phase='live' AND c.expires>? ORDER BY c.node""",(*sites,owner,calendar.now()))
    return {"alerts":[{"node":node,"name":sites[node]["name"],"battle":battle} for node,battle in rows],
            "poll_after":3}

def attack_supply(db,owner,battle):
    energy=db.execute("SELECT amount FROM stocks WHERE owner=? AND resource='energy'",(owner,)).fetchone()[0]
    receipt=None
    if battle and battle["attacker"]==owner:
        receipt=db.execute("SELECT id FROM receipts WHERE owner=? AND business_key=?",
                           (owner,"camp/supply/"+battle["id"])).fetchone()
    return dict(cost=ATTACK_ENERGY,energy=energy,affordable=energy>=ATTACK_ENERGY,
                paid=bool(receipt),receipt_id=receipt[0] if receipt else "")


def overview(db,owner,node=NODE):
    _,nodes=calendar.active(db)
    e=state(db,node)
    battle=live(db,node)
    robots=workshop.owned_robots(db,owner)
    guards=stationed(db,node)
    mine=e["owner"]==owner
    local_stock=stock(db,e) if mine else 0
    owner_fields={}
    if mine:
        resource=calendar.CAMP_RESOURCES[node]
        held=db.execute("SELECT amount FROM stocks WHERE owner=? AND resource=?",(owner,resource)).fetchone()[0]
        private_free=max(0,inventory.STOCK[resource][1]-held)
        collectible=min(local_stock,private_free)
        owner_fields["claim_preview"]=dict(collectible=collectible,private_free=private_free,remaining=local_stock-collectible)
    side="defender" if mine else "attacker"
    grant=None if mine else friends.attack_grant(db,owner,node,nodes)
    grant_id=grant["id"] if grant else None
    aid_units,aid_points=friends.total(db,owner,side,node,grant_id)
    seat=battle if battle and owner in (battle["attacker"],battle["defender"]) else None
    pending=db.execute("""SELECT * FROM camp_contests WHERE attacker=? AND node=? AND grant_id=?
                          AND phase='pending' AND expires>?""",(owner,node,grant_id,calendar.now())).fetchone() if grant else None
    last=db.execute("""SELECT result FROM camp_contests WHERE node=? AND phase='done' AND (attacker=? OR defender=?)
                        ORDER BY rowid DESC LIMIT 1""",(node,owner,owner)).fetchone()
    return {"node":node,"resource":calendar.CAMP_RESOURCES[node],"name":calendar.CAMP_SITES[node]["name"],"revision":e["revision"],"mine":mine,"owner":e["owner"],"active":bool(battle),
            "admission":admission(seat,owner) if seat else (admission(pending,owner) if pending and not battle else None),
            "budget":{"side":side,"max_units":workshop.SQUAD_CAP,"max_points":workshop.POINT_CAP,
                      "aid_units":aid_units,"aid_points":aid_points},
            "robots":[{"id":r["id"],"name":r["name"],"points":workshop.robot_points(r),"ready":not r["task"] and r["state"]=="ready" and workshop.complete(r["slots"]),
                       "weapon":r["slots"].get("weapon",{}).get("definition",""),
                       "guard":r["id"] in guards,"turret":guards.get(r["id"],False)} for r in robots],
            "stock":local_stock,**owner_fields,"attack_supply":attack_supply(db,owner,battle),
            "capacity":CAPACITY,"seconds_per_unit":EXTRACTOR_SECONDS if e["extractor"] else SECONDS_PER_UNIT,
            "extractor":extractor_quote(db,owner,e,battle),
            "last":json.loads(last[0]) if last else {}}


def reserve(db,owner,fields):
    if fields.keys()-{"node"}!={"grant","robots"} or not isinstance(fields["grant"],str):
        raise Fault(400,"invalid_parameters")
    prior=db.execute("SELECT * FROM camp_contests WHERE attacker=? AND grant_id=?",(owner,fields["grant"])).fetchone()
    if prior and fields.get("node",prior["node"])!=prior["node"]:raise Fault(409,"key_conflict")
    if prior and prior["phase"]!="pending":
        if json.loads(prior["selected"])!=fields["robots"]:
            raise Fault(409,"key_conflict")
        return admission(prior,owner)
    grant=calendar.qualification(db,owner,fields["grant"],for_entry=True)
    node=grant["node"]
    if node not in calendar.CAMP_RESOURCES or fields.get("node",node)!=node:
        raise Fault(409,"camp_not_available")
    if live(db,node):
        raise Fault(409,"camp_contested")
    estate=state(db,node)
    if estate["owner"]==owner:
        raise Fault(409,"already_owner")
    selected=workshop.deployment_for(workshop.owned_robots(db,owner),fields["robots"])
    aid_units,aid_points=friends.total(db,owner,"attacker",node,grant["id"])
    friends.check_budget(len(selected["units"])+aid_units,selected["points"]+aid_points)
    ident=prior["id"] if prior else uuid.uuid4().hex
    expiry=min(grant["cutoff_at"],calendar.now()+RESERVATION)
    if prior:
        db.execute("UPDATE camp_contests SET selected=?,expires=?,revision=?,defender=? WHERE id=?",
                   (json.dumps(fields["robots"]),expiry,estate["revision"],estate["owner"],ident))
    else:
        db.execute("""INSERT INTO camp_contests VALUES (?,?,?,?,?,?,?,?,?,'pending',?,NULL,NULL,NULL,NULL)""",
                   (ident,node,grant["id"],owner,estate["owner"],secrets.token_urlsafe(32),secrets.token_urlsafe(32),
                    estate["revision"],json.dumps(fields["robots"]),expiry))
    return admission(db.execute("SELECT * FROM camp_contests WHERE id=?",(ident,)).fetchone(),owner)


def squad(db,owner,ids):
    roster=workshop.owned_robots(db,owner)
    deployment=workshop.deployment_for(roster,ids)
    deployment["names"]={r["id"]:r["name"] for r in roster if r["id"] in ids}
    return deployment


def guard(db,owner,ids,turrets,node=NODE):
    estate=state(db,node)
    if estate["owner"]!=owner or live(db,node):
        raise Fault(409,"camp_not_editable")
    if not isinstance(ids,list) or not isinstance(turrets,list) or not all(isinstance(i,str) for i in ids+turrets) or len(set(turrets))!=len(turrets) or set(turrets)-set(ids):
        raise Fault(400,"invalid_garrison")
    for rid in stationed(db,node):
        db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE owner=? AND id=? AND assignment=?",(owner,rid,"campg_"+rid))
    db.execute("DELETE FROM camp_garrisons WHERE node=?",(node,))
    count,points=friends.total(db,owner,"defender",node)
    if ids:
        deployment=squad(db,owner,ids)
        friends.check_budget(count+len(ids),points+deployment["points"])
        if any(deployment["inventory"][u["slots"]["weapon"]]!="cannon" for u in deployment["units"] if u["chassis"] in turrets):
            raise Fault(409,"turret_requires_cannon")
    for rid in ids:
        db.execute("INSERT INTO camp_garrisons VALUES (?,?,?)",(rid,node,int(rid in turrets)))
        db.execute("UPDATE robots SET task='guard',assignment=? WHERE id=?",("campg_"+rid,rid))


def open_seat(db,body):
    row=db.execute("SELECT * FROM camp_contests WHERE id=?",(body["id"],)).fetchone()
    if not row or not isinstance(body["secret"],str) or not body["secret"].isascii():
        raise Fault(404,"unknown_contest")
    role=next((k for k,s in (("attacker","attack_key"),("defender","defense_key")) if row[k] and secrets.compare_digest(row[s],body["secret"])),None)
    if not role:
        role=friends.aid_role(db,row["id"],body["secret"])
    if not role:
        raise Fault(404,"unknown_contest")
    if row["phase"]=="done":
        return {"receipt":json.loads(row["result"])}
    if row["phase"]=="pending":
        if role!="attacker" or row["expires"]<=calendar.now():
            raise Fault(409,"reservation_expired")
        node=row["node"]
        if live(db,node):
            raise Fault(409,"camp_contested")
        e=state(db,node)
        if e["revision"]!=row["revision"] or e["owner"]!=row["defender"]:
            raise Fault(409,"ownership_changed")
        if db.execute("SELECT COUNT(*) FROM world_camps WHERE owner=?",(row["attacker"],)).fetchone()[0]>=MAX_CAMPS:
            raise Fault(409,"camp_limit")
        grant=calendar.bind_battle(db,row["attacker"],row["grant_id"],row["id"])
        try:
            changes=inventory.apply_stock(db,row["attacker"],{"energy":-ATTACK_ENERGY})
        except Fault as error:
            if error.code=="insufficient_stock":
                raise Fault(409,"insufficient_attack_energy") from error
            raise
        inventory.record(db,row["attacker"],"camp/supply/"+row["id"],"camp_attack_supply",row["id"],changes,
                         node=node,battle=row["id"])
        guards=stationed(db,node)
        for rid in guards:
            cursor=db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?",(rid,"campg_"+rid))
            if not cursor.rowcount:
                raise Fault(409,"garrison_changed")
        attacker=squad(db,row["attacker"],json.loads(row["selected"]))
        defender=squad(db,row["defender"],list(guards)) if guards else {"units":[],"inventory":{},"names":{},"points":0}
        snap={"node":node,"name":calendar.CAMP_SITES[node]["name"],"attacker":attacker,"defender":defender,"turrets":[i for i in guards if guards[i]],"neutral":bool(e["neutral_alive"] and not e["owner"]),"aid_owners":{}}
        tickets={}
        for side in ("attacker","defender"):
            helpers=friends.attach(db,row,side,snap[side])
            snap["aid_owners"].update(helpers)
            for u in snap[side]["units"]:
                rid=u["chassis"]
                tickets[rid]=service_record.start_mission(db,helpers.get(rid,row[side]),rid,row["id"])
        expires=min(calendar.now()+ROUND_LIMIT+30,grant["settle_until"]-1)
        db.execute("UPDATE camp_contests SET phase='live',snapshot=?,tickets=?,expires=? WHERE id=?",
                   (json.dumps(snap),json.dumps(tickets),expires,row["id"]))
    row=db.execute("SELECT * FROM camp_contests WHERE id=?",(row["id"],)).fetchone()
    return {"squads":json.loads(row["snapshot"]),"role":role,"expires":row["expires"]}


def result_signature(result):
    return hashlib.sha256(json.dumps(result,sort_keys=True,separators=(",",":")).encode()).hexdigest()


def normalize_timeout(result):
    # 1010 accumulated 3600 float steps; its terminal event could exceed 180s by ~7e-12.
    if result.get("seconds")!=ROUND_LIMIT or result.get("reason")!="timeout" or not isinstance(result.get("reports"),dict):
        return result
    reports=dict(result["reports"])
    changed=False
    for rid,events in reports.items():
        if not isinstance(events,list):
            continue
        previous=0
        corrected=[]
        for event in events:
            at=event.get("at") if isinstance(event,dict) else None
            if type(at) not in (float,int) or at<previous:
                raise Fault(400,"invalid_event")
            previous=at
            if ROUND_LIMIT<at<=ROUND_LIMIT+1e-9:
                event=dict(event,at=float(ROUND_LIMIT))
                changed=True
            corrected.append(event)
        reports[rid]=corrected
    return dict(result,reports=reports) if changed else result


def settle(db,row,result,expired=False):
    if not expired:
        at=result["finished_at"]
        if type(at) not in (float,int) or not 0<at<=row["expires"] or int(at)!=at:
            raise Fault(400,"invalid_finished_at")
        if type(result["seconds"]) not in (int,float):
            raise Fault(400,"invalid_contest_result")
        result=dict(result,finished_at=int(at),seconds=float(result["seconds"]))
    original_signature=result_signature(result)
    normalized=normalize_timeout(result) if not expired else result
    signature=result_signature(normalized) if normalized is not result else original_signature
    result=normalized
    if row["phase"]=="done":
        if row["signature"] not in (original_signature,signature,"expired"):
            raise Fault(409,"result_conflict")
        return json.loads(row["result"])
    if row["phase"]!="live":
        raise Fault(409,"contest_not_live")
    tickets=json.loads(row["tickets"])
    reports=result["reports"]
    winner=result["winner"]
    seconds=result["seconds"]
    if result["reason"] not in ("core","retreat","surrender","eliminated","expired","disconnected","timeout"):
        raise Fault(400,"invalid_contest_result")
    if winner not in ("attacker","defender","draw") or type(seconds) not in (float,int) or not 0<=seconds<=ROUND_LIMIT+1 or not isinstance(reports,dict) or set(reports)!=set(tickets):
        raise Fault(400,"invalid_contest_result")
    if not expired:
        calendar.settlement_qualification(db,row["attacker"],row["grant_id"],row["id"],result["finished_at"])
    node=row["node"]
    e=state(db,node)
    if e["revision"]!=row["revision"] or e["owner"]!=row["defender"]:
        raise Fault(409,"ownership_changed")
    snap=json.loads(row["snapshot"])
    for side in ("attacker","defender"):
        for u in snap[side]["units"]:
            rid=u["chassis"]
            service_record.finish_mission(db,tickets[rid],row["id"],"draw" if winner=="draw" else "win" if side==winner else "loss",reports[rid],seconds,
                                         defensive_aid=side=="defender" and rid in snap["aid_owners"])
    changed=winner=="attacker"
    if changed:
        calendar.set_owner(db,node,row["attacker"])
        db.execute("UPDATE camp_estates SET revision=revision+1,neutral_alive=0,extractor=0,progress=0,accrued=0,since=? WHERE node=?",(calendar.now(),node))
        for aid in db.execute("SELECT * FROM friend_aid WHERE node=? AND phase='accepted' AND (sender=? OR recipient=?)",(node,row["attacker"],row["attacker"])).fetchall():
            friends.release(db,aid,"withdrawn")
    guards=stationed(db,node)
    db.execute("DELETE FROM camp_garrisons WHERE node=?",(node,))
    if not changed and guards:
        for robot in workshop.owned_robots(db,row["defender"]):
            rid=robot["id"]
            if rid in guards and robot["state"]=="ready" and not robot["task"]:
                db.execute("INSERT INTO camp_garrisons VALUES (?,?,?)",(rid,node,int(guards[rid])))
                db.execute("UPDATE robots SET task='guard',assignment=? WHERE id=?",("campg_"+rid,rid))
    receipt={"id":row["id"],"node":node,"winner":winner,"changed":changed,"owner":row["attacker"] if changed else row["defender"],
             "revision":e["revision"]+int(changed),"reason":result["reason"],"seconds":seconds}
    for role in ("attacker","defender"):
        if row[role]:
            inventory.record(db,row[role],"camp/"+row["id"],"camp_contest",signature,{},battle=row["id"],role=role,outcome=winner)
    friends.finish(db,row,winner)
    db.execute("UPDATE camp_contests SET phase='done',result=?,signature=? WHERE id=?",(json.dumps(receipt),"expired" if expired else signature,row["id"]))
    return receipt


def try_spooled_settlement(db,row,result,expired=False):
    # A late invalid robot report must not leak earlier robot writes into lease cleanup.
    db.execute("SAVEPOINT camp_spool")
    try:
        settle(db,row,result,expired)
        return True
    except (Fault,ValueError,KeyError,TypeError):
        db.execute("ROLLBACK TO camp_spool")
        return False
    finally:
        db.execute("RELEASE camp_spool")


def expire(db):
    for row in db.execute("SELECT * FROM camp_contests WHERE phase='live' AND expires+5<=?",(calendar.now(),)).fetchall():
        directory=os.environ.get("CAMP_SPOOL_DIR")
        path=Path(directory)/ (row["id"]+".result.json") if directory else None
        if path and path.is_file():
            try:
                result=json.loads(path.read_text())["result"]
                if result["id"]==row["id"] and 0<result["finished_at"]<=row["expires"]:
                    if try_spooled_settlement(db,row,result):
                        continue
            except (Fault,OSError,ValueError,KeyError,TypeError):
                pass
        fallback={"winner":"defender","reason":"expired","seconds":0,"reports":{rid:[] for rid in json.loads(row["tickets"])}}
        if directory:
            progress=Path(directory)/(row["id"]+".progress.json")
            if progress.is_file():
                try:
                    partial=json.loads(progress.read_text())
                    if partial["id"]==row["id"] and set(partial["reports"])==set(fallback["reports"]):
                        if try_spooled_settlement(db,row,dict(fallback,seconds=partial["seconds"],reports=partial["reports"]),True):
                            continue
                except (ValueError,KeyError,TypeError,OSError):
                    pass
        settle(db,row,fallback,True)


def claim(db,owner,body,node=NODE):
    if (body.keys() not in ({"key"},{"key","revision"}) or not isinstance(body["key"],str)
            or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",body["key"])
            or ("revision" in body and (type(body["revision"])!=int or body["revision"]<0))):
        raise Fault(400,"invalid_parameters")
    key=body["key"]
    signature="camp_claim" if node==NODE else "camp_claim/"+node
    prior=inventory.previous(db,owner,key,signature)
    if prior:
        return prior
    e=state(db,node)
    if "revision" in body and body["revision"]!=e["revision"]:
        raise Fault(409,"stale_ownership")
    if e["owner"]!=owner:
        raise Fault(409,"not_camp_owner")
    now=calendar.now()
    due,progress=production_at(e,now)
    if not due:
        raise Fault(409,"nothing_to_claim")
    resource=calendar.CAMP_RESOURCES[node]
    change=inventory.apply_stock(db,owner,{resource:due})
    amount=change[resource]
    if not amount:
        raise Fault(409,"storage_full")
    db.execute("UPDATE camp_estates SET accrued=?,since=?,progress=? WHERE node=?",(due-amount,now,progress,node))
    return inventory.record(db,owner,key,"camp_claim",signature,change,node=node)


def internal(db,route,body):
    if route.endswith("/open") and body.keys()=={"id","secret"} and isinstance(body["id"],str):
        return open_seat(db,body)
    if route.endswith("/settle") and body.keys()=={"id","winner","seconds","reports","reason","finished_at"} and isinstance(body["id"],str):
        row=db.execute("SELECT * FROM camp_contests WHERE id=?",(body["id"],)).fetchone()
        if not row:
            raise Fault(404,"unknown_contest")
        return {"receipt":settle(db,row,body)}
    raise Fault(400,"invalid_parameters")


def handle(db,owner,method,route,body):
    pieces=route.split("/")
    node=NODE
    if len(pieces)>=4 and pieces[3] in calendar.CAMP_RESOURCES:
        node=pieces[3]
        route="/v1/camp"+("/"+"/".join(pieces[4:]) if len(pieces)>4 else "")
    if method=="GET" and route=="/v1/camp":
        return {"camp":overview(db,owner,node)}
    if method=="POST":
        if route=="/v1/camp/reserve":
            if body.get("node",node)!=node:
                raise Fault(409,"camp_not_available")
            return {"admission":reserve(db,owner,dict(body,node=node))}
        if route=="/v1/camp/garrison" and body.keys()=={"robots","turrets"}:
            guard(db,owner,body["robots"],body["turrets"],node)
            return {"camp":overview(db,owner,node)}
        if route=="/v1/camp/extractor":
            return {"receipt":build_extractor(db,owner,body,node),"camp":overview(db,owner,node)}
        if route=="/v1/camp/claim":
            return {"receipt":claim(db,owner,body,node),"camp":overview(db,owner,node)}
    raise Fault(400,"invalid_parameters")
