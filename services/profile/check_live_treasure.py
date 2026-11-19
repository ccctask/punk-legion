"""Two real simultaneous M24 rooms, five Godot clients, UI confirmations, video and five-volume restore."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import math
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

from check_profile import api,ok,wait_ready
from check_live_expedition import free_port
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/operations"))
import snapshot


def json_if(path):
    try:return json.loads(path.read_bytes())
    except (OSError,ValueError):return {}


def until(fn,seconds=25):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        result=fn()
        if result:return result
        time.sleep(.08)
    raise AssertionError("timed out at "+str(fn))


def p95(values):
    return round(sorted(values)[math.ceil(.95*len(values))-1],2) if values else None


def run(args):
    out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
    source="m24-live-"+secrets.token_hex(4);target=source+"-restored"
    epoch=int(time.time())-12
    def settings():
        return dict(os.environ,PROFILE_HOST_PORT=str(free_port(socket.SOCK_STREAM)),TREASURE_HOST_PORT=str(free_port(socket.SOCK_DGRAM)),TREASURE_EPOCH=str(epoch))
    envs={source:settings(),target:settings()}
    def compose(project,*actions):
        return subprocess.check_output(["docker","compose","-p",project,*actions],env=envs[project],cwd=ROOT,stderr=subprocess.STDOUT,text=True,encoding="utf8",errors="replace")
    base="http://127.0.0.1:"+envs[source]["PROFILE_HOST_PORT"]
    other="http://127.0.0.1:"+envs[target]["PROFILE_HOST_PORT"]
    with tempfile.TemporaryDirectory(prefix="m24-live-") as tmp:
        folder=Path(tmp);frames=folder/"video";frames.mkdir()
        peers=[];logs=[];counter=[0]*5;timings=[];combat_http=[];rtt=[];stop=threading.Event();ids=[];tokens=[];creds=[]
        def request(i,route,body=None,url=base):
            t=time.perf_counter()
            status,data=api(url,route,body,tokens[i])
            timings.append((time.perf_counter()-t)*1000)
            assert status==200,(route,status,data.get("error"))
            return data
        def directory(i):return folder/str(i)
        def state(i):return json_if(directory(i)/"state.json")
        def waitstate(i,fn,secs=25):
            try:return until(lambda:(s if fn(s:=state(i)) else None),secs)
            except AssertionError as e:
                s=state(i)
                raise AssertionError(("state",i,{k:s.get(k) for k in ("lobby_phase","lobby_ready","rendered","message","tick","outcome","seq")},peers[i].poll())) from e
        def order(i,action,**data):
            idx=counter[i];counter[i]+=1
            root=directory(i)
            path=root/("order"+str(idx)+".json");temp=path.with_suffix(".tmp")
            temp.write_text(json.dumps(dict(action=action,**data)));os.replace(temp,path)
            if action=="quit":return
            reply=until(lambda:json_if(root/("reply"+str(idx)+".json")))
            if "ms" in reply:rtt.append(reply)
            return reply
        def parallel(rows):
            with ThreadPoolExecutor(len(rows)) as executor:
                futures=[executor.submit(order,i,cmd,**fields) for i,cmd,fields in rows]
                return [f.result() for f in futures]
        def pos(s,i):
            return s.get("units",{}).get(ids[i],{}).get("pos",[999,999])
        sides={}
        def home(i):
            return [-7 if sides[i]==0 else 7,0]
        def poll_http():
            while not stop.wait(.3):
                begin=time.perf_counter()
                try:
                    request(0,"/v1/profile")
                    combat_http.append((time.perf_counter()-begin)*1000)
                except Exception as exc:
                    combat_http.append(None)
        try:
            compose(source,"up","-d","--build","profile","treasure")
            wait_ready(base)
            for i in range(5):
                cred=dict(name="cache_live_"+str(i),password=secrets.token_urlsafe())
                row=ok(api(base,"/v1/accounts",cred))
                creds.append(cred);tokens.append(row["token"]);ids.append(row["robots"][0]["id"])
            request(0,"/v1/friends/request",{"friend":creds[2]["name"]});request(2,"/v1/friends/accept",{"friend":creds[0]["name"]})
            for i in range(5):
                directory(i).mkdir()
                visual=args.video and i==0
                opts=["--resolution","960x540","--max-fps","30","--audio-driver","Dummy"] if visual else ["--headless"]
                f=(out/("peer"+str(i)+".log")).open("w",encoding="utf8");logs.append(f)
                p=subprocess.Popen([args.godot,*opts,"--path",str(ROOT/"game"),"--script","res://treasure/tests/live_peer.gd"],
                    stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,PROFILE_URL=base,TREASURE_PORT=envs[source]["TREASURE_HOST_PORT"],
                    TEST_TOKEN=tokens[i],TREASURE_PEER_DIR=str(directory(i)),TREASURE_FRAMES=str(frames) if visual else ""))
                peers.append(p)
            for i in range(5):waitstate(i,lambda s:"lobby_phase" in s)
            order(0,"create",friend=creds[2]["name"]);order(1,"create")
            for i in (0,1,2):waitstate(i,lambda s:s.get("lobby_phase")=="forming")
            order(0,"submit")
            waitstate(2,lambda s:s.get("revision",0)>=1)
            order(2,"submit")
            for i in (0,2,1):order(i,"confirm")
            for i in (0,1,2):waitstate(i,lambda s:"units" in s)
            parallel([(i,"create",{}) for i in (3,4)])
            for i in (3,4):waitstate(i,lambda s:s.get("lobby_phase")=="forming")
            parallel([(i,"confirm",{}) for i in (3,4)])
            for i in (3,4):waitstate(i,lambda s:"units" in s)
            initial=[waitstate(i,lambda s:"units" in s) for i in range(5)]
            sides.update({i:int(s["side"]) for i,s in enumerate(initial)})
            battles={s["id"] for s in initial}
            assert len(battles)==2
            print("TREASURE_UI_ENTER 5 clients via map; premade 2 vs solo; solo vs solo; 2 concurrent battle IDs",flush=True)
            worker=threading.Thread(target=poll_http,daemon=True);worker.start()
            moving=(0,1,3,4)
            for _ in range(args.hold_samples):
                parallel([(i,"move",{"pos":home(i)}) for i in moving])
                time.sleep(.4)
            parallel([(i,"move",{"pos":[0,0]}) for i in moving])
            for i in moving:waitstate(i,lambda s,i=i:math.dist(pos(s,i),[0,0])<1.5)
            replies=parallel([(i,"take",{"item":"crate0"}) for i in moving])
            for pair in (replies[:2],replies[2:]):assert sorted(r["error"] for r in pair)==["","item_taken"],pair
            winners=[i for i,r in zip(moving,replies) if not r["error"]]
            waitstate(0,lambda s:any(u["hp"]<u["max_hp"] for u in s.get("units",{}).values()))
            parallel([(i,"move",{"pos":home(i)}) for i in moving])
            for i in moving:waitstate(i,lambda s,i=i:math.dist(pos(s,i),home(i))<1.8)
            winner_a,winner_b=winners
            assert not order(winner_a,"extract")["error"]
            extracted=waitstate(winner_a,lambda s:s.get("outcome")=="extracted")["receipt"]
            assert extracted["cargo"]==["crate0"]
            admissions=[request(i,"/v1/treasure")["treasure"].get("admission") for i in range(5)]
            bstate=waitstate(winner_b,lambda s:s.get("items",{}).get("crate0",{}).get("bearer")==s.get("owner","no-seat"))
            stop.set();worker.join()
            print("TREASURE_PAIR_RACE both rooms 1 winner/1 collision; real enemy hit; A extracted, B still carrying",flush=True)
            snap=snapshot.capture(source,folder/"snapshot")
            assert snap["services"]["treasure"]["running"] and len(snap["volumes"])==5
            wait_ready(base)
            for i in range(5):
                if i==winner_a:continue
                order(i,"reconnect")
                waitstate(i,lambda s,i=i:s.get("id")==admissions[i]["id"] and s.get("seq",0)>=0)
            # Fresh project uses the same five persistent volumes with a new room key and player sessions.
            compose(target,"create","--build","profile","treasure");snapshot.restore(target,folder/"snapshot")
            compose(target,"start","profile","treasure");wait_ready(other)
            rtokens=[ok(api(other,"/v1/sessions",c))["token"] for c in creds]
            def remote(i,route):return ok(api(other,route,token=rtokens[i]))
            assert remote(winner_a,"/v1/treasure")["treasure"]["last"]==extracted
            # Reuse one real client on a new port to take the restored in-progress seat.
            rp=folder/"restored";rp.mkdir()
            f=(out/"restored-peer.log").open("w",encoding="utf8");logs.append(f)
            restored=subprocess.Popen([args.godot,"--headless","--path",str(ROOT/"game"),"--script","res://treasure/tests/live_peer.gd"],
                stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,PROFILE_URL=other,TREASURE_PORT=envs[target]["TREASURE_HOST_PORT"],
                    TEST_TOKEN=rtokens[winner_b],TREASURE_PEER_DIR=str(rp),TREASURE_FRAMES=""))
            peers.append(restored)
            rs=until(lambda:(s if (s:=json_if(rp/"state.json")).get("id")==bstate["id"] else None))
            assert rs["items"]["crate0"]["bearer"]==bstate["owner"] and math.dist(pos(rs,winner_b),home(winner_b))<2.2
            (rp/"order0.json").write_text(json.dumps({"action":"extract"}))
            rr=until(lambda:json_if(rp/"reply0.json"))
            assert not rr["error"]
            restored_receipt=until(lambda:remote(winner_b,"/v1/treasure")["treasure"]["last"])
            assert restored_receipt["cargo"]==["crate0"]
            compose(target,"restart","profile","treasure");wait_ready(other)
            assert remote(winner_b,"/v1/treasure")["treasure"]["last"]==restored_receipt
            assert remote(winner_a,"/v1/treasure")["treasure"]["last"]==extracted
            remaining=[i for i in range(5) if i!=winner_a]
            parallel([(i,"extract",{}) for i in remaining])
            for i in range(5):
                result=request(i,"/v1/treasure")["treasure"]["last"]
                assert result and result["outcome"]=="extracted" and len(result["cargo"])==int(i in winners)
                assert request(i,"/v1/profile")["robots"][0]["task"] is None
            for i in range(5):order(i,"quit")
            (rp/"order1.json").write_text('{"action":"quit"}')
            if args.video:
                import imageio_ffmpeg
                subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),"-y","-loglevel","error","-framerate","5","-i",str(frames/"%05d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"treasure-live.mp4")],check=True)
            report=dict(rooms=len(battles),clients=5,clock_step_ms=250,success_unique_cargo=2,seat_outcomes=5,
                profile_http_samples=len(timings),profile_http_p95_ms=p95(timings),ack={k:dict(samples=len(samples),p95_ms=p95(samples)) for k in ("move","take","extract") if (samples:=[r["ms"] for r in rtt if r["action"]==k])},
                concurrent_profile_samples=len(combat_http),concurrent_profile_errors=combat_http.count(None),
                concurrent_profile_p95_ms=p95([v for v in combat_http if v is not None]),
                restored_case="One extracted account and one active carrier in a simultaneous two-room snapshot; both receipts unchanged after restart.",
                frames=len(list(frames.glob("*.png"))),details=rtt)
            (out/"live.json").write_text(json.dumps(report,indent=2),encoding="utf8")
            print("TREASURE_LIVE_PASS",json.dumps(report,ensure_ascii=True),flush=True)
        finally:
            stop.set()
            for p in peers:
                if p.poll() is None:p.terminate()
            for p in peers:p.wait(10)
            for f in logs:f.close()
            for project in (source,target):compose(project,"down","--volumes")

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--output",required=True);p.add_argument("--video",action="store_true");p.add_argument("--hold-samples",type=int,default=0);run(p.parse_args())
