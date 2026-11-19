"""M18 world calendar. All admission checks use UTC server time inside the caller's transaction."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import time
import uuid

from inventory import Fault

DAY = 86400
ROUTES = {"party","camp"}
LIVE_CAMP = "brass-yard"
CAMP_SITES=json.loads(Path(__file__).with_name("config").joinpath("territories.json").read_text(encoding="utf8"))
CAMP_RESOURCES={node:site["resource"] for node,site in CAMP_SITES.items()}


def now():
    return int(time.time())


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS world_schedules
               (version INTEGER PRIMARY KEY, digest TEXT NOT NULL, payload TEXT NOT NULL, published INTEGER NOT NULL)""")
    db.execute("CREATE TABLE IF NOT EXISTS world_camps(node TEXT PRIMARY KEY, owner TEXT REFERENCES accounts(id))")
    db.execute("""CREATE TABLE IF NOT EXISTS world_admissions(id TEXT PRIMARY KEY,owner TEXT REFERENCES accounts(id),
               node TEXT NOT NULL,window_version INTEGER NOT NULL,opens_at INTEGER NOT NULL,cutoff_at INTEGER NOT NULL,
               closes_at INTEGER NOT NULL,settle_until INTEGER NOT NULL)""")
    db.execute("CREATE INDEX IF NOT EXISTS world_owner_windows ON world_admissions(owner,node,opens_at)")
    db.execute("""CREATE TABLE IF NOT EXISTS world_requests(owner TEXT REFERENCES accounts(id),business_key TEXT,
               admission TEXT NOT NULL REFERENCES world_admissions(id),PRIMARY KEY(owner,business_key))""")
    db.execute("""CREATE TABLE IF NOT EXISTS world_battles(admission TEXT PRIMARY KEY REFERENCES world_admissions(id),
               battle TEXT NOT NULL,started_at INTEGER NOT NULL)""")


def upgrade_repeat_entries(db):
    old_sql=db.execute("SELECT sql FROM sqlite_master WHERE name='world_admissions'").fetchone()[0]
    if "unique(owner,node,opens_at)" not in "".join(old_sql.lower().split()):
        return
    # Copy dependent rows before replacing their referenced table, retaining issue order and all keys.
    tables=("world_admissions","world_requests","world_battles")
    for table in tables:
        db.execute("CREATE TEMP TABLE retained_"+table+" AS SELECT * FROM "+table+" ORDER BY rowid")
    for table in reversed(tables):
        db.execute("DROP TABLE "+table)
    schema(db)
    for table in tables:
        db.execute("INSERT INTO "+table+" SELECT * FROM retained_"+table+" ORDER BY rowid")
        db.execute("DROP TABLE retained_"+table)


def latest_entry(db,owner,node):
    return db.execute("""SELECT a.*,c.phase contest_phase FROM world_admissions a
                      LEFT JOIN camp_contests c ON c.grant_id=a.id AND c.attacker=a.owner
                      WHERE a.owner=? AND a.node=? ORDER BY a.rowid DESC LIMIT 1""",(owner,node)).fetchone()


def validate(config):
    if not isinstance(config,dict) or set(config)!={"nodes"} or not isinstance(config["nodes"],list) or not 1<=len(config["nodes"])<=64:
        raise ValueError("nodes must contain 1 to 64 entries")
    ids=set()
    for node in config["nodes"]:
        if not isinstance(node,dict):
            raise ValueError("invalid map node")
        kind=node.get("type")
        common={"id","type","name","resource","x","y"}
        if not isinstance(kind,str) or kind not in ROUTES or set(node)!=(common | ({"daily","settlement_grace"} if kind=="camp" else set())):
            raise ValueError("invalid node fields or type")
        ident=node["id"]
        if not isinstance(ident,str) or not re.fullmatch(r"[a-z][a-z0-9-]{1,39}",ident) or ident in ids:
            raise ValueError("duplicate or invalid node ID")
        ids.add(ident)
        if any(not isinstance(node[k],str) or not 1<=len(node[k].strip())<=45 for k in ("name","resource")):
            raise ValueError("invalid map label")
        if any(type(node[k]) not in (int,float) or not 0<=node[k]<=1 for k in ("x","y")):
            raise ValueError("coordinates must be in normalized map space")
        if kind=="party":
            continue
        slots=node["daily"]
        if type(node["settlement_grace"]) is not int or not 0<=node["settlement_grace"]<=86400:
            raise ValueError("invalid settlement grace")
        if not isinstance(slots,list) or not 1<=len(slots)<=96:
            raise ValueError("daily windows missing")
        spans=[]
        for slot in slots:
            if not isinstance(slot,list) or len(slot)!=3 or not all(type(s) is int for s in slot):
                raise ValueError("window must be [open, cutoff, close] in UTC seconds from midnight")
            start,cutoff,close=slot
            if not 0<=start<DAY or not start<=cutoff<=close<=start+DAY or start==close:
                raise ValueError("window ordering must satisfy open <= cutoff <= close")
            spans.extend([(start,close),(start+DAY,close+DAY)])
        spans.sort()
        if any(a[1]>b[0] for a,b in zip(spans,spans[1:])):
            raise ValueError("overlapping windows including midnight boundary")


