"""M11 HTTP regression using a temporary profile DB, two owners and a process restart."""
from concurrent.futures import ThreadPoolExecutor
import argparse
from contextlib import closing, contextmanager
from pathlib import Path
import os
import secrets
import socket
import subprocess
import sys
import tempfile

from check_profile import api, ok, wait_ready


def run(godot=None, capture=None):
    with tempfile.TemporaryDirectory() as temp, closing(socket.socket()) as sock:
        path = Path(temp)/"test.sqlite"
        sock.bind(("127.0.0.1",0))
        port = sock.getsockname()[1]
        sock.close()
        base = f"http://127.0.0.1:{port}"
        @contextmanager
        def serve():
            proc = subprocess.Popen([sys.executable,Path(__file__).with_name("server.py"),"serve","--db",path,"--port",str(port)])
            try:
                wait_ready(base)
                yield
            finally:
                proc.terminate()
                proc.wait(8)
        def get(token):
            return ok(api(base,"/v1/base",token=token))["base"]
        def stock():
            return ok(api(base,"/v1/inventory",token=a))["inventory"]["stock"]["structure"]["amount"]
        def edit(action, x, y, **args):
            return {"revision":get(a)["revision"],"key":secrets.token_hex(12),"action":action,"x":x,"y":y,**args}
        def post(fields):
            return api(base,"/v1/base/edit",fields,a)
        with serve():
            login = {"name":"basea","password":secrets.token_urlsafe()}
            a = ok(api(base,"/v1/accounts",login))["token"]
            b = ok(api(base,"/v1/accounts",dict(login,name="baseb")))["token"]
            original = get(a)
            assert original["buildings"][0]["kind"] == "core"
            other = get(b)
            assert original["buildings"][0]["id"] != other["buildings"][0]["id"]
            for kind,x,y in [("foundry",3,2),("warehouse",5,3),("workshop",7,2),("repair",1,5),("turret",3,5)]:
                op = edit("build",x,y,kind=kind)
                preview = dict(op)
                del preview["key"]
                before = get(a)
                assert ok(api(base,"/v1/base/preview",preview,a))["preview"]["revision"] == before["revision"]+1
                assert get(a) == before
                first = ok(post(op))
                assert ok(post(op))["receipt"] == first["receipt"]
            saved=get(a)
            assert len(saved["buildings"]) == 6 and not saved["buildings"][-1]["powered"] and stock() == 7
            # GET includes the private-base display; the frozen defense contains only layout data.
            assert saved["plaque"] is None
            frozen_layout={key:value for key,value in saved.items() if key!="plaque"}
            for bad,reason in [(edit("build",11,8,kind="foundry"),"outside_grid"),(edit("build",1,2,kind="turret"),"occupied"),
                               (edit("erase",0,4),"entrance_reserved"),(edit("erase",5,4),"road_disconnected"),
                               (edit("build",10,6,kind="repair"),"building_disconnected")]:
                assert post(bad) == (409,{"error":reason}) and get(a) == saved and stock()==7
            assert api(base,"/v1/base/edit",edit("move",6,5,building=saved["buildings"][0]["id"]),b)[0] == 409
            assert api(base,"/v1/base/edit",dict(edit("move",6,5,building=saved["buildings"][0]["id"]),revision=1),b)[0] == 404
            assert get(b)==other
            snap=ok(api(base,"/v1/base/freeze",{"key":"freeze_test","revision":saved["revision"]},a))["receipt"]["snapshot"]
            assert api(base,"/v1/base/snapshots/"+snap,token=b)[0]==404
            ok(post(edit("move",5,5,building=saved["buildings"][0]["id"])))
            current=get(a)
            assert current["buildings"][0]["x"] == 5
            assert ok(api(base,"/v1/base/snapshots/"+snap,token=a))["snapshot"]==frozen_layout
            race = [edit("road",10,4),edit("road",9,5)]
            with ThreadPoolExecutor(2) as pool:
                answers=list(pool.map(post,race))
            assert sorted(r[0] for r in answers)==[200,409]
            end=get(a)
        with serve():
            a=ok(api(base,"/v1/sessions",login))["token"]
            assert get(a)==end and stock()==7
            assert ok(api(base,"/v1/base/snapshots/"+snap,token=a))["snapshot"]==frozen_layout
            if godot:
                env = dict(os.environ,PROFILE_URL=base)
                if capture:
                    env["BASE_CAPTURE"] = str(Path(capture).resolve())
                command = [godot,"--path","game","--script","res://base/tests/base_ui.gd"]
                subprocess.run(command,env=env,check=True,timeout=60)
        print("BASE_PASS six_types preview roads power rollback concurrent isolation move freeze restart")
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot")
    parser.add_argument("--capture")
    args = parser.parse_args()
    run(args.godot,args.capture)

