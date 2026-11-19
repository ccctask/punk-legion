"""Exercise the inventory, garage and mission UI on isolated solo and party servers."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import tempfile
from check_live_expedition import free_port
from check_profile import wait_ready

ROOT=Path(__file__).resolve().parents[2]

def audit(project,folder):
    robots=set()
    for role in ("solo","guest","leader"):
        line=next(l for l in (folder/(role+".log")).read_text(encoding="utf-8-sig").splitlines() if "MODULE_REPAIR_UI_PASS" in l)
        # The first one or two IDs identify deployed robots; remaining IDs are the arm and receipt.
        ids=re.findall(r"\b[a-f0-9]{32}\b",line)
        robots.update(ids[:2 if role=="solo" else 1])
    script=(Path(__file__).with_name("audit_field_repair.py")).read_text(encoding="utf-8-sig")
    result=subprocess.check_output(["docker","compose","-p",project,"exec","-T","profile","python","-","/data/player.sqlite",*sorted(robots)],
        input=script,text=True,encoding="utf8",cwd=ROOT)
    (folder/"ledger.json").write_text(result,encoding="utf8")
    print("FIELD_REPAIR_LEDGER_PASS",flush=True)

def run(godot,out):
    out.mkdir(parents=True,exist_ok=True)
    project="field-repair-"+secrets.token_hex(4)
    http=free_port(socket.SOCK_STREAM)
    udp=free_port(socket.SOCK_DGRAM)
    partner=free_port(socket.SOCK_DGRAM)
    while partner==udp:partner=free_port(socket.SOCK_DGRAM)
    env=dict(os.environ,PROFILE_URL=f"http://127.0.0.1:{http}",PROFILE_HOST_PORT=str(http),SOLO_HOST_PORT=str(udp),
             SOLO_PORT=str(udp),PARTY_HOST_PORT=str(partner),PARTY_PORT=str(partner))
    def compose(*args):
        subprocess.run(["docker","compose","-p",project,*args],cwd=ROOT,env=env,check=True)
    with tempfile.TemporaryDirectory() as tmp:
        def client(role):
            settings=dict(env,REPAIR_ROLE=role,REPAIR_INVITE=str(Path(tmp)/"invite"),CAMPAIGN_LOGIN="rig_"+secrets.token_hex(5),
                      CAMPAIGN_PASSWORD=secrets.token_urlsafe(),CAMPAIGN_EVIDENCE=str(out))
            with (out/(role+".log")).open("w",encoding="utf8") as log:
                subprocess.run([godot,"--path",str(ROOT/"game"),"--max-fps","30","--script","res://owned/tests/field_repair_ui.gd"],
                        stdout=log,stderr=subprocess.STDOUT,check=True,timeout=390,env=settings)
        try:
            compose("up","-d","--build","profile","party","expedition")
            wait_ready(env["PROFILE_URL"])
            with ThreadPoolExecutor(3) as workers:list(workers.map(client,("solo","leader","guest")))
            audit(project,out)
        finally:compose("down","--volumes")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    run(args.godot,args.output.resolve())
