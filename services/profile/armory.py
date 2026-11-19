"""Personal armory salvage, one physical prize per owner and one supply per opening day."""
import re
import uuid

import factory
import inventory

LOCATION = "old_armory"
PART = "chimney_arm"


def schema(db):
    db.execute("CREATE TABLE armory_entries(mission TEXT PRIMARY KEY REFERENCES expeditions(id), day TEXT NOT NULL)")
    db.execute("""CREATE TABLE armory_prizes(owner TEXT PRIMARY KEY REFERENCES accounts(id),
                  mission TEXT NOT NULL UNIQUE REFERENCES expeditions(id), part_id TEXT UNIQUE)""")
    db.execute("""CREATE TABLE armory_supplies(owner TEXT REFERENCES accounts(id), day TEXT,
                  mission TEXT UNIQUE REFERENCES expeditions(id), PRIMARY KEY(owner, day))""")


def quote(db, owner):
    prize = db.execute("SELECT part_id FROM armory_prizes WHERE owner=?", (owner,)).fetchone()
    supply = db.execute("SELECT 1 FROM armory_supplies WHERE owner=? AND day=?", (owner, factory.day())).fetchone()
    return dict(unlocked=bool(factory.layout_for(db, owner).get("factory_south")), first_cleared=bool(prize),
                pending_part=bool(prize and not prize["part_id"]), daily_available=not bool(supply))


def deliver(db, owner):
    count = db.execute("SELECT COUNT(*) FROM (" + inventory.FREE_PARTS + ")", (owner,)).fetchone()[0]
    if count >= inventory.PART_CAP:
        return None
    item = uuid.uuid4().hex
    db.execute("INSERT INTO parts VALUES (?,?,?)", (item, owner, PART))
    db.execute("UPDATE armory_prizes SET part_id=? WHERE owner=?", (item, owner))
    return dict(id=item, definition=PART)


def claim(db, owner, fields):
    if fields.keys() != {"key"} or not isinstance(fields["key"], str) or not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}", fields["key"]):
        raise inventory.Fault(400, "invalid_parameters")
    action = "armory_claim"
    previous = inventory.previous(db, owner, fields["key"], action)
    if previous:
        return previous
    pending = db.execute("SELECT mission FROM armory_prizes WHERE owner=? AND part_id IS NULL", (owner,)).fetchone()
    if not pending:
        raise inventory.Fault(409, "nothing_to_claim")
    part = deliver(db, owner)
    if part is None:
        raise inventory.Fault(409, "parts_full")
    return inventory.record(db, owner, fields["key"], action, action, {}, mission=pending["mission"], part=part)


def reward(db, owner, mission, day, outcome, participated):
    first = False
    supply = False
    part = None
    if participated and outcome == "win":
        first = bool(db.execute("INSERT INTO armory_prizes(owner,mission) VALUES(?,?) ON CONFLICT(owner) DO NOTHING",
                                (owner, mission)).rowcount)
        if first:
            part = deliver(db, owner)
        supply = bool(db.execute("INSERT INTO armory_supplies VALUES(?,?,?) ON CONFLICT(owner,day) DO NOTHING",
                                 (owner, day, mission)).rowcount)
    changes = inventory.apply_stock(db, owner, {"components": 1}) if supply else {"components": 0}
    return dict(first_clear=first, pending_part=quote(db, owner)["pending_part"], part=part, daily_award=supply,
                reward_day=day, changes=changes)
