"""Verify accessory deployment cost and recovery of the old three-mount inventory."""
import secrets
import uuid
import tempfile
from pathlib import Path

from inventory import Fault
import server
import service_record
import treasure_combat as combat
import workshop

def key(**body):
    return dict(key=uuid.uuid4().hex,**body)

def main():
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/"profile.sqlite"
        server.initialize(path)
        login=server.login(path,dict(name="mechanic",password=secrets.token_urlsafe()),True)
        actor=login["account"]["id"]
        hull=login["robots"][0]["id"]
        with server.transaction(path) as db:
            old=workshop.owned_robots(db,actor)[0]
            assert workshop.complete(old["slots"]) and not workshop.complete({"core":1,"head":2,"utility":3})
            fitted={**workshop.BASE,"utility":"repair_arm"}
            design=workshop.operate(db,actor,"design",key(name="支援",version=1,slots=fitted))
            made=workshop.operate(db,actor,"build",key(name="工程机",design=design["design"]))
            assert made["changes"]=={"structure":-5,"components":-3,"energy":-1}
            rows=workshop.owned_robots(db,actor)
            arm=made["installed"]["utility"]
            d=workshop.deployment_for(rows)
            assert d["points"]==5 and d["inventory"][arm]=="repair_arm"
            try:workshop.operate(db,actor,"refit",key(robot=hull,slot="utility",expected="",item=arm))
            except Fault as e:assert e.code=="item_unavailable"
            else:raise AssertionError("stolen mounted arm")
            mission="unit-test-0001"
            ticket=service_record.start_mission(db,actor,hull,mission)
            try:service_record.finish_mission(db,ticket,mission,"win",[dict(at=2,kind="field_repair_output",actor=hull,target=made["robot"],amount=4)],3)
            except Fault as e:assert e.code=="invalid_event"
            else:raise AssertionError("unequipped robot gained output")
            units={r["id"]:combat.unit(r,actor,0,i) for i,r in enumerate(rows)}
            state=combat.fresh(1,units,10)
            units[hull]["hp"]-=2.5
            for _ in range(25):combat.step(state)
            assert units[hull]["hp"]==units[hull]["max_hp"] and units[made["robot"]]["service_charges"]==3
            received=units[hull]["events"][-1]; sent=units[made["robot"]]["events"][-1]
            assert received["kind"]=="field_repair_received" and sent["kind"]=="field_repair_output"
            assert all(received[k]==sent[k] for k in ("at","actor","target","amount"))
            unmounted=workshop.operate(db,actor,"refit",key(robot=made["robot"],slot="utility",expected=arm,item=""))
            assert unmounted["returned"]==arm
            assert all(unit["points"]==2 for unit in [workshop.deployment_for([r]) for r in workshop.owned_robots(db,actor) if not r["task"]])
    print("FIELD_REPAIR_STORAGE_PASS optional slot, physical ownership, recipe cost, deployment, expense, unauthorised output and treasure matching events.")

if __name__=="__main__":main()
