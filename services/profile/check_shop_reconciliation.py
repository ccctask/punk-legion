"""M22 separate payment history, partial fulfilment, legacy snapshots and tamper checks."""
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import secrets
import sqlite3
import sys
import tempfile
import zipfile

import server
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools/operations"))
import snapshot


def run(folder):
    path=folder/"player.sqlite"
    server.initialize(path)
    login=server.handle(path,"POST","/v1/accounts",dict(name="shop_drill",password=secrets.token_urlsafe()),"")
    def call(route,data):
        return server.handle(path,"POST","/v1/store/"+route,data,"Bearer "+login["token"])
    def capture(name,alter=()):
        target=folder/name
        target.mkdir()
        file=target/"player.sqlite"
        with closing(sqlite3.connect(path)) as src,closing(sqlite3.connect(file)) as db:
            src.backup(db)
            with db:
                for sql in alter:db.execute(sql)
        archive=target/"player-profiles.zip"
        with zipfile.ZipFile(archive,"w") as z:z.write(file,"player.sqlite")
        with archive.open("rb") as stream:digest=hashlib.file_digest(stream,"sha256").hexdigest()
        (target/"manifest.json").write_text(json.dumps({"volumes":{"player-profiles":{"sha256":digest}}}))
        return target
    legacy=capture("legacy",["DROP TABLE shop_events","DROP TABLE shop_orders","DROP TABLE robot_paint"])
    empty=capture("empty")
    assert snapshot.reconcile(legacy,empty)==[]
    oid=call("order",{"key":"m22-shop-test","sku":"paint_mint"})["order"]
    call("simulate",dict(order=oid,result="paid"))
    paid=capture("pending")
    delta=snapshot.reconcile(empty,paid)
    assert [r["operation"] for r in delta]==["shop_created","shop_paid"]
    assert all(set(r)=={"id","operation","event","sku"} and r["id"]==oid for r in delta)
    call("simulate",dict(order=oid,result="retry"))
    delivered=capture("delivered")
    assert [r["operation"] for r in snapshot.reconcile(paid,delivered)]==["shop_delivered"]
    call("equip",dict(robot=login["robots"][0]["id"],paint="mint"))
    call("simulate",dict(order=oid,result="refund"))
    refunded=capture("refunded")
    assert [r["operation"] for r in snapshot.reconcile(delivered,refunded)]==["shop_refunded"]
    for index,sql in enumerate(["UPDATE shop_orders SET price=100","UPDATE shop_orders SET intent='changed'",
            "UPDATE shop_events SET at=at+1","UPDATE shop_orders SET state='delivered'",
            "INSERT INTO robot_paint SELECT id,'mint' FROM robots"]):
        try:snapshot.reconcile(refunded,capture("corrupt"+str(index),[sql]))
        except ValueError:pass
        else:raise AssertionError("invalid business state accepted")
    print("SHOP_RECONCILE_PASS legacy, created, paid-pending, delivered, refund, original order/event fields, rights consistency, redaction")

if __name__=="__main__":
    os.environ["PUNK_TEST_PAYMENTS"]="1"
    with tempfile.TemporaryDirectory() as folder:run(Path(folder))
