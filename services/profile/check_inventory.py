"""M08 trust boundary, migration, replay, recovery and partial deduction checks through HTTP."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing, contextmanager
import os
from pathlib import Path
import secrets
import socket
import sqlite3
import subprocess
import sys
import tempfile

from check_profile import api, ok, wait_ready
import server


def run():
    with tempfile.TemporaryDirectory() as tmp, closing(socket.socket()) as sock:
        path = Path(tmp)/"old.db"
        backup = Path(tmp)/"saved.db"
        keyfile = Path(tmp)/"room.key"
        sock.bind(("127.0.0.1",0))
        port = sock.getsockname()[1]
        sock.close()
        url = f"http://127.0.0.1:{port}"
        account = {"name":"legacy","password":secrets.token_urlsafe()}
        salt = secrets.token_bytes(16)
        with closing(sqlite3.connect(path)) as db, db:
            db.execute("CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT UNIQUE,salt BLOB,digest BLOB,session TEXT UNIQUE)")
            db.execute("CREATE TABLE robots(id TEXT PRIMARY KEY,owner TEXT,name TEXT,task TEXT,assignment TEXT UNIQUE)")
            db.execute("INSERT INTO accounts VALUES ('old','legacy',?,?,NULL)",(salt,server.digest(account['password'],salt)))
            db.execute("INSERT INTO robots VALUES ('existing','old','旧机体','guard','old-task')")
            db.execute("PRAGMA user_version=1")
        server.snapshot(path,Path(tmp)/"before.db")
        @contextmanager
        def serve():
            proc = subprocess.Popen([sys.executable,Path(__file__).with_name("server.py"),"serve","--db",path,"--port",str(port),"--room-key-file",keyfile])
            try:
                wait_ready(url)
                yield
            finally:
                proc.terminate()
                proc.wait(8)
        def inv():
            return ok(api(url,"/v1/inventory",token=token))["inventory"]
        def craft(key="craft_one",recipe="cannon"):
            return api(url,"/v1/inventory/craft",{"key":key,"recipe":recipe},token)
        with serve():
            user = ok(api(url,"/v1/sessions",account))
            assert user["robots"][0]["assignment"] == "old-task"
            token = user["token"]
            assert len(inv()["ledger"]) == 1
            other = ok(api(url,"/v1/accounts",{"name":"second","password":secrets.token_urlsafe()}))["token"]
            with ThreadPoolExecutor(6) as pool:
                receipts = list(pool.map(lambda _: ok(craft())["receipt"],range(6)))
            assert all(r == receipts[0] for r in receipts)
            assert craft(recipe="drill")[0] == 409 and craft("lock_drill","drill")[0] == 403
            ok(craft("craft_two"))
            ok(craft("craft_three"))
            exhausted = inv()
            assert len(exhausted["parts"]) == 3 and exhausted["stock"]["structure"]["amount"] == 3
            assert craft("craft_four")[0] == 409 and inv() == exhausted  # structure debited before components fail
            assert not ok(api(url,"/v1/inventory",token=other))["inventory"]["parts"]
            admission = {"key":"admit_once"}
            ticket = ok(api(url,"/v1/inventory/admit",admission,token))["receipt"]["ticket"]
            assert ok(api(url,"/v1/inventory/admit",admission,token))["receipt"]["ticket"] == ticket
            assert api(url,"/v1/inventory/admit",{"key":"new_ticket"},token)[0] == 409
            result = {"ticket":ticket,"battle":"battle_001","outcome":"win"}
            assert api(url,"/internal/results",result,token)[0] == 401
            room = keyfile.read_text()
            assert api(url,"/internal/results",dict(result,drop=100),room)[0] == 400
            with ThreadPoolExecutor(4) as pool:
                awards = list(pool.map(lambda _: ok(api(url,"/internal/results",result,room))["receipt"],range(4)))
            assert all(r == awards[0] for r in awards)
            assert api(url,"/internal/results",dict(result,battle="battle_002"),room)[0] == 409
            assert api(url,"/internal/results",dict(result,outcome="draw"),room)[0] == 409
            after = inv()
            assert after["stock"]["components"]["amount"] == 2 and not after["pending_ticket"]
            server.snapshot(path,backup)
        with serve():
            assert ok(craft())["receipt"] == receipts[0]
            assert ok(api(url,"/internal/results",result,room))["receipt"] == awards[0] and inv() == after
            ok(craft("craft_four"))  # previously failed key can resume after replenishment
        restored = Path(tmp)/"restored.db"
        server.snapshot(backup,restored,restore=True)
        os.replace(restored,path)
        with serve():
            token = ok(api(url,"/v1/sessions",account))["token"]
            assert inv() == after and ok(craft())["receipt"] == receipts[0]
            for n in range(4):
                entry = ok(api(url,"/v1/inventory/admit",{"key":f"admit_000{n}"},token))
                ok(api(url,"/internal/results",{"ticket":entry["receipt"]["ticket"],"battle":f"battle_10{n}", "outcome":"win"},room))
            assert inv()["stock"]["energy"]["amount"] == 0
            assert api(url,"/v1/inventory/admit",{"key":"no_energy"},token)[0] == 409
        print("INVENTORY_PASS migration concurrency rollback isolation admission trusted settlement restart backup")
if __name__ == "__main__":
    run()
