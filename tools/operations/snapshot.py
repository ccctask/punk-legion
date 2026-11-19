"""Quiescent, checksum-verified backup/restore for local PunkLegion Compose projects."""
import argparse
import json
from pathlib import Path
import subprocess
import sqlite3
import hashlib
import zipfile
from contextlib import closing
import tempfile
import time

ROOT=Path(__file__).resolve().parents[2]
VOLUMES={"player-profiles","room-results","solo-missions","party-missions","camp-battles"}
SERVICES={"profile","room","expedition","party","camp","treasure"}
WORKER=Path(__file__).with_name("volume_archive.py")

def docker(*args,input=None):
    return subprocess.check_output(["docker",*map(str,args)],cwd=ROOT,input=input,encoding="utf8",errors="replace").strip()


def compose(project,*args):
    return docker("compose","-p",project,*args)


def inspect_project(project):
    ids=compose(project,"ps","--all","--quiet").split()
    if not ids:raise ValueError("no containers in requested Compose project")
    containers=json.loads(docker("inspect",*ids))
    services={};volumes={}
    for c in containers:
        labels=c["Config"]["Labels"]
        if labels.get("com.docker.compose.project")!=project:raise ValueError("wrong Compose project")
        service=labels.get("com.docker.compose.service")
        if service not in SERVICES:raise ValueError("unexpected service "+str(service))
        services[service]={"image":c["Image"],"running":c["State"]["Running"]}
        for mount in c["Mounts"]:
            if mount["Type"]!="volume":continue
            name=mount["Name"];logical=name.removeprefix(project+"_")
            if logical in VOLUMES:
                volume=json.loads(docker("volume","inspect",name))[0]
                if volume["Labels"].get("com.docker.compose.project")!=project:raise ValueError("unexpected shared volume")
                volumes[logical]=name
    if "profile" not in services or volumes.keys()!=VOLUMES:
        raise ValueError("profile and all five profile/authoritative volumes required")
    return services,volumes


def launch_worker(image,volumes,bundle,action):
    args=["run","--rm","-i","--network","none","--mount",f"type=bind,source={bundle},target=/bundle"+(",readonly" if action=="restore" else "")]
    for logical,name in volumes.items():
        args.extend(["--mount",f"type=volume,source={name},target=/state/{logical}"+(",readonly" if action=="capture" else "")])
    args.extend(["--entrypoint","python",image,"-",action])
    return json.loads(docker(*args,input=WORKER.read_text(encoding="utf8")))


def capture(project,bundle):
    bundle=Path(bundle).resolve()
    if bundle.exists():raise ValueError("new backup directory required")
    services,volumes=inspect_project(project)
    running=[s for s,v in services.items() if v["running"]]
    bundle.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".pl-capture-",dir=bundle.parent) as work:
        staging=Path(work)/"snapshot";staging.mkdir()
        try:
            workers=[s for s in running if s!="profile"]
            if workers:compose(project,"stop","-t","10",*workers)
            if "profile" in running:compose(project,"stop","-t","10","profile")
            frozen_at=int(time.time())
            if any(v["running"] for v in inspect_project(project)[0].values()):raise ValueError("writers still running")
            # Named volumes must have no active writer from any other helper/project.
            for name in volumes.values():
                if docker("ps","-q","--filter","volume="+name):raise ValueError("active volume user: "+name)
            result=launch_worker(services["profile"]["image"],volumes,staging,"capture")
            manifest=dict(format=1,captured=frozen_at,project=project,services=services,**result)
            (staging/"manifest.json").write_text(json.dumps(manifest,sort_keys=True,indent=2),encoding="utf8")
            staging.rename(bundle)
        finally:
            if "profile" in running:compose(project,"start","profile")
            workers=[s for s in running if s!="profile"]
            if workers:compose(project,"start",*workers)
    return manifest


def restore(project,bundle):
    bundle=Path(bundle).resolve()
    manifest=json.loads((bundle/"manifest.json").read_text(encoding="utf8"))
    services,volumes=inspect_project(project)
    if project==manifest["project"] or any(v["running"] for v in services.values()):
        raise ValueError("restore to a different, stopped project")
    for name in volumes.values():
        if docker("ps","-q","--filter","volume="+name):raise ValueError("target volume in use")
    result=launch_worker(services["profile"]["image"],volumes,bundle,"restore")
    return dict(restored=project,schema=result["schema"],receipt_count=result["receipt_count"])


