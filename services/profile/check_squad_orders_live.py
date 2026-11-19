"""Run three real Godot clients through prebattle orders, role selection and reconnection."""
from concurrent.futures import ThreadPoolExecutor
import argparse
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
from check_live_expedition import free_port
from check_profile import wait_ready
from check_field_repair import ROOT
from check_private_campaign import encode


def run(godot,out):
    out.mkdir(parents=True,exist_ok=True)
    project="squad-orders-"+secrets.token_hex(4)
    http=free_port(socket.SOCK_STREAM)
    solo,party=free_port(socket.SOCK_DGRAM),free_port(socket.SOCK_DGRAM)
    while solo==party:party=free_port(socket.SOCK_DGRAM)
    env=dict(os.environ,PROFILE_URL=f"http://127.0.0.1:{http}",PROFILE_HOST_PORT=str(http),SOLO_HOST_PORT=str(solo),
             SOLO_PORT=str(solo),PARTY_HOST_PORT=str(party),PARTY_PORT=str(party))
    def compose(*args):subprocess.run(["docker","compose","-p",project,*args],env=env,cwd=ROOT,check=True)
    with tempfile.TemporaryDirectory() as tmp:
        temporary=Path(tmp)
        frames=temporary/"frames";frames.mkdir()
        def client(role):
            settings=dict(env,REPAIR_ROLE=role,REPAIR_INVITE=str(temporary/"invite"),CAMPAIGN_LOGIN="orders_"+secrets.token_hex(4),
                CAMPAIGN_PASSWORD=secrets.token_urlsafe(),CAMPAIGN_EVIDENCE=str(out),CAMPAIGN_FRAMES=str(frames) if role=="solo" else "")
            target=out/(role+".log")
            with target.open("w",encoding="utf8") as stream:
                subprocess.run([godot,"--path",str(ROOT/"game"),"--max-fps","30","--script","res://battle/tests/squad_orders_ui.gd"],
                    env=settings,stdout=stream,stderr=subprocess.STDOUT,timeout=100,check=True)
            log=target.read_text(encoding="utf8")
            assert "SQUAD_ORDERS_LIVE_PASS" in log and "ERROR:" not in log
        try:
            compose("up","-d","--build","profile","party","expedition");wait_ready(env["PROFILE_URL"])
            with ThreadPoolExecutor(3) as workers:list(workers.map(client,["solo","leader","guest"]))
            encode(frames,out/"roles.mp4")
            print("SQUAD_ORDERS_LIVE_COMPLETE",flush=True)
        finally:compose("down","--volumes")

if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--godot",required=True);parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args();run(args.godot,args.output.resolve())
