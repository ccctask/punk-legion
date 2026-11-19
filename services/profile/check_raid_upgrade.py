"""Restore both deployed v7 shapes, upgrade, restart, and authenticate against the live server."""
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

from check_profile import api,ok,wait_ready
import server


def run():
    with tempfile.TemporaryDirectory() as tmp:
        for missing in (True,False):
            path=Path(tmp)/f"old-{missing}.sqlite"
            server.initialize(path)
            login={"name":"upgrade_probe","password":"sample-only-pass"}
            account=server.login(path,login,True)["account"]["id"]
            with server.transaction(path) as db:
                old_due=db.execute("SELECT due FROM raid_clocks WHERE owner=?",(account,)).fetchone()[0]
                if missing:
                    db.execute("ALTER TABLE raid_clocks DROP COLUMN await_owner")
                else:
                    db.execute("UPDATE raid_clocks SET await_owner=1 WHERE owner=?",(account,))
                db.execute("PRAGMA user_version=7")
            server.initialize(path)
            server.initialize(path)
            with server.transaction(path) as db:
                due,hold=db.execute("SELECT due,await_owner FROM raid_clocks WHERE owner=?",(account,)).fetchone()
                assert due==old_due and hold==int(not missing)
                assert db.execute("PRAGMA user_version").fetchone()[0]==server.VERSION
            with socket.socket() as s:
                s.bind(("127.0.0.1",0))
                port=s.getsockname()[1]
            proc=subprocess.Popen([sys.executable,Path(__file__).with_name("server.py"),"serve","--db",path,"--port",str(port)])
            try:
                url=f"http://127.0.0.1:{port}"
                wait_ready(url)
                token=ok(api(url,"/v1/sessions",login))["token"]
                assert ok(api(url,"/v1/base/raids",token=token))["raid"]["stage"]=="protected"
                assert ok(api(url,"/v1/profile",token=token))["account"]["id"]==account
            finally:
                proc.terminate()
                proc.wait(timeout=8)
            print("RAID_UPGRADE_PASS", "v7 missing column" if missing else "v7 with column", "retained due/session owner, restarted HTTP healthy")

if __name__=="__main__":
    run()
