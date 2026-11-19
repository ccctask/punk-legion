"""Live ENet verification against two accounts in an isolated pair of Compose services."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
import json
from pathlib import Path
import secrets
import socket
import subprocess
import shutil
import tempfile
import time
from check_profile import api,ok,wait_ready


def free_port(protocol):
    with socket.socket(type=protocol) as sock:
        sock.bind(("127.0.0.1",0))
        return sock.getsockname()[1]


def run(godot,rounds,capture,outage=False,video=None):
    root=Path(__file__).resolve().parents[2]
    project="solo-test-"+secrets.token_hex(5)
    port=free_port(socket.SOCK_DGRAM)
    http=free_port(socket.SOCK_STREAM)
    env=dict(os.environ,SOLO_HOST_PORT=str(port),PROFILE_HOST_PORT=str(http),SOLO_PORT=str(port))
    base=f"http://127.0.0.1:{http}"
    frozen=tempfile.TemporaryDirectory(prefix="solo-client-")
    game=Path(frozen.name)/"game"
    shutil.copytree(root/"game",game,ignore=shutil.ignore_patterns("*.apk","*.aab"))
    def compose(*args):
        subprocess.run(["docker","compose","-p",project,*args],cwd=root,env=env,check=True)
    def output(*args):
        return subprocess.check_output(["docker","compose","-p",project,*args],cwd=root,env=env,text=True,encoding="utf-8")
    def interrupt_profile(owner):
        end=time.monotonic()+75
        while True:
            query="import json,glob,sqlite3; c=sqlite3.connect('/data/player.sqlite'); r=c.execute('SELECT id FROM expeditions WHERE owner=? AND result IS NULL',('"+owner+"',)).fetchone(); files=glob.glob('/run/solo-missions/'+r[0]+'.progress.json') if r else []; print(json.load(open(files[0]))['seconds'] if files else 0)"
            try:
                seconds=float(output("exec","-T","profile","python","-c",query).strip())
            except (subprocess.CalledProcessError,ValueError):
                seconds=0
            if seconds>12:
                break
            assert time.monotonic()<end
            time.sleep(2)
        mission=output("exec","-T","profile","python","-c","import sqlite3;print(sqlite3.connect('/data/player.sqlite').execute('SELECT id FROM expeditions WHERE owner=? AND result IS NULL',('"+owner+"',)).fetchone()[0])").strip()
        compose("stop","profile")
        deadline=time.monotonic()+280
        while True:
            try:
                result=json.loads(output("exec","-T","expedition","sh","-c","test ! -f /var/lib/punk-room/"+mission+".result.json || cat /var/lib/punk-room/"+mission+".result.json"))
                break
            except json.JSONDecodeError:
                assert time.monotonic()<deadline
                time.sleep(3)
        assert result["result"]["outcome"]=="win"
        # Set only this disposable mission's lease to its actual finish second.
        # On reopening the DB the expiry sweep will execute before the room's retry.
        adjust="import sqlite3; c=sqlite3.connect('/data/player.sqlite'); c.execute('UPDATE expeditions SET expires=? WHERE id=?',("+str(int(result["finished_at"]))+",'"+mission+"'));c.commit()"
        compose("run","--rm","--no-deps","profile","python","-c",adjust)
        compose("start","profile")
        wait_ready(base)
        print("PERSISTED_WIN_BEFORE_TTL",mission,flush=True)
    def client(outcome):
        credentials={"name":"solo_"+secrets.token_hex(5),"password":secrets.token_urlsafe()}
        user=ok(api(base,"/v1/accounts",credentials))
        token=user["token"]
        chassis=user["robots"][0]["id"]
        if outcome=="win" and rounds>1:
            # Create a line from the normal base and manufacture the actual machine used by this campaign.
            layout=ok(api(base,"/v1/base",token=token))["base"]
            ok(api(base,"/v1/base/edit",{"revision":layout["revision"],"key":"build_foundry","action":"build","kind":"foundry","x":3,"y":2},token))
            design=ok(api(base,"/v1/workshop/design",{"key":"save_pattern","name":"轨道侦察型","version":1,"slots":{"core":"boiler","head":"eye","weapon":"cannon"}},token))["receipt"]["design"]
            chassis=ok(api(base,"/v1/workshop/build",{"key":"make_scout","design":design,"name":"条纹发条"},token))["receipt"]["robot"]
        actual_rounds=rounds if outcome=="win" else 1
        rare_seen=False
        for n in range(actual_rounds):
            local=dict(env,PROFILE_URL=base,SOLO_EXPECT=outcome,SOLO_LOGIN=credentials["name"],SOLO_PASSWORD=credentials["password"],
                       SOLO_ROBOT=chassis,SOLO_BRANCH="fuel" if n==1 else "scrap")
            command=[godot,"--path",str(game),"--script","res://expedition/tests/solo_ui.gd"]
            if (capture or video) and n==0 and outcome=="win":
                if capture:
                    local["SOLO_CAPTURE"]=str(Path(capture).resolve())
                if video:
                    frames=Path(frozen.name)/"frames"
                    frames.mkdir()
                    local["SOLO_FRAMES"]=str(frames)
            else:
                command.insert(1,"--headless")
            if outage and outcome=="win" and n==0:
                with ThreadPoolExecutor(1) as monitor:
                    pending=monitor.submit(interrupt_profile,user["account"]["id"])
                    subprocess.run(command,cwd=root,env=local,timeout=320,check=True)
                    pending.result()
            else:
                subprocess.run(command,cwd=root,env=local,timeout=320,check=True)
            if video and n==0 and outcome=="win":
                encoder=shutil.which("ffmpeg")
                if not encoder:
                    import imageio_ffmpeg
                    encoder=imageio_ffmpeg.get_ffmpeg_exe()
                subprocess.run([encoder,"-hide_banner","-loglevel","error","-y","-framerate","6","-i",str(frames/"%06d.jpg"),
                    "-c:v","libx264","-crf","25","-pix_fmt","yuv420p","-movflags","+faststart",str(Path(video).resolve())],check=True)
            token=ok(api(base,"/v1/sessions",credentials))["token"]
            saved=ok(api(base,"/v1/expedition",token=token))["expedition"]
            result=saved["last"]
            assert saved["active"] is None and result["outcome"]==outcome
            assert ok(api(base,"/v1/robots/"+chassis+"/history",token=token))["history"]["totals"]["battles"]==n+1
            if outcome=="win":
                assert 180<=result["seconds"]<=300
                if n==0:
                    assert result["part"]["definition"]=="drill"
                rare_seen |= result["rare"]
            print("CAMPAIGN",n+1,outcome,result["seconds"],result["part"],flush=True)
            if n+1<actual_rounds:
                path="/v1/robots/"+chassis+"/recovery"
                if ok(api(base,path,token=token))["recovery"]["state"]=="damaged":
                    ok(api(base,path+"/repair",{"key":secrets.token_hex(8)},token))
                    end=time.monotonic()+40
                    while ok(api(base,path,token=token))["recovery"]["state"]!="ready":
                        assert time.monotonic()<end
                        time.sleep(1)
                item=result["part"]
                slot="core" if item["definition"]=="reinforced_boiler" else "weapon"
                robot=next(r for r in ok(api(base,"/v1/workshop",token=token))["workshop"]["robots"] if r["id"]==chassis)
                ok(api(base,"/v1/workshop/refit",{"key":secrets.token_hex(8),"robot":chassis,"slot":slot,"item":item["id"],"expected":robot["slots"][slot]["id"]},token))
        if outcome=="win" and rounds>=3:
            assert rare_seen
        return saved["last"]["id"]
    try:
        compose("up","-d","--build","expedition","profile")
        wait_ready(base)
        with ThreadPoolExecutor(2) as pool:
            ids=list(pool.map(client,["win","retreat"]))
        assert len(set(ids))==2
        print("LIVE_SOLO_PASS private missions, reconnect, extraction, retreat, real rewards and robot histories")
    finally:
        compose("logs","--tail","12","expedition","profile")
        compose("down","--volumes")
        frozen.cleanup()
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",required=True)
    parser.add_argument("--rounds",type=int,choices=[1,3],default=1)
    parser.add_argument("--capture")
    parser.add_argument("--outage",action="store_true")
    parser.add_argument("--video")
    args=parser.parse_args()
    run(args.godot,args.rounds,args.capture,args.outage,args.video)
