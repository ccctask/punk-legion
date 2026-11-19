"""M22 30/90-day effects of explicit behaviour schedules on current server rules."""
import argparse
from collections import Counter
import importlib.util
import json
import os
from pathlib import Path
import random
import tempfile
from unittest.mock import patch

import camp
import inventory
import server
import workshop
import world_calendar


def scenario(folder,label,seed,template):
    rng=random.Random(seed)
    t=[1794000000]
    data=json.loads(template)
    data["nodes"][1]["daily"]=[[0,86400,86400]]
    config=folder/(label+".json");config.write_text(json.dumps(data),encoding="utf8")
    path=folder/(label+".sqlite")
    discarded_rewards=Counter();production_claimed=Counter();stats=Counter();result=[]
    recording_final_award=False
    apply=inventory.apply_stock
    def counted(db,owner,deltas):
        actual=apply(db,owner,deltas)
        for k,v in deltas.items():
            if recording_final_award and v>0:discarded_rewards[k]+=v-actual[k]
        return actual
    with patch("time.time",side_effect=lambda:t[0]),patch("secrets.randbelow",side_effect=rng.randrange), patch.dict(os.environ,{"WORLD_CALENDAR_FILE":str(config)}),patch.object(inventory,"apply_stock",counted):
        server.initialize(path)
        player=server.handle(path,"POST","/v1/accounts",{"name":label,"password":"fixture-password"},"")
        user=player["account"]["id"];robot=player["robots"][0]["id"]
        def api(route,body=None):
            return server.handle(path,"POST" if body is not None else "GET",route,body or {},"Bearer "+player["token"])
        def authority(route,body):
            return server.handle(path,"POST",route,body,"Bearer local-m22","local-m22")
        def stock():
            return {k:v["amount"] for k,v in api("/v1/inventory")["inventory"]["stock"].items()}
        def build(kind,x):
            revision=api("/v1/base")["base"]["revision"]
            api("/v1/base/edit",dict(revision=revision,action="build",kind=kind,x=x,y=2,key="build_"+kind))
        initial=stock()
        if label!="newcomer":
            build("foundry",3);build("workshop",5)
        if label=="tech_ready":
            for tech in ("drill","casting"):
                api("/v1/base/production/research",dict(tech=tech,key="research_"+tech))
        if label=="long_camp":
            grant=api("/v1/world/admit",dict(node=camp.NODE,key="camp_grant"))["admission"]["id"]
            admission=api("/v1/camp/reserve",dict(grant=grant,robots=[robot]))["admission"]
            authority("/internal/camp/open",{k:admission[k] for k in ("id","secret")})
            t[0]+=16
            body=dict(id=admission["id"],winner="attacker",reason="core",reports={robot:[]},seconds=16,finished_at=t[0])
            authority("/internal/camp/settle",body)
        start=t[0]
        def recover(key):
            route=f"/v1/robots/{robot}/recovery"
            state=api(route)["recovery"]
            if state["state"]=="damaged":
                try:
                    api(route+"/repair",dict(key=key+"_repair"));stats["paid_repairs"]+=1
                    t[0]+=31;api(route)
                except inventory.Fault as exc:
                    if exc.code!="insufficient_stock": raise
                    api(route+"/relief",dict(key=key+"_relief"));stats["relief"]+=1
        for day in range(1,91):
            t[0]=start+86400*day
            if label=="newcomer" and day in (4,9):
                build("foundry" if day==4 else "workshop",3 if day==4 else 5)
            prod=api("/v1/base/production")["production"]
            if any(line["pending"] for line in prod["lines"].values()):
                claim=api("/v1/base/production/claim",dict(key=f"daily_claim_{day}"))
                for k,line in prod["lines"].items():
                    granted=claim["receipt"]["changes"].get(k,0)
                    assert granted+claim["production"]["lines"][k]["pending"]==line["pending"]
                    production_claimed[k]+=granted
            if label=="long_camp":
                camp_before=api("/v1/camp")["camp"]
                assert camp_before["mine"]
                due=camp_before["stock"]
                try:
                    claim=api("/v1/camp/claim",dict(key=f"camp_claim_{day}"))
                    amount=claim["receipt"]["changes"]["structure"]
                    assert amount+claim["camp"]["stock"]==due
                    stats["camp_claims"]+=1
                    stats["camp_partial_claims"]+=amount<due
                    stats["camp_units_claimed"]+=amount
                except inventory.Fault as exc:
                    if exc.code not in ("storage_full","nothing_to_claim"):raise
                    assert api("/v1/camp")["camp"]["stock"]==due
                    stats["camp_full_claim_rejections"]+=exc.code=="storage_full"
            runs=(0 if (label=="newcomer" and day%3==0) else 2 if label=="high_damage" else 1)
            for attempt in range(runs):
                key=f"sortie_{day:02}_{attempt}"
                recover(key+"_pre")
                try:
                    admission=api("/v1/expedition/start",dict(robots=[robot],key=key))
                except inventory.Fault as exc:
                    if exc.code!="insufficient_stock":raise
                    api(f"/v1/robots/{robot}/recovery/relief",dict(key=key+"_fuel"));stats["relief"]+=1
                    admission=api("/v1/expedition/start",dict(robots=[robot],key=key))
                assert admission["receipt"]==api("/v1/expedition/start",dict(robots=[robot],key=key))["receipt"]
                mission=admission["expedition"]["active"]["id"]
                lost=label=="high_damage" and (day+attempt)%3!=0
                hurt=label=="high_damage" or (label=="newcomer" and day%5==0) or (label=="long_camp" and day%7==0)
                events=[dict(kind="condition",target=robot,actor="combat",amount=15,at=185)] if hurt else []
                report=dict(id=mission,outcome="defeat" if lost else "win",seconds=195,nodes=[] if lost else ["scrap","coil"],reports={robot:events},commanded=True)
                t[0]+=195
                recording_final_award=True
                receipt=authority("/internal/expedition/settle",report)["receipt"]
                recording_final_award=False
                assert receipt==authority("/internal/expedition/settle",report)["receipt"]
                stats["defeats" if lost else "wins"]+=1;stats["damage"]+=hurt
                stats["converted_parts"]+=int(receipt["converted"])
                recover(key+"_post")
            balance=stock()
            assert all(0<=balance[k]<=inventory.STOCK[k][1] for k in balance)
            for k,n in balance.items():stats[k+"_cap_days"]+=n==inventory.STOCK[k][1]
            if day in (30,90):
                income=Counter();spend=Counter()
                with server.transaction(path) as db:
                    for r in db.execute("SELECT body FROM receipts WHERE owner=? AND operation!='starter'",(user,)):
                        for k,v in json.loads(r[0])["changes"].items():
                            if v>0:income[k]+=v
                            if v<0:spend[k]-=v
                    free=db.execute("SELECT COUNT(*) FROM ("+workshop.FREE+")",(user,)).fetchone()[0]
                    techs=[r[0] for r in db.execute("SELECT tech FROM technologies WHERE owner=?",(user,))]
                assert all(initial[k]+income[k]-spend[k]==balance[k] for k in balance)
                can_fuel=balance["energy"]>0 or api(f"/v1/robots/{robot}/recovery")["recovery"]["voucher"]
                ready=bool(api("/v1/workshop")["workshop"]["deployment"]["units"] and can_fuel)
                assert ready and free<=inventory.PART_CAP
                lines=api("/v1/base/production")["production"]["lines"]
                result.append(dict(day=day,initial=initial,stock=balance,income=dict(income),spend=dict(spend),
                    discarded_expedition_rewards=dict(discarded_rewards),production_claimed=dict(production_claimed),
                    production_pending={k:v["pending"] for k,v in lines.items()},
                    camp_unclaimed_at_cutoff=api("/v1/camp")["camp"]["stock"] if label=="long_camp" else 0,
                    available_parts=free,ready=bool(ready),technology=techs,**stats))
        return result


def main(out):
    root=Path(__file__).resolve().parents[2]
    helper=next((root/"openspec/changes").rglob("root_pure_pve.py"))
    spec=importlib.util.spec_from_file_location("baseline",helper)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    with patch("secrets.randbelow",side_effect=random.Random(22099).randrange):
        module.run()
    result={}
    with tempfile.TemporaryDirectory() as tmp:
        template=world_calendar.config_path().read_text(encoding="utf8")
        for i,label in enumerate(("newcomer","tech_ready","low_damage","high_damage","long_camp")):
            result[label]=scenario(Path(tmp),label,22100+i,template)
            print("ECONOMY_PASS",label,result[label][-1]["stock"],flush=True)
    Path(out).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf8")

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--output",required=True);main(p.parse_args().output)

