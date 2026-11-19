"""Native password accounts and opt-in, one-use offline recovery credentials."""
from hashlib import pbkdf2_hmac, sha256
from hmac import compare_digest, digest as keyed_digest
import re
import secrets
from time import time

from inventory import Fault

ISSUE = "/v1/account/recovery-code"
REDEEM = "/v1/account/recover"
WINDOW = 300
ACCOUNT_LIMIT = 5
SOURCE_LIMIT = 40
# Keyed slots cap storage even when callers invent names and vary source addresses.
SLOTS = 4096

def schema(db):
    db.execute("CREATE TABLE recovery_codes(owner TEXT PRIMARY KEY REFERENCES accounts(id), verifier BLOB NOT NULL)")
    db.execute("CREATE TABLE recovery_rate_key(key BLOB NOT NULL)")
    db.execute("INSERT INTO recovery_rate_key VALUES (?)",(secrets.token_bytes(32),))
    db.execute("""CREATE TABLE recovery_attempts(scope TEXT NOT NULL,slot INTEGER NOT NULL,
                  started INTEGER NOT NULL,used INTEGER NOT NULL,PRIMARY KEY(scope,slot))""")

def valid_password(password):
    return isinstance(password,str) and 8<=len(password)<=128

def valid_name(name):
    return isinstance(name,str) and re.fullmatch(r"[A-Za-z0-9_-]{3,32}",name)

def digest(password,salt):
    return pbkdf2_hmac("sha256",password.encode(),salt,240000)

def reserve_attempt(db,route,identity,peer):
    key=db.execute("SELECT key FROM recovery_rate_key").fetchone()[0]
    now=int(time())
    action="issue" if route==ISSUE else "redeem"
    for kind,value,limit in (("source",peer,SOURCE_LIMIT),("account",identity,ACCOUNT_LIMIT)):
        scope=action+"_"+kind
        raw=keyed_digest(key,value.encode(),"sha256")
        slot=int.from_bytes(raw[:2],"big")%SLOTS
        row=db.execute("SELECT started,used FROM recovery_attempts WHERE scope=? AND slot=?",(scope,slot)).fetchone()
        if row and now<row["started"]+WINDOW:
            if row["used"]>=limit:
                raise Fault(429,"recovery_rate_limited")
            db.execute("UPDATE recovery_attempts SET used=used+1 WHERE scope=? AND slot=?",(scope,slot))
        else:
            db.execute("INSERT OR REPLACE INTO recovery_attempts VALUES (?,?,?,1)",(scope,slot,now))

def issue(db,owner,fields):
    password=fields.get("password")
    if fields.keys()!={"password"} or not valid_password(password):
        raise Fault(403,"invalid_credentials")
    row=db.execute("SELECT salt,digest FROM accounts WHERE id=?",(owner,)).fetchone()
    if not compare_digest(digest(password,row["salt"]),row["digest"]):
        raise Fault(403,"invalid_credentials")
    raw=secrets.token_bytes(16)
    db.execute("INSERT OR REPLACE INTO recovery_codes VALUES (?,?)",(owner,sha256(raw).digest()))
    text=raw.hex().upper()
    return {"code":"-".join(text[i:i+4] for i in range(0,len(text),4))}

def redeem(db,name,fields):
    password=fields.get("new_password")
    if not valid_password(password):
        raise Fault(400,"invalid_password")
    code=fields.get("code")
    if fields.keys()!={"name","code","new_password"} or not valid_name(name) or not isinstance(code,str) or len(code)>128:
        raise Fault(400,"invalid_recovery")
    code=code.replace("-","").replace(" ","")
    if not re.fullmatch(r"[a-fA-F0-9]{32}",code):
        raise Fault(400,"invalid_recovery")
    row=db.execute("""SELECT a.id,c.verifier FROM accounts a JOIN recovery_codes c ON a.id=c.owner
                      WHERE a.name=?""",(name.lower(),)).fetchone()
    matches=compare_digest(sha256(bytes.fromhex(code)).digest(),row["verifier"] if row else bytes(32))
    if not matches or row is None:
        raise Fault(400,"invalid_recovery")
    salt=secrets.token_bytes(16)
    db.execute("UPDATE accounts SET salt=?,digest=?,session=NULL WHERE id=?",(salt,digest(password,salt),row["id"]))
    db.execute("DELETE FROM recovery_codes WHERE owner=?",(row["id"],))
    return {"recovered":True}
