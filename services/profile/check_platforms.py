"""Exercise private platform item ownership, offline defenses and old-layout replay."""
from concurrent.futures import ThreadPoolExecutor
import copy
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
from unittest.mock import patch

from check_profile import api,ok
from check_production import serve
import private_base
import raids
import server


def run(godot=None,capture=None,video_directory=None):
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/"private.sqlite"
        login={"name":"platform_demo","password":"local-test-only-password"}
        with serve(path) as url:
            player=ok(api(url,"/v1/accounts",login));token=player["token"]
            owner=player["account"]["id"];robot=player["robots"][0]["id"]
            other=ok(api(url,"/v1/accounts",dict(login,name="platform_guest")))["token"]
            def get(route):
                return ok(api(url,route,token=token))
            def post(route,body):
                return api(url,route,body,token)
            def build(x):
                rev=get("/v1/base")["base"]["revision"]
                base=ok(post("/v1/base/edit",dict(revision=rev,key=secrets.token_hex(8),action="build",kind="turret",x=x,y=3)))["base"]
                return base["buildings"][-1]["id"]
            t1,t2=build(3),build(4)
            paths=["/v1/base/platforms/"+t for t in (t1,t2)]
            def operate(route,verb,item=""):
                return dict(key=secrets.token_hex(8),action=verb,item=item,revision=get(route)["platform"]["revision"])
            def parts():
                return get("/v1/inventory")["inventory"]["parts"]
            def craft(kind):
                ok(post("/v1/inventory/craft",dict(recipe=kind,key=secrets.token_hex(8))))
                return next(p["id"] for p in parts() if p["definition"]==kind)
            gun=craft("cannon");arm=craft("repair_arm")
            def wealth():
                layout=get("/v1/base")["base"]
                with server.transaction(path) as db:
                    return raids.wealth(db,owner,layout)
            original_wealth=wealth()
            assert api(url,paths[0],token=other)[0]==404
            jobs=[operate(route,"install",gun) for route in paths]
            with ThreadPoolExecutor(2) as executor:
                results=list(executor.map(post,paths,jobs))
            assert sorted(r[0] for r in results)==[200,409]
            ix=next(n for n,r in enumerate(results) if r[0]==200)
            gun_path,arm_path=paths[ix],paths[1-ix]
            assert ok(post(gun_path,jobs[ix]))["receipt"]==results[ix][1]["receipt"]
            assert gun not in {p["id"] for p in parts()}
            refit={"key":"use_mounted_gun","robot":robot,"slot":"weapon","item":gun,
                   "expected":get("/v1/workshop")["workshop"]["robots"][0]["slots"]["weapon"]["id"]}
            assert post("/v1/workshop/refit",refit)[0]==409
            ok(post(arm_path,operate(arm_path,"install",arm)))
            assert wealth()==original_wealth
            assert not parts()
            layout=get("/v1/base")["base"]
            guard=get("/v1/workshop")["workshop"]["robots"][0]
            # Weak defending tool and many attackers ensure damage occurs within reach.
            combat=raids.simulate(layout,42,12,guard)
            assert any(f["shots"] for f in combat["frames"])
            gun_tower=next(b for b in layout["buildings"] if b.get("module",{}).get("id")==gun)
            ok(post("/v1/base/edit",dict(revision=layout["revision"],action="power",building=gun_tower["id"],
                                        x=gun_tower["x"],y=gun_tower["y"],key="pause_gun_platform")))
            combat=raids.simulate(get("/v1/base")["base"],42,12,guard)
            assert 0<sum(len(f.get("repairs",[])) for f in combat["frames"])<=4
            with server.transaction(path) as db:
                db.execute("UPDATE raid_clocks SET due=1 WHERE owner=?",(owner,))
                raids.advance(db,owner,stamp=1)
                db.execute("UPDATE wild_raids SET seed=42,budget=12 WHERE owner=? AND outcome IS NULL",(owner,))
            with patch("time.time",return_value=2):
                assert not get(arm_path)["platform"]["locked"]
                ok(post(arm_path,operate(arm_path,"detach")))
                ok(post(arm_path,operate(arm_path,"install",arm)))
                warning=get("/v1/base/raids")["raid"]
                ok(post("/v1/base/raids/guard",dict(raid=warning["id"],robot=robot)))
            with patch("time.time",return_value=warning["starts"]):
                assert get(arm_path)["platform"]["locked"]
                assert post(arm_path,operate(arm_path,"detach"))[1]["error"]=="platform_locked"
            replay=get("/v1/base/raids")["raid"]
            assert replay["stage"]=="replay"
            assert replay["receipt"]["platform_repair"]>0
            if video_directory:
                directory=Path(video_directory).resolve()
                directory.mkdir(parents=True,exist_ok=True)
                env=dict(os.environ,PROFILE_URL=url,RAID_VIDEO_DIRECTORY=str(directory))
                cmd=[godot,"--path","game","--script","res://base/tests/raid_platform_replay.gd"]
                if os.environ.get("RAID_VIEW_SIZE"):
                    cmd[1:1]=["--resolution",os.environ["RAID_VIEW_SIZE"]]
                subprocess.run(cmd,env=env,timeout=75,check=True)
                # The replay viewer signed in to the same fixture, rotating its session.
                token=ok(api(url,"/v1/sessions",login))["token"]
            assert replay["layout"]["buildings"][-1]["module"]["id"] in (arm,gun)
            command=operate(gun_path,"detach")
            before_detach=wealth()
            first=ok(post(gun_path,command))
            assert wealth()==before_detach
            assert ok(post(gun_path,command))==first and gun in {p["id"] for p in parts()}
            refit["key"]="fit_returned_gun"
            ok(post("/v1/workshop/refit",refit))
            remove=operate(arm_path,"remove")
            assert ok(post(arm_path,remove))==ok(post(arm_path,remove))
            assert arm in {p["id"] for p in parts()}
            old=copy.deepcopy(layout)
            for b in old["buildings"]:
                b.pop("module",None)
            legacy=raids.simulate(old,42,8)
            assert any(f["shots"] for f in legacy["frames"]) and not any("repairs" in f for f in legacy["frames"])
            if godot:
                env=dict(os.environ,PROFILE_URL=url,PLATFORM_CAPTURE=capture or "")
                command=[godot,"--path","game","--script","res://base/tests/platform_ui.gd"]
                if not capture:command.insert(1,"--headless")
                proc=subprocess.run(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding="utf8",errors="replace",timeout=60)
                print(proc.stdout)
                assert proc.returncode==0 and "PLATFORM_UI_PASS" in proc.stdout and "SCRIPT ERROR" not in proc.stdout
        with serve(path) as url:
            token=ok(api(url,"/v1/sessions",login))["token"]
            assert get("/v1/base/raids")["raid"]["receipt"]==replay["receipt"]
            assert get("/v1/workshop")["workshop"]["robots"][0]["slots"]["weapon"]["id"]==gun
    print("PLATFORM_PASS concurrent real item, mount locks, original IDs returned, weapon and bounded actual service, frozen layout, old tower, persisted replay")


if __name__=="__main__":
    import argparse
    cli=argparse.ArgumentParser()
    cli.add_argument("--godot")
    cli.add_argument("--capture")
    cli.add_argument("--video-directory")
    args=cli.parse_args()
    run(args.godot,args.capture,args.video_directory)
