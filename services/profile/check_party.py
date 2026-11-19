"""Transactional membership, budget, ownership, rejoin and frozen group recovery regression."""
import json
import os
from pathlib import Path
import secrets
import tempfile
from unittest.mock import patch

import server
import workshop
from check_profile import api,ok
from check_production import serve

def run():
    with tempfile.TemporaryDirectory() as d, patch.dict(os.environ,{"PARTY_SPOOL_DIR":d}):
        path=Path(d)/"players.sqlite"
        key=secrets.token_hex(32)
        with serve(path) as url:
            users=[ok(api(url,"/v1/accounts",{"name":"party_"+secrets.token_hex(6),"password":secrets.token_urlsafe()})) for _ in range(4)]
            def room(i,op=None,data=None):
                return api(url,"/v1/party"+("/"+op if op else ""), (data or {}) if op else None,users[i]["token"])
            def state(i):
                return ok(room(i))["party"]["roomscope"]
            def trusted(op,data):
                return server.handle(path,"POST","/internal/party/"+op,data,"Bearer "+key,key)
            def robots(i):
                return [u["id"] for u in ok(api(url,"/v1/workshop",token=users[i]["token"]))["workshop"]["robots"]]
            invite=ok(room(0,"create"))["party"]["roomscope"]["code"]
            for i in (1,2):ok(room(i,"join",{"code":invite}))
            assert room(3,"join",{"code":invite})[1]["error"]=="party_full"
            ok(room(0,"leave"))
            assert state(1)["leader"]==users[1]["account"]["id"]
            assert room(2,"start")[1]["error"]=="leader_only"
            assert room(1,"start")[1]["error"]=="not_ready"
            assert room(1,"ready",{"robots":robots(2)})[1]["error"]=="unit_unavailable"
            # Eight light robots on one account and five on another exceed the shared budget.
            with server.transaction(path) as db:
                for i,n in ((1,7),(2,4)):
                    owner=users[i]["account"]["id"]
                    for _ in range(n):
                        rid=secrets.token_hex(16)
                        db.execute("INSERT INTO robots VALUES (?,?,?,NULL,NULL)",(rid,owner,"Fixture"))
                        workshop.initial_fit(db,owner,rid)
            ok(room(1,"ready",{"robots":robots(1)}))
            assert room(2,"ready",{"robots":robots(2)})[1]["error"]=="team_budget"
            ok(room(1,"ready",{"robots":[robots(1)[0]]}))
            ok(room(2,"ready",{"robots":[robots(2)[0]]}))
            robot=robots(2)[0]
            with server.transaction(path) as db:
                mount=db.execute("SELECT item FROM mounts WHERE robot=? AND slot='head'",(robot,)).fetchone()[0]
                db.execute("DELETE FROM mounts WHERE item=?",(mount,))
                workshop.insert_part(db,users[2]["account"]["id"],robot,"head","visor")
            assert room(1,"start")[1]["error"]=="changed_fit"
            assert not state(1).get("admission")
            ok(room(2,"ready",{"robots":[robot]}))
            active=ok(room(1,"start"))["party"]["roomscope"]
            assert ok(room(1,"start"))["party"]["roomscope"]==active
            participants={}
            for i in (1,2):
                owner=users[i]["account"]["id"]
                ticket=state(i)["admission"]
                assert ticket["id"]==active["id"] and trusted("open",ticket)["owner"]==owner
                assert ok(api(url,"/v1/expedition",token=users[i]["token"]))["expedition"]["active"] is None
                participants[owner]={"participated":True,"outcome":"win","reports":{robots(i)[0]:[]},"nodes":["scrap","coil"],"seconds":193,"commanded":i==1}
            with server.transaction(path) as db:
                db.execute("UPDATE expeditions SET expires=200")
            Path(d,active["id"]+".result.json").write_text(json.dumps({"id":active["id"],"results":participants,"finished_at":199}),encoding="utf8")
            payload={"id":active["id"],"results":participants}
            assert not state(1)
            response=trusted("settle",payload)
            assert trusted("settle",payload)==response
            for i in (1,2):
                assert ok(room(i))["party"]["last"]["outcome"]=="win"
                history=ok(api(url,"/v1/robots/"+robots(i)[0]+"/history",token=users[i]["token"]))["history"]
                assert history["totals"]["battles"]==1
                guide=ok(api(url,"/v1/onboarding",token=users[i]["token"]))["guide"]
                assert guide["daily"]["complete"] and guide["daily"]["mode"]=="party"
                assert guide["facts"]["command"]==(i==1)
            first_round=active["id"]
            energy_before=[ok(api(url,"/v1/inventory",token=users[i]["token"]))["inventory"]["stock"]["energy"]["amount"] for i in (1,2)]
            for i in (2,1):
                joined=ok(room(i,"again",{"round":first_round}))["party"]["roomscope"]
                assert joined["code"]==invite and joined["team"]==first_round and joined["id"]!=first_round
                assert ok(room(i,"again",{"round":first_round}))["party"]["roomscope"]==joined
            assert state(1)["leader"]==users[1]["account"]["id"]
            for i in (1,2):
                assert ok(api(url,"/v1/inventory",token=users[i]["token"]))["inventory"]["stock"]["energy"]["amount"]==energy_before[i-1]
                ok(room(i,"ready",{"robots":[robots(i)[1]]}))
            assert room(1,"start",{"round":first_round})[1]["error"]=="round_changed"
            assert trusted("settle",payload)==response
            second_round=ok(room(1,"start",{"round":joined["id"]}))["party"]["roomscope"]
            assert second_round["id"]!=first_round
            for i in (1,2):
                assert ok(api(url,"/v1/inventory",token=users[i]["token"]))["inventory"]["stock"]["energy"]["amount"]==energy_before[i-1]-1
            second_results={users[i]["account"]["id"]:{"participated":True,"outcome":"retreat","reports":{robots(i)[1]:[]},"nodes":[],"seconds":12} for i in (1,2)}
            trusted("settle",{"id":second_round["id"],"results":second_results})
            for i in (1,2):
                before=ok(api(url,"/v1/inventory",token=users[i]["token"]))["inventory"]["stock"]
                for _ in range(2):assert not ok(room(i,"finish",{"round":second_round["id"]}))["party"]["continuation"]
                assert before==ok(api(url,"/v1/inventory",token=users[i]["token"]))["inventory"]["stock"]
            print("PARTY_CONTINUITY_PASS same team, distinct sortie, opt-in free, stale start rejected, new locks, old receipt replay, no cost on finish")
            print("PARTY_LEDGER_PASS fourth rejected; leader reassigned; stale refit and cross-owner denied; budget 13 rejected; atomic start; solo isolation; TTL frozen group recovered; idempotent personal histories")

if __name__=="__main__":run()
