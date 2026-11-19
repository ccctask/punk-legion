"""Two-site physical allocations, combat locking, legacy idempotency and local transfer."""
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import json
import os
import uuid

import camp
import server
import workshop
import world_calendar as world


def run():
    brass,coil=world.CAMP_RESOURCES
    with TemporaryDirectory() as tmp:
        path=Path(tmp)/"profile.db"
        file=Path(tmp)/"calendar.json"
        config=json.loads(world.config_path().read_text(encoding="utf8"))
        for n in config["nodes"]:
            if n["type"]=="camp":n["daily"]=[[0,86400,86400]]
        file.write_text(json.dumps(config),encoding="utf8")
        t=[2100000000]
        server.initialize(path)
        visitor=server.login(path,{"name":"calendar_guest","password":"local-client"},True)["account"]["id"]
        midnight=t[0]//86400*86400
        for second,open_site,closed_site in ((14500,brass,coil),(32500,coil,brass),(86399,coil,brass),(300,coil,brass)):
            with patch.object(world,"now",lambda:midnight+second),server.transaction(path) as db:
                states={n["id"]:n["state"] for n in world.view(db,visitor)["nodes"] if n["type"]=="camp"}
                assert states[open_site]=="open" and states[closed_site]=="closed"
                world.admit(db,visitor,open_site,uuid.uuid4().hex)
                try:world.admit(db,visitor,closed_site,uuid.uuid4().hex)
                except server.Fault as err:assert err.code=="camp_closed",err.code
                else:raise AssertionError("out of window")
        with patch.dict(os.environ,WORLD_CALENDAR_FILE=str(file)),patch.object(world,"now",lambda:t[0]):
            server.initialize(path)
            a,b=[server.login(path,{"name":name,"password":"local-client"},True) for name in ("keeper","challenger")]
            one=a["robots"][0]["id"]
            enemy=b["robots"][0]["id"]
            def req(who,url,data=None):
                return server.handle(path,"GET" if data is None else "POST",url,data or {},"Bearer "+who["token"])
            def cmd(**kw):return dict(key=uuid.uuid4().hex,**kw)
            def reject(f,code):
                try:f()
                except server.Fault as exc:assert exc.code==code,(exc.code,code)
                else:raise AssertionError(code)
            def reserve(who,site,rid):
                grant=req(who,"/v1/world/admit",cmd(node=site))["admission"]
                return req(who,"/v1/camp/"+site+"/reserve",dict(grant=grant["id"],robots=[rid]))["admission"]
            def trusted(op,body):
                return server.handle(path,"POST","/internal/camp/"+op,body,"Bearer testkey","testkey")
            def open_seat(seat):
                return trusted("open",{k:seat[k] for k in ("id","secret")})
            def finish(seat,reports,winner="attacker"):
                args=dict(id=seat["id"],winner=winner,reason="core",seconds=18,finished_at=t[0],reports={r:[] for r in reports})
                first=trusted("settle",args)
                assert trusted("settle",args)==first
                return first
            def guards(site,ids):
                return req(a,"/v1/camp/"+site+"/garrison",dict(robots=ids,turrets=[]))
            def view(who,site):return req(who,"/v1/camp/"+site)["camp"]
            design=req(a,"/v1/workshop/design",cmd(name="Dock crew",version=1,slots=workshop.BASE))["receipt"]["design"]
            two=req(a,"/v1/workshop/build",cmd(design=design,name="Second"))["receipt"]["robot"]
            left=reserve(a,brass,one)
            wrong=reserve(a,coil,one)
            assert open_seat(left)["squads"]["node"]==brass
            reject(lambda:open_seat(wrong),"unit_unavailable")
            right=reserve(a,coil,two)
            assert open_seat(right)["squads"]["node"]==coil
            assert view(a,brass)["active"] and view(a,coil)["active"]
            finish(left,[one]);finish(right,[two])
            guards(brass,[one]);guards(coil,[two])
            reject(lambda:guards(coil,[one]),"unit_unavailable")
            assert next(r for r in view(a,coil)["robots"] if r["id"]==two)["guard"]
            guards(coil,[]);guards(brass,[]);guards(coil,[one]);guards(brass,[two])
            t[0]+=900*16
            key={"key":"legacy_claim_11"}
            rc=req(a,"/v1/camp/claim",key)["receipt"]
            assert rc==req(a,"/v1/camp/"+brass+"/claim",key)["receipt"]
            reject(lambda:req(a,"/v1/camp/"+coil+"/claim",key),"key_conflict")
            assert req(a,"/v1/camp/"+coil+"/claim",{"key":"coil_claim_11"})["receipt"]["changes"]=={"components":8}
            t[0]+=900
            protected=view(a,brass)
            attack=reserve(b,coil,enemy)
            assert open_seat(attack)["squads"]["defender"]["units"][0]["chassis"]==one
            finish(attack,[enemy,one],"defender")
            assert next(r for r in view(a,coil)["robots"] if r["id"]==one)["guard"]
            attack=reserve(b,coil,enemy)
            open_seat(attack)
            finish(attack,[enemy,one])
            server.initialize(path)
            assert req(a,"/v1/camp/claim",key)["receipt"]==rc
            after=view(a,brass)
            assert all(protected[k]==after[k] for k in ("owner","revision","stock","last"))
            assert next(r for r in after["robots"] if r["id"]==two)["guard"]
            assert view(b,coil)["mine"] and view(b,coil)["stock"]==0
            print("TWO_CAMPS_PASS concurrent battles on different owned robots, same robot rejected, 2 simultaneous holdings, independent guards, reassignment, site-specific retry/legacy replay, defender retention and local takeover, restart")
if __name__=="__main__":run()

