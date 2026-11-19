"""M21 store ledger, capacity, durable orders, refits and legacy design preservation."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
from unittest.mock import patch

import server
import workshop
from check_production import serve


def run(godot=None,capture=None):
    with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,{"PUNK_TEST_PAYMENTS":"1"}):
        db=Path(folder)/"store.sqlite"
        server.initialize(db)
        cred={"name":"store_fixture","password":"test-store-pass"}
        def login(new):return server.handle(db,"POST","/v1/accounts" if new else "/v1/sessions",cred,"")
        user=login(True)
        token=user["token"]
        robot=user["robots"][0]["id"]
        def request(route,body=None):
            return server.handle(db,"POST" if body is not None else "GET",route,body or {},"Bearer "+token)
        def reject(reason,func):
            try:func()
            except server.Fault as exc:assert exc.code==reason,(exc.code,reason)
            else:raise AssertionError(reason)
        def buy(sku,key=None):return request("/v1/store/order",dict(sku=sku,key=key or secrets.token_hex(8)))["order"]
        def result(oid,r):return request("/v1/store/simulate",dict(order=oid,result=r))["store"]
        def fit(name,**extra):return request("/v1/workshop/design",dict(key=secrets.token_hex(8),name=name,version=1,slots=workshop.BASE,**extra))["receipt"]["design"]
        def deploy():return request("/v1/workshop/deployment",dict(robots=[robot]))["deployment"]
        raw=deploy()
        inventory=request("/v1/inventory")["inventory"]["stock"]
        cancelled=buy("paint_mint");result(cancelled,"cancel");assert result(cancelled,"success")["orders"][0]["state"]=="cancelled"
        failed=buy("paint_mint");result(failed,"fail");assert result(failed,"success")["orders"][0]["state"]=="failed"
        with ThreadPoolExecutor(4) as pool:
            ids=list(pool.map(lambda _:buy("paint_mint","repeat_intent"),range(4)))
        assert len(set(ids))==1
        oid=ids[0]
        result(oid,"paid")
        assert "mint" not in request("/v1/store")["store"]["styles"]
        token=login(False)["token"]
        with ThreadPoolExecutor(4) as pool:
            list(pool.map(lambda _:result(oid,"retry"),range(4)))
        order=request("/v1/store")["store"]["orders"][0]
        assert [e["state"] for e in order["events"]]==["created","paid","delivered"]
        reject("product_limit",lambda:buy("paint_mint"))
        request("/v1/store/equip",dict(robot=robot,paint="mint"))
        painted=deploy()
        assert painted["paints"][robot]=="mint" and {k:v for k,v in raw.items() if k!="paints"}=={k:v for k,v in painted.items() if k!="paints"}
        assert request("/v1/inventory")["inventory"]["stock"]==inventory
        result(oid,"refund"); result(oid,"success"); result(oid,"refund")
        assert deploy()["paints"][robot]=="base"
        reject("paint_not_owned",lambda:request("/v1/store/equip",dict(robot=robot,paint="mint")))
        fresh=buy("paint_mint");result(fresh,"success")
        names=[fit("design"+str(i)) for i in range(1,7)]
        newer=fit("design1")
        assert request("/v1/workshop")["workshop"]["design_used"]==6
        reject("design_slots_full",lambda:fit("design7"))
        o7=buy("extra_slot");result(o7,"success")
        d7=fit("design7")
        o8=buy("extra_slot");result(o8,"success")
        d8=fit("design8")
        reject("design_slots_full",lambda:fit("design9"))
        reject("product_limit",lambda:buy("extra_slot"))
        result(o8,"refund")
        reject("inactive_design",lambda:request("/v1/workshop/build",dict(design=d8,key="legacy_build",name="old")))
        d9=fit("design9",replace=names[1])
        view=request("/v1/workshop")["workshop"]
        assert view["design_used"]==7 and any(d["id"]==d8 and not d["active"] for d in view["designs"])
        request("/v1/workshop/remove",dict(key="free_slot_1",design=d9))
        alternate=dict(workshop.BASE,weapon="drill")
        drill=request("/v1/workshop/design",dict(key="drill_scheme",name="钻头方案",version=1,slots=alternate))["receipt"]["design"]
        reject("design_part_missing",lambda:request("/v1/workshop/apply",dict(key="without_drill",robot=robot,design=drill)))
        assert deploy()["inventory"]==raw["inventory"]
        result(o7,"refund")
        # Represent a v11 database with >6 historical names and multiple revisions.
        with server.transaction(db) as conn:
            for table in ("shop_events","shop_orders","robot_paint","design_positions"):
                conn.execute("DROP TABLE "+table)
            conn.execute("PRAGMA user_version=11")
        server.initialize(db)
        migrated=request("/v1/workshop")["workshop"]
        assert migrated["design_used"]==6 and len(migrated["designs"])==len(view["designs"])+1
        assert {d["id"] for d in migrated["designs"]}>={d8,d7,d9,newer,*names}
        with patch.dict(os.environ,{"PUNK_TEST_PAYMENTS":"0"}):
            reject("test_payments_disabled",lambda:buy("extra_slot"))
        print("STORE_LEDGER_PASS concurrent retry, payment success/hold/redelivery/cancel/fail/refund/repurchase, free paint, unchanged deployment and stocks")
        print("DESIGN_SLOTS_PASS six/eight/nine, same-name version, swap and remove, missing actual item, downgrade, v11 overflow archive preserved")
        if godot:
            root=Path(__file__).resolve().parents[2]
            with serve(db) as url:
                cmd=[godot,"--path",str(root/"game"),"--script","res://store/tests/store_ui.gd"]
                if not capture:cmd.insert(1,"--headless")
                subprocess.run(cmd,env={**os.environ,"PROFILE_URL":url,"ROOM_HOST":"127.0.0.1:24999","STORE_CAPTURE":str(Path(capture).resolve()) if capture else ""},check=True,timeout=60)

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--godot")
    p.add_argument("--capture")
    args=p.parse_args()
    run(args.godot,args.capture)
