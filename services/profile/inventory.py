"""Inventory rules for the M08 development economy. All mutations use the caller's transaction."""
import json
import re
import secrets
import uuid

# Prototype quantities. All costs and caps are server-owned.
STOCK = {"structure": (12, 40), "components": (6, 24), "energy": (5, 12)}
RECIPES = {"survey_radar":{"structure":-2,"components":-2}, "rivet_repeater":{"structure":-2,"components":-1}, "rivet_shield":{"structure":-3,"components":-1}, "visor":{"structure":-1,"components":-2}, "jammer":{"structure":-2,"components":-2},"repair_arm":{"structure":-2,"components":-2}, "cannon": {"structure": -3, "components": -2}, "drill": {"structure": -5, "components": -3}}
REWARDS = {"win": {"structure": 4, "components": 2}, "loss": {"structure": 1}, "draw": {"structure": 2}}
PART_CAP = 24
FREE_PARTS = """SELECT p.id,p.definition FROM parts p WHERE p.owner=?
    AND NOT EXISTS (SELECT 1 FROM mounts m WHERE m.item=p.id)
    AND NOT EXISTS (SELECT 1 FROM platform_parts x WHERE x.item=p.id)"""


class Fault(Exception):
    def __init__(self, status, code):
        self.status = status
        self.code = code


def create_tables(db):
    # Execute each statement separately: executescript would commit the caller's transaction.
    for definition in (
        "stocks(owner TEXT REFERENCES accounts(id), resource TEXT, amount INTEGER NOT NULL CHECK(amount >= 0), PRIMARY KEY(owner,resource))",
        "blueprints(owner TEXT REFERENCES accounts(id), recipe TEXT, PRIMARY KEY(owner,recipe))",
        "parts(id TEXT PRIMARY KEY, owner TEXT REFERENCES accounts(id), definition TEXT NOT NULL)",
        """receipts(id TEXT PRIMARY KEY, owner TEXT REFERENCES accounts(id), operation TEXT NOT NULL,
        business_key TEXT NOT NULL, signature TEXT NOT NULL, body TEXT NOT NULL, UNIQUE(owner,business_key))""",
        """admissions(ticket TEXT PRIMARY KEY, owner TEXT REFERENCES accounts(id), battle TEXT, outcome TEXT,
        UNIQUE(owner,battle))""",
    ):
        db.execute("CREATE TABLE " + definition)
    db.execute("CREATE UNIQUE INDEX one_pending_ticket ON admissions(owner) WHERE battle IS NULL")


def record(db, owner, key, operation, signature, changes, **fields):
    rid = uuid.uuid4().hex
    body = dict(id=rid, operation=operation, changes=changes, **fields)
    db.execute("INSERT INTO receipts VALUES (?,?,?,?,?,?)", (rid,owner,operation,key,signature,json.dumps(body)))
    return body


def seed(db, owner):
    for resource, (initial, _cap) in STOCK.items():
        db.execute("INSERT INTO stocks VALUES (?,?,?)", (owner,resource,initial))
    db.executemany("INSERT INTO blueprints VALUES (?,?)", [(owner,"cannon"),(owner,"rivet_repeater"),(owner,"survey_radar")])
    record(db,owner,"system/starter","starter","", {name: values[0] for name,values in STOCK.items()})


def view(db, owner):
    rows = db.execute("SELECT resource, amount FROM stocks WHERE owner=?", (owner,))
    stocks = {r: {"amount": n, "capacity": STOCK[r][1]} for r,n in rows}
    rights = [r[0] for r in db.execute("SELECT recipe FROM blueprints WHERE owner=? ORDER BY recipe", (owner,))]
    parts = [dict(r) for r in db.execute(FREE_PARTS+" ORDER BY p.rowid", (owner,))]
    ledger = []
    for row in db.execute("SELECT body FROM receipts WHERE owner=? ORDER BY rowid DESC LIMIT 30", (owner,)):
        entry = json.loads(row[0])
        entry.pop("ticket", None)
        ledger.append(entry)
    pending = db.execute("SELECT ticket FROM admissions WHERE owner=? AND battle IS NULL", (owner,)).fetchone()
    return {"stock":stocks, "blueprints": rights, "parts":parts, "ledger":ledger,
            "pending_ticket": pending[0] if pending else "", "recipes":RECIPES, "part_capacity":PART_CAP}


