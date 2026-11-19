"""Personal PvE pump ruin windows, instance identity and bounded daily rewards."""
import hashlib
import os
import re
import time
import uuid

import inventory
import recovery
from inventory import Fault

PERIOD = 1800
DURATION = 1200
SITES = (("雾桥泵站", .32, .69), ("铁杉泵站", .71, .72), ("高架泵站", .56, .28))


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS pump_groups(
        gid TEXT PRIMARY KEY REFERENCES parties(id),event TEXT NOT NULL,seed INTEGER NOT NULL,
        mode TEXT NOT NULL CHECK(mode IN ('solo','coop')))""")
    db.execute("""CREATE TABLE IF NOT EXISTS pump_entries(
        mission TEXT PRIMARY KEY REFERENCES expeditions(id),day TEXT NOT NULL)""")
    db.execute("""CREATE TABLE IF NOT EXISTS pump_rewards(
        owner TEXT REFERENCES accounts(id),day TEXT,mission TEXT UNIQUE REFERENCES expeditions(id),
        PRIMARY KEY(owner,day))""")
    db.execute("""CREATE TABLE pump_recovered_arms(owner TEXT PRIMARY KEY REFERENCES accounts(id),
        mission TEXT NOT NULL UNIQUE REFERENCES expeditions(id), part_id TEXT UNIQUE)""")


def recovered_arm(db,owner):
    row=db.execute("SELECT mission,part_id FROM pump_recovered_arms WHERE owner=?",(owner,)).fetchone()
    if not row:
        return dict(status="unearned",part_id="",mission="")
    return dict(status="delivered" if row["part_id"] else "pending", part_id=row["part_id"] or "",mission=row["mission"])


def deliver_arm(db,owner):
    free_parts=db.execute("SELECT COUNT(*) FROM ("+inventory.FREE_PARTS+")",(owner,)).fetchone()[0]
    if free_parts>=inventory.PART_CAP:
        return None
    ident=uuid.uuid4().hex
    db.execute("INSERT INTO parts VALUES (?,?,?)",(ident,owner,"repair_arm"))
    db.execute("UPDATE pump_recovered_arms SET part_id=? WHERE owner=?",(ident,owner))
    return dict(id=ident,definition="repair_arm")


def claim_arm(db,owner,fields):
    if fields.keys()!={"key"} or not isinstance(fields["key"],str) or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",fields["key"]):
        raise Fault(400,"invalid_parameters")
    action="pump_arm_claim"
    prior=inventory.previous(db,owner,fields["key"],action)
    if prior:
        return prior
    recovered=recovered_arm(db,owner)
    if recovered["status"]!="pending":
        raise Fault(409,"no_pending_pump_arm")
    part=deliver_arm(db,owner)
    if not part:
        raise Fault(409,"parts_full")
    return inventory.record(db,owner,fields["key"],action,action,{},part=part,mission=recovered["mission"])


def event(now=None):
    now = time.time() if now is None else now
    epoch = int(os.environ.get("PUMP_EPOCH", "0"))
    start = epoch + int((now-epoch)//PERIOD)*PERIOD
    seed = int.from_bytes(hashlib.sha256(f"pump:{start}".encode()).digest()[:4],"big")
    name,x,y = SITES[seed % len(SITES)]
    return dict(id=f"pump_{start}",type="pump_ruin",name=name,x=x,y=y,seed=seed,
                opens=start,closes=start+DURATION,next=start+PERIOD,active=now<start+DURATION,
                utc_day=time.strftime("%Y-%m-%d",time.gmtime(now)))


def require_window(event_id):
    current=event()
    if current["id"]!=event_id or not current["active"]:
        raise Fault(409,"pump_closed")
    return current


def quote(db,owner):
    current=event()
    awarded=db.execute("SELECT 1 FROM pump_rewards WHERE owner=? AND day=?",(owner,current["utc_day"])).fetchone()
    amount=db.execute("SELECT amount FROM stocks WHERE owner=? AND resource='components'",(owner,)).fetchone()[0]
    reward=0 if awarded else 2
    return current | dict(reward_available=reward,expected_components=min(reward,inventory.STOCK["components"][1]-amount),
                          departure_quote=recovery.entry_quote(db,owner),recovered_arm=recovered_arm(db,owner))


def group(db,gid):
    return db.execute("SELECT * FROM pump_groups WHERE gid=?",(gid,)).fetchone()


def validate_squad(mode,deployment):
    if mode=="coop" and (len(deployment["units"])>6 or deployment["points"]>12):
        raise Fault(409,"team_budget")


def reward(db,owner,mission,day,outcome,participated):
    first=False
    first_clear=False
    if outcome=="win" and participated:
        first=bool(db.execute("INSERT OR IGNORE INTO pump_rewards VALUES(?,?,?)",(owner,day,mission)).rowcount)
        first_clear=bool(db.execute("INSERT INTO pump_recovered_arms(owner,mission) VALUES(?,?) ON CONFLICT(owner) DO NOTHING",
                                   (owner,mission)).rowcount)
        if first_clear:
            deliver_arm(db,owner)
    changes=inventory.apply_stock(db,owner,{"components":2}) if first else {"components":0}
    return dict(changes=changes,reward_day=day,first_daily=first,reward_available=2 if first else 0,
                first_clear=first_clear,recovered_arm=recovered_arm(db,owner))
