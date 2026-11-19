"""Run independent Godot clients through the ordinary invite UI against an isolated room."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import json
import workshop
from check_profile import api,ok,wait_ready

def run(args):
    root=Path(__file__).resolve().parents[2]
    wait_ready(args.profile)
    records=[]
    with tempfile.TemporaryDirectory(prefix="punk-party-invite-") as rendezvous:
        game=root/"game"
        if args.video:
            game=Path(rendezvous)/"game"
            shutil.copytree(root/"game",game)
        for seat in range(args.size):
            login={"name":"pve_"+secrets.token_hex(5),"password":secrets.token_urlsafe()}
            user=ok(api(args.profile,"/v1/accounts",login))
            robot=user["robots"][0]["id"]
            ok(api(args.profile,"/v1/robots/"+robot+"/rename",{"name":["黄铜领航","青柠先锋","蓝莓工兵"][seat]},user["token"]))
            other=""
            if args.twice:
                def op(action,**fields):
                    return ok(api(args.profile,"/v1/workshop/"+action,dict(key=secrets.token_hex(12),**fields),user["token"]))["receipt"]
                draft=op("design",name="替补轻机",version=1,slots=workshop.BASE)
                other=op("build",design=draft["design"],name="预备机")["robot"]
            records.append((seat,login,robot,other))
        def play(row):
            seat,login,robot,other=row
            env=dict(os.environ,PROFILE_URL=args.profile,PARTY_PORT=str(args.port),PARTY_INVITE=str(Path(rendezvous)/"invite"),
                     SOLO_EXPECT="win",SOLO_LOGIN=login["name"],SOLO_PASSWORD=login["password"],SOLO_ROBOT=robot,PARTY_ROLE=str(seat),PARTY_SIZE=str(args.size),PARTY_SECOND_ROBOT=other)
            command=[args.godot,"--path",str(game),"--max-fps","30","--script","res://party/tests/party_ui.gd"]
            if args.video:
                frames=Path(rendezvous)/("view"+str(seat))
                frames.mkdir()
                env["PARTY_FRAMES"]=str(frames)
            else:
                command.insert(1,"--headless")
            subprocess.run(command,env=env,check=True,timeout=680 if args.twice else 350)
            who=ok(api(args.profile,"/v1/sessions",login))["token"]
            state=ok(api(args.profile,"/v1/party",token=who))["party"]
            history=ok(api(args.profile,"/v1/robots/"+robot+"/history",token=who))["history"]
            assert not state["roomscope"] and state["last"]["outcome"]=="win" and history["totals"]["battles"]==1
            if args.twice:
                second=ok(api(args.profile,"/v1/robots/"+other+"/history",token=who))["history"]
                assert second["totals"]["battles"]==1 and not state["continuation"]
                if args.evidence:
                    Path(args.evidence).mkdir(parents=True,exist_ok=True)
                    (Path(args.evidence)/f"seat-{seat}.json").write_text(json.dumps({"first":history,"second":second,"last":state["last"]},indent=2,ensure_ascii=False),encoding="utf8")
            return (seat,state["last"]["id"],state["last"]["seconds"],history["totals"])
        with ThreadPoolExecutor(args.size) as pool: result=list(pool.map(play,records))
        if args.video:
            import imageio_ffmpeg
            encoder=shutil.which("ffmpeg") or imageio_ffmpeg.get_ffmpeg_exe()
            command=[encoder,"-loglevel","error","-y"]
            for seat in range(args.size):
                command+=["-framerate","6","-i",str(Path(rendezvous)/("view"+str(seat))/"%06d.jpg")]
            scale=";".join(f"[{i}:v]scale=640:360[v{i}]" for i in range(args.size))
            layout="".join(f"[v{i}]" for i in range(args.size))+f"hstack=inputs={args.size}:shortest=1"
            command+=["-filter_complex",scale+";"+layout,"-c:v","libx264","-crf","23","-pix_fmt","yuv420p","-movflags","+faststart",str(Path(args.video).resolve())]
            subprocess.run(command,check=True)
        assert len({r[1] for r in result})==args.size
        print("LIVE_PARTY_PASS",result,flush=True)

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",required=True)
    parser.add_argument("--profile",required=True)
    parser.add_argument("--port",type=int,required=True)
    parser.add_argument("--video")
    parser.add_argument("--twice",action="store_true")
    parser.add_argument("--evidence")
    parser.add_argument("--size",type=int,choices=[2,3],default=2)
    run(parser.parse_args())
