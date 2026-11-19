"""Verify owned robot favorites survive rename, refit, stale requests and restart."""
from contextlib import contextmanager
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
from uuid import uuid4

import server
import workshop
from check_profile import api, ok, wait_ready


def run():
    with tempfile.TemporaryDirectory() as temp:
        folder=Path(temp)
        path=folder/"profile.sqlite"
        server.initialize(path)
        keyfile=folder/"room-key"
        keyfile.write_text(secrets.token_hex(32))
        with socket.socket() as s:
            s.bind(("127.0.0.1",0))
            port=s.getsockname()[1]
        base=f"http://127.0.0.1:{port}"
        @contextmanager
        def service():
            process=subprocess.Popen([sys.executable,str(Path(server.__file__)),"serve","--db",str(path),"--port",str(port),"--room-key-file",str(keyfile)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            try:
                wait_ready(base)
                yield
            finally:
                process.terminate()
                process.wait(timeout=10)
        creds={"name":"pins_owner","password":secrets.token_urlsafe()}
        def body(**fields):return dict(key=uuid4().hex,**fields)
        with service():
            first=ok(api(base,"/v1/accounts",creds))
            token=first["token"]
            robot=first["robots"][0]["id"]
            other=ok(api(base,"/v1/accounts",{"name":"pins_other","password":secrets.token_urlsafe()}))["token"]
            get=lambda route, fields=None:ok(api(base,route,fields,token))
            history=f"/v1/robots/{robot}/history"
            get(f"/v1/robots/{robot}/rename",{"name":"Twins"})
            design=get("/v1/workshop/design",body(name="Twin",version=1,slots=workshop.BASE))["receipt"]["design"]
            twin=get("/v1/workshop/build",body(design=design,name="Twins"))["receipt"]["robot"]
            setpin=body(robot=robot,saved=True)
            for _ in range(2):
                fleet=get("/v1/workshop/favorite",setpin)["workshop"]["robots"]
                assert [r["id"] for r in fleet if r["favorite"]]==[robot]
            assert next(r for r in fleet if r["id"]==twin)["name"]=="Twins"
            assert api(base,"/v1/workshop/favorite",setpin,other)[0]==404
            get(f"/v1/robots/{robot}/rename",{"name":"Tin Finch"})
            get("/v1/workshop/chassis",body(robot=robot,expected="crawler",chassis="biped"))
        with service():
            token=ok(api(base,"/v1/sessions",creds))["token"]
            fleet=get("/v1/workshop")["workshop"]["robots"]
            pin=next(r for r in fleet if r["favorite"])
            assert (pin["id"],pin["name"],pin["chassis"])==(robot,"Tin Finch","biped")
            assert get(history)["history"]["totals"]=={"battles":0,"kills":0,"output":0}
            get("/v1/workshop/favorite",body(robot=robot,saved=False))
            get("/v1/workshop/favorite",setpin)
            assert not any(r["favorite"] for r in get("/v1/workshop")["workshop"]["robots"])
            print("PINS_HTTP_PASS two owners, same-name robots, stale writes, restart, rename and refit")

if __name__=="__main__":
    run()
