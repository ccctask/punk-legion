"""Owner-scoped pins for robot identities."""
import json
import re
from inventory import Fault


def schema(db):
    db.execute("CREATE TABLE IF NOT EXISTS favorite_robots(robot TEXT PRIMARY KEY REFERENCES robots(id))")
    db.execute("""CREATE TABLE IF NOT EXISTS pin_intents(owner TEXT REFERENCES accounts(id),
        key TEXT, signature TEXT NOT NULL, PRIMARY KEY(owner,key))""")


def update(db, owner, robot, fields):
    expected = {"key","saved"}
    if fields.keys() != expected or type(fields["saved"]) is not bool:
        raise Fault(400,"invalid_parameters")
    key = fields["key"]
    if not isinstance(key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",key):
        raise Fault(400,"invalid_key")
    if not isinstance(robot,str) or not db.execute("SELECT 1 FROM robots WHERE id=? AND owner=?",(robot,owner)).fetchone():
        raise Fault(404,"unknown_robot")
    signature=json.dumps([robot,fields["saved"]])
    old=db.execute("SELECT signature FROM pin_intents WHERE owner=? AND key=?",(owner,key)).fetchone()
    if old:
        if old[0]!=signature:
            raise Fault(409,"key_conflict")
        return
    db.execute("INSERT INTO pin_intents VALUES(?,?,?)",(owner,key,signature))
    if fields["saved"]:
        db.execute("INSERT OR IGNORE INTO favorite_robots VALUES(?)",(robot,))
    else:
        db.execute("DELETE FROM favorite_robots WHERE robot=?",(robot,))
