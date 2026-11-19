"""Disposable real HTTP production regression. Clock injection is confined to this test process."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import threading
from unittest.mock import patch

from check_profile import api, ok
import inventory
import production
import server


@contextmanager
def serve(path):
    server.initialize(path)
    with server.ThreadingHTTPServer(("127.0.0.1",0),server.Handler) as http:
        http.path, http.room_key = path,""
        worker=threading.Thread(target=http.serve_forever,daemon=True)
        worker.start()
        try:
            yield f"http://127.0.0.1:{http.server_port}"
        finally:
            http.shutdown()
            worker.join()


def run(godot=None):
    clock=[100000]
    with tempfile.TemporaryDirectory() as temp, patch.object(production,"now",lambda: clock[0]):
        path=Path(temp)/"test.sqlite"
        def stock():
            return ok(api(base,"/v1/inventory",token=token))["inventory"]["stock"]
        def get():
            return ok(api(base,"/v1/base/production",token=token))["production"]
        def edit(action,x,y,**fields):
            state=ok(api(base,"/v1/base",token=token))["base"]
            return ok(api(base,"/v1/base/edit",dict(revision=state["revision"],key=secrets.token_hex(8),action=action,x=x,y=y,**fields),token))["base"]
        def claim(key):
            return api(base,"/v1/base/production/claim",{"key":key},token)
        def research(tech,key):
            return api(base,"/v1/base/production/research",{"tech":tech,"key":key},token)
        def register():
            fields={"name":"p_"+secrets.token_hex(6),"password":secrets.token_urlsafe()}
            user=ok(api(base,"/v1/accounts",fields))
            return fields,user["token"],user["account"]["id"]
        def facilities():
            edit("build",3,2,kind="foundry")
            edit("build",5,2,kind="workshop")
            return edit("build",7,3,kind="warehouse")
        with serve(path) as base:
            user,token,owner=register()
            assert research("drill","no_workshop")[0]==409
            state=facilities()
            foundry=state["buildings"][1]["id"]
            assert api(base,"/v1/base/production/claim",{"key":"timehack","advance":999999},token)[0]==400
            clock[0]+=1800
            seen=get()["lines"]
            assert [seen[k]["pending"] for k in production.LINES]==[1,1,0] and seen["structure"]["progress"]==600
            with ThreadPoolExecutor(4) as pool:
                results=list(pool.map(lambda _:ok(claim("same_claim"))["receipt"],range(4)))
            assert results==[results[0]]*4 and claim("new_empty")[0]==409
            edit("power",3,2,building=foundry)
            clock[0]+=3600
            seen=get()["lines"]
            assert seen["structure"]["pending"]==0 and seen["structure"]["progress"]==600 and seen["structure"]["rate"]==0
            edit("power",3,2,building=foundry)
            clock[0]+=600
            assert get()["lines"]["structure"]["pending"]==1
            with ThreadPoolExecutor(2) as pool:
                results=list(pool.map(claim,["claim_race_A","claim_race_B"]))
            assert sorted(pair[0] for pair in results)==[200,409]
            design=ok(api(base,"/v1/workshop/design",{"key":"drill_design","name":"研制型","version":1,"slots":{"core":"boiler","head":"eye","weapon":"drill"}},token))["receipt"]["design"]
            build={"key":"new_driller","name":"手摇钻","design":design}
            assert api(base,"/v1/workshop/build",build,token)[0]==403
            first=ok(research("drill","drill_research"))["receipt"]
            before=stock()
            assert ok(research("drill","drill_research"))["receipt"]==first
            assert research("drill","another_key")[0]==409 and stock()==before
            assert ok(api(base,"/v1/workshop/build",build,token))["receipt"]["robot"]
            before=get()["lines"]["structure"]["progress"]
            ok(research("casting","casting_research"))
            assert get()["lines"]["structure"]["rate"]==2
            clock[0]+=600
            assert get()["lines"]["structure"]["pending"]==1 and get()["lines"]["structure"]["progress"]==before
            ok(claim("claim_casting"))
            with server.transaction(path) as db:
                inventory.apply_stock(db,owner,{"structure":100})
            clock[0]+=7*86400
            assert get()["lines"]["structure"]["pending"]==0
            with server.transaction(path) as db:
                inventory.apply_stock(db,owner,{"structure":-1})
            assert get()["lines"]["structure"]["pending"]==0
            clock[0]+=1200
            assert get()["lines"]["structure"]["pending"]==1 and get()["lines"]["structure"]["progress"]==0
            ok(claim("near_full"))
            assert stock()["structure"]["amount"]==40
            old_user=user
            for seconds in [86400,3*86400,7*86400]:
                _,token,_=register()
                facilities()
                clock[0]+=seconds
                lines=get()["lines"]
                assert [v["pending"] for v in lines.values()]==[8,6,4]
                assert all(v["progress"]==0 for v in lines.values())
            # One foundry can make 36 units in 12h. Nine warehouses leave room for 40.
            _,token,_=register()
            edit("build",3,2,kind="foundry")
            edit("road",10,4)
            edit("road",11,4)
            for x in [0,2,4,6,8,10]:
                edit("build",x,5,kind="warehouse")
            for x in [5,7,9]:
                edit("build",x,3,kind="warehouse")
            clock[0]+=7*86400
            line=get()["lines"]["structure"]
            assert line["pending"]==36 and line["free"]==38 and line["capacity"]==40
            ok(claim("cap_window"))
            assert get()["lines"]["structure"]["pending"]==0
            if godot:
                demo,token,_=register()
                facilities()
                clock[0]+=3600
                env=dict(os.environ,PROFILE_URL=base,PRODUCTION_DEMO_NAME=demo["name"],PRODUCTION_DEMO_PASS=demo["password"])
                subprocess.run([godot,"--headless","--path","game","--script","res://base/tests/production_ui.gd"],env=env,check=True,timeout=40)
        with serve(path) as base:
            token=ok(api(base,"/v1/sessions",old_user))["token"]
            after=get()
            assert sorted(after["tech"])==["casting","drill"] and after["lines"]["structure"]["stock"]==40
            assert ok(claim("near_full"))["receipt"]["operation"]=="claim"
        print("PRODUCTION_PASS partial work offline 1/3/7d power/overflow storage claims research workshop restart")
if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--godot")
    run(cli.parse_args().godot)
