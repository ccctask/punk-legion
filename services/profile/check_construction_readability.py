"""Drive two real Godot base screens against a temporary single-material account per run."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import threading

import server

ROOT=Path(__file__).resolve().parents[2]


def run(args):
    out=args.output.resolve()
    out.mkdir(exist_ok=True,parents=True)
    with tempfile.TemporaryDirectory() as sandbox:
        temp=Path(sandbox)
        db=temp/"profile.sqlite"
        server.initialize(db)
        http=server.ProfileHTTPServer(("127.0.0.1",0),server.Handler)
        http.path=db
        http.room_key=""
        worker=threading.Thread(target=http.serve_forever,daemon=True)
        worker.start()
        try:
            for size in ("960x540","640x360"):
                name="construction_"+secrets.token_hex(3)
                password=secrets.token_urlsafe()
                server.login(db,{"name":name,"password":password},True)
                with server.transaction(db) as cx:
                    owner=cx.execute("SELECT id FROM accounts WHERE name=?",(name,)).fetchone()[0]
                    cx.execute("UPDATE stocks SET amount=1 WHERE owner=? AND resource='structure'",(owner,))
                env=dict(os.environ,PROFILE_URL=f"http://127.0.0.1:{http.server_port}",PL_BASE_SESSION_FILE=str(temp/(size+".cfg")),
                         HOME_QA_MODE=size,HOME_QA_PROOF=str(out),HOME_QA_ACCOUNT=name,HOME_QA_PASSWORD=password,HOME_QA_NAME="铆钉")
                command=[args.godot,"--path",str(ROOT/"game"),"--max-fps","30","--resolution",size,"--script","res://base/tests/construction_readability.gd"]
                if args.headless:command.append("--headless")
                result=subprocess.run(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=55)
                log=result.stdout.decode("utf8",errors="replace")
                (out/(size+".log")).write_text(log,encoding="utf8")
                assert result.returncode==0 and "M11_READABILITY_PASS" in log and "ERROR:" not in log,log[-2500:]
                with server.transaction(db) as cx:
                    stock=cx.execute("SELECT amount FROM stocks WHERE owner=? AND resource='structure'",(owner,)).fetchone()[0]
                    base=json.loads(cx.execute("SELECT layout FROM bases WHERE owner=?",(owner,)).fetchone()[0])
                    receipts=[json.loads(row[0]) for row in cx.execute("SELECT body FROM receipts WHERE owner=? AND operation='base_edit'",(owner,))]
                assert base["revision"]==2 and sum(b["kind"]=="hangar" for b in base["buildings"])==1
                assert stock==0 and len(receipts)==1 and receipts[0]["changes"]=={"structure":-1}
                print(size,"M11_READABILITY_PASS ledger=1 structure=1→0 hangars=1 revision=2")
        finally:
            http.shutdown()
            http.server_close()
            worker.join()


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--headless",action="store_true")
    run(p.parse_args())
