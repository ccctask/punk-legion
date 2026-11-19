"""Restore live game evidence into another named stack, then test an actual older profile image."""
import argparse
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time

from check_profile import api,ok,wait_ready
from check_live_expedition import free_port
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/operations"))
import snapshot


def eventually(check,seconds=20):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        if check():return
        time.sleep(.25)
    raise AssertionError("deadline reached")


def run(args):
    source="m22-src-"+secrets.token_hex(4);target="m22-dst-"+secrets.token_hex(4)
    h1,h2=free_port(socket.SOCK_STREAM),free_port(socket.SOCK_STREAM)
    u1,u2=free_port(socket.SOCK_DGRAM),free_port(socket.SOCK_DGRAM)
    envs={p:{**os.environ,"SOLO_HOST_PORT":str(u),"PROFILE_HOST_PORT":str(h)} for p,h,u in [(source,h1,u1),(target,h2,u2)]}
    b1,b2=f"http://127.0.0.1:{h1}",f"http://127.0.0.1:{h2}"
    path=Path(args.output).resolve();path.mkdir(parents=True,exist_ok=True)
    def compose(p,*cmd):
        run=subprocess.run(["docker","compose","-p",p,*cmd],cwd=ROOT,env=envs[p],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding="utf8",errors="replace")
        if run.returncode:raise RuntimeError(run.stdout[-1500:])
        return run.stdout
    def inventory(base,token):
        return ok(api(base,"/v1/inventory",token=token))["inventory"]["stock"]
    def execute_key(base,token,route,data=None):return ok(api(base,route,data,token))
    with tempfile.TemporaryDirectory(prefix="m22-drill-") as tmp:
        folder=Path(tmp);gate=folder/"finish";expected=folder/"checkpoint.bin"
        live=None
        try:
            compose(source,"up","-d","--build","profile","expedition");wait_ready(b1)
            credentials=[];users=[];missions=[]
            for index in range(2):
                cred=dict(name="drill_user_"+str(index),password=secrets.token_urlsafe())
                credentials.append(cred)
                users.append(ok(api(b1,"/v1/accounts",cred)))
            a,b=users
            # Normal mock order; actual rights and equipment must survive the restore.
            order=execute_key(b1,a["token"],"/v1/store/order",dict(sku="paint_mint",key="drill_shop"))["order"]
            execute_key(b1,a["token"],"/v1/store/simulate",dict(order=order,result="success"))
            execute_key(b1,a["token"],"/v1/store/equip",dict(robot=a["robots"][0]["id"],paint="mint"))
            # Set estate by the real internal settlement contract on this isolated fixture.
            def estate():
                code="""import server,world_calendar as w,camp,json,os
from unittest.mock import patch
p='/data/player.sqlite';owner=__OWNER__;robot=__ROBOT__
with server.transaction(p) as db:
 data=json.loads(w.config_path().read_text());data['nodes'][1]['daily']=[[0,86400,86400]]
 from pathlib import Path
 f=Path('/tmp/m22-fixture-calendar.json');f.write_text(json.dumps(data));os.environ['WORLD_CALENDAR_FILE']=str(f)
 grant=w.handle(db,owner,'POST','/v1/world/admit',{'node':camp.NODE,'key':'drill_grant'})['admission']['id']
 entry=camp.handle(db,owner,'POST','/v1/camp/reserve',{'grant':grant,'robots':[robot]})['admission']
 camp.internal(db,'/internal/camp/open',{k:entry[k] for k in ('id','secret')})
 camp.internal(db,'/internal/camp/settle',dict(id=entry['id'],winner='attacker',reason='core',reports={robot:[]},seconds=16,finished_at=w.now()))
"""
                code=code.replace("__OWNER__",repr(a["account"]["id"])).replace("__ROBOT__",repr(a["robots"][0]["id"]))
                compose(source,"exec","-T","profile","python","-c",code)
            estate()
            for user in users:
                active=execute_key(b1,user["token"],"/v1/expedition/start",dict(key="drill_enter",robots=[user["robots"][0]["id"]]))["expedition"]["active"]
                missions.append(active)
            def client_env(i,port):
                return {**os.environ,"TEST_MISSION_ID":missions[i]["id"],"TEST_MISSION_SECRET":missions[i]["secret"],
                        "SOLO_ROBOT":users[i]["robots"][0]["id"],"SOLO_PORT":str(port),"SOLO_EXPECTED_FILE":str(expected),"M22_GATE":str(gate)}
            def checkpoint(phase,port):
                subprocess.run([args.godot,"--headless","--path",str(ROOT/"game"),"--script","res://expedition/tests/restart_peer.gd"],
                               check=True,env={**client_env(0,port),"SOLO_PHASE":phase},timeout=40)
            checkpoint("before",u1)
            live=subprocess.Popen([args.godot,"--headless","--path",str(ROOT/"game"),"--script","res://net/tests/backup_peer.gd"],env=client_env(1,u1))
            eventually(lambda:(folder/"finish.ready").exists(),110)
            before=inventory(b1,b["token"])["structure"]["amount"]
            compose(source,"stop","profile")
            gate.write_text("finish")
            assert live.wait(timeout=15)==0
            marker="/var/lib/punk-room/"+missions[1]["id"]+".result.json"
            eventually(lambda:compose(source,"exec","-T","expedition","sh","-c","if test -f "+marker+"; then echo ready; fi").strip()=="ready")
            compose(source,"kill","-s","SIGKILL","expedition")
            manifest=snapshot.capture(source,folder/"frozen")
            assert manifest["volumes"]["solo-missions"]["files"]>=4
            print("DRILL_FROZEN",manifest["schema"],"real active checkpoint",missions[0]["id"],"unposted terminal",missions[1]["id"],"volumes",len(manifest["volumes"]),flush=True)
            compose(target,"create","--build","profile","expedition")
            manifest_file=folder/"frozen/manifest.json"
            original=manifest_file.read_bytes()
            corrupt=json.loads(original)
            corrupt["volumes"]["solo-missions"]["sha256"]="0"*64
            manifest_file.write_text(json.dumps(corrupt),encoding="utf8")
            try:
                try:snapshot.restore(target,folder/"frozen")
                except subprocess.CalledProcessError:pass
                else:raise AssertionError("corrupt backup accepted")
            finally:manifest_file.write_bytes(original)
            resume=snapshot.restore(target,folder/"frozen")
            try:snapshot.restore(target,folder/"frozen")
            except subprocess.CalledProcessError:pass
            else:raise AssertionError("non-empty target accepted")
            print("DRILL_GUARDS_PASS checksum rejected before restore; occupied target retained",flush=True)
            assert resume["schema"]==manifest["schema"]
            compose(target,"start","profile");wait_ready(b2)
            assert api(b2,"/v1/profile",token=a["token"])[0]==401
            tokens=[ok(api(b2,"/v1/sessions",c))["token"] for c in credentials]
            assert execute_key(b2,tokens[0],"/v1/store")["store"]["robots"][0]["paint"]=="mint"
            assert execute_key(b2,tokens[0],"/v1/camp")["camp"]["mine"]
            assert execute_key(b2,tokens[0],"/v1/profile")["robots"][0]["task"]=="expedition"
            compose(target,"start","expedition");time.sleep(1)
            checkpoint("after",u2)
            eventually(lambda:execute_key(b2,tokens[1],"/v1/expedition")["expedition"]["active"] is None)
            for i,token in enumerate(tokens):
                last=execute_key(b2,token,"/v1/expedition")["expedition"]["last"]
                assert last["mission"]==missions[i]["id"] and last["outcome"]=="retreat"
                assert execute_key(b2,token,"/v1/profile")["robots"][0]["task"] is None
            assert inventory(b2,tokens[1])["structure"]["amount"]==before+1
            compose(target,"restart","expedition");time.sleep(1)
            assert inventory(b2,tokens[1])["structure"]["amount"]==before+1
            after=snapshot.capture(target,folder/"settled")
            diff=snapshot.reconcile(folder/"frozen",folder/"settled")
            assert len(diff)==2 and all(row["operation"]=="expedition_result" for row in diff)
            old_code="""import json,sqlite3,tempfile,zipfile,server
from pathlib import Path
with tempfile.TemporaryDirectory() as temp:
 p=Path(temp)/'old.sqlite'
 with zipfile.ZipFile('/bundle/player-profiles.zip') as z:p.write_bytes(z.read('player.sqlite'))
 old=server.VERSION
 try:server.initialize(p)
 except ValueError as exc:assert 'unsupported' in str(exc)
 else:raise RuntimeError('old binary accepted newer database')
 p=Path(temp)/'compatible.sqlite';server.initialize(p);a=server.login(p,{'name':'rollback_old','password':'local-old-test'},True)
 backup=p.with_suffix('.snapshot');server.snapshot(p,backup);p.unlink();server.snapshot(backup,p,True)
 assert server.login(p,{'name':'rollback_old','password':'local-old-test'},False)['account']['id']==a['account']['id']
 print('ROLLBACK_OLD_BINARY_PASS schema',old,'rejected new DB; booted matching backup')
"""
            msg=snapshot.docker("run","--rm","--network","none","--mount",f"type=bind,source={folder/'frozen'},target=/bundle,readonly","--entrypoint","python",args.previous_image,"-c",old_code)
            print(msg,flush=True)
            print("DRILL_RESTORE_PASS revoked old login, retained paint and camp owner, A resumed position, B delivered +1 exactly once, both locks released. Later receipts:",diff,flush=True)
            (path/"drill.json").write_text(json.dumps(dict(schema=manifest["schema"],volumes=manifest["volumes"],earlier=manifest["receipt_count"],later=after["receipt_count"],delta=diff,previous_image=args.previous_image),indent=2),encoding="utf8")
        finally:
            if live and live.poll() is None:live.terminate();live.wait(10)
            for p in (source,target):compose(p,"down","--volumes")

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--previous-image",required=True);p.add_argument("--output",required=True);run(p.parse_args())

