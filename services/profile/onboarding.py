"""Account-scoped guide facts and immutable offline arrival statements."""
import json
import os
from pathlib import Path
import time

import expedition
import private_base
import production
import recovery
import workshop

MIN_ABSENCE = 15 * 60


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS activity_anchor(owner TEXT PRIMARY KEY REFERENCES accounts(id),
        seen INTEGER NOT NULL, stocks TEXT NOT NULL, receipt_cursor INTEGER NOT NULL,
        repairs_cursor INTEGER NOT NULL, statement TEXT NOT NULL)""")
    db.execute("CREATE TABLE IF NOT EXISTS named_robots(robot TEXT PRIMARY KEY REFERENCES robots(id))")


def stocks(db, owner):
    return dict(db.execute("SELECT resource,amount FROM stocks WHERE owner=?", (owner,)))


def capture(db, owner):
    """Call after a successful authenticated operation; compare against the last committed session."""
    at = int(time.time())
    row = db.execute("SELECT * FROM activity_anchor WHERE owner=?", (owner,)).fetchone()
    if not row:
        # Restored pre-guide sessions may reach an authenticated route before the next login.
        private_base.activate(db,owner)
    current = stocks(db, owner)
    receipt_cursor = db.execute("SELECT COALESCE(MAX(rowid),0) FROM receipts WHERE owner=?", (owner,)).fetchone()[0]
    repair_cursor = db.execute("""SELECT COALESCE(MAX(l.id),0) FROM repair_log l JOIN robots r
        ON l.robot=r.id WHERE r.owner=?""", (owner,)).fetchone()[0]
    summary = row["statement"] if row else "{}"
    if row and at-row["seen"] >= MIN_ABSENCE:
        lines = production.update(db, owner)["lines"]
        previous = json.loads(row["stocks"])
        ledger = [json.loads(r[0]) for r in db.execute(
            "SELECT body FROM receipts WHERE owner=? AND rowid>? ORDER BY rowid", (owner,row["receipt_cursor"]))]
        repairs = [dict(r) for r in db.execute("""SELECT r.name,l.robot,l.at FROM repair_log l JOIN robots r
            ON r.id=l.robot WHERE r.owner=? AND l.kind='workshop_repair' AND l.id>? ORDER BY l.id""",
            (owner,row["repairs_cursor"]))]
        summary = json.dumps(dict(start=row["seen"],end=at,cap_seconds=production.OFFLINE_SECONDS,
            before=previous.get("stock",previous),after=current,ledger=ledger,repairs=repairs,
            production={k:dict(before=previous.get("pending",{}).get(k),**{f:v[f] for f in ("pending","capacity","rate","free")})
                        for k,v in lines.items()}))
    line_row=db.execute("SELECT lines FROM production_state WHERE owner=?",(owner,)).fetchone()
    snapshot=dict(stock=current,pending={k:v["pending"] for k,v in json.loads(line_row[0]).items()} if line_row else {})
    db.execute("INSERT OR REPLACE INTO activity_anchor VALUES (?,?,?,?,?,?)",
               (owner,at,json.dumps(snapshot),receipt_cursor,repair_cursor,summary))


def active_rust_rail(db,owner):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE name='expeditions'").fetchone():
        return False
    return db.execute("""SELECT id FROM expeditions WHERE owner=? AND result IS NULL
                      AND id NOT IN (SELECT mission FROM pump_entries)
                      AND id NOT IN (SELECT mission FROM factory_entries)
                      AND id NOT IN (SELECT mission FROM armory_entries)""",(owner,)).fetchone()


def current_command(db,owner,mission):
    if not mission:
        return False
    member=expedition.party_seat(db,mission[0])
    if member:
        ident=db.execute("SELECT group_id FROM party_members WHERE mission=?",(mission[0],)).fetchone()[0]
    else:
        ident=mission[0]
    folder=os.environ.get("PARTY_SPOOL_DIR" if member else "SOLO_SPOOL_DIR")
    if folder:
        try:
            progress=json.loads((Path(folder)/(ident+".progress.json")).read_text(encoding="utf-8"))
            player=progress.get("results",{}).get(owner,{}) if member else progress
            return player.get("commanded") is True
        except (OSError,ValueError):
            pass
    return False


def guide(db, owner):
    fleet = workshop.owned_robots(db, owner)
    ready = [robot for robot in fleet if expedition.ready_to_deploy(robot)]
    facts = {k:False for k in ("name","fit","command","reward","repair","build")}
    today=int(time.time())//86400
    daily={"complete":False,"receipt":"","mode":"","changes":{},"resets_at":(today+1)*86400}
    starter = db.execute("""SELECT r.id,n.robot FROM robots r LEFT JOIN named_robots n ON n.robot=r.id
                            WHERE r.owner=? ORDER BY r.rowid LIMIT 1""",(owner,)).fetchone()
    facts["name"] = bool(starter and starter[1])
    for entry in db.execute("""SELECT operation,body FROM receipts WHERE owner=? AND operation IN
        ('refit','apply','build','expedition_result','claim') ORDER BY rowid""", (owner,)):
        receipt = json.loads(entry["body"])
        if entry["operation"] in ("refit","apply"):
            facts["fit"] |= bool(receipt.get("installed"))
        elif entry["operation"]=="build":
            facts["build"] = True
        elif entry["operation"]=="claim":
            if (not daily["complete"] and receipt["credited_at"]//86400==today
                    and any(amount>0 for amount in receipt["changes"].values())):
                daily.update(complete=True,receipt=receipt["id"],changes=receipt["changes"],
                             mode="production")
        elif entry["operation"]=="expedition_result":
            # Reaching and collecting a guarded node requires accepted manual orders.
            if "commanded" in receipt:
                facts["command"] |= receipt["commanded"]
            elif receipt.get("nodes") and not expedition.party_seat(db,receipt["mission"]):
                facts["command"] = True
            facts["reward"] |= (receipt.get("outcome")=="win" and receipt.get("participated") is True
                                and receipt.get("debrief",{}).get("activity") in ("solo","party"))
            if (not daily["complete"] and receipt.get("credited_at",0)//86400==today
                    and receipt.get("nodes") and receipt["outcome"] in ("win","retreat")):
                daily.update(complete=True,receipt=receipt["id"],changes=receipt["changes"],
                             mode="party" if expedition.party_seat(db,receipt["mission"]) else "solo")
    facts["repair"] = bool(db.execute("""SELECT 1 FROM repair_log l JOIN robots r ON l.robot=r.id
        WHERE r.owner=? AND l.kind='workshop_repair' LIMIT 1""", (owner,)).fetchone())
    active = active_rust_rail(db,owner)
    if not facts["command"]:
        facts["command"]=current_command(db,owner,active)
    summary = db.execute("SELECT statement FROM activity_anchor WHERE owner=?", (owner,)).fetchone()
    damaged = next((r["id"] for r in fleet if r["state"] in ("damaged","repairing")), "")
    pending = db.execute("SELECT 1 FROM expedition_first_parts WHERE owner=?", (owner,)).fetchone()
    loose = db.execute(workshop.FREE+" AND p.definition='drill' LIMIT 1", (owner,)).fetchone()

    return dict(facts=facts, fit_route="claim_drill" if pending else "install_drill" if loose else "spare",
                damaged=damaged, ready_count=len(ready), entry_source=recovery.entry_quote(db,owner)["source"],
                active_mode=("party" if expedition.party_seat(db,active[0]) else "solo") if active else "",
                summary=json.loads(summary[0]) if summary else {}, daily=daily)

