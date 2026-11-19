"""Verify final-hull eligibility, stale dual quotes and due-time consistency through real UI."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

from check_profile import api,ok,wait_ready
import server
import workshop


def run(godot):
    root=Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory() as temp:
        dbpath=Path(temp)/"player.sqlite"
        with socket.socket() as s:
            s.bind(("127.0.0.1",0))
            port=s.getsockname()[1]
        url=f"http://127.0.0.1:{port}"
        proc=subprocess.Popen([sys.executable,root/"services/profile/server.py","serve","--db",dbpath,"--port",str(port)])
        try:
            wait_ready(url)
            credentials={"name":"quote_test","password":"fixture-only-password"}
            a=ok(api(url,"/v1/accounts",credentials))
            first=a["robots"][0]["id"]
            token=a["token"]
            def view(id):
                return ok(api(url,f"/v1/robots/{id}/recovery",token=token))["recovery"]
            def ui(mode):
                nonlocal token
                result=subprocess.run([godot,"--headless","--path","game","--script","res://profile/tests/recycle_quote_ui.gd"],
                    cwd=root,env=dict(os.environ,PROFILE_URL=url,SERVICE_TEST_NAME=credentials["name"],SERVICE_TEST_PASS=credentials["password"],QUOTE_MODE=mode),
                    capture_output=True,text=True,encoding="utf8",errors="replace",timeout=18)
                assert result.returncode==0 and f"QUOTE_UI_{mode}_PASS" in result.stdout and "SCRIPT ERROR" not in result.stderr,(result.stdout,result.stderr)
                print(f"QUOTE_UI_{mode}_PASS")
                token=ok(api(url,"/v1/sessions",credentials))["token"]
            original=view(first)
            assert not original["can_recycle"] and original["return"]=={} and original["recycle_reason"]=="keep_last_robot"
            ui("one")
            design=ok(api(url,"/v1/workshop/design",{"key":"spare_design","name":"标准型","slots":workshop.BASE,"version":1},token))["receipt"]["design"]
            def build(key):
                return ok(api(url,"/v1/workshop/build",{"key":key,"name":"铜虎","design":design},token))["receipt"]["robot"]
            second=build("spare_two")
            assert view(first)["can_recycle"] and view(second)["can_recycle"]
            ui("two")
            assert view(first)["recycle_reason"]=="robot_retired" and view(second)["recycle_reason"]=="keep_last_robot"
            third=build("spare_three")
            bodies=[second,third]
            quotes=[view(r)["quote"] for r in bodies]
            def race(i):
                return api(url,f"/v1/robots/{bodies[i]}/recovery/recycle",{"key":"race_key_"+str(i),"quote":quotes[i],"confirmed":True},token)
            with ThreadPoolExecutor(2) as pool:
                results=list(pool.map(race,range(2)))
            assert sorted(v[0] for v in results)==[200,409]
            assert next(v for status,v in results if status==409)["error"]=="keep_last_robot"
            # Fixture uses a fresh single-robot account so login selects the repaired robot first.
            credentials={"name":"timer_test","password":"fixture-only-password"}
            a=ok(api(url,"/v1/accounts",credentials))
            rid=a["robots"][0]["id"]
            token=a["token"]
            with server.transaction(dbpath) as db:
                server.recovery.damage(db,rid,"fixture_damage")
            ok(api(url,f"/v1/robots/{rid}/recovery/repair",{"key":"timer_repair"},token))
            due=int(time.time())+5
            with server.transaction(dbpath) as db:
                db.execute("UPDATE robot_condition SET due=? WHERE robot=?",(due,rid))
            ui("timer")
            report=view(rid)
            assert next(e["at"] for e in report["recent"] if e["kind"]=="workshop_repair")==due
            with server.transaction(dbpath) as db:
                server.recovery.damage(db,rid,"fixture_delayed")
            ok(api(url,f"/v1/robots/{rid}/recovery/repair",{"key":"late_repair"},token))
            past=int(time.time())-75
            with server.transaction(dbpath) as db:
                db.execute("UPDATE robot_condition SET due=? WHERE robot=?",(past,rid))
            report=view(rid)
            assert report["recent"][0]["kind"]=="workshop_repair" and report["recent"][0]["at"]==past
            print("QUOTE_RACE_AND_CLOCK_PASS two old quotes -> one salvage; idle panel synchronizes parent and history; offline receipt uses due")
        finally:
            proc.terminate()
            proc.wait(timeout=8)

if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--godot",required=True)
    run(cli.parse_args().godot)
