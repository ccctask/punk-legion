"""Restore an actual pre-treasure schema-14 five-volume snapshot into the M24 deployment."""
import argparse
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
from check_live_expedition import free_port
from check_profile import api,ok,wait_ready

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/operations"))
import snapshot


def run(old_image):
    prefix="m24-legacy-"+secrets.token_hex(4)
    old,new=prefix+"-old",prefix+"-new"
    env={p:dict(os.environ,PROFILE_HOST_PORT=str(free_port(socket.SOCK_STREAM)),TREASURE_HOST_PORT=str(free_port(socket.SOCK_DGRAM))) for p in (old,new)}
    urls={p:"http://127.0.0.1:"+e["PROFILE_HOST_PORT"] for p,e in env.items()}
    with tempfile.TemporaryDirectory() as tmp:
        folder=Path(tmp);override=folder/"legacy.yaml"
        override.write_text(json.dumps({"services":{"profile":{"image":old_image}}}))
        def compose(proj,*args):
            files=["-f",str(ROOT/"compose.yaml"),"-f",str(override)] if proj==old else []
            return subprocess.check_output(["docker","compose","-p",proj,*files,*args],cwd=ROOT,env=env[proj],stderr=subprocess.STDOUT,text=True)
        try:
            compose(old,"up","--no-build","-d","profile");wait_ready(urls[old])
            cred=dict(name="legacy_crew",password=secrets.token_urlsafe())
            account=ok(api(urls[old],"/v1/accounts",cred))
            shop=ok(api(urls[old],"/v1/store/order",dict(sku="extra_slot",key="legacy_slot"),account["token"]))
            ok(api(urls[old],"/v1/store/simulate",dict(order=shop["order"],result="success"),account["token"]))
            manifest=snapshot.capture(old,folder/"pre")
            assert manifest["schema"]==14 and len(manifest["volumes"])==5 and "treasure" not in manifest["services"]
            compose(new,"create","--build","profile","treasure")
            restored=snapshot.restore(new,folder/"pre")
            assert restored["schema"]==14
            compose(new,"start","profile");wait_ready(urls[new])
            assert api(urls[new],"/v1/profile",token=account["token"])[0]==401
            login=ok(api(urls[new],"/v1/sessions",cred));token=login["token"]
            assert login["robots"][0]["id"]==account["robots"][0]["id"]
            assert ok(api(urls[new],"/v1/store",token=token))["store"]["capacity"]==7
            assert ok(api(urls[new],"/v1/treasure",token=token))["treasure"]["roster"][0]["id"]==account["robots"][0]["id"]
            version=compose(new,"exec","-T","profile","python","-c","import server,sqlite3; actual=sqlite3.connect('/data/player.sqlite').execute('pragma user_version').fetchone()[0]; assert actual==server.VERSION; print(actual)").strip()
            print(f"TREASURE_LEGACY_BACKUP_PASS actual v14 without treasure service -> same five volumes -> v{version}, old login revoked, same robot and 7 paid design slots retained")
        finally:
            for p in (old,new):compose(p,"down","--volumes")

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--previous-image",required=True);run(p.parse_args().previous_image)
