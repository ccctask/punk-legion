"""Real ENet restart with existing volume; optional render of the latest game UI."""
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
import argparse
from check_live_expedition import free_port
from check_profile import api, ok, wait_ready
import socket


def run(godot):
    root=Path(__file__).resolve().parents[2]
    project="solo-resume-"+secrets.token_hex(4)
    port=free_port(socket.SOCK_DGRAM)
    http=free_port(socket.SOCK_STREAM)
    env=dict(os.environ,SOLO_HOST_PORT=str(port),SOLO_PORT=str(port),PROFILE_HOST_PORT=str(http))
    base=f"http://127.0.0.1:{http}"
    def docker(*args):
        subprocess.run(["docker","compose","-p",project,*args],cwd=root,env=env,check=True)
    with tempfile.TemporaryDirectory() as folder:
        try:
            docker("up","-d","--build","profile","expedition")
            wait_ready(base)
            user=ok(api(base,"/v1/accounts",{"name":"resume_"+secrets.token_hex(4),"password":secrets.token_urlsafe()}))
            robot=user["robots"][0]["id"]
            admission=ok(api(base,"/v1/expedition/start",{"key":"resume_test","robots":[robot]},user["token"]))["expedition"]["active"]
            for phase in ("before","after"):
                local=dict(env,SOLO_PHASE=phase,SOLO_EXPECTED_FILE=str(Path(folder)/"expected.bin"),TEST_MISSION_ID=admission["id"],TEST_MISSION_SECRET=admission["secret"],SOLO_ROBOT=robot)
                subprocess.run([godot,"--headless","--path","game","--script","res://expedition/tests/restart_peer.gd"],cwd=root,env=local,check=True,timeout=35)
                if phase=="before":
                    time.sleep(.4)
                    docker("restart","expedition")
                    time.sleep(.8)
            state=ok(api(base,"/v1/expedition",token=user["token"]))["expedition"]
            assert not state["active"] and state["last"]["outcome"]=="retreat"
        finally:
            docker("down","--volumes")
if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--godot",required=True)
    run(cli.parse_args().godot)