def config_path():
    return Path(os.environ.get("WORLD_CALENDAR_FILE",Path(__file__).with_name("config")/"calendar.json"))


def publish(db, raw):
    schema(db)
    data=json.loads(raw)
    validate(data)
    canonical=json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    digest=hashlib.sha256(canonical.encode()).hexdigest()
    prior=db.execute("SELECT version,digest FROM world_schedules ORDER BY version DESC LIMIT 1").fetchone()
    if prior and prior["digest"]==digest:
        return prior["version"]
    version=(prior["version"] if prior else 0)+1
    db.execute("INSERT INTO world_schedules VALUES (?,?,?,?)",(version,digest,canonical,now()))
    for node in data["nodes"]:
        if node["type"]=="camp":
            db.execute("INSERT OR IGNORE INTO world_camps(node) VALUES (?)",(node["id"],))
    return version


def active(db):
    schema(db)
    try:
        publish(db,config_path().read_text(encoding="utf-8-sig"))
    except (OSError,ValueError) as error:
        if not db.execute("SELECT 1 FROM world_schedules LIMIT 1").fetchone():
            raise Fault(503,"world_configuration_unavailable") from error
    row=db.execute("SELECT version,payload FROM world_schedules ORDER BY version DESC LIMIT 1").fetchone()
    return row["version"],json.loads(row["payload"])["nodes"]


