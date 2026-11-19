"""Persistence, lease recovery and finite loot regression with two accounts over HTTP."""
import json
import os
from pathlib import Path
import secrets
import tempfile
from unittest.mock import patch

import expedition
import server
from check_profile import api,ok
from check_production import serve


def run():
    with tempfile.TemporaryDirectory() as d, patch.dict(os.environ,{"SOLO_SPOOL_DIR":d}):
        path=Path(d)/"player.sqlite"
        key=secrets.token_hex(32)
        def register():
            return ok(api(url,"/v1/accounts",{"name":"exp_"+secrets.token_hex(6),"password":secrets.token_urlsafe()}))
        def start(row):
            fields={"key":secrets.token_hex(9),"robots":[row["robots"][0]["id"]]}
            rsp=ok(api(url,"/v1/expedition/start",fields,row["token"]))
            assert ok(api(url,"/v1/expedition/start",fields,row["token"]))["receipt"]==rsp["receipt"]
            return rsp["expedition"]["active"]
        def trusted(data):
            return server.handle(path,"POST","/internal/expedition/settle",data,"Bearer "+key,key)["receipt"]
        def result(m,robot,outcome="win"):
            return {"id":m["id"],"outcome":outcome,"seconds":193,"nodes":["scrap","coil"],"reports":{robot:[]}}
        with serve(path) as url:
            a,b=register(),register()
            robot=a["robots"][0]["id"]
            not_mine=b["robots"][0]["id"]
            assert api(url,"/v1/expedition/start",{"key":"not_owned","robots":[not_mine]},a["token"])[0]==409
            mission=start(a)
            result1=result(mission,robot)
            assert api(url,"/internal/expedition/settle",result1,a["token"])[0]==401
            with server.transaction(path) as db:
                for _ in range(24):
                    db.execute("INSERT INTO parts VALUES (?,?,'cannon')",(secrets.token_hex(16),a["account"]["id"]))
                db.execute("UPDATE expeditions SET expires=1050 WHERE id=?",(mission["id"],))
            Path(d,mission["id"]+".result.json").write_text(json.dumps({"finished_at":1049,"result":result1}),encoding="utf8")
        with serve(path) as url:
            account=ok(api(url,"/v1/expedition",token=a["token"]))["expedition"]
            assert account["last"]["outcome"]=="win" and account["pending_drill"]
            assert trusted(result1)==account["last"]
            assert ok(api(url,"/v1/robots/"+robot+"/history",token=a["token"]))["history"]["totals"]["battles"]==1
            try:
                trusted(dict(result1,outcome="retreat"))
            except server.Fault as exc:
                assert exc.code=="result_conflict"
            else:
                raise AssertionError("different duplicate accepted")
            claim={"key":"recover_first"}
            assert api(url,"/v1/expedition/claim-first",claim,a["token"])[0]==409
            # A full backpack can be relieved via outfitting or other inventory sinks.
            # Reserve one empty slot in the isolated fixture, then redeem via the actual HTTP route.
            with server.transaction(path) as db:
                part=db.execute("SELECT id FROM parts WHERE owner=? AND id NOT IN (SELECT item FROM mounts) LIMIT 1",(a["account"]["id"],)).fetchone()[0]
                db.execute("DELETE FROM parts WHERE id=?",(part,))
            award=ok(api(url,"/v1/expedition/claim-first",claim,a["token"]))["receipt"]
            assert award["part"]["definition"]=="drill" and ok(api(url,"/v1/expedition/claim-first",claim,a["token"]))["receipt"]==award
            with server.transaction(path) as db:
                db.execute("DELETE FROM parts WHERE owner=? AND id NOT IN (SELECT item FROM mounts)",(a["account"]["id"],))
            with patch.object(expedition.secrets,"randbelow",return_value=4):
                second=trusted(result(start(a),robot))
                third=trusted(result(start(a),robot))
            assert not second["rare"] and third["rare"] and third["part"]["definition"]=="reinforced_boiler"
            defeated=start(b)
            defeat=result(defeated,not_mine,"defeat")
            defeat["reports"][not_mine]=[{"at":193,"kind":"disabled","actor":"enemy","target":not_mine,"amount":1}]
            assert trusted(defeat)["changes"]=={}
            assert ok(api(url,"/v1/robots/"+not_mine+"/recovery",token=b["token"]))["recovery"]["state"]=="damaged"
            expired=start(a)
            with server.transaction(path) as db:
                db.execute("UPDATE expeditions SET expires=100 WHERE id=?",(expired["id"],))
            assert ok(api(url,"/v1/expedition",token=a["token"]))["expedition"]["last"]["outcome"]=="expired"
            assert trusted(result(expired,robot))["outcome"]=="expired"
        print("SOLO_LEDGER_PASS owner isolation untrusted result future TTL proof replay full bag first redemption pity loss expiry")
if __name__=="__main__":
    run()
