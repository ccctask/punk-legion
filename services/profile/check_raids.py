"""Compare online and offline wild raids from real base layouts using the same server clock."""
from concurrent.futures import ThreadPoolExecutor
import argparse
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch

import private_base
import raids
import server
from check_profile import wait_ready


def run(godot=None,capture=None,*,historical_storage=False):
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/"profile.sqlite"
        server.initialize(path)
        stamp=int(time.time())
        def account(name):
            return server.login(path,{"name":name,"password":"local-fixture-password"},True)
        a,b,c=[account(name) for name in ("watch_online","watch_offline","watch_wealth")]
        absent=account("away_month")
        if historical_storage:
            with server.transaction(path) as db:
                db.execute("DROP TABLE wild_raids")
                for table in ("treasure_members","treasure_rooms","treasure_groups"):
                    db.execute("DROP TABLE "+table)
                db.execute("DROP TABLE raid_clocks")
                db.execute("PRAGMA user_version=6")
            server.initialize(path)
        with server.transaction(path) as db:
            assert db.execute("SELECT COUNT(*) FROM raid_clocks").fetchone()[0]==4
        def api(user,route="/v1/base/raids",body=None):
            return server.handle(path,"GET" if body is None else "POST",route,body or {},"Bearer "+user["token"])
        def raid(user):
            return api(user)["raid"]
        layout=private_base.starter()
        layout["buildings"].append({"id":"tower_a","kind":"turret","x":0,"y":3})
        state=private_base.check(layout)
        checked=raids.simulate(state,42,8)
        assert any(f["shots"] for f in checked["frames"])
        for frame in checked["frames"]:
            for shot in frame["shots"]:
                assert shot["source"]=="tower_a" and raids.math.dist(shot["origin"],shot["target"])<=5
        bad=json.loads(json.dumps(layout))
        bad["buildings"][-1]["paused"]=True
        assert not any(f["shots"] for f in raids.simulate(private_base.check(bad),42,8)["frames"])
        with server.transaction(path) as db:
            for user in (a,b):
                uid=user["account"]["id"]
                db.execute("UPDATE bases SET layout=? WHERE owner=?",(json.dumps(layout),uid))
                db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(stamp,uid))
            db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(stamp,absent["account"]["id"]))
            uid=c["account"]["id"]
            small=raids.wealth(db,uid,state)
            db.execute("UPDATE stocks SET amount=CASE resource WHEN 'structure' THEN 40 WHEN 'energy' THEN 12 ELSE 24 END WHERE owner=?",(uid,))
            mid=raids.wealth(db,uid,state)
            for i in range(12):
                r=secrets.token_hex(16)
                db.execute("INSERT INTO robots VALUES (?,?,?,NULL,NULL)",(r,uid,str(i)))
                server.workshop.initial_fit(db,uid,r)
            rich=raids.wealth(db,uid,state)
            db.execute("UPDATE robots SET task='aid',assignment=id WHERE owner=?",(uid,))
            assert small<mid<rich and raids.wealth(db,uid,state)==rich
            db.execute("UPDATE robots SET task=NULL,assignment=NULL WHERE owner=?",(uid,))
            assert min(12,2+rich//30)<=12
        with patch("time.time",return_value=stamp),patch("secrets.randbelow",return_value=42):
            wa,wb=raid(a),raid(b)
            assert wa["stage"]==wb["stage"]=="warning" and wa["budget"]==wb["budget"]
            assert api(a,"/v1/base")["raid_stage"]=="warning"
            for user,record in [(a,wa),(b,wb)]:
                bound=api(user,"/v1/base/raids/guard",{"raid":record["id"],"robot":user["robots"][0]["id"]})["raid"]
                assert bound["guard"]["name"]==user["robots"][0]["name"]
                assert not api(user,"/v1/workshop")["workshop"]["deployment"]["units"]
                api(user,"/v1/base/edit",{"revision":1,"action":"power","building":"tower_a","x":0,"y":3,"key":"offline_toggle"})
            assert raid(a)["layout"]["revision"]==2 and api(a,"/v1/base")["base"]["revision"]==2
        starts=wa["starts"]
        with patch("time.time",return_value=starts+1):
            online=raid(a)
            assert online["stage"]=="live" and len(online["frames"])==2
        with patch("time.time",return_value=starts+120):
            with ThreadPoolExecutor(4) as pool:
                rows=list(pool.map(lambda _:raid(a),range(4)))
            completed=rows[0]
            assert all(r["receipt"]==completed["receipt"] for r in rows)
            other=raid(b)
            assert other["frames"]==completed["frames"] and other["receipt"]["outcome"]==completed["receipt"]["outcome"]
            assert not api(a,"/v1/profile")["robots"][0]["assignment"]
            assert api(a,f"/v1/robots/{a['robots'][0]['id']}/history")["history"]["totals"]["battles"]==1
        with server.transaction(path) as db:
            uid=c["account"]["id"]
            db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(stamp,uid))
        with patch("time.time",return_value=stamp), patch("secrets.randbelow",return_value=2):
            wc=raid(c)
            api(c,"/v1/base/raids/guard",{"raid":wc["id"],"robot":c["robots"][0]["id"]})
        late=stamp+30*86400
        with patch("time.time",return_value=late):
            lost=raid(c)
            assert lost["stage"]=="replay" and lost["receipt"]["outcome"]=="loss"
            cost=sum(-v for v in lost["receipt"]["changes"].values())
            assert cost<=3 and cost+lost["receipt"]["repair_cost"]<=4 and lost["due"]==late+raids.LOSS_RECOVERY
            assert raid(c)["receipt"]==lost["receipt"]
            stocks=api(c,"/v1/inventory")["inventory"]["stock"]
            assert all(stocks[k]["amount"]>=v for k,v in raids.INSURANCE.items())
            with server.transaction(path) as db:
                assert db.execute("SELECT COUNT(*) FROM wild_raids WHERE owner=?",(c["account"]["id"],)).fetchone()[0]==1
                db.execute("UPDATE stocks SET amount=0 WHERE owner=?",(c["account"]["id"],))
        with patch("time.time",return_value=late+raids.LOSS_RECOVERY):
            smaller=raid(c)
            assert smaller["wealth"]<wc["wealth"] and smaller["budget"]<=wc["budget"]
        with server.transaction(path) as db:
            missed=db.execute("SELECT COUNT(*) FROM wild_raids WHERE owner=?",(absent["account"]["id"],)).fetchone()[0]
            assert missed==1
        with patch("time.time",return_value=late+3*raids.COOLDOWN):
            assert raid(absent)["due"]==late+4*raids.COOLDOWN
        if historical_storage:
            backup=Path(temp)/"backup.sqlite"
            restored=Path(temp)/"restored.sqlite"
            server.snapshot(path,backup)
            server.snapshot(backup,restored,restore=True)
            server.initialize(restored)
            with server.transaction(restored) as db:
                row=db.execute("SELECT receipt,seed,layout FROM wild_raids WHERE id=?",(completed["id"],)).fetchone()
                assert json.loads(row["receipt"])==completed["receipt"] and row["seed"]==completed["seed"] and json.loads(row["layout"])==completed["layout"]
        print("RAIDS_PASS wealth low/mid/high",small,mid,rich,"online/offline frames",len(completed["frames"]),
              "warning tracks v2 edits, in-range muzzle, offline power, real guard released and history saved;")
        print("long-offline single defeat, material loss",cost,"repair budget",lost["receipt"]["repair_cost"],
              "loss recovery",raids.LOSS_RECOVERY,"budget after loss",wc["budget"],smaller["budget"])
        print("RAID_ABSENCE_PASS inactive owner sees one raid despite active world")
        if godot:
            ui_user=account("watch_ui")
            uid=ui_user["account"]["id"]
            with server.transaction(path) as db:
                db.execute("UPDATE bases SET layout=? WHERE owner=?",(json.dumps(layout),uid))
                db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(stamp,uid))
                raids.advance(db,uid,stamp)
                now=int(time.time())
                db.execute("UPDATE wild_raids SET starts=? WHERE owner=?",(now+7,uid))
                db.execute("UPDATE raid_clocks SET due=? WHERE owner=?",(now+7,uid))
            with socket.socket() as s:
                s.bind(("127.0.0.1",0))
                port=s.getsockname()[1]
            root=Path(__file__).resolve().parents[2]
            url=f"http://127.0.0.1:{port}"
            proc=subprocess.Popen([sys.executable,root/"services/profile/server.py","serve","--db",path,"--port",str(port)])
            try:
                wait_ready(url)
                env=dict(os.environ,PROFILE_URL=url,RAID_UI_TOKEN=ui_user["token"])
                if capture:
                    env["RAID_CAPTURE"]=str(Path(capture).resolve())
                flags=[] if capture else ["--headless"]
                result=subprocess.run([godot,*flags,"--path","game","--script","res://raids/tests/raid_ui.gd"],
                    env=env,cwd=root,timeout=40,capture_output=True,text=True,encoding="utf8",errors="replace")
                print(result.stdout)
                assert result.returncode==0 and "RAID_UI_PASS" in result.stdout and "SCRIPT ERROR" not in result.stderr
            finally:
                proc.terminate()
                proc.wait(timeout=10)

if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--godot")
    cli.add_argument("--capture")
    args=cli.parse_args()
    run(args.godot,args.capture)