def shop_ledger(db):
    """Read and verify the storefront's separate append-only event history."""
    tables={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if not tables.intersection({"shop_orders","shop_events"}):
        return {},{}
    if not {"shop_orders","shop_events"}.issubset(tables):
        raise ValueError("incomplete shop ledger")
    orders={}
    current={}
    for oid,owner,intent,sku,price,state,created in db.execute("SELECT id,owner,intent,sku,price,state,created FROM shop_orders"):
        orders[oid]=(owner,intent,sku,price,created)
        current[oid]=state
    states={}
    events={}
    transitions={None:{"created"},"created":{"paid","cancelled","failed"},"paid":{"delivered","refunded"},"delivered":{"refunded"}}
    for eid,oid,state,at in db.execute("SELECT id,order_id,state,at FROM shop_events ORDER BY id"):
        if oid not in orders or state not in transitions.get(states.get(oid),set()):
            raise ValueError("invalid shop event sequence")
        states[oid]=state
        events[eid]=(oid,state,at)
    if states!=current:
        raise ValueError("order state disagrees with shop events")
    if "robot_paint" in tables and db.execute("""SELECT 1 FROM robot_paint p LEFT JOIN robots r ON r.id=p.robot
        WHERE r.owner IS NULL OR p.paint NOT IN ('mint','base') OR (p.paint='mint' AND NOT EXISTS
        (SELECT 1 FROM shop_orders o WHERE o.owner=r.owner AND o.sku='paint_mint' AND o.state='delivered')) LIMIT 1""").fetchone():
        raise ValueError("equipped paint has no delivered entitlement")
    return orders,events


def reconcile(earlier,later):
    """Compare immutable receipts and shop events without exporting private payloads."""
    def ledger(bundle):
        bundle=Path(bundle)
        manifest=json.loads((bundle/"manifest.json").read_text(encoding="utf8"))
        archive=bundle/"player-profiles.zip"
        with archive.open("rb") as stream:
            if hashlib.file_digest(stream,"sha256").hexdigest()!=manifest["volumes"]["player-profiles"]["sha256"]:
                raise ValueError("database archive checksum mismatch")
        with tempfile.TemporaryDirectory() as directory,zipfile.ZipFile(archive) as z:
            db_path=Path(directory)/"player.sqlite"
            # SQLite can use journal or WAL sidecars present at the quiescent boundary.
            for name in ["player.sqlite","player.sqlite-wal","player.sqlite-shm","player.sqlite-journal"]:
                if name in z.namelist():(Path(directory)/name).write_bytes(z.read(name))
            with closing(sqlite3.connect(db_path)) as db:
                receipts={rid:(op,hashlib.sha256(body.encode()).hexdigest()) for rid,op,body in db.execute("SELECT id,operation,body FROM receipts")}
                return receipts,*shop_ledger(db)
    old,old_orders,old_events=ledger(earlier)
    new,new_orders,new_events=ledger(later)
    for previous,current in ((old,new),(old_orders,new_orders),(old_events,new_events)):
        if any(k not in current or v!=current[k] for k,v in previous.items()):
            raise ValueError("divergent or altered ledger; manual review required")
    if old_events and any(e<=max(old_events) for e in new_events.keys()-old_events.keys()):
        raise ValueError("shop history is not append-only")
    changes=[{"id":k,"operation":new[k][0]} for k in sorted(new.keys()-old.keys())]
    for eid in sorted(new_events.keys()-old_events.keys()):
        oid,state,_at=new_events[eid]
        changes.append({"id":oid,"operation":"shop_"+state,"event":eid,"sku":new_orders[oid][2]})
    return changes


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("action",choices=["capture","restore","reconcile"]);p.add_argument("--project");p.add_argument("--bundle",required=True);p.add_argument("--later")
    args=p.parse_args()
    if args.action=="reconcile":
        if not args.later:p.error("--later is required for reconcile")
        result=reconcile(args.bundle,args.later)
    else:
        if not args.project:p.error("--project is required")
        result=(capture if args.action=="capture" else restore)(args.project,args.bundle)
    print(json.dumps(result,ensure_ascii=False))
