"""Permanent factory escort, personal southern land and limited daily supplies."""
import json
import time

import inventory
import private_base

ACTIVITY = "factory_escort"
EVENT = "sealed-factory"


def schema(db):
    db.execute("""CREATE TABLE factory_groups(gid TEXT PRIMARY KEY REFERENCES parties(id),
        mode TEXT NOT NULL CHECK(mode IN ('solo','coop')),seed INTEGER NOT NULL)""")
    db.execute("""CREATE TABLE factory_entries(mission TEXT PRIMARY KEY REFERENCES expeditions(id),day TEXT NOT NULL)""")
    db.execute("""CREATE TABLE factory_rewards(owner TEXT REFERENCES accounts(id),day TEXT,
        mission TEXT UNIQUE REFERENCES expeditions(id),PRIMARY KEY(owner,day))""")


def day():
    return time.strftime("%Y-%m-%d",time.gmtime(time.time()))


def layout_for(db,owner):
    row=db.execute("SELECT layout FROM bases WHERE owner=?",(owner,)).fetchone()
    return json.loads(row[0]) if row else {}


def quote(db,owner):
    layout=layout_for(db,owner)
    used=db.execute("SELECT 1 FROM factory_rewards WHERE owner=? AND day=?",(owner,day())).fetchone()
    return dict(id=EVENT,unlocked=bool(layout.get("rustrail_east")),south_unlocked=bool(layout.get("factory_south")),
                reward_available=int(not used))


def require_access(db,owner):
    if not layout_for(db,owner).get("rustrail_east"):
        raise inventory.Fault(403,"requires_east_land")


def require_friend(db,owner,leader):
    if owner!=leader and not db.execute("SELECT 1 FROM friendships WHERE a=? AND b=? AND state='friends'",
                                        tuple(sorted((owner,leader)))).fetchone():
        raise inventory.Fault(403,"friends_required")


def reward(db,owner,mission,opened_day,outcome,participated):
    first=False
    grant=False
    if participated and outcome=="win":
        layout=layout_for(db,owner)
        if not layout.get("factory_south"):
            layout["factory_south"]=True
            layout["revision"]+=1
            private_base.save_layout(db,owner,layout)
            first=True
        grant=bool(db.execute("INSERT OR IGNORE INTO factory_rewards VALUES(?,?,?)",(owner,opened_day,mission)).rowcount)
    return dict(first_clear=first,daily_award=grant,
                changes=inventory.apply_stock(db,owner,{"structure":1}) if grant else {"structure":0})
