"""Read-only ledger reconciliation from within the isolated campaign profile container."""
import json
import sqlite3
import sys
from collections import Counter

def check(path,robot,relief_robot):
    with sqlite3.connect("file:"+path+"?mode=ro",uri=True) as db:
        db.row_factory=sqlite3.Row
        def rows_for(rid):
            owner=db.execute("SELECT owner FROM robots WHERE id=?",(rid,)).fetchone()[0]
            return [json.loads(r[0]) for r in db.execute("SELECT body FROM receipts WHERE owner=? ORDER BY rowid",(owner,))]
        def history(rid):
            traces=[]
            for r in db.execute("SELECT battle,outcome FROM robot_sorties WHERE robot=? AND result_digest IS NOT NULL ORDER BY rowid",(rid,)):
                mission=db.execute("SELECT deployment,receipt FROM expeditions WHERE id=?",(r["battle"],)).fetchone()
                deployment=json.loads(mission["deployment"])
                entity=next(u for u in deployment["units"] if u["chassis"]==rid)
                weapon=entity["slots"]["weapon"]
                summary=next(u for u in json.loads(mission["receipt"])["debrief"]["robots"] if u["id"]==rid)
                traces.append(dict(battle=r["battle"],outcome=r["outcome"],weapon=dict(id=weapon,definition=deployment["inventory"][weapon]),performance=summary))
            return traces
        def safe(row):
            return {k:row[k] for k in ("id","operation","changes","robot","outcome","mission","slot","returned","installed") if k in row}
        ledger=rows_for(robot)
        claim=next(i for i,r in enumerate(ledger) if r["operation"]=="claim")
        balance=Counter()
        for r in ledger[:claim]:balance.update(r["changes"])
        assert balance["structure"]==2 and ledger[claim]["changes"]["structure"]>=1
        assert ledger[claim+1]["operation"]=="build" and ledger[claim+1]["robot"]==robot and ledger[claim+1]["changes"]["structure"]==-3
        traces=history(robot)
        assert len(traces)==2 and all(t["outcome"]=="win" for t in traces)
        assert all(t["performance"]["kills"]>0 for t in traces)
        assert [t["weapon"]["definition"] for t in traces]==["cannon","drill"]
        result=[r for r in ledger if r["operation"]=="expedition_result"]
        assert result[0]["part"]["id"]==traces[1]["weapon"]["id"]
        refit=next(r for r in ledger if r["operation"]=="refit")
        assert refit["installed"]==traces[1]["weapon"]["id"] and refit["returned"]==traces[0]["weapon"]["id"]
        repairs=[dict(r) for r in db.execute("SELECT kind,at FROM repair_log WHERE robot=? ORDER BY id",(robot,))]
        started=next(r["at"] for r in repairs if r["kind"]=="repair_started")
        completed=next(r["at"] for r in repairs if r["kind"]=="workshop_repair")
        assert completed-started==30
        relief=rows_for(relief_robot)
        eligible=next(i for i,r in enumerate(relief) if r["operation"]=="relief")
        stock=Counter()
        for r in relief[:eligible]:stock.update(r["changes"])
        assert all(stock[k]==0 for k in ("components","structure","energy"))
        assert sum(r["operation"]=="relief" for r in relief)==1 and relief[eligible]["changes"]=={}
        entries=[r for r in relief if r["operation"]=="expedition_start"]
        assert len(entries)==2 and entries[0]["changes"]=={"energy":-1} and entries[1]["changes"]=={}
        redeemed=db.execute("SELECT voucher FROM relief JOIN robots ON robots.owner=relief.owner WHERE robots.id=?",(relief_robot,)).fetchone()[0]
        assert redeemed==0
        return dict(robot=robot,preclaim_balance=dict(balance),ledger=[safe(r) for r in ledger],history=traces,workshop_repair=repairs,
                    relief_robot=relief_robot,relief_stock_before=dict(stock),relief_ledger=[safe(r) for r in relief],voucher_after_second_entry=redeemed)

if __name__=="__main__":
    print(json.dumps(check(*sys.argv[1:]),indent=2))
