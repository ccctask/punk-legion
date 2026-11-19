"""Real Godot clients entering M19 from the world map against isolated Compose services."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
from check_profile import api,ok,wait_ready
from check_live_expedition import free_port


def run(godot,evidence=None,paint_check=False,orders_check=False,terr=False):
    root=Path(__file__).resolve().parents[2]
    path=Path(evidence).resolve() if evidence else None
    if path:
        path.mkdir(exist_ok=True,parents=True)
    port=free_port(socket.SOCK_DGRAM)
    http=free_port(socket.SOCK_STREAM)
    base=f"http://127.0.0.1:{http}"
    env=dict(os.environ,CAMP_HOST_PORT=str(port),CAMP_PORT=str(port),PROFILE_HOST_PORT=str(http),PROFILE_URL=base)
    with tempfile.TemporaryDirectory() as tmp:
        folder=Path(tmp)
        game=folder/"game"
        shutil.copytree(root/"game",game,ignore=shutil.ignore_patterns("*.apk","*.aab"))
        config=folder/"conf"
        config.mkdir()
        dat=json.loads((root/"services/profile/config/calendar.json").read_text(encoding="utf8"))
        for node in dat["nodes"]:
            if node["type"]=="camp" and (terr or node["id"]=="brass-yard"):
                node["daily"]=[[0,86400,86400]]
        (config/"calendar.json").write_text(json.dumps(dat),encoding="utf8")
        override=folder/"override.json"
        override.write_text(json.dumps({"services":{"profile":{"volumes":[{"type":"bind","source":str(config),"target":"/etc/punk/world","read_only":True}]}}}))
        args=["docker","compose","-p","camp-test-"+secrets.token_hex(5),"-f",str(root/"compose.yaml"),"-f",str(override)]
        def compose(*cmd):
            subprocess.run([*args,*cmd],cwd=root,env=env,check=True)
        def crash_live_room():
            query=("import glob,json; rows=[json.load(open(f)) for f in glob.glob('/run/camp/*.progress.json')]; "
                   "print(max([x['seconds'] for x in rows]+[0]))")
            deadline=time.monotonic()+35
            while True:
                raw=subprocess.check_output([*args,"exec","-T","profile","python","-c",query],cwd=root,env=env,text=True)
                elapsed=float(raw.strip())
                if elapsed>=1:
                    break
                assert time.monotonic()<deadline
                time.sleep(0.2)
            compose("kill","-s","SIGKILL","camp")
            compose("start","camp")
            print("CAMP_CRASH_AFTER_ACTIVE_CHECKPOINT",elapsed,flush=True)
        def client(who,mode,site="brass-yard"):
            opts=dict(env,CAMP_NODE=site,CAMP_LOGIN=who["name"],CAMP_PASSWORD=who["password"],CAMP_ACTION=mode)
            if orders_check and mode in ("neutral","attacker","defender"):opts["CAMP_EXPECT_ROLE"]="support"
            if paint_check and mode in ("attacker","defender"):
                opts["CAMP_EXPECT_MINT"]=br
            args=[godot,"--path",str(game),"--script","res://camp/tests/contest_ui.gd"]
            if path and mode in ("neutral","attacker","defender","takeover"):
                opts["CAMP_CAPTURE"]=str(path/((site+"-" if terr else "")+mode+".png"))
                if mode=="attacker":
                    frames=folder/"frames"
                    frames.mkdir()
                    opts["CAMP_FRAMES"]=str(frames)
            else:
                args.insert(1,"--headless")
            subprocess.run(args,env=opts,check=True,timeout=115)
        def encode_frames():
            encoder=shutil.which("ffmpeg")
            if not encoder:
                import imageio_ffmpeg
                encoder=imageio_ffmpeg.get_ffmpeg_exe()
            subprocess.run([encoder,"-hide_banner","-loglevel","error","-y","-framerate","6","-i",str(folder/"frames/%06d.jpg"),"-c:v","libx264","-crf","26","-pix_fmt","yuv420p","-movflags","+faststart",str(path/"live-attack.mp4")],check=True)
        def session(who):
            return ok(api(base,"/v1/sessions",who))["token"]
        def fetch(who,route):
            return ok(api(base,route,token=session(who)))
        def register():
            credentials={"name":"camp_"+secrets.token_hex(5),"password":secrets.token_urlsafe()}
            user=ok(api(base,"/v1/accounts",credentials))
            return credentials,user["robots"][0]["id"]
        def repair_if_needed(who,rid):
            token=session(who)
            route="/v1/robots/"+rid+"/recovery"
            if ok(api(base,route,token=token))["recovery"]["state"]=="damaged":
                ok(api(base,route+"/repair",{"key":secrets.token_hex(9)},token))
                limit=time.monotonic()+45
                while ok(api(base,route,token=token))["recovery"]["state"]!="ready":
                    assert time.monotonic()<limit
                    time.sleep(1)
        def ensure_guard(who,rid):
            repair_if_needed(who,rid)
            client(who,"station")
        try:
            compose("up","-d","--build","camp","profile")
            wait_ready(base)
            a,ar=register()
            b,br=register()
            c,cr=register()
            if terr:
                brass,coil="brass-yard","coil-depot"
                def estate(who,node):
                    return fetch(who,"/v1/camp/"+node)["camp"]
                with ThreadPoolExecutor(2) as pool:
                    waves=[pool.submit(client,who,"neutral",node) for who,node in ((a,brass),(b,coil))]
                    for wave in waves:wave.result()
                assert estate(a,brass)["mine"] and estate(b,coil)["mine"]
                repair_if_needed(b,br)
                client(b,"station",coil)
                with ThreadPoolExecutor(2) as pool:
                    defend=pool.submit(client,b,"defender",coil)
                    attack=pool.submit(client,c,"attacker",coil)
                    crash_live_room()
                    defend.result()
                    attack.result()
                assert estate(b,coil)["mine"] and estate(a,brass)["mine"]
                client(b,"release",coil)
                repair_if_needed(a,ar)
                client(a,"takeover",coil)
                assert estate(a,coil)["mine"] and estate(a,brass)["mine"]
                if path:
                    encode_frames()
                print("TWO_REAL_CAMPS_PASS two concurrent neutral captures, distinct owners, coil real turret and live defense, restart/rejoin, local transfer to dual owner",flush=True)
                return
            if orders_check:
                for who,rid in ((a,ar),(b,br)):
                    ok(api(base,"/v1/workshop/orders",dict(key=secrets.token_hex(8),robot=rid,
                        orders=dict(role="support",guard="",distance="weapon",priority="nearest",retreat=0)),session(who)))
            if paint_check:
                token=session(b)
                def post(route,body):
                    return ok(api(base,route,body,token))
                initial=post("/v1/workshop/deployment",dict(robots=[br]))["deployment"]
                oid=post("/v1/store/order",dict(sku="paint_mint",key="mint_camp"))["order"]
                post("/v1/store/simulate",dict(order=oid,result="success"))
                post("/v1/store/equip",dict(robot=br,paint="mint"))
                painted=post("/v1/workshop/deployment",dict(robots=[br]))["deployment"]
                assert painted["paints"][br]=="mint"
                assert all(initial[k]==painted[k] for k in ("units","inventory","points"))
            before=fetch(a,"/v1/camp")["camp"]
            assert not before["owner"]
            client(a,"neutral")
            assert fetch(a,"/v1/camp")["camp"]["mine"]
            ensure_guard(a,ar)
            client(c,"absent")
            assert fetch(c,"/v1/camp")["camp"]["last"]["winner"]=="defender"
            ensure_guard(a,ar)
            with ThreadPoolExecutor(2) as pool:
                x=pool.submit(client,a,"defender")
                y=pool.submit(client,b,"attacker")
                crash_live_room()
                x.result()
                y.result()
            for who in (a,b,c):
                state=fetch(who,"/v1/camp")["camp"]
                assert not state["active"]
                print("REAL_CAMP_ACCOUNT",who["name"],state["mine"],state["last"],flush=True)
            client(a,"release")
            owned=fetch(a,"/v1/inventory")["inventory"]
            repair_if_needed(b,br)
            client(b,"takeover")
            assert fetch(b,"/v1/camp")["camp"]["mine"] and not fetch(a,"/v1/camp")["camp"]["mine"]
            retained=fetch(a,"/v1/inventory")["inventory"]
            assert all(owned[k]==retained[k] for k in ("stock","blueprints","parts"))
            print("REAL_CAMP_ABSENT_TRANSFER zero enemies, revision 2, former owner's warehouse/parts/blueprints unchanged")
            if path:
                encode_frames()
            print("LIVE_CAMP_PASS 3 sessions, neutral occupation, real turret garrison, absent defense, 2 live windows, container restart, receipts")
        finally:
            compose("logs","--tail","18","camp","profile")
            compose("down","--volumes")
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",required=True)
    parser.add_argument("--evidence")
    parser.add_argument("--paint-check",action="store_true")
    parser.add_argument("--territories",action="store_true")
    parser.add_argument("--orders-check",action="store_true")
    args=parser.parse_args()
    run(args.godot,args.evidence,args.paint_check,args.orders_check,args.territories)
