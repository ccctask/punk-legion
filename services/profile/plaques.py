"""Private-base commissions backed by settled robot service records."""
import json
import re
import uuid
from urllib.parse import parse_qs, urlsplit

import inventory
from inventory import Fault

PRICE = {"structure": 4, "components": 1, "energy": 0}
PAGE_SIZE = 20
RECORDS = """SELECT s.robot, s.battle, s.name, s.outcome
    FROM robot_sorties s JOIN admissions a USING(ticket)
    WHERE a.owner=? AND s.result_digest IS NOT NULL AND s.void_reason IS NULL AND s.battle IS NOT NULL"""


def schema(db):
    db.execute("""CREATE TABLE battle_plaques(
        id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES accounts(id), robot TEXT NOT NULL,
        battle TEXT NOT NULL, name TEXT NOT NULL, outcome TEXT NOT NULL, displayed INTEGER NOT NULL,
        UNIQUE(owner,robot,battle))""")
    db.execute("CREATE UNIQUE INDEX one_displayed_plaque ON battle_plaques(owner) WHERE displayed=1")
    db.execute("""CREATE TABLE public_plaque(owner TEXT PRIMARY KEY REFERENCES accounts(id),
               plaque TEXT UNIQUE NOT NULL REFERENCES battle_plaques(id))""")
    db.execute("CREATE INDEX plaque_collection ON battle_plaques(owner)")


def inscription(db, owner):
    row = db.execute("SELECT name,substr(battle,1,8) AS battle FROM battle_plaques WHERE owner=? AND displayed=1", (owner,)).fetchone()
    return dict(row) if row else None


def overview(db, owner, page=0, collection_page=0):
    rows = db.execute(RECORDS + """ AND NOT EXISTS (SELECT 1 FROM battle_plaques p
        WHERE p.owner=a.owner AND p.robot=s.robot AND p.battle=s.battle)
        ORDER BY s.rowid DESC LIMIT ? OFFSET ?""", (owner, PAGE_SIZE+1, page*PAGE_SIZE)).fetchall()
    items = "SELECT id,robot,battle,name,outcome FROM battle_plaques WHERE owner=?"
    collection = db.execute(items+" ORDER BY rowid DESC LIMIT ? OFFSET ?",
                            (owner,PAGE_SIZE+1,collection_page*PAGE_SIZE)).fetchall()
    displayed = db.execute(items+" AND displayed=1", (owner,)).fetchone()
    return {"eligible": [dict(r) for r in rows[:PAGE_SIZE]], "page": page, "more": len(rows)>PAGE_SIZE,
            "collection": [dict(r) for r in collection[:PAGE_SIZE]], "collection_page":collection_page,
            "collection_more":len(collection)>PAGE_SIZE,"displayed": displayed["id"] if displayed else None,
            "displayed_item":dict(displayed) if displayed else None,
            "card_public":bool(displayed and db.execute("SELECT 1 FROM public_plaque WHERE owner=? AND plaque=?",
                                                        (owner,displayed["id"])).fetchone()),"price": PRICE,
            "stock": dict(db.execute("SELECT resource,amount FROM stocks WHERE owner=?", (owner,)))}


def craft(db, owner, key, robot, battle):
    signature = json.dumps(["plaque_craft",robot,battle], separators=(",",":"))
    previous = inventory.previous(db, owner, key, signature)
    if previous:
        return previous
    if db.execute("SELECT 1 FROM battle_plaques WHERE owner=? AND robot=? AND battle=?", (owner,robot,battle)).fetchone():
        raise Fault(409, "already_commissioned")
    record = db.execute(RECORDS + " AND s.robot=? AND s.battle=?", (owner,robot,battle)).fetchone()
    if not record:
        raise Fault(404, "unknown_record")
    changes = inventory.apply_stock(db, owner, {k:-v for k,v in PRICE.items() if v})
    first = not db.execute("SELECT 1 FROM battle_plaques WHERE owner=?", (owner,)).fetchone()
    plaque = uuid.uuid4().hex
    db.execute("INSERT INTO battle_plaques VALUES (?,?,?,?,?,?,?)",
               (plaque,owner,robot,battle,record["name"],record["outcome"],first))
    return inventory.record(db, owner, key, "plaque_craft", signature, changes, plaque=plaque)


def handle(db, owner, method, route, fields):
    url = urlsplit(route)
    if url.path == "/v1/base/plaques" and method == "GET":
        pages = parse_qs(url.query,keep_blank_values=True)
        if pages.keys()-{"page","collection_page"} or any(
                len(v)!=1 or not re.fullmatch(r"[0-9]{1,7}",v[0]) for v in pages.values()):
            raise Fault(400, "invalid_page")
        return {"plaques": overview(db, owner, **{k:int(v[0]) for k,v in pages.items()})}
    if method != "POST" or url.query:
        raise Fault(404, "unknown_route")
    if url.path == "/v1/base/plaques/public":
        if fields.keys() != {"plaque","public"} or not isinstance(fields["plaque"],str) or type(fields["public"]) is not bool:
            raise Fault(400, "invalid_parameters")
        current = db.execute("SELECT id FROM battle_plaques WHERE owner=? AND displayed=1", (owner,)).fetchone()
        if not current or current["id"] != fields["plaque"]:
            raise Fault(409, "display_changed")
        if fields["public"]:
            db.execute("INSERT OR IGNORE INTO public_plaque(owner,plaque) VALUES (?,?)", (owner,current["id"]))
        else:
            db.execute("DELETE FROM public_plaque WHERE owner=?", (owner,))
        return {"plaques": overview(db, owner)}
    if not all(isinstance(v,str) for v in fields.values()):
        raise Fault(400, "invalid_parameters")
    if url.path == "/v1/base/plaques/craft":
        if fields.keys() != {"key","robot","battle"} or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}", fields["key"]):
            raise Fault(400, "invalid_parameters")
        receipt = craft(db, owner, **fields)
        return {"receipt": receipt, "plaques": overview(db, owner)}
    if url.path == "/v1/base/plaques/display":
        if fields.keys() != {"plaque"}:
            raise Fault(400, "invalid_parameters")
        row = db.execute("SELECT displayed FROM battle_plaques WHERE owner=? AND id=?", (owner,fields["plaque"])).fetchone()
        if not row:
            raise Fault(404, "unknown_plaque")
        if not row["displayed"]:
            db.execute("DELETE FROM public_plaque WHERE owner=?", (owner,))
            db.execute("UPDATE battle_plaques SET displayed=0 WHERE owner=? AND displayed=1", (owner,))
            db.execute("UPDATE battle_plaques SET displayed=1 WHERE owner=? AND id=?", (owner,fields["plaque"]))
        return {"plaques": overview(db, owner)}
    raise Fault(404, "unknown_route")
