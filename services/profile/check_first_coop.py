"""Time one invited co-op daily through two first-time player UIs and reconcile receipts."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import json
import os
import re
import secrets
import socket
import subprocess
import tempfile
from check_field_repair import ROOT
from check_live_expedition import free_port
from check_profile import wait_ready
from check_private_campaign import encode

def run(godot,out):
    out.mkdir(parents=True,exist_ok=True)
    project="first-coop-"+secrets.token_hex(4)
    http,udp=free_port(socket.SOCK_STREAM),free_port(socket.SOCK_DGRAM)
    env=dict(os.environ,PROFILE_URL=f"http://127.0.0.1:{http}",PROFILE_HOST_PORT=str(http),PARTY_HOST_PORT=str(udp),PARTY_PORT=str(udp))
    def compose(*args):
        subprocess.run(["docker","compose","-p",project,*args],cwd=ROOT,env=env,check=True)
    with tempfile.TemporaryDirectory() as tmp:
        frames=Path(tmp)/"frames"
        frames.mkdir()
        def client(role):
            settings=dict(env,REPAIR_ROLE=role,REPAIR_INVITE=str(Path(tmp)/"invite"),CAMPAIGN_LOGIN="day_"+secrets.token_hex(5),
                    CAMPAIGN_PASSWORD=secrets.token_urlsafe(),CAMPAIGN_EVIDENCE=str(out),CAMPAIGN_FRAMES=str(frames) if role=="leader" else "")
            with (out/(role+".log")).open("w",encoding="utf8") as log:
                subprocess.run([godot,"--path",str(ROOT/"game"),"--max-fps","30","--script","res://onboarding/tests/first_coop.gd"],
                               cwd=ROOT,env=settings,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=390)
        try:
            compose("up","-d","--build","profile","party")
            wait_ready(env["PROFILE_URL"])
            with ThreadPoolExecutor(2) as team:list(team.map(client,("leader","guest")))
            awards=[]; milestones={}
            for role in ["leader","guest"]:
                log=(out/(role+".log")).read_text(encoding="utf8")
                assert "FIRST_COOP_PASS "+role in log and "SCRIPT ERROR" not in log
                matches=re.findall(r"^FIRST_COOP_AWARD "+role+r" ([0-9a-f]{32}) (.+)$",log,re.M)
                assert len(matches)==1
                robot,body=matches[0];awards.append((robot,json.loads(body)["id"]))
                milestones[role]={s:float(t) for s,t in re.findall(r"^FIRST_COOP "+role+r" (\w+) ([\d.]+)",log,re.M)}
            audit="""import sqlite3, sys, json
db=sqlite3.connect('file:/data/player.sqlite?mode=ro',uri=True)
details=[]
for rid,award in zip(sys.argv[1::2],sys.argv[2::2]):
 row=db.execute('SELECT owner,body FROM receipts WHERE id=?',(award,)).fetchone()
 r=json.loads(row[1]); assert r['nodes'] and r['outcome']=='win' and r['commanded']
 rows=db.execute('SELECT group_id FROM party_members WHERE owner=? AND mission=?',(row[0],r['mission'])).fetchall()
 assert len(rows)==1 and db.execute('SELECT COUNT(*) FROM robot_sorties WHERE robot=? AND result_digest IS NOT NULL',(rid,)).fetchone()[0]==1
 details.append(dict(robot=rid,room=rows[0][0],receipt=award,changes=r['changes'],nodes=r['nodes'],seconds=r['seconds']))
assert details[0]['room']==details[1]['room'] and details[0]['receipt']!=details[1]['receipt']
print(json.dumps(details))"""
            result=subprocess.check_output(["docker","compose","-p",project,"exec","-T","profile","python","-",*[v for duo in awards for v in duo]],
                           input=audit,cwd=ROOT,encoding="utf8")
            (out/"session.json").write_text(json.dumps(dict(milestones=milestones,details=json.loads(result)),indent=2),encoding="utf8")
            encode(frames,out/"first-coop.mp4")
            print("FIRST_COOP_EVIDENCE_PASS",milestones,flush=True)
        finally:compose("down","--volumes")

if __name__=="__main__":
    cli=argparse.ArgumentParser();cli.add_argument("--godot",required=True);cli.add_argument("--output",required=True,type=Path)
    args=cli.parse_args();run(args.godot,args.output.resolve())