def apply_stock(db, owner, deltas):
    # Advance using the old headroom before resources leave or enter the warehouse.
    import production
    production.update(db,owner)
    changes = {}
    for name, delta in deltas.items():
        amount = db.execute("SELECT amount FROM stocks WHERE owner=? AND resource=?", (owner,name)).fetchone()[0]
        if amount + delta < 0:
            raise Fault(409, "insufficient_stock")
        total = min(amount + delta, STOCK[name][1])
        db.execute("UPDATE stocks SET amount=? WHERE owner=? AND resource=?", (total,owner,name))
        changes[name] = total - amount
    production.update(db,owner)
    return changes


def previous(db, owner, key, signature):
    row = db.execute("SELECT signature, body FROM receipts WHERE owner=? AND business_key=?", (owner,key)).fetchone()
    if not row:
        return None
    if row[0] != signature:
        raise Fault(409, "key_conflict")
    return json.loads(row[1])


def operate(db, owner, operation, fields):
    key = fields.get("key")
    if not isinstance(key,str) or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}",key):
        raise Fault(400, "invalid_key")
    allowed = {"key","recipe"} if operation == "craft" else {"key"}
    if operation == "admit" and "robot" in fields:
        if not isinstance(fields["robot"],str) or not re.fullmatch(r"[a-f0-9]{32}",fields["robot"]):
            raise Fault(400,"invalid_robot")
        allowed.add("robot")
    if fields.keys() != allowed:
        raise Fault(400, "invalid_parameters")
    signature = json.dumps([operation,fields.get("recipe")])
    if "robot" in fields:
        signature = json.dumps([operation,fields["robot"]])
    receipt = previous(db,owner,key,signature)
    if receipt:
        return receipt
    if operation == "craft":
        recipe = fields["recipe"]
        if not isinstance(recipe,str) or recipe not in RECIPES:
            raise Fault(400, "unknown_recipe")
        if recipe not in ("repair_arm","jammer","rivet_shield") and not db.execute("SELECT 1 FROM blueprints WHERE owner=? AND recipe=?", (owner,recipe)).fetchone():
            raise Fault(403, "blueprint_locked")
        if db.execute("SELECT COUNT(*) FROM ("+FREE_PARTS+")", (owner,)).fetchone()[0] >= PART_CAP:
            raise Fault(409, "parts_full")
        changes = apply_stock(db,owner,RECIPES[recipe])
        part = uuid.uuid4().hex
        db.execute("INSERT INTO parts VALUES (?,?,?)", (part,owner,recipe))
        return record(db,owner,key,operation,signature,changes,part=part,recipe=recipe)
    if db.execute("SELECT 1 FROM admissions WHERE owner=? AND battle IS NULL", (owner,)).fetchone():
        raise Fault(409, "admission_pending")
    if "robot" in fields:
        from recovery import consume_entry_energy
        changes = consume_entry_energy(db,owner)
    else:
        changes = apply_stock(db,owner,{"energy":-1})
    ticket = secrets.token_urlsafe(32)
    if "robot" in fields:
        ticket = "owned_" + ticket
    db.execute("INSERT INTO admissions VALUES (?,?,NULL,NULL)", (ticket,owner))
    return record(db,owner,key,operation,signature,changes,ticket=ticket)


def settle(db, fields):
    if fields.keys() != {"ticket","battle","outcome"}:
        raise Fault(400, "invalid_parameters")
    ticket, battle, outcome = (fields[k] for k in ("ticket","battle","outcome"))
    if not all(isinstance(v,str) for v in (ticket,battle,outcome)) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",battle) or outcome not in REWARDS:
        raise Fault(400, "invalid_result")
    row = db.execute("SELECT owner,battle,outcome FROM admissions WHERE ticket=?", (ticket,)).fetchone()
    if not row:
        raise Fault(404, "unknown_ticket")
    owner = row["owner"]
    key = "result/" + battle
    signature = json.dumps([ticket,battle,outcome])
    receipt = previous(db,owner,key,signature)
    if receipt:
        return receipt
    if row["battle"] is not None:
        raise Fault(409,"ticket_used")
    changes = apply_stock(db,owner,REWARDS[outcome])
    db.execute("UPDATE admissions SET battle=?, outcome=? WHERE ticket=?", (battle,outcome,ticket))
    return record(db,owner,key,"reward",signature,changes,battle=battle,outcome=outcome)
