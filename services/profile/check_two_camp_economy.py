"""Fixed-clock paired 30/90-day actual SQLite warehouse and claim ledgers."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

import camp
import inventory
import server
import world_calendar as world


def scenario(days,sites):
    with TemporaryDirectory() as tmp:
        path=Path(tmp)/"economy.sqlite"
        server.initialize(path)
        player=server.login(path,{"name":"worker","password":"economy-local"},True)["account"]["id"]
        clock=[2100000000]
        earned=dict(structure=0,components=0)
        spent=dict.fromkeys(earned,0)
        salvage=dict.fromkeys(earned,0)
        overflow=dict.fromkeys(earned,0)
        takeover_loss=dict.fromkeys(earned,0)
        with server.transaction(path) as db,patch.object(world,"now",lambda:clock[0]):
            world.active(db)
            for node in sites:
                world.set_owner(db,node,player)
                camp.state(db,node)
            for day in range(1,days+1):
                clock[0]+=86400
                # One completed PVE salvage and one modest daily resource sink per profile.
                # The common daily basket is an experiment input, not an online average.
                for k,v in inventory.apply_stock(db,player,{"structure":3,"components":2}).items():salvage[k]+=v
                stocks={r[0]:r[1] for r in db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(player,))}
                cost={k:-min(stocks[k],v) for k,v in dict(structure=5,components=4).items()}
                for k,v in inventory.apply_stock(db,player,cost).items():spent[k]-=v
                for node in sites:
                    resource=world.CAMP_RESOURCES[node]
                    estate=camp.state(db,node)
                    gross=(clock[0]-estate["since"])//camp.SECONDS_PER_UNIT
                    ready=camp.stock(db,estate)
                    if day==15 and node=="coil-depot":
                        # Isolate the local stock destroyed by a takeover and prompt recapture.
                        takeover_loss[resource]+=ready
                        overflow[resource]+=gross+estate["accrued"]-ready
                        db.execute("UPDATE camp_estates SET accrued=0,since=? WHERE node=?",(clock[0],node))
                        continue
                    before=ready
                    key=f"claim_{day}_{node}"
                    try:
                        receipt=camp.claim(db,player,{"key":key},node)
                    except inventory.Fault as err:
                        assert err.code=="storage_full"
                        continue
                    assert receipt==camp.claim(db,player,{"key":key},node)
                    earned[resource]+=receipt["changes"][resource]
                    overflow[resource]+=gross+estate["accrued"]-before
            actual={r[0]:r[1] for r in db.execute("SELECT resource,amount FROM stocks WHERE owner=?",(player,)) if r[0] in earned}
            local={world.CAMP_RESOURCES[n]:camp.stock(db,camp.state(db,n)) for n in sites}
            for k in earned:
                assert inventory.STOCK[k][0]+salvage[k]+earned[k]-spent[k]==actual[k]
                assert earned[k]+overflow[k]+takeover_loss[k]+local.get(k,0)==(days*96 if k in local else 0)
            return dict(days=days,sites=sites,pve_received=salvage,camp_received=earned,spent=spent,warehouse=actual,local=local,camp_overflow=overflow,takeover_lost=takeover_loss)


if __name__=="__main__":
    print(json.dumps([scenario(d,s) for d in (30,90) for s in ([],["brass-yard"],["brass-yard","coil-depot"])],indent=2))
