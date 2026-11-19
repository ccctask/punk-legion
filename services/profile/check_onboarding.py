"""M17 upgrade/resume, a seven-day server-clock return, balance and evidence reconciliation."""
import tempfile
import argparse
import os
import subprocess
from pathlib import Path
from unittest.mock import patch

import server
import time
from check_production import serve


def run(godot=None,capture=None):
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/"profile.sqlite"
        server.initialize(path)
        credentials={"name":"m17_return","password":"test-password-42"}
        start=int(time.time())-7*86400
        key="temporary-room-proof"
        def request(route,data=None):
            return server.handle(path,"GET" if data is None else "POST",route,data or {},"Bearer "+token)
        with patch("time.time",return_value=start):
            user=server.handle(path,"POST","/v1/accounts",credentials,"")
            token=user["token"]
            owner=user["account"]["id"]
            robot=user["robots"][0]["id"]
            assert not any(request("/v1/onboarding")["guide"]["facts"].values())
            request("/v1/robots/"+robot+"/rename",{"name":"铁奶罐"})
            layout=request("/v1/base")["base"]
            request("/v1/base/edit",dict(revision=layout["revision"],action="build",kind="foundry",x=3,y=2,key="build_forge"))
            active=request("/v1/expedition/start",{"robots":[robot],"key":"m17_start"})["expedition"]["active"]
            report={"id":active["id"],"nodes":["scrap","coil"],"reports":{robot:[dict(at=192,kind="condition",actor="combat",target=robot,amount=12)]},"seconds":193,"outcome":"win","commanded":True}
            result=server.handle(path,"POST","/internal/expedition/settle",report,"Bearer "+key,key)["receipt"]
            assert request("/v1/onboarding")["guide"]["daily"]["receipt"]==result["id"]
            token=server.handle(path,"POST","/v1/sessions",credentials,"")["token"]
            assert request("/v1/expedition")["expedition"]["last"]["id"]==result["id"]
            old_fit=request("/v1/workshop")["workshop"]["robots"][0]["slots"]["weapon"]["id"]
            request("/v1/workshop/refit",dict(key="install_drill",robot=robot,slot="weapon",expected=old_fit,item=result["part"]["id"]))
            # Restore the pre-guide database shape while retaining the real historical receipts.
            with server.transaction(path) as db:
                for table in ("named_robots","activity_anchor"):
                    db.execute("DROP TABLE "+table)
                db.execute("PRAGMA user_version=8")
            server.initialize(path)
            token=server.handle(path,"POST","/v1/sessions",credentials,"")["token"]
            guide=request("/v1/onboarding")["guide"]
            assert guide["facts"]==dict(name=True,fit=True,command=True,reward=True,repair=False)
            assert guide["damaged"]==robot and guide["summary"]=={}
            repair=request("/v1/robots/"+robot+"/recovery/repair",dict(key="repair_before_absence"))["recovery"]
            stock=lambda:{k:v["amount"] for k,v in request("/v1/inventory")["inventory"]["stock"].items()}
            before=stock()
        end=start+7*86400
        with patch("time.time",return_value=end):
            token=server.handle(path,"POST","/v1/sessions",credentials,"")["token"]
            guide=request("/v1/onboarding")["guide"]
            r=guide["summary"]
            assert guide["facts"]["repair"] and guide["damaged"]==""
            assert not guide["daily"]["complete"]
            assert (r["start"],r["end"],r["cap_seconds"])==(start,end,43200)
            assert r["before"]==before and r["after"]==stock()
            assert len(r["repairs"])==1 and r["repairs"][0]["at"]==repair["due"]
            raid=request("/v1/base/raids")["raid"]["receipt"]
            assert [x["id"] for x in r["ledger"]]==[raid["id"]]
            for k in before:
                assert before[k]+sum(x["changes"].get(k,0) for x in r["ledger"])==r["after"][k]
            economy=request("/v1/base/production")["production"]
            assert all(economy["lines"][k]["pending"]==r["production"][k]["pending"] for k in before)
            assert r["production"]["structure"]["pending"]==4 and r["production"]["energy"]["pending"]==2
            assert r["production"]["components"]["pending"]==0
            claimed=request("/v1/base/production/claim",dict(key="claim_return"))["receipt"]
            assert claimed["changes"]=={"structure":4,"energy":2} or all(claimed["changes"].get(k,0)==v for k,v in dict(structure=4,components=0,energy=2).items())
            current=stock()
            assert all(current[k]==r["after"][k]+claimed["changes"].get(k,0) for k in current)
            assert request("/v1/onboarding")["guide"]["summary"]==r and stock()==current
            print("M17_RETURN_PASS legacy v8/name/fit/result, actual due repair, seven-day absence, twelve-hour production cap, exactly one raid",raid["changes"],"before",before,"arrival",r["after"],"claimed",claimed["changes"],"after",current)
        midnight=(end//86400+1)*86400
        with patch("time.time",return_value=midnight-2):
            new=server.handle(path,"POST","/v1/accounts",dict(name="m17_full",password="test-password-42"),"")
            token=new["token"]
            robot=new["robots"][0]["id"]
            def sortie(key):
                return request("/v1/expedition/start",dict(robots=[robot],key=key))["expedition"]["active"]["id"]
            def finish(mission,nodes):
                return server.handle(path,"POST","/internal/expedition/settle",
                    dict(id=mission,outcome="retreat",seconds=1,nodes=nodes,reports={robot:[]}),
                    "Bearer "+key,key)["receipt"]
            finish(sortie("empty_exit"),[])
            assert not request("/v1/onboarding")["guide"]["daily"]["complete"]
            m=sortie("cross_day")
            with server.transaction(path) as db:
                db.execute("UPDATE stocks SET amount=40 WHERE resource='structure' AND owner=?",(new["account"]["id"],))
        with patch("time.time",return_value=midnight+1):
            r=finish(m,["scrap"])
            daily=request("/v1/onboarding")["guide"]["daily"]
            assert daily["complete"] and daily["receipt"]==r["id"] and sum(daily["changes"].values())==0
            assert r["credited_at"]==midnight+1 and daily["resets_at"]==midnight+86400
            print("M17_DAILY_PASS full store +1 collected node, actual stock delta 0; empty retreat ineligible; uses settlement UTC after midnight")
        if godot:
            root=Path(__file__).resolve().parents[2]
            with serve(path) as url:
                cmd=[godot,"--path",str(root/"game"),"--script","res://onboarding/tests/return_ui.gd"]
                if not capture:
                    cmd.insert(1,"--headless")
                subprocess.run(cmd,env={**os.environ,"PROFILE_URL":url,"ROOM_HOST":"127.0.0.1:24999",
                               "M17_CAPTURE":str(Path(capture).resolve()) if capture else ""},check=True,timeout=35)
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot")
    parser.add_argument("--capture")
    args=parser.parse_args()
    run(args.godot,args.capture)
