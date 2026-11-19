"""Per-starter facts and conditional naming across identities and racing responses."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import secrets
import tempfile
import server
import workshop
from inventory import Fault

def run():
    with tempfile.TemporaryDirectory() as d:
        path=Path(d)/"db";server.initialize(path)
        def create():
            session=server.login(path,{"name":"unit_"+secrets.token_hex(5),"password":secrets.token_urlsafe()},True)
            return "Bearer "+session["token"],session["robots"][0]["id"]
        token,rid=create()
        foreign,other=create()
        def post(route,body,auth=token):
            try:return server.handle(path,"POST",route,body,auth)
            except Fault as e:return e.code
        def rename(value,restricted=True,auth=token):
            return post(f"/v1/robots/{rid}/rename",dict(name=value,first_name_only=restricted),auth)
        def first():
            return server.handle(path,"GET","/v1/profile",{},token)["robots"][0]
        design=post("/v1/workshop/design",dict(key=secrets.token_hex(8),version=1,name="stored",slots=workshop.BASE))["receipt"]["design"]
        post("/v1/workshop/build",dict(key=secrets.token_hex(8),design=design,name="Already named second"))
        assert first()["id"]==rid and not first()["named"] and first()["name"]=="新虎机组"
        assert rename("别的机体",auth=foreign)=="unknown_robot"
        with ThreadPoolExecutor(2) as pool:
            results=list(pool.map(rename,["第一命名","另一个名字"]))
        assert len([r for r in results if isinstance(r,dict)])==1 and results.count("already_named")==1
        accepted=first()["name"]
        assert rename(accepted)["robots"][0]["name"]==accepted
        assert rename("后续改名",False)["robots"][0]["name"]=="后续改名"
        assert rename(accepted)=="already_named" and first()["name"]=="后续改名"
        with server.transaction(path) as db:
            db.execute("DELETE FROM named_robots WHERE robot=?",(rid,))
        assert first()["name"]=="后续改名" and rename("延迟旧名")=="already_named"
        assert post(f"/v1/robots/{other}/rename",{"name":"新虎机组","first_name_only":True},foreign)["robots"][0]["named"]==1
        assert post(f"/v1/robots/{other}/rename",{"name":"新虎机组","first_name_only":True},foreign)["robots"][0]["named"]==1
        print("BASE_FIRST_RACE_PASS first UUID independent of second robot; one winning first name; lost response replay preserves later name; default-name flag and legacy nondefault; foreign owner refused")

if __name__=="__main__":run()
