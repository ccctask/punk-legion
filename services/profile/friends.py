"""M20 bilateral friendships, definition sharing, and real units lent to M19."""
from collections import Counter
import json
import re
import secrets
import uuid

import inventory
from inventory import Fault
import private_base
import storefront
import workshop
import world_calendar as calendar

NODE="brass-yard"
LIVE=("offered","accepted","locked","returning")


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS friendships(a TEXT REFERENCES accounts(id), b TEXT REFERENCES accounts(id),
                proposer TEXT NOT NULL,state TEXT NOT NULL,PRIMARY KEY(a,b),CHECK(a<b))""")
    db.execute("""CREATE TABLE IF NOT EXISTS shared_designs(id TEXT PRIMARY KEY,sender TEXT REFERENCES accounts(id),
                recipient TEXT REFERENCES accounts(id),source TEXT,definition TEXT,UNIQUE(sender,recipient,source))""")
    db.execute("""CREATE TABLE IF NOT EXISTS friend_aid(id TEXT PRIMARY KEY,sender TEXT REFERENCES accounts(id),
                recipient TEXT REFERENCES accounts(id),robot TEXT REFERENCES robots(id),node TEXT,side TEXT,
                phase TEXT,points INTEGER DEFAULT 0,grant_id TEXT,battle TEXT,secret TEXT,expires INTEGER,
                outcome TEXT,business_key TEXT NOT NULL, UNIQUE(sender,business_key))""")
    db.execute("CREATE UNIQUE INDEX IF NOT EXISTS one_aid_per_robot ON friend_aid(robot) WHERE phase IN ('offered','accepted','locked','returning')")
    db.execute("CREATE INDEX IF NOT EXISTS aid_recipient ON friend_aid(recipient,node,side,phase)")


def member(db,name):
    if not isinstance(name,str):
        raise Fault(400,"invalid_friend")
    row=db.execute("SELECT id FROM accounts WHERE name=?",(name.lower(),)).fetchone()
    if not row:
        raise Fault(404,"unknown_friend")
    return row[0]


def relation(db,owner,other,required=True):
    if owner==other:
        raise Fault(400,"self_friend")
    pair=sorted([owner,other])
    row=db.execute("SELECT * FROM friendships WHERE a=? AND b=?",pair).fetchone()
    if required and (not row or row["state"]!="friends"):
        raise Fault(403,"friendship_required")
    return row


def release(db,row,phase):
    db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?",(row["robot"],"aidg_"+row["id"]))
    db.execute("UPDATE friend_aid SET phase=? WHERE id=?",(phase,row["id"]))


def expire(db):
    for row in db.execute("SELECT * FROM friend_aid WHERE phase IN ('offered','accepted') AND expires IS NOT NULL AND expires<=?",(calendar.now(),)).fetchall():
        release(db,row,"expired")


def relationship(db,owner,name,action):
    other=member(db,name)
    row=relation(db,owner,other,False)
    a,b=sorted([owner,other])
    if action=="request":
        if row:
            if row["state"]=="pending" and row["proposer"]!=owner:
                raise Fault(409,"respond_to_request")
            return
        db.execute("INSERT INTO friendships VALUES (?,?,?,'pending')",(a,b,owner))
    elif action=="accept":
        if not row or row["proposer"]==owner:
            raise Fault(403,"not_invited")
        db.execute("UPDATE friendships SET state='friends' WHERE a=? AND b=?",(a,b))
    elif action=="remove" and row:
        for offer in db.execute("""SELECT * FROM friend_aid WHERE ((sender=? AND recipient=?) OR (sender=? AND recipient=?))
                AND phase IN ('offered','accepted','locked')""",(owner,other,other,owner)).fetchall():
            if offer["phase"]=="locked":
                db.execute("UPDATE friend_aid SET phase='returning' WHERE id=?",(offer["id"],))
            else:
                release(db,offer,"withdrawn")
        db.execute("DELETE FROM shared_designs WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)",(owner,other,other,owner))
        db.execute("DELETE FROM friendships WHERE a=? AND b=?",(a,b))


def get_aid(db,owner,aid):
    row=db.execute("SELECT * FROM friend_aid WHERE id=? AND (sender=? OR recipient=?)",(aid,owner,owner)).fetchone()
    if not row:
        raise Fault(404,"unknown_aid")
    return row


def base_owner(db,node=NODE):
    calendar.active(db)
    row=db.execute("SELECT owner FROM world_camps WHERE node=?",(node,)).fetchone()
    if row is None:
        raise Fault(404,"unknown_node")
    return row[0]


def offer(db,owner,fields):
    if fields.keys()!={"friend","robot","side","node","key"} or fields["side"] not in ("attacker","defender") or not isinstance(fields["node"],str) or fields["node"] not in calendar.CAMP_RESOURCES:
        raise Fault(400,"invalid_offer")
    if not all(isinstance(v,str) for v in fields.values()) or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",fields["key"]):
        raise Fault(400,"invalid_offer")
    other=member(db,fields["friend"])
    original=db.execute("SELECT * FROM friend_aid WHERE sender=? AND business_key=?",(owner,fields["key"])).fetchone()
    if original:
        if original["recipient"]!=other or original["robot"]!=fields["robot"] or original["side"]!=fields["side"] or original["node"]!=fields["node"]:
            raise Fault(409,"key_conflict")
        return original["id"]
    relation(db,owner,other)
    if db.execute("SELECT 1 FROM friend_aid WHERE robot=? AND phase IN ('offered','accepted','locked','returning')",(fields["robot"],)).fetchone():
        raise Fault(409,"aid_already_offered")
    deployment=workshop.deployment_for(workshop.owned_robots(db,owner),[fields["robot"]])
    ident=uuid.uuid4().hex
    db.execute("""INSERT INTO friend_aid(id,sender,recipient,robot,node,side,phase,points,business_key,expires)
                VALUES (?,?,?,?,?,?,'offered',?,?,?)""",(ident,owner,other,fields["robot"],fields["node"],fields["side"],deployment["points"],fields["key"],calendar.now()+86400))
    return ident


def reserved(db,recipient,side,node,grant_id=None):
    return db.execute("""SELECT * FROM friend_aid WHERE recipient=? AND side=? AND node=? AND phase='accepted'
                      AND (expires IS NULL OR expires>?) AND (grant_id IS NULL OR grant_id=?) ORDER BY rowid""",
                      (recipient,side,node,calendar.now(),grant_id)).fetchall()


def total(db,recipient,side,node=NODE,grant_id=None):
    rows=reserved(db,recipient,side,node,grant_id)
    return len(rows), sum(row["points"] for row in rows)


def attack_grant(db,owner,node,nodes):
    current=calendar.latest_entry(db,owner,node)
    if not current or current["contest_phase"]=="done":
        return None
    return current if calendar.entry_open(current,nodes,calendar.now()) else None


def check_budget(count,points):
    if count>workshop.SQUAD_CAP or points>workshop.POINT_CAP:
        raise Fault(409,"aid_budget")


def respond(db,owner,ident,action):
    row=get_aid(db,owner,ident)
    phase=row["phase"]
    if action in ("accept","reject") and row["recipient"]!=owner:
        raise Fault(403,"recipient_required")
    if action=="recall" and row["sender"]!=owner:
        raise Fault(403,"sender_required")
    if action in ("recall","reject"):
        if action=="reject" and phase not in ("offered","declined"):
            raise Fault(409,"aid_already_accepted")
        if phase=="locked":
            db.execute("UPDATE friend_aid SET phase='returning' WHERE id=?",(ident,))
        elif phase in ("accepted","offered"):
            release(db,row,"withdrawn" if action=="recall" else "declined")
        return
    if phase in ("accepted","locked","returning","complete"):
        return
    if phase!="offered":
        raise Fault(409,"offer_inactive")
    relation(db,owner,row["sender"])
    node=row["node"]
    holder=base_owner(db,node)
    if (row["side"]=="defender")!=(holder==owner) or row["sender"]==holder:
        raise Fault(409,"camp_role_changed")
    if db.execute("SELECT 1 FROM camp_contests WHERE node=? AND phase='live'",(node,)).fetchone():
        raise Fault(409,"camp_contested")
    if db.execute("""SELECT 1 FROM friend_aid WHERE node=? AND sender=? AND phase='accepted'
                     AND (side!=? OR recipient!=?)""",(node,row["sender"],row["side"],owner)).fetchone():
        raise Fault(409,"conflicting_aid")
    roster=workshop.owned_robots(db,row["sender"])
    aid=workshop.deployment_for(roster,[row["robot"]])
    recipient=workshop.owned_robots(db,owner)
    grant=None
    until=None
    if row["side"]=="defender":
        guards={r[0] for r in db.execute("SELECT robot FROM camp_garrisons WHERE node=?",(node,))}
        main=workshop.deployment_for([dict(r,task=None) for r in recipient if r["id"] in guards],list(guards)) if guards else {"points":0,"units":[]}
    else:
        current=attack_grant(db,owner,node,calendar.active(db)[1])
        if not current:
            raise Fault(409,"recipient_needs_window")
        grant=current["id"]
        until=current["cutoff_at"]
        ready=[workshop.deployment_for([r],[r["id"]]) for r in recipient if not r["task"] and r["state"]=="ready" and workshop.complete(r["slots"])]
        if not ready:
            raise Fault(409,"recipient_needs_robot")
        pending=db.execute("SELECT selected FROM camp_contests WHERE grant_id=? AND phase='pending' AND expires>?",(grant,calendar.now())).fetchone()
        main=workshop.deployment_for(recipient,json.loads(pending[0])) if pending else min(ready,key=lambda d:d["points"])
    count,points=total(db,owner,row["side"],node,grant)
    check_budget(count+1+len(main["units"]),points+aid["points"]+main["points"])
    locked=db.execute("UPDATE robots SET task='aid',assignment=? WHERE id=? AND owner=? AND task IS NULL",("aidg_"+ident,row["robot"],row["sender"]))
    if not locked.rowcount:
        raise Fault(409,"unit_unavailable")
    db.execute("UPDATE friend_aid SET phase='accepted',points=?,expires=?,grant_id=? WHERE id=?",(aid["points"],until,grant,ident))


def attach(db,row,side,deployment):
    owner=row[side]
    if not owner:
        return {}
    rows=reserved(db,owner,side,row["node"],row["grant_id"])
    check_budget(len(deployment["units"])+len(rows),deployment["points"]+sum(r["points"] for r in rows))
    command={}
    for aid in rows:
        if aid["sender"] in (row["attacker"],row["defender"]):
            raise Fault(409,"conflicting_aid")
        active=db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE id=? AND assignment=?",(aid["robot"],"aidg_"+aid["id"]))
        if not active.rowcount:
            raise Fault(409,"garrison_changed")
        squad=workshop.deployment_for(workshop.owned_robots(db,aid["sender"]),[aid["robot"]])
        deployment["units"].extend(squad["units"])
        deployment["inventory"].update(squad["inventory"])
        deployment["points"]+=squad["points"]
        deployment.setdefault("paints",{}).update(squad["paints"])
        deployment.setdefault("hull_numbers",{}).update(squad["hull_numbers"])
        deployment.setdefault("orders",{}).update(squad["orders"])
        deployment["names"][aid["robot"]]=db.execute("SELECT name FROM robots WHERE id=?",(aid["robot"],)).fetchone()[0]
        command[aid["robot"]]=aid["sender"]
        db.execute("UPDATE friend_aid SET phase='locked',battle=?,secret=? WHERE id=?",(row["id"],secrets.token_urlsafe(32),aid["id"]))
    return command


def aid_role(db,battle,secret):
    row=db.execute("SELECT sender FROM friend_aid WHERE battle=? AND secret=? AND phase IN ('locked','returning','complete')",(battle,secret)).fetchone()
    return "aid_"+row[0] if row else None


def finish(db,row,winner):
    owners=set()
    for aid in db.execute("SELECT * FROM friend_aid WHERE battle=? AND phase IN ('locked','returning')",(row["id"],)).fetchall():
        outcome="win" if aid["side"]==winner else ("draw" if winner=="draw" else "loss")
        db.execute("UPDATE friend_aid SET phase='complete',outcome=? WHERE id=?",(outcome,aid["id"]))
        if aid["sender"] not in owners:
            inventory.record(db,aid["sender"],"aid/"+row["id"],"camp_aid","aid",{},battle=row["id"],outcome=outcome)
            owners.add(aid["sender"])


def share(db,owner,friend,design):
    other=member(db,friend)
    relation(db,owner,other)
    row=db.execute("SELECT name,version,slots,chassis FROM designs WHERE owner=? AND id=?",(owner,design)).fetchone()
    if not row:
        raise Fault(404,"unknown_design")
    if storefront.positions(db,owner).get(row["name"],999999)>storefront.capacity(db,owner):
        raise Fault(409,"inactive_design")
    payload={"chassis":row["chassis"],"name":row["name"],"version":row["version"],"slots":json.loads(row["slots"])}
    db.execute("INSERT OR IGNORE INTO shared_designs VALUES (?,?,?,?,?)",(uuid.uuid4().hex,owner,other,design,json.dumps(payload)))


def preview(db,owner,row):
    definition=json.loads(row["definition"])
    # Show deficits for a new installation; installed parts stay attached to their current robots.
    free=Counter(r[0] for r in db.execute("SELECT definition FROM ("+workshop.FREE+")",(owner,)))
    needed=Counter(definition["slots"].values())
    missing=dict(needed-free)
    return dict(definition,id=row["id"],sender=row["sender"],missing=missing)


def overview(db,owner):
    pals=[dict(r) for r in db.execute("""SELECT x.name,x.id,f.state,f.proposer=? outgoing FROM friendships f
        JOIN accounts x ON x.id=CASE WHEN f.a=? THEN f.b ELSE f.a END WHERE f.a=? OR f.b=? ORDER BY x.name""",(owner,owner,owner,owner))]
    own=workshop.owned_robots(db,owner)
    aids=[]
    for r in db.execute("""SELECT a.*,s.name sender_name,t.name recipient_name,r.name robot_name FROM friend_aid a
         JOIN accounts s ON s.id=a.sender JOIN accounts t ON t.id=a.recipient JOIN robots r ON r.id=a.robot
         WHERE a.sender=? OR a.recipient=? ORDER BY (a.phase IN ('offered','accepted','locked','returning')) DESC,a.rowid DESC LIMIT 80""",(owner,owner)):
        aids.append({k:r[k] for k in ("id","sender_name","recipient_name","robot_name","node","side","phase","outcome","points")}|
                    {"outgoing":r["sender"]==owner,"admission":{"id":r["battle"],"secret":r["secret"]} if r["sender"]==owner and r["phase"] in ("locked","returning") else None})
    return {"friends":pals,"aids":aids,"shares":[preview(db,owner,r) for r in db.execute("SELECT * FROM shared_designs WHERE recipient=? ORDER BY rowid DESC",(owner,))],
            "robots":[{"id":r["id"],"name":r["name"],"ready":not r["task"] and r["state"]=="ready" and workshop.complete(r["slots"])} for r in own],
            "designs":[dict(r) for r in db.execute("""SELECT d.id,d.name,d.revision FROM designs d JOIN design_positions p ON d.owner=p.owner AND d.name=p.name
                        WHERE d.owner=? AND p.pos<=? ORDER BY d.rowid DESC""",(owner,storefront.capacity(db,owner)))]}


def handle(db,owner,method,path,body):
    action=path.removeprefix("/v1/friends").strip("/")
    if method=="GET" and not action:
        return {"social":overview(db,owner)}
    if method!="POST" or not all(isinstance(v,str) for v in body.values()):
        raise Fault(400,"invalid_parameters")
    if action in ("request","accept","remove") and body.keys()=={"friend"}:
        relationship(db,owner,body["friend"],action)
    elif action=="visit" and body.keys()=={"friend"}:
        other=member(db,body["friend"])
        relation(db,owner,other)
        row=db.execute("SELECT layout FROM bases WHERE owner=?",(other,)).fetchone()
        import plaques
        layout=private_base.check(json.loads(row[0]))
        layout["plaque"]=plaques.inscription(db,other)
        return {"visit":{"name":body["friend"],"layout":layout}}
    elif action=="share" and body.keys()=={"friend","design"}:
        share(db,owner,body["friend"],body["design"])
    elif action=="save" and body.keys()=={"share","key"}:
        row=db.execute("SELECT * FROM shared_designs WHERE id=? AND recipient=?",(body["share"],owner)).fetchone()
        if not row:
            raise Fault(404,"unknown_share")
        relation(db,owner,row["sender"])
        return {"receipt":workshop.operate(db,owner,"design",dict(json.loads(row["definition"]),key=body["key"])),"social":overview(db,owner)}
    elif action=="offer":
        ident=offer(db,owner,body)
        return {"aid":ident,"social":overview(db,owner)}
    elif action in ("accept-aid","reject-aid","recall") and body.keys()=={"aid"}:
        respond(db,owner,body["aid"],{"accept-aid":"accept","reject-aid":"reject","recall":"recall"}[action])
    else:
        raise Fault(400,"invalid_parameters")
    return {"social":overview(db,owner)}
