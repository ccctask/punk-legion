"""Run against isolated temp processes; optional --compose uses a disposable Docker project."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing, contextmanager
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
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import server


def api(base, route, fields=None, token=""):
    headers = {"Content-Type":"application/json", "Authorization":"Bearer "+token}
    req = Request(base+route, None if fields is None else json.dumps(fields).encode(), headers)
    try:
        with urlopen(req,timeout=8) as resp:
            return resp.status, json.load(resp)
    except HTTPError as err:
        return err.code, json.load(err)


def ok(pair):
    assert pair[0] == 200, pair[0]
    return pair[1]


def wait_ready(base):
    for _ in range(100):
        try:
            if api(base,"/v1/profile")[0] == 401:
                return
        except (URLError, ConnectionError):
            pass
        time.sleep(0.1)
    raise RuntimeError("profile service unavailable")


def run(compose=False):
    with tempfile.TemporaryDirectory() as temp, closing(socket.socket()) as sock:
        sock.bind(("127.0.0.1",0))
        port = sock.getsockname()[1]
        sock.close()
        base = f"http://127.0.0.1:{port}"
        root = Path(__file__).resolve().parent
        db = Path(temp)/"player.sqlite"
        env = dict(os.environ,PROFILE_HOST_PORT=str(port))
        project = "profile-test-"+secrets.token_hex(4)
        def docker(*args):
            subprocess.run(["docker","compose","-p",project,*args],check=True,env=env,cwd=root.parent.parent)
        @contextmanager
        def service():
            proc = None
            if compose:
                docker("up","-d","--build","profile")
            else:
                proc = subprocess.Popen([sys.executable,root/"server.py","serve","--db",db,"--port",str(port)])
            try:
                wait_ready(base)
                yield
            finally:
                if compose:
                    docker("stop","profile")
                else:
                    proc.terminate()
                    proc.wait(timeout=8)
        try:
            with service():
                account = {"name":"alpha","password":secrets.token_urlsafe()}
                a = ok(api(base,"/v1/accounts",account))
                b = ok(api(base,"/v1/accounts",{"name":"bravo","password":secrets.token_urlsafe()}))
                robot = a["robots"][0]
                route = "/v1/robots/"+robot["id"]+"/"
                assert b["robots"][0]["id"] != robot["id"]
                assert api(base,route+"rename",{"name":"越界"},b["token"])[0] == 404
                assert api(base,"/v1/accounts",account)[0] == 409
                assert api(base,"/v1/sessions",dict(account,password="incorrect"))[0] == 401
                a2 = ok(api(base,"/v1/sessions",account))
                assert api(base,route+"rename",{"name":"旧会话"},a["token"])[0] == 401
                token = a2["token"]
                ok(api(base,route+"rename",{"name":"小铜罐"},token))
                def assign(task):
                    return api(base,route+"assign",{"task":task},token)
                with ThreadPoolExecutor(4) as pool:
                    assigned = list(pool.map(assign,server.TASKS))
                assert sorted(r[0] for r in assigned) == [200,409,409,409]
                previous = next(r[1]["robots"][0] for r in assigned if r[0] == 200)
                ok(api(base,route+"finish",{"assignment":previous["assignment"],"outcome":"cancelled"},token))
                for task in server.TASKS:
                    current = ok(assign(task))["robots"][0]
                    assert current["task"] == task
                    assert api(base,route+"finish",{"assignment":previous["assignment"],"outcome":"completed"},token)[0] == 409
                    assert ok(api(base,"/v1/profile",token=token))["robots"][0] == current
                    if task != "repair":
                        ok(api(base,route+"finish",{"assignment":current["assignment"],"outcome":"completed"},token))
                if compose:
                    docker("exec","-T","profile","python","server.py","backup","--file","/data/check.sqlite")
                else:
                    server.snapshot(db, Path(temp)/"check.sqlite")
            with service():
                verify = ok(api(base,"/v1/sessions",account))
                assert verify["robots"][0] == current and current["name"] == "小铜罐"
                ok(api(base,route+"rename",{"name":"备份后修改"},verify["token"]))
            if compose:
                docker("run","--rm","--no-deps","profile","python","server.py","restore","--db","/data/restored.sqlite","--file","/data/check.sqlite")
                docker("run","--rm","--no-deps","profile","python","-c","import os;os.replace('/data/restored.sqlite','/data/player.sqlite')")
            else:
                restored = Path(temp)/"new.sqlite"
                server.snapshot(Path(temp)/"check.sqlite",restored,restore=True)
                os.replace(restored,db)
            with service():
                assert api(base,"/v1/profile",token=token)[0] == 401
                assert ok(api(base,"/v1/sessions",account))["robots"][0] == current
            future = Path(temp)/"future.sqlite"
            with closing(sqlite3.connect(future)) as conn:
                conn.execute(f"PRAGMA user_version={server.VERSION+1}")
            try:
                server.initialize(future)
            except ValueError as exc:
                assert "unsupported" in str(exc)
            else:
                raise AssertionError("unsupported schema accepted")
        finally:
            if compose:
                docker("down","--volumes")
    print("PASS accounts isolation rotation four-way contention assignments restart backup restore schema",flush=True)


if __name__ == "__main__":
    cli = argparse.ArgumentParser()
    cli.add_argument("--compose",action="store_true")
    run(cli.parse_args().compose)
