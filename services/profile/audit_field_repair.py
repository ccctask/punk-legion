"""Reconcile four owned robots against immutable personal receipts and career totals."""
import json
import sqlite3
import sys

def verify(path, robots):
    source=sqlite3.connect("file:"+path+"?mode=ro",uri=True)
    db=sqlite3.connect(":memory:")
    source.backup(db)
    source.close()
    db.row_factory=sqlite3.Row
    rows=[db.execute("""SELECT s.robot,s.battle,s.outcome,r.owner,c.battles,c.output,e.receipt
        FROM robot_sorties s JOIN robots r ON r.id=s.robot JOIN robot_career c ON c.robot=s.robot
        JOIN expeditions e ON e.id=s.battle WHERE s.robot=? AND s.result_digest IS NOT NULL""",(rid,)).fetchone() for rid in robots]
    assert len(rows)==4 and all(rows)
    def room(row):
        seat=db.execute("SELECT group_id FROM party_members WHERE mission=?",(row["battle"],)).fetchone()
        return seat[0] if seat else row["battle"]
    battles={room(r) for r in rows}
    assert len(battles)==2 and {len({r["owner"] for r in rows if room(r)==battle}) for battle in battles}=={1,2}
    out=[]
    for battle in battles:
        records=[r for r in rows if room(r)==battle]
        for row in records:
            unit=next(u for u in json.loads(row["receipt"])["debrief"]["robots"] if u["id"]==row["robot"])
            assert row["battles"]==1 and row["outcome"]=="win" and unit["repair_output"]==row["output"]
        amount=sum(r["output"] for r in records)
        assert 0<amount<=40
        out.append(dict(battle=battle,owners=len({r["owner"] for r in records}),total=amount))
    print(json.dumps(out,indent=2))
    db.close()

if __name__=="__main__":
    verify(sys.argv[1],sys.argv[2:])
