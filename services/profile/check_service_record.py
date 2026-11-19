"""Run an owned robot through two real Godot clients, reconnect, ledger and history."""
import argparse
from contextlib import closing
import json
import os
from pathlib import Path
import secrets
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time

from check_profile import api, ok, wait_ready


def port(kind):
    with socket.socket(type=kind) as sock:
        sock.bind(("127.0.0.1",0))
        return sock.getsockname()[1]


def run(godot):
    if os.name == "nt" and godot.endswith("_console.exe"):
        godot = godot.removesuffix("_console.exe") + ".exe"
    root = Path(__file__).resolve().parents[2]
    http,udp = port(socket.SOCK_STREAM),port(socket.SOCK_DGRAM)
    url = f"http://127.0.0.1:{http}"
    with tempfile.TemporaryDirectory() as temp:
        tmp = Path(temp)
        keyfile = tmp/"key"
        db = tmp/"profile.sqlite"
        env = dict(os.environ, ROOM_PORT=str(udp), ROOM_RESULTS_URL=url+"/internal/results",
                   ROOM_AUTH_FILE=str(keyfile), ROOM_OUTBOX_DIR=str(tmp/"outbox"), PROFILE_URL=url)
        processes = []
        def launch(*args):
            number = len(processes)
            if args[0] == godot:
                args = (args[0],"--log-file",str(tmp/f"godot{number}.log"),*args[1:])
            p = subprocess.Popen(args,cwd=root,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            processes.append(p)
            return p
        try:
            launch(sys.executable,root/"services/profile/server.py","serve","--db",db,"--port",str(http),"--room-key-file",keyfile)
            wait_ready(url)
            clients = []
            accounts = []
            for n in [1,2]:
                account = {"name":f"service_{n}","password":secrets.token_urlsafe()}
                a = ok(api(url,"/v1/accounts",account))
                rid = a["robots"][0]["id"]
                token = a["token"]
                ok(api(url,f"/v1/robots/{rid}/rename",{"name":f"铜虎机组{n}"},token))
                ticket = ok(api(url,"/v1/inventory/admit",{"key":"sortie_001","robot":rid},token))["receipt"]["ticket"]
                env[f"ROOM_TEST_TICKET{n}"] = ticket
                accounts.append((account,rid,ticket))
            launch(godot,"--headless","--path","game","res://net/server.tscn","--","--server")
            time.sleep(1)
            for _ in range(2):
                clients.append(launch(godot,"--headless","--path","game","--script","res://client/tests/exercise_flow.gd"))
            for n,client in enumerate(clients,2):
                client.wait(timeout=210)
                output = (tmp/f"godot{n}.log").read_text(encoding="utf8",errors="replace")
                print(output.strip(),flush=True)
                assert client.returncode == 0 and "EXERCISE_RESULT" in output
            for account,rid,ticket in accounts:
                token = ok(api(url,"/v1/sessions",account))["token"]
                route = f"/v1/robots/{rid}/history"
                for _ in range(40):
                    history = ok(api(url,route,token=token))["history"]
                    if history["totals"]["battles"]:
                        break
                    time.sleep(.15)
                assert history["totals"]["battles"] == 1
                assert set(history)=={"robot","totals"} and set(history["totals"])=={"battles","kills","output"}
                ok(api(url,f"/v1/robots/{rid}/rename",{"name":"Tin Finch"},token))
                assert ok(api(url,route,token=token))["history"]==history
                print("OWNED_CAREER",rid,history["totals"],flush=True)
            account,rid,_ticket = accounts[0]
            other_token = ok(api(url,"/v1/sessions",accounts[1][0]))["token"]
            assert api(url,f"/v1/robots/{rid}/history",token=other_token)[0] == 404
            # Create one paid controlled fixture to verify assists do not change kills or output.
            token = ok(api(url,"/v1/sessions",account))["token"]
            recovery_route = f"/v1/robots/{rid}/recovery"
            state = ok(api(url,recovery_route,token=token))["recovery"]["state"]
            if state == "damaged":
                env.update(SERVICE_TEST_NAME=account["name"],SERVICE_TEST_PASS=account["password"])
                ui = launch(godot,"--headless","--path","game","--script","res://profile/tests/recovery_ui.gd")
                assert ui.wait(timeout=25) == 0
                token = ok(api(url,"/v1/sessions",account))["token"]
                print("RECOVERY_UI_PASS paid repair and recycle preview for the actual damaged body")
                with closing(sqlite3.connect(db)) as fixture, fixture:
                    fixture.execute("UPDATE robot_condition SET due=0 WHERE robot=?", (rid,))
            ticket = ok(api(url,"/v1/inventory/admit",{"key":"assists_run","robot":rid},token))["receipt"]["ticket"]
            battle = ok(api(url,"/internal/deploy",{"tickets":{"1":ticket}},keyfile.read_text()))["battle"]
            events = [{"at":0,"kind":"deployment","actor":rid,"target":"","amount":0}]
            for i in range(8):
                events.append({"at":i+1,"kind":"assist","actor":rid,"target":f"training-{i}","amount":1})
            events.append({"at":10,"kind":"result","actor":rid,"target":"win","amount":0})
            ok(api(url,"/internal/results",{"ticket":ticket,"battle":battle,"outcome":"win","report":{"robot":rid,"events":events}},keyfile.read_text()))
            assert api(url,f"/v1/robots/{rid}/history/{battle}",token=token)[0]==404
            assert ok(api(url,f"/v1/robots/{rid}/history",token=token))["history"]["totals"]["battles"]==2
            def energy():
                return ok(api(url,"/v1/inventory",token=token))["inventory"]["stock"]["energy"]["amount"]
            original = energy()
            for case in ["before_match","crashed_room"]:
                ticket = ok(api(url,"/v1/inventory/admit",{"key":case,"robot":rid},token))["receipt"]["ticket"]
                assert energy() == original-1
                cancel = {"assignment":ticket,"outcome":"cancelled"}
                if case == "crashed_room":
                    battle = ok(api(url,"/internal/deploy",{"tickets":{"1":ticket}},keyfile.read_text()))["battle"]
                    assert api(url,f"/v1/robots/{rid}/finish",cancel,token)[0] == 409
                    with closing(sqlite3.connect(db)) as fixture, fixture:
                        fixture.execute("UPDATE robot_sorties SET expires=0 WHERE ticket=?",(ticket,))
                    assert api(url,"/internal/results",{"ticket":ticket,"battle":battle,"outcome":"win"},keyfile.read_text())[0] == 409
                for _ in range(2):
                    assert ok(api(url,f"/v1/robots/{rid}/finish",cancel,token))["robots"][0]["assignment"] is None
                assert energy() == original and ok(api(url,f"/v1/robots/{rid}/history",token=token))["history"]["totals"]["battles"] == 2
            print("SERVICE_CANCEL_PASS unmatched refund and expired bound battle; late delivery rejected")
            ticket = ok(api(url,"/v1/inventory/admit",{"key":"offline_outbox","robot":rid},token))["receipt"]["ticket"]
            battle = ok(api(url,"/internal/deploy",{"tickets":{"1":ticket}},keyfile.read_text()))["battle"]
            processes[0].terminate()
            processes[0].wait(timeout=10)
            expiry = int(time.time())-90
            with closing(sqlite3.connect(db)) as fixture, fixture:
                fixture.execute("UPDATE robot_sorties SET expires=? WHERE ticket=?",(expiry,ticket))
            entry = {"ticket":ticket,"battle":battle,"outcome":"win","finished_at":expiry-10,
                     "report":{"robot":rid,"events":[{"at":0,"kind":"deployment","actor":rid,"target":"","amount":0},
                     {"at":5,"kind":"result","actor":rid,"target":"win","amount":0}]}}
            spool = tmp/"outbox"/(battle+".json")
            spool.write_text(json.dumps({"deliveries":[entry]}),encoding="utf8")
            launch(sys.executable,root/"services/profile/server.py","serve","--db",db,"--port",str(http),"--room-key-file",keyfile)
            wait_ready(url)
            # A real running room drainer may win the delivery race after profile restarts.
            first = ok(api(url,"/internal/results",entry,keyfile.read_text()))["receipt"]
            assert ok(api(url,"/internal/results",entry,keyfile.read_text()))["receipt"] == first
            assert ok(api(url,f"/v1/robots/{rid}/history",token=token))["history"]["totals"]["battles"] == 3
            assert energy() == original-1
            print("SERVICE_LATE_TERMINAL_PASS persisted before deadline, restart after deadline, one reward and no refund")
            print("SERVICE_RECORD_E2E_PASS")
        finally:
            for p in reversed(processes):
                if p.poll() is None:
                    p.terminate()
                p.wait(timeout=10)

if __name__ == "__main__":
    cli = argparse.ArgumentParser()
    cli.add_argument("--godot",required=True)
    run(cli.parse_args().godot)
