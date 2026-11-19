"""Regression for v18 migration, physical conversions, budgets and immutable battle records."""
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import tempfile
import uuid

import server
import service_record
import treasure_combat
import workshop
from inventory import Fault


def run(path):
    server.initialize(path)
    credentials = {"name":"chassis_qa","password":uuid.uuid4().hex}
    auth = server.login(path,credentials,True)
    rid = auth["robots"][0]["id"]
    owner = auth["account"]["id"]
    token = "Bearer "+auth["token"]

    def command(action, **body):
        body.setdefault("key",uuid.uuid4().hex)
        try:
            return server.handle(path,"POST","/v1/workshop/"+action,body,token)["receipt"]
        except Fault as e:
            return e.code

    def state():
        return server.handle(path,"GET","/v1/workshop",{},token)["workshop"]

    old=command("design",version=1,name="legacy",slots=workshop.BASE)
    initial=state()
    assert initial["robots"][0]["chassis"]==initial["designs"][0]["chassis"]=="crawler"
    assert initial["designs"][0]["id"]==old["design"]
    with server.transaction(path) as db:
        t=service_record.start_mission(db,owner,rid,"before-conversion")
    assert command("chassis",robot=rid,expected="crawler",chassis="biped")=="unit_unavailable"
    with server.transaction(path) as db:
        assert json.loads(db.execute("SELECT snapshot FROM robot_sorties WHERE ticket=?",(t,)).fetchone()[0])["chassis"]=="crawler"
        service_record.finish_mission(db,t,"before-conversion","win",[],1)
    fields=dict(robot=rid,expected="crawler",chassis="biped",key=uuid.uuid4().hex)
    with ThreadPoolExecutor(4) as pool:
        receipts=list(pool.map(lambda _:command("chassis",**fields),range(4)))
    assert all(r==receipts[0] for r in receipts)
    assert command("chassis",robot=rid,expected="crawler",chassis="biped")=="fit_changed"
    assert command("chassis",robot=rid,expected="biped",chassis="biped")=="unchanged_fit"
    assert command("chassis",robot=rid,expected="biped",chassis={})=="chassis"
    after=state()
    assert initial["robots"][0]["slots"]==after["robots"][0]["slots"]
    assert {k:after["stock"][k]-v for k,v in initial["stock"].items()}==workshop.CHASSIS_PRICE
    assert after["deployment"]["inventory"][rid]=="biped" and after["deployment"]["points"]==3
    with server.transaction(path) as db:
        ticket=service_record.start_mission(db,owner,rid,"after-conversion")
        assert json.loads(db.execute("SELECT snapshot FROM robot_sorties WHERE ticket=?",(ticket,)).fetchone()[0])["chassis"]=="biped"
        service_record.finish_mission(db,ticket,"after-conversion","win",[],1)
        assert service_record.history(db,owner,f"/v1/robots/{rid}/history")["history"]["totals"]["battles"]==2
        assert not db.execute("SELECT 1 FROM robot_sorties WHERE robot=? AND snapshot IS NOT NULL",(rid,)).fetchone()
    heavy=dict(workshop.BASE,head="visor",utility="repair_arm")
    assert command("design",slots=heavy,name="invalid",version=1,chassis="biped")=="weight"
    before=state()["stock"]
    heavy_design=command("design",slots=heavy,name="heavy",version=1)
    heavy_id=command("build",design=heavy_design["design"],name="heavy")["robot"]
    stable=state()
    assert command("chassis",robot=heavy_id,expected="crawler",chassis="biped")=="weight"
    assert stable["stock"]==state()["stock"]
    blueprint=command("design",slots=workshop.BASE,name="biped",version=1,chassis="biped")
    assert command("build",design=blueprint["design"],name="fresh")=="insufficient_stock"
    assert state()["stock"]==stable["stock"]
    with server.transaction(path) as db:
        server.inventory.apply_stock(db,owner,{"components":4})
    before=state()["stock"]
    new_id=command("build",design=blueprint["design"],name="fresh")["robot"]
    fresh=state()
    assert fresh["deployment"]["inventory"][new_id]=="biped"
    assert {k:fresh["stock"][k]-v for k,v in before.items()}=={"structure":-4,"components":-2,"energy":-1}
    assert command("apply",robot=new_id,design=old["design"])=="different_chassis"
    template=fresh["robots"][0]
    fleet=[dict(template,id=str(i),slots={k:dict(v,id=f"{i}-{k}") for k,v in template["slots"].items()}) for i in range(12)]
    assert len(workshop.deployment_for(fleet)["units"])==8
    try:
        workshop.deployment_for(fleet,[r["id"] for r in fleet[:9]])
    except Fault as e:
        assert e.code=="point_limit"
    else:
        raise AssertionError("overbudget")
    for kind,hp,speed,radius in [("crawler",70,3.6,.6),("biped",58,4.6,.48)]:
        actual=treasure_combat.unit(dict(template,chassis=kind),owner,0,0)
        assert (actual["chassis"],actual["hp"],actual["speed"],actual["body_radius"])==(kind,hp,speed,radius)
    print("CHASSIS_PASS fresh database, replay x4, rollback, actual item IDs, construction, deployment snapshots; 8 bipeds / 24 points")

if __name__=="__main__":
    with tempfile.TemporaryDirectory() as temp:
        run(Path(temp)/"profile.sqlite")
