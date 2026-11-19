"""M13 transactional regression with an isolated server clock and real SQLite transactions."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import tempfile
from unittest.mock import patch

import recovery
import server
import service_record
import workshop
from inventory import Fault


def run():
    with tempfile.TemporaryDirectory() as temp:
        dbpath = Path(temp)/"profile.sqlite"
        reference = Path(temp)/"current.sqlite"
        server.initialize(reference)
        credentials = {"name":"recovery_user","password":"temporary-fixture-password"}
        a = server.login(reference,credentials,True)
        token = a["token"]
        owner,robot = a["account"]["id"],a["robots"][0]["id"]
        # Construct the genuine v5 fixture: later modules must never be present before their migrations.
        with server.transaction(reference) as current, server.transaction(dbpath) as db:
            for table in ("accounts","robots"):
                definition = current.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name=?",(table,)).fetchone()[0]
                db.execute(definition)
                row = tuple(current.execute("SELECT * FROM "+table).fetchone())
                db.execute("INSERT INTO "+table+" VALUES ("+",".join("?" for _ in row)+")",row)
            server.inventory.create_tables(db)
            server.inventory.seed(db,owner)
            workshop.create_tables(db)
            service_record.create_tables(db)
            service_record.add_lease(db)
            db.execute("UPDATE robots SET task='guard',assignment='existing-guard' WHERE id=?",(robot,))
            db.execute("PRAGMA user_version=5")
        server.initialize(dbpath)
        server.initialize(dbpath)
        migrated = server.handle(dbpath,"GET","/v1/profile",{},"Bearer "+token)["robots"][0]
        assert migrated["id"]==robot and migrated["state"]=="ready" and migrated["assignment"]=="existing-guard"
        server.handle(dbpath,"POST",f"/v1/robots/{robot}/finish",{"outcome":"completed","assignment":"existing-guard"},"Bearer "+token)
        route = f"/v1/robots/{robot}/recovery"
        def call(path,body=None):
            return server.handle(dbpath,"POST" if body is not None else "GET",path,body or {},"Bearer "+token)
        def denied(code,fn):
            try:
                fn()
            except Fault as exc:
                assert exc.code == code,(exc.code,code)
            else:
                raise AssertionError(f"expected {code}")
        def funds():
            return {r:v["amount"] for r,v in call("/v1/inventory")["inventory"]["stock"].items()}
        def view():
            return call(route)["recovery"]
        def damage(target,mission):
            with server.transaction(dbpath) as db:
                ticket = service_record.start_mission(db,owner,target,mission)
                event = {"at":5,"kind":"disabled","actor":"npc","target":target,"amount":4}
                service_record.finish_mission(db,ticket,mission,"loss",[event],6)
                service_record.finish_mission(db,ticket,mission,"loss",[event],6)
        frozen = call("/v1/workshop")["workshop"]["robots"][0]["slots"]
        damage(robot,"fixture_battle_1")
        assert view()["state"]=="damaged" and len(view()["recent"])==1
        denied("unit_unavailable",lambda:call("/v1/inventory/admit",{"key":"deny_admit","robot":robot}))
        before = funds()
        with ThreadPoolExecutor(4) as pool:
            receipts = list(pool.map(lambda _:call(route+"/repair",{"key":"repair_001"})["receipt"],range(4)))
        assert all(r==receipts[0] for r in receipts)
        assert funds()["structure"]==before["structure"]-1 and funds()["components"]==before["components"]-1
        assert view()["state"]=="repairing"
        denied("repair_in_progress",lambda:call(f"/v1/robots/{robot}/finish",{"assignment":"fake","outcome":"completed"}))
        due = view()["due"]
        with patch("time.time",return_value=due+1):
            token = server.login(dbpath,credentials,False)["token"]
            assert view()["state"]=="ready" and sum(e["kind"]=="workshop_repair" for e in view()["recent"])==1
        assert call("/v1/workshop")["workshop"]["robots"][0]["slots"]==frozen
        draft = call("/v1/workshop/design",{"key":"make_design","name":"轻机","version":1,"slots":workshop.BASE})
        balance = funds()
        spare = call("/v1/workshop/build",{"key":"build_spare","name":"待回收机","design":draft["receipt"]["design"]})["receipt"]["robot"]
        salvage = f"/v1/robots/{spare}/recovery"
        preview = call(salvage)["recovery"]
        confirm = {"key":"salvage_spare","quote":preview["quote"],"confirmed":True}
        denied("recycle_preview_changed",lambda:call(salvage+"/recycle",dict(confirm,confirmed=False)))
        first = call(salvage+"/recycle",confirm)["receipt"]
        assert call(salvage+"/recycle",confirm)["receipt"]==first
        assert all(amount<=balance[k] for k,amount in funds().items()) and funds()["structure"]<balance["structure"]
        assert spare not in [r["id"] for r in call("/v1/workshop")["workshop"]["robots"]]
        assert call(f"/v1/robots/{spare}/history")["history"]["totals"]["battles"]==0
        damage(robot,"fixture_battle_2")
        with server.transaction(dbpath) as db:
            db.execute("UPDATE stocks SET amount=0 WHERE owner=?",(owner,))
        denied("insufficient_stock",lambda:call(route+"/repair",{"key":"cannot_pay"}))
        relief = call(route+"/relief",{"key":"only_relief"})["receipt"]
        assert call(route+"/relief",{"key":"only_relief"})["receipt"]==relief and view()["voucher"]
        denied("relief_cooldown",lambda:call(route+"/relief",{"key":"again_relief"}))
        assert not any(funds().values()) and view()["state"]=="ready" and view()["return"]=={}
        ticket = call("/v1/inventory/admit",{"key":"relief_entry","robot":robot})["receipt"]["ticket"]
        assert not view()["voucher"] and not any(funds().values())
        call(f"/v1/robots/{robot}/finish",{"assignment":ticket,"outcome":"cancelled"})
        assert view()["voucher"] and not any(funds().values())
        denied("keep_last_robot",lambda:call(route+"/recycle",{"key":"scrap_last","quote":view()["quote"],"confirmed":True}))
        print("RECOVERY_PASS schema5 migration preserves existing robot/assignment; damage, unchanged inventory, no disabled deployment, concurrent repair, server-clock completion,")
        print("stable identity, distinct workshop event, salvage quote/confirm and replay, no salvage profit,")
        print("empty account relief, free entry, cancellation restores voucher without cash, cooldown and last robot retained")

if __name__=="__main__":
    run()
