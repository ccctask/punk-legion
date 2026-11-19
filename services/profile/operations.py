"""Separate loopback-only operator service. Credentials are provisioned outside the game and database."""
from contextlib import closing
import sqlite3
import argparse
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import time

import inventory
import server

IDENT=re.compile(r"[A-Za-z0-9_-]{8,96}")
REASONS={"missed_reward","rollback_reconciliation","duplicate_charge"}
LOCATIONS={"SOLO_SPOOL_DIR":"solo","PARTY_SPOOL_DIR":"party","CAMP_SPOOL_DIR":"camp","ROOM_OUTBOX_DIR":"room"}


def validate_id(value):
    if not isinstance(value,str) or not IDENT.fullmatch(value):
        raise inventory.Fault(400,"invalid_reference")


def authenticate(policy,header):
    if not header.startswith("Bearer "):
        raise inventory.Fault(401,"operator_auth_required")
    digest=hashlib.sha256(header[7:].encode()).hexdigest()
    for user,row in policy.items():
        if hmac.compare_digest(row["sha256"],digest):
            return user,row["role"]
    raise inventory.Fault(401,"operator_auth_required")


def battle(db,ident):
    validate_id(ident)
    matches={}
    for table,name,columns in [
        ("expeditions","solo","id,owner,result AS outcome,expires"),
        ("treasure_rooms","treasure","id,event,deadline,done"),
        ("camp_contests","camp","id,attacker,defender,phase,revision,expires"),
        ("wild_raids","raid","id,owner,outcome,starts"),
        ("parties","party","id,phase")]:
        if db.execute("SELECT 1 FROM sqlite_master WHERE name=?",(table,)).fetchone():
            row=db.execute(f"SELECT {columns} FROM {table} WHERE id=?",(ident,)).fetchone()
            if row:matches[name]=dict(row)
    actors=[dict(r) for r in db.execute("""SELECT r.owner,s.robot,s.outcome,s.result_digest IS NULL AS unsettled
        FROM robot_sorties s JOIN robots r ON r.id=s.robot WHERE s.battle=?""",(ident,))]
    if "party" in matches:
        actors.extend(dict(r) for r in db.execute("SELECT owner FROM party_members WHERE group_id=?",(ident,)))
    receipts=[dict(r) for r in db.execute("""SELECT id,owner,operation FROM receipts WHERE json_extract(body,'$.battle')=?
        OR json_extract(body,'$.mission')=? OR json_extract(body,'$.raid')=? OR json_extract(body,'$.incident')=?""",
        (ident,ident,ident,ident))]
    evidence={}
    for env,service in LOCATIONS.items():
        if not os.environ.get(env):continue
        folder=Path(os.environ[env])
        names=[suffix for suffix in (".save",".progress.json",".result.json",".json") if (folder/(ident+suffix)).is_file()]
        if names:evidence[service]=names
    if not matches and not actors and not receipts and not evidence:
        raise inventory.Fault(404,"unknown_incident")
    return dict(battle=ident,records=matches,actors=actors,receipts=receipts,evidence=evidence)


def dispatch(path,policy,auth,method,route,fields):
    operator,role=authenticate(policy,auth)
    if method=="GET" and route.startswith("/ops/battles/"):
        uri=Path(path).resolve().as_uri()+"?mode=ro"
        with closing(sqlite3.connect(uri,uri=True,timeout=8)) as db:
            db.row_factory=sqlite3.Row
            db.execute("BEGIN")
            return battle(db,route.removeprefix("/ops/battles/"))
    if method!="POST" or route!="/ops/compensations":
        raise inventory.Fault(404,"unknown_route")
    if role!="compensator":raise inventory.Fault(403,"compensation_role_required")
    with server.transaction(path) as db:
        if fields.keys()!={"owner","incident","reason","key","resource","amount"}:
            raise inventory.Fault(400,"invalid_parameters")
        owner,incident,key=(fields[k] for k in ("owner","incident","key"))
        for ref in (owner,incident,key):validate_id(ref)
        resource,amount,reason=(fields[k] for k in ("resource","amount","reason"))
        if not isinstance(reason,str) or reason not in REASONS or not isinstance(resource,str) or resource not in inventory.STOCK or type(amount)is not int or not 1<=amount<=3:
            raise inventory.Fault(400,"invalid_compensation")
        signature=json.dumps(fields,sort_keys=True)
        previous=inventory.previous(db,owner,"ops/"+key,signature)
        if previous:return {"receipt":previous}
        incident_row=battle(db,incident)
        owners={r["owner"] for r in incident_row["actors"]+incident_row["receipts"]}
        for rec in incident_row["records"].values():
            owners.update(rec.get(k) for k in ("owner","attacker","defender"))
        if owner not in owners:raise inventory.Fault(409,"account_not_in_battle")
        if db.execute("""SELECT 1 FROM receipts WHERE owner=? AND operation='ops_credit' AND
            json_extract(body,'$.incident')=? AND json_extract(body,'$.reason')=?""",(owner,incident,reason)).fetchone():
            raise inventory.Fault(409,"already_compensated")
        changes=inventory.apply_stock(db,owner,{resource:amount})
        if not changes.get(resource):raise inventory.Fault(409,"storage_full")
        receipt=inventory.record(db,owner,"ops/"+key,"ops_credit",signature,changes,operator=operator,incident=incident,
            reason=reason,requested=amount,resource=resource,at=int(time.time()))
        return {"receipt":receipt}


class Handler(BaseHTTPRequestHandler):
    def log_message(self,*_args): pass

    def request_action(self):
        try:
            length=int(self.headers.get("Content-Length","0"))
            if not 0<=length<=4096:raise inventory.Fault(400,"request_size")
            fields=json.loads(self.rfile.read(length)) if length else {}
            if not isinstance(fields,dict):raise inventory.Fault(400,"invalid_parameters")
            data=dispatch(self.server.db,self.server.policy,self.headers.get("Authorization",""),self.command,self.path,fields)
            status=200
        except inventory.Fault as err:
            status,data=err.status,{"error":err.code}
        except (ValueError,UnicodeError):
            status,data=400,{"error":"invalid_request"}
        if status>=400:
            action="compensate" if self.path=="/ops/compensations" else "diagnose" if self.path.startswith("/ops/battles/") else "other"
            print(json.dumps({"event":"operator_request_rejected","at":int(time.time()),"action":action,
                              "status":status,"reason":data["error"]}),flush=True)
        body=json.dumps(data).encode()
        self.send_response(status);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
    do_POST=do_GET=request_action


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--db",required=True);p.add_argument("--policy",required=True);p.add_argument("--port",type=int,default=24679)
    args=p.parse_args();policy=json.loads(Path(args.policy).read_text(encoding="utf8"))
    if not policy or any(not re.fullmatch(r"[\w.-]{1,32}",name) or item.get("role") not in ("viewer","compensator")
            or not re.fullmatch("[0-9a-f]{64}",item.get("sha256","")) for name,item in policy.items()):
        p.error("invalid operator policy")
    if not Path(args.db).is_file():p.error("existing archive database required")
    with ThreadingHTTPServer(("127.0.0.1",args.port),Handler) as service:
        service.db=args.db;service.policy=policy;service.serve_forever()


