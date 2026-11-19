"""Fixed-step treasure combat, ownership, and defense-platform compatibility."""
import json
from pathlib import Path
import secrets
import tempfile

from check_production import serve
from check_profile import api,ok
import platforms
import treasure_combat as combat
import workshop


def unit(rid,side,tool=None):
    slots={k:{"definition":v} for k,v in workshop.BASE.items()}
    if tool:slots["utility"]={"definition":tool}
    return combat.unit({"name":rid,"paint":"base","slots":slots},rid,side,0)


def trial(jam):
    fighters={"a":unit("a",0,"jammer" if jam else None),"b":unit("b",0,"jammer" if jam else None),
              "t":unit("t",1,"repair_arm"),"hurt":unit("hurt",1)}
    for (rid,u),pos in zip(fighters.items(),([0,0],[-1,0],[2,0],[6.8,0])):
        u.update(pos=pos,target=pos,damage=0)
    fighters["hurt"]["hp"]-=16
    fighters["t"].update(next_shot=2,last_service=-3)
    state=combat.fresh(2,fighters,0)
    attack=repair=None
    for n in range(20):
        combat.step(state)
        if n==0 and jam:
            assert sum(fighters[id]["jam_charges"] for id in ("a","b"))==7
            assert not fighters["a"]["service_charges"]
            frozen=json.loads(json.dumps(state))
            assert frozen["units"]["t"]["protected_until"]==4
        if attack is None and fighters["t"]["shot"]>=0:attack=fighters["t"]["shot"]
        if repair is None and fighters["t"]["last_service"]>=0:repair=fighters["t"]["last_service"]
    if jam:assert len([e for e in fighters["t"]["events"] if e["kind"]=="jam_received" and e["at"]<4])==1
    return (attack,repair)


def run():
    base,delayed=trial(False),trial(True)
    assert [b-a for a,b in zip(base,delayed)]==[1,1],(base,delayed)
    f={"a":unit("a",0,"jammer"),"t":unit("t",1,"repair_arm"),"ally":unit("ally",1)}
    for key,x in (("a",0),("t",2),("ally",7)):f[key].update(pos=[x,0],target=[x,0],damage=0)
    f["t"].update(target=[2,2],manual_move=True,last_service=0)
    state=combat.fresh(3,f,0)
    combat.step(state)
    assert f["t"]["pos"]!=[2,0] and f["t"]["repair_not_before"]==1
    saved=json.loads(json.dumps(state))
    for _ in range(6):combat.step(state);combat.step(saved)
    assert saved==state
    # No one needed repair when the target was jammed. A later injury can be
    # serviced on its first normal tick, without a reservation from the old pulse.
    f["a"]["jam_charges"]=0
    f["ally"].update(pos=[3,2],target=[3,2])
    while state["tick"]*combat.STEP<6.5:combat.step(state)
    at=state["tick"]*combat.STEP
    f["ally"]["hp"]-=12
    combat.step(state)
    assert f["t"]["last_service"]==at
    with tempfile.TemporaryDirectory() as temp,serve(Path(temp)/"player.sqlite") as url:
        user=ok(api(url,"/v1/accounts",dict(name="jamt",password=secrets.token_urlsafe())))
        token=user["token"]
        payload={"key":"fab_jammer_one","recipe":"jammer"}
        item=ok(api(url,"/v1/inventory/craft",payload,token))["receipt"]
        assert ok(api(url,"/v1/inventory/craft",payload,token))["receipt"]==item
        assert all(workshop.CATALOG["chassis"][chassis]["slots"]["utility"]["interface"]=="aux" for chassis in ("biped","crawler"))
        assert platforms.function("jammer")=="utility"
    print("JAM_TREASURE_PASS",base,delayed,"moving target, idle repair, shared immunity, restored identical frames, idempotent item and AUX compatibility")


if __name__=="__main__":run()
