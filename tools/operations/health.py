"""Local profile reachability and settlement queue age. Only the monitor's SQLite file is writable."""
import argparse
from contextlib import closing
from http.client import HTTPException
import json
import os
from pathlib import Path
import sqlite3
import time
from urllib.request import urlopen


RETENTION = 7 * 86400
INTERVAL = 30
STALE_AFTER = 90
QUEUE_AGE = 120
FAILURES = 3
QUEUES = {"room":"*.json","solo":"*.result.json","party":"*.result.json","camp":"*.result.json"}


def collect(endpoint, folders, stamp):
    start = time.monotonic()
    try:
        with urlopen(endpoint + "/v1/beta/compat", timeout=3) as response:
            data = json.load(response)
        reachable = isinstance(data, dict) and isinstance(data.get("server_now"), int)
    except (ValueError, OSError, HTTPException):
        reachable = False
    http_ms = round((time.monotonic()-start)*1000)
    pending = oldest = 0
    readable = True
    for name, pattern in QUEUES.items():
        try:
            with os.scandir(folders/name) as entries:
                for entry in entries:
                    if not entry.name.endswith(pattern[1:]) or not entry.is_file(follow_symlinks=False):
                        continue
                    try:
                        modified = entry.stat(follow_symlinks=False).st_mtime
                    except FileNotFoundError:
                        continue
                    pending += 1
                    oldest = max(oldest,int(stamp-modified))
        except OSError:
            readable = False
    return (stamp,int(reachable),http_ms,pending,oldest,int(readable))


def initialize(db):
    db.executescript("""
        CREATE TABLE IF NOT EXISTS samples(time INTEGER PRIMARY KEY,http_ok INTEGER,http_ms INTEGER,
            pending INTEGER,oldest_seconds INTEGER,queues_ok INTEGER);
        CREATE TABLE IF NOT EXISTS checks(name TEXT PRIMARY KEY,streak INTEGER,active INTEGER);
        CREATE TABLE IF NOT EXISTS events(time INTEGER,name TEXT,active INTEGER);
        CREATE INDEX IF NOT EXISTS events_time ON events(time);
    """)


def record(db, row):
    stamp,http_ok,_,_,oldest,queues_ok = row
    changes = []
    with db:
        if not db.execute("INSERT OR IGNORE INTO samples VALUES(?,?,?,?,?,?)",row).rowcount:
            return []
        for name,failed in {"profile_unreachable":not http_ok,"result_overdue":oldest>=QUEUE_AGE,
                            "queues_unreadable":not queues_ok}.items():
            previous = db.execute("SELECT streak,active FROM checks WHERE name=?",(name,)).fetchone() or (0,0)
            streak = min(FAILURES,previous[0]+1) if failed else 0
            active = int(streak>=FAILURES)
            if active != previous[1]:
                db.execute("INSERT INTO events VALUES(?,?,?)",(stamp,name,active))
                changes.append({"time":stamp,"name":name,"state":"alert" if active else "recovered"})
            db.execute("INSERT OR REPLACE INTO checks VALUES(?,?,?)",(name,streak,active))
        for table in ("samples","events"):
            db.execute("DELETE FROM "+table+" WHERE time<?",(stamp-RETENTION,))
    return changes


def report(path, count, now):
    with closing(sqlite3.connect(path.resolve().as_uri()+"?mode=ro",uri=True)) as db:
        db.row_factory = sqlite3.Row
        samples = [dict(r) for r in db.execute("SELECT * FROM samples ORDER BY time DESC LIMIT ?",(count,))]
        events = [dict(r) for r in db.execute("SELECT * FROM events ORDER BY time DESC,rowid DESC LIMIT ?",(count,))]
        active = [r[0] for r in db.execute("SELECT name FROM checks WHERE active=1 ORDER BY name")]
    stale = not samples or now-samples[0]["time"]>STALE_AFTER
    return {"stale":stale,"active":active,"samples":samples,"events":events}


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("action",choices=("run","report"))
    parser.add_argument("--db",type=Path,default=Path("/history/health.sqlite"))
    parser.add_argument("--profile",default="http://profile:24670")
    parser.add_argument("--queues",type=Path,default=Path("/queues"))
    parser.add_argument("--limit",type=int,default=10)
    args=parser.parse_args()
    if args.action=="report":
        if not 1<=args.limit<=10000:
            parser.error("--limit ranges from 1 through 10000")
        try:
            result=report(args.db,args.limit,int(time.time()))
        except sqlite3.Error as exc:
            raise SystemExit("Health history unavailable: "+str(exc))
        print(json.dumps(result,ensure_ascii=False))
        raise SystemExit(2 if result["stale"] or result["active"] else 0)
    with closing(sqlite3.connect(args.db)) as db:
        initialize(db)
        while True:
            stamp=int(time.time())
            events=record(db,collect(args.profile,args.queues,stamp))
            for event in events:
                print(json.dumps(event),flush=True)
            time.sleep(INTERVAL)