def windows(node,stamp):
    midnight=(stamp//DAY)*DAY
    times=sorted((midnight+day*DAY+start,midnight+day*DAY+cut,midnight+day*DAY+end)
                 for day in (-1,0,1,2) for start,cut,end in node["daily"])
    current=next((w for w in times if w[0]<=stamp<w[2]),None)
    after=next(w for w in times if w[0]>stamp)
    def fields(w):
        return {"opens_at":w[0],"cutoff_at":w[1],"closes_at":w[2]}
    return {"state":"closed" if not current else ("open" if stamp<current[1] else "cutoff"),
            "current":fields(current) if current else None,"next":fields(after)}


def view(db,owner):
    version,nodes=active(db)
    stamp=now()
    output=[]
    cards={}
    for node in nodes:
        item={k:node[k] for k in ("id","type","name","resource","x","y")}
        if item["type"]=="camp":
            item["contest_available"] = item["id"] in CAMP_RESOURCES
            item["resource_key"]=CAMP_RESOURCES.get(item["id"])
            row=db.execute("""SELECT c.owner,a.name FROM world_camps c LEFT JOIN accounts a ON a.id=c.owner
                           WHERE c.node=?""",(item["id"],)).fetchone()
            if row["owner"] and item["contest_available"]:
                owner_id = row["owner"]
                if owner_id not in cards:
                    shared = db.execute("""SELECT p.name FROM public_plaque s JOIN battle_plaques p
                        ON p.id=s.plaque AND p.owner=s.owner AND p.displayed=1 WHERE s.owner=?""",(owner_id,)).fetchone()
                    cards[owner_id] = {"name":row["name"], "holdings":[], "inscription":shared["name"] if shared else None}
                card = cards[owner_id]
                card["holdings"].append({"node":item["id"], "name":item["name"], "resource":item["resource"]})
                item["workshop_card"] = card
            grant=latest_entry(db,owner,item["id"])
            completed=grant is not None and grant["contest_phase"]=="done"
            active_grant=grant and not completed and grant["settle_until"]>stamp
            item.update(windows(node,stamp),owner=row["name"],mine=row["owner"]==owner,
                        admission=dict(grant) if active_grant else None,completed_grant=grant["id"] if completed else None)
            item["contested"]=bool(db.execute("SELECT 1 FROM camp_contests WHERE node=? AND phase='live'",(item["id"],)).fetchone())
        output.append(item)
    return {"server_time":stamp,"version":version,"nodes":output}


def admit(db,owner,node_id,business_key):
    if not isinstance(business_key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",business_key) or not isinstance(node_id,str):
        raise Fault(400,"invalid_parameters")
    schema(db)
    original=db.execute("""SELECT a.* FROM world_requests r JOIN world_admissions a ON a.id=r.admission
                        WHERE r.owner=? AND r.business_key=?""",(owner,business_key)).fetchone()
    if original:
        if original["node"]!=node_id:
            raise Fault(409,"key_conflict")
        return dict(original)
    version,nodes=active(db)
    node=next((n for n in nodes if n["id"]==node_id),None)
    if not node:
        raise Fault(404,"unknown_node")
    if node["type"]!="camp":
        raise Fault(409,"non_occupiable")
    if node_id not in CAMP_RESOURCES:
        raise Fault(409,"camp_preview_only")
    current=windows(node,now())
    if current["state"]!="open":
        raise Fault(409,"entry_cutoff" if current["state"]=="cutoff" else "camp_closed")
    window=current["current"]
    previous=latest_entry(db,owner,node_id)
    if previous and previous["opens_at"]==window["opens_at"] and previous["contest_phase"]!="done":
        ident=previous["id"]
    else:
        ident=uuid.uuid4().hex
        db.execute("INSERT INTO world_admissions VALUES (?,?,?,?,?,?,?,?)",
                   (ident,owner,node_id,version,window["opens_at"],window["cutoff_at"],window["closes_at"],
                    window["closes_at"]+node["settlement_grace"]))
    db.execute("INSERT INTO world_requests VALUES (?,?,?)",(owner,business_key,ident))
    return dict(db.execute("SELECT * FROM world_admissions WHERE id=?",(ident,)).fetchone())


def entry_open(grant,nodes,stamp):
    node=next((n for n in nodes if n["id"]==grant["node"] and n["type"]=="camp"),None)
    rule=windows(node,stamp) if node else None
    return bool(rule and rule["state"]=="open" and rule["current"]["opens_at"]==grant["opens_at"] and stamp<grant["cutoff_at"])


def qualification(db,owner,ident,*,for_entry=False):
    schema(db)
    row=db.execute("SELECT * FROM world_admissions WHERE owner=? AND id=?",(owner,ident)).fetchone()
    if not row:
        raise Fault(404,"unknown_admission")
    stamp=now()
    if for_entry and not entry_open(row,active(db)[1],stamp):
        raise Fault(409,"entry_cutoff")
    if stamp>=row["settle_until"]:
        raise Fault(409,"qualification_expired")
    return dict(row)

def bind_battle(db,owner,grant_id,battle_id):
    """Call inside M19's new encounter transaction. A pre-registered ticket alone cannot start after cutoff."""
    if not isinstance(battle_id,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",battle_id):
        raise Fault(400,"invalid_battle")
    grant=qualification(db,owner,grant_id)
    prior=db.execute("SELECT battle,started_at FROM world_battles WHERE admission=?",(grant_id,)).fetchone()
    if prior:
        if prior["battle"]!=battle_id:
            raise Fault(409,"admission_used")
        return {**grant,**dict(prior)}
    _,nodes=active(db)
    stamp=now()
    if not entry_open(grant,nodes,stamp):
        raise Fault(409,"entry_cutoff")
    db.execute("INSERT INTO world_battles VALUES (?,?,?)",(grant_id,battle_id,stamp))
    return dict(grant,battle=battle_id,started_at=stamp)


def settlement_qualification(db,owner,grant_id,battle_id,finished_at):
    """Only M19's trusted result consumer supplies the actual finish timestamp for delayed delivery."""
    schema(db)
    row=db.execute("""SELECT a.*,b.battle,b.started_at FROM world_admissions a JOIN world_battles b
                   ON a.id=b.admission WHERE a.id=? AND a.owner=? AND b.battle=?""",(grant_id,owner,battle_id)).fetchone()
    if not row:
        raise Fault(404,"unknown_battle_admission")
    if type(finished_at) is not int or not row["started_at"]<=finished_at<row["settle_until"] or finished_at>now():
        raise Fault(409,"qualification_expired")
    return dict(row)


def set_owner(db,node,account_id):
    if not db.execute("UPDATE world_camps SET owner=? WHERE node=?",(account_id,node)).rowcount:
        raise Fault(404,"unknown_camp")


def handle(db,owner,method,route,body):
    if route=="/v1/world" and method=="GET":
        return {"world":view(db,owner)}
    if method=="GET" and route.startswith("/v1/world/admissions/"):
        return {"admission":qualification(db,owner,route.rsplit("/",1)[1])}
    if route=="/v1/world/admit" and method=="POST" and body.keys()=={"node","key"}:
        return {"admission":admit(db,owner,body["node"],body["key"]),"world":view(db,owner)}
    raise Fault(400,"invalid_parameters")


if __name__=="__main__":
    from server import transaction
    cli=argparse.ArgumentParser(description="Validate and apply the mounted M18 world calendar")
    cli.add_argument("--db",default="/data/player.sqlite")
    args=cli.parse_args()
    try:
        with transaction(args.db) as db:
            print("world_calendar_version",publish(db,config_path().read_text(encoding="utf-8-sig")))
    except (ValueError,OSError) as exc:
        cli.exit(1,"world calendar rejected: "+str(exc)+"\n")
