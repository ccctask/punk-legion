"""M20 three-account HTTP consent, aid leases, bounded squad ownership and personal settlement."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import secrets
import tempfile
import time
from unittest.mock import patch
from check_profile import api,ok
from check_production import serve
import camp
import friends
import server
import workshop
import world_calendar


def run():
    with tempfile.TemporaryDirectory() as tmp:
        file=Path(tmp)/"calendar.json"
        data=json.loads(world_calendar.config_path().read_text(encoding="utf8"))
        data["nodes"][1]["daily"]=[[0,86400,86400]]
        file.write_text(json.dumps(data))
        db=Path(tmp)/"social.sqlite"
        with patch.dict(os.environ,{"WORLD_CALENDAR_FILE":str(file)}),serve(db) as base:
            def register():
                name="social_"+secrets.token_hex(5)
                u=ok(api(base,"/v1/accounts",{"name":name,"password":"test-password"}))
                return dict(name=name,token=u["token"],id=u["account"]["id"],robot=u["robots"][0]["id"])
            a,b,h=[register() for _ in range(3)]
            def post(who,route,body):
                return ok(api(base,route,body,who["token"]))
            def social(who,op,fields):
                return post(who,"/v1/friends/"+op,fields)
            def get(who,route):
                return ok(api(base,route,token=who["token"]))
            def room(act,body):
                return server.handle(db,"POST","/internal/camp/"+act,body,"Bearer localkey","localkey")
            def prepare(who):
                return post(who,"/v1/world/admit",{"key":secrets.token_hex(9),"node":camp.NODE})["admission"]["id"]
            def fight(who,grant):
                admission=post(who,"/v1/camp/reserve",{"grant":grant,"robots":[who["robot"]]})["admission"]
                response=room("open",{k:admission[k] for k in ("id","secret")})
                return admission["id"],response
            def offer(who,target,side="attacker"):
                return social(who,"offer",{"friend":target["name"],"robot":who["robot"],"side":side,"node":camp.NODE,"key":secrets.token_hex(8)})["aid"]
            def friends_with(x,y):
                social(x,"request",{"friend":y["name"]})
                social(y,"accept",{"friend":x["name"]})
            def finish(ident,reply,winner,damage=None):
                reports={u["chassis"]:[] for side in ["attacker","defender"] for u in reply["squads"][side]["units"]}
                if damage:
                    reports[damage]=[{"at":10,"kind":"condition","actor":"combat","target":damage,"amount":12}]
                r={"id":ident,"winner":winner,"seconds":11,"reports":reports,"reason":"core","finished_at":int(time.time())}
                return room("settle",r),room("settle",r)
            assert api(base,"/v1/friends/visit",{"friend":h["name"]},a["token"])[0]==403
            friends_with(h,a)
            friends_with(h,b)
            visit=social(a,"visit",{"friend":h["name"]})["visit"]
            assert visit["layout"]["buildings"] and "stock" not in visit
            design=post(h,"/v1/workshop/design",{"key":"design_friend","name":"红铜样机","version":1,"slots":workshop.BASE})["receipt"]["design"]
            assert len(get(a,"/v1/inventory")["inventory"]["parts"])==0
            social(h,"share",{"friend":a["name"],"design":design})
            copy=get(a,"/v1/friends")["social"]["shares"][0]
            assert copy["slots"]==workshop.BASE and copy["missing"]=={v:1 for v in workshop.BASE.values()}
            social(a,"save",{"share":copy["id"],"key":"save_shared_once"})
            assert not get(a,"/v1/inventory")["inventory"]["parts"]
            declined=offer(h,a)
            assert get(h,"/v1/profile")["robots"][0]["task"] is None
            social(a,"reject-aid",{"aid":declined})
            grant=prepare(a)
            one=offer(h,a)
            social(a,"accept-aid",{"aid":one})
            assert get(h,"/v1/profile")["robots"][0]["task"]=="aid"
            social(h,"recall",{"aid":one})
            assert get(h,"/v1/profile")["robots"][0]["task"] is None
            def race(target):
                return api(base,"/v1/friends/offer",{"friend":target["name"],"robot":h["robot"],"side":"attacker","node":camp.NODE,"key":secrets.token_hex(8)},h["token"])[0]
            with ThreadPoolExecutor(2) as pool:
                assert sorted(pool.map(race,[a,b]))==[200,409]
            active=next(x for x in get(h,"/v1/friends")["social"]["aids"] if x["phase"]=="offered")
            social(h,"recall",{"aid":active["id"]})
            one=offer(h,a)
            social(a,"accept-aid",{"aid":one})
            ident,reply=fight(a,grant)
            assert reply["squads"]["aid_owners"]=={h["robot"]:h["id"]}
            assert len(reply["squads"]["attacker"]["units"])==2
            lease=next(x for x in get(h,"/v1/friends")["social"]["aids"] if x["id"]==one)["admission"]
            assert room("open",lease)["role"]=="aid_"+h["id"]
            social(h,"recall",{"aid":one})
            social(a,"remove",{"friend":h["name"]})
            assert room("open",lease)["role"]=="aid_"+h["id"]
            assert get(h,"/v1/profile")["robots"][0]["task"]
            assert finish(ident,reply,"attacker")[0]["receipt"]["changed"]
            assert get(h,"/v1/profile")["robots"][0]["task"] is None
            assert get(h,"/v1/robots/"+h["robot"]+"/history")["history"]["totals"]["battles"]==1
            friends_with(h,a)
            defend=offer(h,a,"defender")
            social(a,"accept-aid",{"aid":defend})
            ident,reply=fight(b,prepare(b))
            assert reply["squads"]["defender"]["units"][0]["chassis"]==h["robot"]
            before=get(a,"/v1/inventory")["inventory"]["stock"]
            first,second=finish(ident,reply,"attacker",h["robot"])
            assert first==second
            assert get(a,"/v1/inventory")["inventory"]["stock"]==before
            assert get(h,"/v1/robots/"+h["robot"]+"/recovery")["recovery"]["state"]=="damaged"
            assert get(h,"/v1/robots/"+h["robot"]+"/history")["history"]["totals"]["battles"]==2
            # Seed additional real, owner-scoped machines in this disposable fixture; all dispatches below use the normal API.
            ids=[b["robot"]]
            with server.transaction(db) as txn:
                for i in range(11):
                    ident=secrets.token_hex(16)
                    txn.execute("INSERT INTO robots VALUES (?,?,?,NULL,NULL)",(ident,b["id"],"guard"+str(i)))
                    workshop.initial_fit(txn,b["id"],ident)
                    ids.append(ident)
            post(b,"/v1/camp/garrison",{"robots":ids,"turrets":ids[:1]})
            friends_with(a,b)
            extra=offer(a,b,"defender")
            assert api(base,"/v1/friends/accept-aid",{"aid":extra},b["token"])[1]["error"]=="aid_budget"
            assert get(a,"/v1/profile")["robots"][0]["task"] is None
            post(b,"/v1/camp/garrison",{"robots":ids[:-1],"turrets":ids[:1]})
            social(b,"accept-aid",{"aid":extra})
            assert api(base,"/v1/camp/garrison",{"robots":ids,"turrets":[]},b["token"])[1]["error"]=="aid_budget"
            assert len([r for r in get(b,"/v1/camp")["camp"]["robots"] if r["guard"]])==11
            social(a,"recall",{"aid":extra})
            post(b,"/v1/camp/garrison",{"robots":[],"turrets":[]})
            with server.transaction(db) as txn:
                for robot in ids[:6]:
                    for slot,part in (("head","visor"),("core","reinforced_boiler")):
                        txn.execute("UPDATE parts SET definition=? WHERE id=(SELECT item FROM mounts WHERE robot=? AND slot=?)",(part,robot,slot))
            post(b,"/v1/camp/garrison",{"robots":ids[:6],"turrets":[]})
            extra=offer(a,b,"defender")
            assert api(base,"/v1/friends/accept-aid",{"aid":extra},b["token"])[1]["error"]=="aid_budget"
            social(a,"recall",{"aid":extra})
            print("AID_POINTS_PASS six heavy units at 24 points deny additional 2-point helper")
            print("AID_BUDGET_PASS 12 guards including turret reject 13th, 11 guards plus one ally allowed, failed later overfill rolled back")
            print("SOCIAL_PASS mutual consent, read-only visit, share with missing parts, decline, recall, contested offers, attack/defense, unlink while locked, owner-only repair and replay")
if __name__=="__main__":
    run()
