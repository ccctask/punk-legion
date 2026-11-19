"""M20 normal Godot entry, cooperation by three live accounts; isolated Compose volumes."""
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


def run(godot,evidence):
    root=Path(__file__).resolve().parents[2]
    path=Path(evidence).resolve() if evidence else None
    if path:path.mkdir(exist_ok=True,parents=True)
    udp=free_port(socket.SOCK_DGRAM)
    http=free_port(socket.SOCK_STREAM)
    base=f"http://127.0.0.1:{http}"
    env=dict(os.environ,CAMP_HOST_PORT=str(udp),CAMP_PORT=str(udp),PROFILE_HOST_PORT=str(http),PROFILE_URL=base)
    with tempfile.TemporaryDirectory(prefix="aid-verification-") as temp:
        folder=Path(temp)
        game=folder/"game"
        shutil.copytree(root/"game",game,ignore=shutil.ignore_patterns("*.apk","*.aab"))
        config=folder/"cfg"
        config.mkdir()
        world=json.loads((root/"services/profile/config/calendar.json").read_text(encoding="utf8"))
        world["nodes"][1]["daily"]=[[0,86400,86400]]
        (config/"calendar.json").write_text(json.dumps(world))
        overrides=folder/"override.json"
        overrides.write_text(json.dumps({"services":{"profile":{"volumes":[{"type":"bind","source":str(config),"target":"/etc/punk/world","read_only":True}]}}}))
        args=["docker","compose","-p","aid-test-"+secrets.token_hex(5),"-f",str(root/"compose.yaml"),"-f",str(overrides)]
        def compose(*cmd):
            subprocess.run([*args,*cmd],cwd=root,env=env,check=True)
        def login(user):
            return ok(api(base,"/v1/sessions",user))["token"]
        def new():
            cred={"name":"friend_"+secrets.token_hex(4),"password":secrets.token_urlsafe()}
            result=ok(api(base,"/v1/accounts",cred))
            return cred,result["robots"][0]["id"]
        def app(user,mode,other=None,camp=False,record=False):
            opts=dict(env,CAMP_LOGIN=user["name"],CAMP_PASSWORD=user["password"],CAMP_ACTION=mode,FRIEND_ROLE=mode,FRIEND_NAME=other["name"] if other else "")
            cmd=[godot,"--path",str(game),"--script","res://camp/tests/contest_ui.gd" if camp else "res://friends/tests/social_ui.gd"]
            if path and record:
                sub=folder/mode
                sub.mkdir()
                if camp:
                    opts["CAMP_FRAMES"]=str(sub)
                else:
                    opts.update(FRIEND_FRAMES=str(sub),FRIEND_SHOT=str(path/"aid-defense.png"))
            else:
                cmd.insert(1,"--headless")
            subprocess.run(cmd,env=opts,check=True,timeout=105)
        def repair(user,rid):
            token=login(user)
            route="/v1/robots/"+rid+"/recovery"
            if ok(api(base,route,token=token))["recovery"]["state"]=="damaged":
                ok(api(base,route+"/repair",{"key":secrets.token_hex(8)},token))
                end=time.monotonic()+50
                while ok(api(base,route,token=token))["recovery"]["state"]!="ready":
                    assert time.monotonic()<end
                    time.sleep(1)
        try:
            compose("up","-d","--build","camp","profile")
            wait_ready(base)
            host,hid=new()
            rival,rid=new()
            helper,aid=new()
            app(helper,"request",host)
            app(host,"friends",helper)
            token=login(helper)
            ok(api(base,"/v1/workshop/design",{"key":"real_shared","name":"青铜侦察","version":1,"slots":{"core":"boiler","head":"eye","weapon":"cannon"}},token))
            app(helper,"share",host)
            app(host,"save",helper)
            token=login(host)
            ok(api(base,"/v1/world/admit",{"node":"brass-yard","key":"prep_attack_001"},token))
            app(helper,"offer-attack",host)
            app(host,"accept-aid",helper)
            with ThreadPoolExecutor(2) as clients:
                helper_run=clients.submit(app,helper,"pilot")
                time.sleep(1)
                attack_run=clients.submit(app,host,"neutral",None,True)
                helper_run.result();attack_run.result()
            history="/v1/robots/"+aid+"/history"
            assert ok(api(base,history,token=login(helper)))["history"]["totals"]["battles"]==1
            repair(helper,aid)
            repair(host,hid)
            app(host,"station",None,True)
            app(helper,"offer-defend",host)
            app(host,"accept-aid",helper)
            old=ok(api(base,"/v1/inventory",token=login(host)))["inventory"]["stock"]
            env["CAMP_VIDEO_EPOCH"]=str(round(time.time()*1000))
            with ThreadPoolExecutor(3) as clients:
                ally=clients.submit(app,helper,"pilot",None,False,True)
                defender=clients.submit(app,host,"defender",None,True,True)
                time.sleep(1.5)
                attacker=clients.submit(app,rival,"attacker",None,True,True)
                for client in (ally,defender,attacker):client.result()
            if path:
                encoder=shutil.which("ffmpeg")
                if not encoder:
                    import imageio_ffmpeg
                    encoder=imageio_ffmpeg.get_ffmpeg_exe()
                inputs=[]
                for mode in ("pilot","defender","attacker"):
                    inputs.extend(["-framerate","6","-i",str(folder/mode/"%06d.jpg")])
                layout="[0:v]scale=960:540[p];[1:v]scale=480:270[d];[2:v]scale=480:270[a];[d][a]vstack[r];[p][r]hstack=shortest=1[out]"
                subprocess.run([encoder,"-hide_banner","-loglevel","error","-y",*inputs,"-filter_complex",layout,"-map","[out]","-c:v","libx264","-crf","24","-pix_fmt","yuv420p","-movflags","+faststart",str(path/"friend-defense.mp4")],check=True)
            token=login(helper)
            result=ok(api(base,history,token=token))["history"]
            offers=ok(api(base,"/v1/friends",token=token))["social"]["aids"]
            assert result["totals"]["battles"]==2 and all(x["phase"]=="complete" for x in offers)
            assert ok(api(base,"/v1/inventory",token=login(host)))["inventory"]["stock"]==old
            print("LIVE_AID_PASS consent, visit, definition sharing, attack and three-account defense, return, two own histories; beneficiary stock unchanged")
        finally:
            compose("logs","--tail","12","camp","profile")
            compose("down","--volumes")
if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--godot",required=True)
    cli.add_argument("--evidence")
    args=cli.parse_args()
    run(args.godot,args.evidence)
