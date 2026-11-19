"""Actual Godot account/base windows against an isolated SQLite profile and injected transport faults."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import json
import os
from pathlib import Path
import secrets
import sqlite3
import subprocess
import tempfile
import threading
import server

ROOT=Path(__file__).resolve().parents[2]

class HomeHandler(server.Handler):
    def respond(self):
        fault=self.server.fault
        mode=fault.read_text() if fault.exists() else ""
        self.server.seen[self.path]=self.server.seen.get(self.path,0)+1
        if self.server.fail_first.get(self.path,0)>0:
            self.server.fail_first[self.path]-=1
            self.send_response(503); self.send_header("Content-Length","0"); self.end_headers()
            return
        if mode=="down" or (mode=="layout_down" and self.path=="/v1/base") or (mode=="guide_down" and self.path=="/v1/onboarding") or mode=="old" and self.path=="/v1/beta/compat":
            body=json.dumps({"protocol_min":1,"protocol_max":99}).encode()
            self.send_response(200 if mode=="old" else 503)
            self.send_header("Content-Length",str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif mode=="drop_rename" and self.path.endswith("/rename"):
            fields=json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            server.handle(self.server.path,self.command,self.path,fields,self.headers["Authorization"])
            fault.unlink()
            self.close_connection=True
        else:
            super().respond()
    do_GET=respond
    do_POST=respond

def run(godot,out,headless=False):
    out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        t=Path(temp);db=t/"profile.sqlite";server.initialize(db)
        http=server.ProfileHTTPServer(("127.0.0.1",0),HomeHandler)
        http.path=db;http.room_key="";http.fault=t/"fault";http.fail_first={};http.seen={}
        base=f"http://127.0.0.1:{http.server_port}"
        worker=threading.Thread(target=http.serve_forever,daemon=True);worker.start()
        accounts=[("home_"+secrets.token_hex(4),secrets.token_urlsafe(),name) for name in ("铃兰巡检","新虎机组","芥末机组","桔糖队长")]
        def window(mode,index):
            name,password,given=accounts[index]
            env=dict(os.environ,PROFILE_URL=base,PL_BASE_SESSION_FILE=str(t/f"session-{index}.cfg"),HOME_QA_MODE=mode,HOME_QA_PROOF=str(out),
                     HOME_QA_ACCOUNT=name,HOME_QA_PASSWORD=password,HOME_QA_NAME=given,HOME_QA_FAULT=str(http.fault))
            path=out/(mode+".log")
            with path.open("w",encoding="utf8") as f:
                p=subprocess.run([godot,*(["--headless"] if headless else []),"--path",str(ROOT/"game"),"--max-fps","30","--resolution","800x450" if index==1 else "960x540",
                    "--script","res://beta/tests/base_first.gd"],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=65)
            text=path.read_text(encoding="utf8");assert p.returncode==0 and "BASE_FIRST_PASS" in text and "ERROR:" not in text,(mode,text[-800:])
        try:
            with ThreadPoolExecutor(2) as pool:
                jobs=[pool.submit(window,"new",0),pool.submit(window,"default",1)]
                for job in jobs:job.result()
            routes=("/v1/beta/compat","/v1/base","/v1/onboarding")
            http.fail_first=dict.fromkeys(routes,2);http.seen.clear()
            window("transient",2)
            assert all(http.seen.get(route)==3 for route in routes[:2]) and http.seen.get(routes[2])==4,http.seen
            assert http.seen.get("/v1/accounts")==1 and not http.seen.get("/v1/sessions"),http.seen
            # After a successful name ack the guide is refreshed once to advance beyond naming.
            http.fault.write_text("down");window("offline",0)
            for failure,route in (("layout_down","/v1/base"),("guide_down","/v1/onboarding")):
                http.fault.write_text(failure);http.seen.clear()
                window(failure,0)
                assert http.seen[route]==4,("bounded attempts + explicit retry",route,http.seen)
            http.fault.write_text("old");window("incompatible",0);http.fault.unlink()
            with server.transaction(db) as cx:cx.execute("UPDATE accounts SET session=NULL WHERE name=?",(accounts[0][0],))
            http.fail_first={"/v1/base":1,"/v1/onboarding":1};http.seen.clear()
            window("expired",0)
            assert http.seen["/v1/sessions"]==1 and http.seen.get("/v1/workshop",0)==0 and http.seen["/v1/base"]==2 and http.seen["/v1/onboarding"]==2,http.seen
            window("restore",0)
            http.fault.write_text("drop_rename");window("lost",3)
            with closing(sqlite3.connect(db)) as cx:
                for name,_,given in accounts:
                    rows=cx.execute("SELECT r.name,n.robot FROM robots r JOIN accounts a ON a.id=r.owner JOIN named_robots n ON n.robot=r.id WHERE a.name=?",(name,)).fetchall()
                    assert len(rows)==1 and rows[0][0]==given
            print("BASE_FIRST_MULTIWINDOW_PASS registered=4; default/fresh/lost-ack, recovered session, expired token, incompatible old server, offline recovery")
        finally:
            http.shutdown();http.server_close();worker.join()

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--output",type=Path,required=True)
    p.add_argument("--headless",action="store_true")
    a=p.parse_args();run(a.godot,a.output.resolve(),a.headless)
