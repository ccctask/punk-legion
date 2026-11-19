"""Bounded parallel real ENet expedition journeys on a disposable local Compose deployment."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import math
import os
from pathlib import Path
import platform
import secrets
import shutil
import socket
import subprocess
import tempfile
import threading
import time

from check_profile import api,ok,wait_ready
from check_live_expedition import free_port

ROOT=Path(__file__).resolve().parents[2]


def p95(samples):
    return sorted(samples)[math.ceil(len(samples)*0.95)-1] if samples else None


def run(args):
    project="m22-soak-"+secrets.token_hex(4)
    http,udp=free_port(socket.SOCK_STREAM),free_port(socket.SOCK_DGRAM)
    env={**os.environ,"PROFILE_HOST_PORT":str(http),"SOLO_HOST_PORT":str(udp),"SOLO_PORT":str(udp)}
    base=f"http://127.0.0.1:{http}"
    timings=[]; commands=[]; resource_samples=[]; receipts=[]; errors=[]; active_counts=[];thermal=[]
    stop=threading.Event()
    output=Path(args.output).resolve()
    output.parent.mkdir(parents=True,exist_ok=True)
    def compose(*cmd):
        return subprocess.check_output(["docker","compose","-p",project,*cmd],cwd=ROOT,env=env,stderr=subprocess.STDOUT,encoding="utf8",errors="replace")
    def request(route,token,body=None):
        begin=time.perf_counter()
        data=ok(api(base,route,body,token))
        timings.append((time.perf_counter()-begin)*1000)
        return data
    def monitor():
        while not stop.is_set():
            result=subprocess.run(["docker","stats","--no-stream","--format","{{json .}}",project+"-profile-1",project+"-expedition-1"],
                                  stdout=subprocess.PIPE,text=True,encoding="utf8",errors="replace")
            if result.returncode==0:
                for line in result.stdout.splitlines():
                    resource_samples.append(json.loads(line))
            counts=compose("exec","-T","profile","python","-c",
                "import sqlite3;c=sqlite3.connect('/data/player.sqlite');print(c.execute('SELECT COUNT(*) FROM expeditions WHERE result IS NULL').fetchone()[0] if c.execute(\"SELECT 1 FROM sqlite_master WHERE name='expeditions'\").fetchone() else 0)")
            active_counts.append(int(counts))
            if os.name=="nt":
                measure=subprocess.run(["powershell","-NoProfile","-Command",
                    "Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -OperationTimeoutSec 3 -ErrorAction SilentlyContinue | ForEach-Object { [Console]::WriteLine($_.CurrentTemperature) }"],
                    stdout=subprocess.PIPE,text=True,timeout=12)
                thermal.extend(round(int(v)/10-273.15,1) for v in measure.stdout.split() if v.isdigit())
            stop.wait(8)
    with tempfile.TemporaryDirectory(prefix="m22-soak-") as tmp:
        game=Path(tmp)/"game"
        shutil.copytree(ROOT/"game",game,ignore=shutil.ignore_patterns("*.apk","*.aab"))
        def client(worker):
            user=request("/v1/accounts","",{"name":f"soak_{worker}","password":secrets.token_urlsafe()})
            token=user["token"]; robot=user["robots"][0]["id"]
            for iteration in range(args.rounds):
                key=f"soak_{worker}_{iteration}"
                start=request("/v1/expedition/start",token,dict(robots=[robot],key=key))
                replay=request("/v1/expedition/start",token,dict(robots=[robot],key=key))
                assert replay["receipt"]==start["receipt"]
                active=start["expedition"]["active"]
                run=subprocess.run([args.godot,"--headless","--path",str(game),"--script","res://net/tests/soak_peer.gd"],
                                   env={**env,"TEST_MISSION_ID":active["id"],"TEST_MISSION_SECRET":active["secret"],"SOLO_EXPECT":"win"},
                                   stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding="utf8",errors="replace",timeout=330)
                messages=run.stdout.splitlines()
                if run.returncode or not any(x.startswith("M22_ACK ") for x in messages):
                    raise RuntimeError(f"peer {worker}, battle {active['id']} failed: "+str([x for x in messages if "ERROR" in x]))
                stats=json.loads(next(x[8:] for x in messages if x.startswith("M22_ACK ")))
                assert stats["rejoined"] and len(stats["ms"])>5
                commands.append(stats)
                result=request("/v1/expedition",token)["expedition"]["last"]
                receipts.append(dict(mission=active["id"],receipt=result["id"],result=result["outcome"],duration=result["seconds"]))
                print("SOAK_SETTLED",worker,iteration,active["id"],len(stats["ms"]),flush=True)
                repair_route=f"/v1/robots/{robot}/recovery"
                cond=request(repair_route,token)["recovery"]
                if cond["state"]=="damaged":
                    request(repair_route+"/repair",token,dict(key=key+"_repair"))
                    end=time.monotonic()+45
                    while request(repair_route,token)["recovery"]["state"]!="ready":
                        assert time.monotonic()<end
                        time.sleep(1)
            history=request(f"/v1/robots/{robot}/history",token)["history"]
            assert history["totals"]["battles"]==args.rounds
            assert request("/v1/profile",token)["robots"][0]["task"] is None
        try:
            print("SOAK_START",project,http,udp,flush=True)
            compose("up","-d","--build","profile","expedition")
            wait_ready(base)
            began=time.monotonic()
            thread=threading.Thread(target=monitor,daemon=True); thread.start()
            with ThreadPoolExecutor(args.clients) as pool:
                work=[pool.submit(client,i) for i in range(args.clients)]
                for future in work:
                    try:future.result()
                    except Exception as err:errors.append(str(err))
            stop.set();thread.join(14)
            assert len({r["receipt"] for r in receipts})==len(receipts)
            assert len({r["mission"] for r in receipts})==len(receipts)
            cpu=subprocess.check_output(["docker","info","--format","{{.NCPU}} vCPU, {{.MemTotal}} bytes, Docker {{.ServerVersion}}"],text=True).strip()
            measurement=dict(project=project,clients=args.clients,rounds=args.rounds,wall_seconds=round(time.monotonic()-began,2),
                host=platform.platform(),processor=os.environ.get("PROCESSOR_IDENTIFIER"),docker=cpu,godot="4.6.1",schema=compose("exec","-T","profile","python","-c","import server;print(server.VERSION)").strip(),
                http_count=len(timings),http_p95_ms=round(p95(timings),2) if timings else None,
                ack_count=sum(len(s["ms"]) for s in commands),ack_p95_ms=p95([n for s in commands for n in s["ms"]]),
                ack_timeouts=sum(s["timeouts"] for s in commands),completed=receipts,failed=errors,resources=resource_samples,
                peak_active_database=max(active_counts,default=0),acpi_zone_c=thermal,
                temperature="Windows host ACPI firmware thermal zone only; CPU package, GPU and Android temperatures not measured")
            output.write_text(json.dumps(measurement,ensure_ascii=False,indent=2),encoding="utf8")
            print("SOAK_REPORT",measurement["wall_seconds"],measurement["http_p95_ms"],measurement["ack_p95_ms"],len(receipts),errors,flush=True)
            assert not errors and len(receipts)==args.clients*args.rounds
        finally:
            stop.set()
            compose("down","--volumes")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True);p.add_argument("--clients",type=int,default=4);p.add_argument("--rounds",type=int,default=3);p.add_argument("--output",required=True)
    run(p.parse_args())
