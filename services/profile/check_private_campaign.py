"""Run the private campaign through Godot controls and reconcile its read-only receipt history."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import tempfile

from check_live_expedition import free_port
from check_profile import wait_ready

ROOT=Path(__file__).resolve().parents[2]


def encode(frames,output):
    ffmpeg=shutil.which("ffmpeg")
    if not ffmpeg:
        import imageio_ffmpeg
        ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run([ffmpeg,"-hide_banner","-loglevel","error","-y","-framerate","2","-i",str(frames/"%06d.jpg"),
                    "-c:v","libx264","-pix_fmt","yuv420p","-crf","25","-movflags","+faststart",str(output)],check=True)
    return ffmpeg


def package(output,frames):
    with tempfile.TemporaryDirectory(dir=output) as folder:
        tmp=Path(folder)
        encode(frames/"a",tmp/"setup.mp4")
        exe=encode(frames/"b",tmp/"rounds.mp4")
        listing=tmp/"clips.txt"
        listing.write_text("file 'setup.mp4'\nfile 'rounds.mp4'\n",encoding="ascii")
        subprocess.run([exe,"-hide_banner","-loglevel","error","-y","-f","concat","-safe","1","-i",str(listing),
            "-c","copy","-movflags","+faststart",str(output/"private-campaign.mp4")],check=True)
    encode(frames/"relief",output/"depleted-recovery.mp4")


def audit(project,output):
    def identity(log,pattern):
        return re.search(pattern,(output/log).read_text(encoding="utf-8-sig")).group(1)
    robot=identity("two-rounds.log",r"PRIVATE_CAMPAIGN_PASS ([a-f0-9]{32})")
    rescue=identity("relief.log",r"RELIEF_CAMPAIGN_PASS ([a-f0-9]{32})")
    script=Path(__file__).with_name("audit_private_campaign.py").read_text(encoding="utf-8-sig")
    report=subprocess.check_output(["docker","compose","-p",project,"exec","-T","profile","python","-","/data/player.sqlite",robot,rescue],
                                   input=script,cwd=ROOT,text=True,encoding="utf8")
    data=json.loads(report)
    (output/"ledger.json").write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf8")
    print("PRIVATE_CAMPAIGN_LEDGER_PASS",robot,"claims/repair/physical drill/second deployment and one rescue voucher",flush=True)


def run(executable,output):
    output.mkdir(parents=True,exist_ok=True)
    project="m14-campaign-"+secrets.token_hex(4)
    http=free_port(socket.SOCK_STREAM); udp=free_port(socket.SOCK_DGRAM)
    env=dict(os.environ,PROFILE_HOST_PORT=str(http),SOLO_HOST_PORT=str(udp),SOLO_PORT=str(udp),PROFILE_URL=f"http://127.0.0.1:{http}")
    def compose(*args):
        subprocess.run(["docker","compose","-p",project,*args],env=env,cwd=ROOT,check=True)
    with tempfile.TemporaryDirectory(prefix="campaign-") as folder:
        frames=Path(folder)
        def client(script,name,secret,path,log,timeout):
            framepath=frames/path
            framepath.mkdir()
            with (output/log).open("w",encoding="utf8") as target:
                subprocess.run([executable,"--path",str(ROOT/"game"),"--max-fps","30","--script","res://campaign/tests/"+script+".gd"],
                    env=dict(env,CAMPAIGN_LOGIN=name,CAMPAIGN_PASSWORD=secret,CAMPAIGN_FRAMES=str(framepath),CAMPAIGN_EVIDENCE=str(output)),
                    stdout=target,stderr=subprocess.STDOUT,check=True,timeout=timeout)
        try:
            compose("up","-d","--build","profile","expedition")
            wait_ready(env["PROFILE_URL"])
            name="campaign_"+secrets.token_hex(4); secret=secrets.token_urlsafe()
            client("setup",name,secret,"a","setup.log",90)
            with ThreadPoolExecutor(2) as pool:
                rescue=pool.submit(client,"relief","rescue_"+secrets.token_hex(4),secrets.token_urlsafe(),"relief","relief.log",100)
                rounds=pool.submit(client,"two_rounds",name,secret,"b","two-rounds.log",1100)
                rescue.result();rounds.result()
            audit(project,output)
            package(output,frames)
        finally:compose("down","--volumes")

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--output",required=True)
    a=p.parse_args();run(a.godot,Path(a.output).resolve())
