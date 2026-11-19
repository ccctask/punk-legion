"""M11 real build/deduction/reopen, visiting and projected Godot facility navigation."""
import argparse
import os
from pathlib import Path
import secrets
import subprocess
from tempfile import TemporaryDirectory

from check_profile import api,ok
from check_production import serve


def run(godot,capture):
    with TemporaryDirectory() as folder:
        path=Path(folder)/"test.sqlite"
        login={"name":"hangar_owner","password":"hangar-fixture-password"}
        with serve(path) as url:
            owner=ok(api(url,"/v1/accounts",login))
            a=owner["token"]
            b=ok(api(url,"/v1/accounts",dict(login,name="visitor")))["token"]
            def layout():
                return ok(api(url,"/v1/base",token=a))["base"]
            def garage(token=a):
                return ok(api(url,"/v1/workshop",token=token))["workshop"]
            def place(x,y):
                return dict(revision=layout()["revision"],key=secrets.token_hex(10),action="build",kind="hangar",x=x,y=y)
            def edit(command):
                return api(url,"/v1/base/edit",command,a)
            prior=garage()
            assert prior["hangar_capacity"]==18 and len(prior["robots"])==1
            before=prior["stock"]["structure"]
            assert edit(place(1,2))[0]==409 and edit(place(11,8))[0]==409 and edit(place(7,7))[0]==409
            cmd=place(3,2)
            first=ok(edit(cmd))
            assert ok(edit(cmd))["receipt"]==first["receipt"]
            assert garage()["stock"]["structure"]==before-1
            ok(edit(place(5,2)))
            hangar=first["base"]["buildings"][-1]
            assert hangar["kind"]=="hangar" and hangar["demand"]==0 and hangar["w"]==hangar["h"]==2
            ok(edit(dict(revision=layout()["revision"],key="move_hangar",action="move",building=hangar["id"],x=4,y=5)))
            assert garage()["stock"]["structure"]==before-2
            ok(api(url,"/v1/friends/request",{"friend":"visitor"},a))
            ok(api(url,"/v1/friends/accept",{"friend":"hangar_owner"},b))
            visited=ok(api(url,"/v1/friends/visit",{"friend":"hangar_owner"},b))["visit"]["layout"]
            assert any(row["kind"]=="hangar" and row["x"]==4 and row["y"]==5 for row in visited["buildings"])
            assert garage(b)["robots"][0]["id"]!=prior["robots"][0]["id"]
            assert garage()["robots"]==prior["robots"] and garage()["hangar_capacity"]==18
            rid=prior["robots"][0]["id"]
            dispatched=ok(api(url,"/v1/robots/"+rid+"/assign",{"task":"guard"},a))["robots"][0]
            assert garage()["robots"][0]["task"]=="guard"
            assert api(url,"/v1/robots/"+rid+"/assign",{"task":"expedition"},a)[0]==409
            ok(api(url,"/v1/robots/"+rid+"/finish",{"assignment":dispatched["assignment"],"outcome":"cancelled"},a))
        with serve(path) as url:
            a=ok(api(url,"/v1/sessions",login))["token"]
            assert len([b for b in layout()["buildings"] if b["kind"]=="hangar"])==2
            assert garage(a)["robots"]==prior["robots"]
            if godot:
                env=dict(os.environ,PROFILE_URL=url)
                cmd=[godot,"--path","game","--script","res://base/tests/hangar_ui.gd"]
                if capture:
                    env["HANGAR_CAPTURE"]=str(Path(capture).resolve())
                else:
                    cmd.insert(1,"--headless")
                result=subprocess.run(cmd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                                      encoding="utf8",errors="replace",timeout=60,check=True)
                print(result.stdout)
                assert "HANGAR_UI_PASS" in result.stdout and "SCRIPT ERROR" not in result.stdout
    print("HANGAR_PASS old 18-capacity account, legal roads and bounds, two hangars, charge-once, free move, visitor and restart")


if __name__=="__main__":
    args=argparse.ArgumentParser()
    args.add_argument("--godot")
    args.add_argument("--capture")
    options=args.parse_args()
    run(options.godot,options.capture)
