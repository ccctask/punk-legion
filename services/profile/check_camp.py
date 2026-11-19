"""Real two-account HTTP flow and atomic M19 qualification/result tests on a disposable profile."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import json
import os
import secrets
import time

from check_profile import api,ok
from check_production import serve
import camp
import server
import world_calendar as calendar


def run():
    with TemporaryDirectory() as tmp:
        db=Path(tmp)/"camp.sqlite"
        config=Path(tmp)/"calendar.json"
        data=json.loads(calendar.config_path().read_text(encoding="utf8"))
        data["nodes"][1]["daily"]=[[0,86400,86400]]
        config.write_text(json.dumps(data))
        t=[int(time.time())//86400*86400+1000]
        with patch.dict(os.environ,{"WORLD_CALENDAR_FILE":str(config),"CAMP_SPOOL_DIR":tmp}),patch.object(calendar,"now",lambda:t[0]),serve(db) as url:
            def get(who,route):
                return ok(api(url,route,token=who["token"]))
            def post(who,route,body):
                return ok(api(url,route,body,who["token"]))
            def room(action,body):
                return server.handle(db,"POST","/internal/camp/"+action,body,"Bearer roomlocal","roomlocal")
            def grant(who):
                return post(who,"/v1/world/admit",{"node":camp.NODE,"key":secrets.token_hex(9)})["admission"]["id"]
            def reserve(who):
                return post(who,"/v1/camp/reserve",{"grant":grant(who),"robots":[who["robots"][0]["id"]]})["admission"]
            def join(adm):
                return room("open",{k:adm[k] for k in ("id","secret")})
            def winner(row,side):
                return {"id":row["id"],"winner":side,"reason":"core","reports":{},"seconds":15,"finished_at":t[0]}
            users=[ok(api(url,"/v1/accounts",{"name":"camper_"+secrets.token_hex(4),"password":"test-pass-local"})) for _ in range(3)]
            a,b,c=users
            proposals=[reserve(a),reserve(b)]
            def attempt(i):
                try:
                    return join(proposals[i])
                except server.Fault as err:
                    return err.code
            with ThreadPoolExecutor(2) as pool:
                results=list(pool.map(attempt,range(2)))
            assert results.count("camp_contested")==1
            idx=next(i for i,v in enumerate(results) if isinstance(v,dict))
            a,b=users[idx],users[1-idx]
            round1=proposals[idx]
            rid=a["robots"][0]["id"]
            assert join(round1)["squads"]["neutral"] and get(b,"/v1/profile")["robots"][0]["task"] is None
            assert get(a,"/v1/profile")["robots"][0]["task"]=="expedition"
            r=winner(round1,"attacker")
            r["reports"][rid]=[]
            assert api(url,"/internal/camp/settle",r,a["token"])[0]==401
            receipt=room("settle",r)["receipt"]
            assert receipt==room("settle",r)["receipt"] and receipt["revision"]==1
            with server.transaction(db) as txn:
                weapon=txn.execute("SELECT item FROM mounts WHERE robot=? AND slot='weapon'",(rid,)).fetchone()[0]
                txn.execute("UPDATE parts SET definition='drill' WHERE id=?",(weapon,))
            assert api(url,"/v1/camp/garrison",{"robots":[rid],"turrets":[rid]},a["token"])[1]["error"]=="turret_requires_cannon"
            assert get(a,"/v1/profile")["robots"][0]["task"] is None
            with server.transaction(db) as txn:
                txn.execute("UPDATE parts SET definition='cannon' WHERE id=?",(weapon,))
            post(a,"/v1/camp/garrison",{"robots":[rid],"turrets":[rid]})
            campview=get(a,"/v1/camp")["camp"]
            assert campview["robots"][0]["guard"] and campview["robots"][0]["turret"] and campview["mine"]
            t[0]+=camp.SECONDS_PER_UNIT*20
            assert get(a,"/v1/camp")["camp"]["stock"]==camp.CAPACITY
            collected=post(a,"/v1/camp/claim",{"key":"produce_001"})["receipt"]
            assert collected["changes"]["structure"]==camp.CAPACITY and collected==post(a,"/v1/camp/claim",{"key":"produce_001"})["receipt"]
            challenger=reserve(c)
            fight=join(challenger)
            assert not fight["squads"]["neutral"] and fight["squads"]["turrets"]==[rid]
            defense=get(a,"/v1/camp")["camp"]["admission"]
            assert defense["id"]==challenger["id"] and defense["secret"]!=challenger["secret"]
            assert join(defense)["role"]=="defender"
            result=winner(challenger,"attacker")
            result["reports"]={rid:[],c["robots"][0]["id"]:[]}
            protected=get(a,"/v1/inventory")["inventory"]
            t[0]+=1
            room("settle",result)
            assert get(c,"/v1/camp")["camp"]["mine"]
            assert not get(a,"/v1/camp")["camp"]["mine"]
            after=get(a,"/v1/inventory")["inventory"]
            assert all(after[k]==protected[k] for k in ("stock","parts","blueprints"))
            assert get(a,"/v1/profile")["robots"][0]["task"] is None
            assert get(a,"/v1/robots/"+rid+"/history")["history"]["totals"]["battles"]==2
            t[0]+=86400
            retrykey="first_attempt_stable"
            oldgrant=post(b,"/v1/world/admit",{"node":camp.NODE,"key":retrykey})["admission"]["id"]
            payload={"grant":oldgrant,"robots":[b["robots"][0]["id"]]}
            last=post(b,"/v1/camp/reserve",payload)["admission"]
            assert not join(last)["squads"]["defender"]["units"]
            t[0]+=camp.ROUND_LIMIT+60
            assert not get(b,"/v1/camp")["camp"]["active"]
            assert get(b,"/v1/profile")["robots"][0]["task"] is None
            assert post(b,"/v1/world/admit",{"node":camp.NODE,"key":retrykey})["admission"]["id"]==oldgrant
            assert post(b,"/v1/camp/reserve",payload)["admission"]["id"]==last["id"]
            assert join(last)["receipt"]["reason"]=="expired"
            newgrant=grant(b)
            assert newgrant!=oldgrant
            new=post(b,"/v1/camp/reserve",dict(payload,grant=newgrant))["admission"]
            binding=join(new)
            assert new["id"]!=last["id"] and binding["role"]=="attacker"
            assert post(b,"/v1/world/admit",{"node":camp.NODE,"key":retrykey})["admission"]["id"]==oldgrant
            print("CAMP_SAME_WINDOW_PASS old business key returns settled battle; new intent after loss opens new battle in same window")
            finished=winner(new,"attacker")
            finished["reports"]={b["robots"][0]["id"]:[]}
            Path(tmp,new["id"]+".result.json").write_text(json.dumps({"result":finished}))
            t[0]=binding["expires"]+15
            state=get(b,"/v1/camp")["camp"]
            assert state["mine"] and state["last"]["id"]==new["id"]
            assert room("settle",finished)["receipt"]==state["last"]
            print("CAMP_LATE_TERMINAL_PASS overdue sweep recovers once before late original RPC")
            print("CAMP_SERVICE_PASS simultaneous ENet open, no losing reservation lock, neutral, real garrison, guard takeover, single claim/transfer, old inventory retained, expiry")
if __name__=="__main__":
    run()
