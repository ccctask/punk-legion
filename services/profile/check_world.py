"""M18 persisted UTC windows, ownership, admission and room-binding contract."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import copy
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
from unittest.mock import patch

from check_profile import api,ok
from check_production import serve
import server
import world_calendar as world


def run(godot=None,captures=None):
    fixture=json.loads(world.config_path().read_text(encoding="utf8"))
    node=fixture["nodes"][1]
    node["daily"]=[[86340,86460,86520]]
    fixture["nodes"].append(dict(node,id="ice-dock",name="冰港"))
    midnight=2200000000//86400*86400
    t=[midnight+86339]
    with tempfile.TemporaryDirectory() as tmp:
        path=Path(tmp)/"profile.sqlite"
        file=Path(tmp)/"calendar.json"
        file.write_text(json.dumps(fixture),encoding="utf8")
        with patch.dict(os.environ,{"WORLD_CALENDAR_FILE":str(file)}),patch.object(world,"now",lambda:t[0]):
            def request(who,k,node="brass-yard"):
                return api(base,"/v1/world/admit",{"key":k,"node":node},who["token"])
            def camp():
                return ok(api(base,"/v1/world",token=a["token"]))["world"]["nodes"][1]
            def expect_fault(code,call):
                try:
                    call()
                except server.Fault as exc:
                    assert exc.code==code,(code,exc.code)
                else:
                    raise AssertionError(code)
            with serve(path) as base:
                a,b=[ok(api(base,"/v1/accounts",{"name":"calendar_"+secrets.token_hex(4),"password":secrets.token_urlsafe()})) for _ in range(2)]
                assert camp()["state"]=="closed" and request(a,"early_try")[0]==409
                t[0]+=1
                assert camp()["state"]=="open"
                assert request(a,"not_a_camp","rustrail")[0]==409
                assert api(base,"/v1/world/admit",{"key":"fake_time","node":"brass-yard","server_time":t[0]+86400},a["token"])[0]==400
                with ThreadPoolExecutor(3) as pool:
                    grants=list(pool.map(lambda _:ok(request(a,"real_entry"))["admission"],range(3)))
                grant=grants[0]
                assert grants==[grant]*3
                assert ok(request(a,"alias_entry"))["admission"]==grant
                assert request(a,"real_entry","coil-depot")[0]==409
                assert request(a,"preview_only","ice-dock")== (409,{"error":"camp_preview_only"})
                sites=ok(api(base,"/v1/world",token=a["token"]))["world"]["nodes"]
                assert {n["id"]:n["contest_available"] for n in sites if n["type"]=="camp"}=={"brass-yard":True,"coil-depot":True,"ice-dock":False}
                assert api(base,"/v1/world/admissions/"+grant["id"],token=b["token"])[0]==404
                with server.transaction(path) as db:
                    world.set_owner(db,"brass-yard",a["account"]["id"])
                    first_battle=world.bind_battle(db,a["account"]["id"],grant["id"],"fight_0001")
                assert camp()["mine"] and camp()["owner"]==a["account"]["name"]
                if godot:
                    def client(mode):
                        env=dict(os.environ,PROFILE_URL=base,WORLD_TEST_MODE=mode)
                        cmd=[godot,"--path","game","--script","res://world/tests/world_ui.gd"]
                        if captures:
                            Path(captures).mkdir(exist_ok=True,parents=True)
                            env["WORLD_CAPTURE"]=str((Path(captures)/(mode+".png")).resolve())
                        else:
                            cmd.insert(1,"--headless")
                        subprocess.run(cmd,env=env,timeout=40,check=True)
                    with ThreadPoolExecutor(2) as pool:
                        list(pool.map(client,["camp","party"]))
                t[0]=midnight+86459
                late=ok(request(b,"almost_cut"))["admission"]
                t[0]+=1
                assert camp()["state"]=="cutoff" and request(a,"aftercutoff")[0]==409
                assert ok(request(a,"real_entry"))["admission"]==grant
                assert api(base,"/v1/world/admissions/"+late["id"],token=b["token"])[0]==200
                with server.transaction(path) as db:
                    expect_fault("entry_cutoff",lambda:world.bind_battle(db,b["account"]["id"],late["id"],"late_battle"))
                t[0]=midnight+86520
                assert camp()["state"]=="closed"
                # Invalid windows, including a cross-midnight overlap, leave the accepted version intact.
                broken=copy.deepcopy(fixture)
                broken["nodes"][1]["daily"].append([10,15,30])
                file.write_text(json.dumps(broken))
                assert camp()["state"]=="closed"
                cli=[sys.executable,str(Path(world.__file__)),"--db",str(path)]
                rejected=subprocess.run(cli,capture_output=True,text=True)
                assert rejected.returncode==1 and "overlapping windows" in rejected.stderr
                with server.transaction(path) as db:
                    assert world.active(db)[0]==1
                for invalid in [[[100,99,101]],[[100,160,140]]]:
                    bad=copy.deepcopy(fixture)
                    bad["nodes"][1]["daily"]=invalid
                    try:
                        world.validate(bad)
                    except ValueError:
                        pass
                    else:
                        raise AssertionError("invalid ordering accepted")
                future=copy.deepcopy(fixture)
                future["nodes"][1]["daily"]=[[3600,4000,4200]]
                file.write_text(json.dumps(future))
                assert "world_calendar_version 2" in subprocess.check_output(cli,text=True)
                assert ok(api(base,"/v1/world",token=a["token"]))["world"]["version"]==2
            with serve(path) as base:
                assert ok(request(a,"real_entry"))["admission"]==grant
                with server.transaction(path) as db:
                    assert world.bind_battle(db,a["account"]["id"],grant["id"],"fight_0001")==first_battle
                    expect_fault("admission_used",lambda:world.bind_battle(db,a["account"]["id"],grant["id"],"fight_0002"))
                    t[0]=grant["settle_until"]+86400
                    assert world.settlement_qualification(db,a["account"]["id"],grant["id"],"fight_0001",grant["closes_at"]+1)["window_version"]==1
                    expect_fault("qualification_expired",lambda:world.qualification(db,a["account"]["id"],grant["id"]))
                    expect_fault("qualification_expired",lambda:world.settlement_qualification(db,a["account"]["id"],grant["id"],"fight_0001",grant["settle_until"]))
                file.unlink()
                assert ok(api(base,"/v1/world",token=a["token"]))["world"]["version"]==2
    print("WORLD_PASS UTC midnight open/cutoff/close update fallback isolation M19 bind/late_result restart")

def upgrade(old):
    with tempfile.TemporaryDirectory() as tmp:
        path=Path(tmp)/"account.sqlite"
        server.initialize(path)
        user=server.login(path,{"name":"migrate_player","password":"testonly-password"},True)
        with server.transaction(path) as db:
            for table in ("treasure_members","treasure_rooms","treasure_groups","robot_orders"):
                db.execute("DROP TABLE "+table)
            if old < 9:
                db.execute("DROP TABLE activity_anchor")
                db.execute("DROP TABLE named_robots")
            for table in ("world_battles","world_requests","world_admissions","world_camps","world_schedules"):
                db.execute("DROP TABLE "+table)
            db.execute(f"PRAGMA user_version={old}")
        with serve(path) as base:
            assert ok(api(base,"/v1/profile",token=user["token"]))["account"]==user["account"]
            assert ok(api(base,"/v1/world",token=user["token"]))["world"]["version"]==1
        with server.transaction(path) as db:
            assert db.execute("PRAGMA foreign_key_check").fetchall()==[]
            assert db.execute("PRAGMA user_version").fetchone()[0]==server.VERSION
        print("WORLD_UPGRADE_PASS",old,"to",server.VERSION)
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--godot")
    p.add_argument("--captures")
    args=p.parse_args()
    for previous in (7,8,9):
        upgrade(previous)
    run(args.godot,args.captures)
