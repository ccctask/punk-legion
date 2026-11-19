"""Run the account chassis or private-base layout scenario on a disposable local stack."""
import argparse
import os
from pathlib import Path
import secrets
import socket
import subprocess
from check_profile import wait_ready
from check_live_expedition import free_port

ROOT = Path(__file__).resolve().parents[2]
SCENES = {"biped":("owned/tests/biped_ui","BIPED_LIVE_PASS"),"base-layout":("onboarding/tests/base_layout","BASE_LAYOUT_PASS")}

def run(godot, mode, output):
    output.mkdir(parents=True, exist_ok=True)
    project="ui-"+mode+"-"+secrets.token_hex(3)
    http=free_port(socket.SOCK_STREAM)
    udp=free_port(socket.SOCK_DGRAM)
    env=dict(os.environ,PROFILE_URL=f"http://127.0.0.1:{http}",PROFILE_HOST_PORT=str(http),
             SOLO_HOST_PORT=str(udp),SOLO_PORT=str(udp),CAMPAIGN_LOGIN="tester_"+secrets.token_hex(5),
             CAMPAIGN_PASSWORD=secrets.token_urlsafe(),CAMPAIGN_EVIDENCE=str(output))
    def compose(*args):
        subprocess.run(["docker","compose","-p",project,*args],env=env,cwd=ROOT,check=True)
    try:
        compose("up","-d","--build","profile","expedition")
        wait_ready(env["PROFILE_URL"])
        scene,marker=SCENES[mode]
        log=output/(mode+".log")
        with log.open("w",encoding="utf8") as stream:
            subprocess.run([godot,"--path",str(ROOT/"game"),"--max-fps","30","--script","res://"+scene+".gd"],
                           env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=400,check=True)
        result=log.read_text(encoding="utf8")
        assert marker in result and "ERROR:" not in result,log
        print(marker)
    finally:
        compose("down","--volumes")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("mode",choices=SCENES)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    run(args.godot,args.mode,args.output.resolve())
