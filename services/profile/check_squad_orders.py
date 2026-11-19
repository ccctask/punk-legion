"""M04 checks persisted identity, authorization, frozen deployments and v16 compatibility."""
from pathlib import Path
import json
import secrets
import tempfile
import uuid
import server
import workshop
from inventory import Fault

def check():
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/"profile.sqlite"
        server.initialize(path)
        a=server.login(path,dict(name="orders_a",password=secrets.token_urlsafe()),True)
        b=server.login(path,dict(name="orders_b",password=secrets.token_urlsafe()),True)
        auth="Bearer "+a["token"]
        robot=a["robots"][0]["id"]
        foreign=b["robots"][0]["id"]
        # Emulate the already shipped schema on a database with genuine existing robots.
        with server.transaction(path) as db:
            db.execute("DROP TABLE robot_orders")
            db.execute("PRAGMA user_version=16")
        server.initialize(path)
        server.initialize(path)
        def get():return server.handle(path,"GET","/v1/workshop",{},auth)["workshop"]
        def post(action,fields):
            return server.handle(path,"POST","/v1/workshop/"+action,dict(fields,key=uuid.uuid4().hex),auth)
        def reject(action,fields,code):
            try:post(action,fields)
            except Fault as exc:assert exc.code==code,(exc.code,code)
            else:raise AssertionError("invalid change accepted")
        assert get()["robots"][0]["orders"]==workshop.default_orders({})
        design=post("design",dict(name="default",version=1,slots=workshop.BASE))["receipt"]["design"]
        ally=post("build",dict(name="partner",design=design))["receipt"]["robot"]
        config=dict(role="front",guard=ally,distance="standoff",priority="weakest",retreat=25)
        old_stock=get()["stock"]
        reject("orders",dict(robot=foreign,orders=config),"unknown_robot")
        for target in (robot,foreign,"invalid"):
            reject("orders",dict(robot=robot,orders=dict(config,guard=target)),"invalid_guard")
        for fields in [dict(config,retreat=True),dict(config,priority="custom"),dict(config,role="assistant"),dict(config,distance="any")]:
            reject("orders",dict(robot=robot,orders=fields),"invalid_orders")
        post("orders",dict(robot=robot,orders=config))
        server.handle(path,"POST",f"/v1/robots/{robot}/rename",dict(name="after-renaming"),auth)
        dep=server.handle(path,"POST","/v1/workshop/deployment",dict(robots=[ally,robot]),auth)["deployment"]
        assert dep["orders"][robot]==config and dep["orders"][ally]["role"]=="fire" and get()["stock"]==old_stock
        response=server.handle(path,"POST","/v1/expedition/start",dict(key=uuid.uuid4().hex,robots=[robot]),auth)
        mission=response["receipt"]["mission"]
        reject("orders",dict(robot=robot,orders=None),"robot_busy")
        with server.transaction(path) as db:
            frozen=json.loads(db.execute("SELECT deployment FROM expeditions WHERE id=?",(mission,)).fetchone()[0])
            pinned=json.loads(db.execute("SELECT snapshot FROM robot_sorties WHERE robot=?",(robot,)).fetchone()[0])
            assert frozen["orders"][robot]==pinned["orders"]==config
        post("orders",dict(robot=ally,orders=dict(config,guard="",role="support")))
        post("orders",dict(robot=ally,orders=None))
        assert get()["robots"][1]["orders"]["role"]=="fire" and not get()["robots"][1]["custom_orders"]
        assert get()["robots"][0]["orders"]==config
    print("SQUAD_ORDERS_STORAGE_PASS v16 upgrade; ownership, guard, role and choice checks; rename, reset and natural expedition snapshot.")

if __name__=="__main__":check()
