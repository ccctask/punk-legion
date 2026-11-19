"""Verify role separation, safe diagnostics and race/replay using an isolated real HTTP operator API."""
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from pathlib import Path
from secrets import token_urlsafe
from tempfile import TemporaryDirectory
import threading
import json
import operations
import server
from check_profile import api,ok

def run():
    with TemporaryDirectory() as tmp:
        db=Path(tmp)/"test.sqlite";server.initialize(db)
        user=server.login(db,dict(name="ops_user",password="local-fixture-pass"),True)
        other=server.login(db,dict(name="ops_other",password="local-fixture-pass"),True)
        robot=user["robots"][0]["id"]
        player="Bearer "+user["token"];owner=user["account"]["id"]
        m=server.handle(db,"POST","/v1/expedition/start",dict(key="work_key01",robots=[robot]),player)["expedition"]["active"]
        viewer,issuer=token_urlsafe(32),token_urlsafe(32)
        policy={"observer":dict(role="viewer",sha256=sha256(viewer.encode()).hexdigest()),
                "duty_staff":dict(role="compensator",sha256=sha256(issuer.encode()).hexdigest())}
        with server.ThreadingHTTPServer(("127.0.0.1",0),operations.Handler) as http:
            http.db=db;http.policy=policy
            worker=threading.Thread(target=http.serve_forever,daemon=True);worker.start()
            url=f"http://127.0.0.1:{http.server_port}"
            try:
                path="/ops/battles/"+m["id"]
                info=ok(api(url,path,token=viewer))
                for s in (m["secret"],viewer,issuer,user["token"],"secret","snapshot"):
                    assert s not in json.dumps(info)
                assert info["actors"][0]["unsettled"] and info["actors"][0]["robot"]==robot
                fields=dict(owner=owner,incident=m["id"],reason="missed_reward",key="ops_key_01",resource="structure",amount=2)
                ledger="/ops/compensations"
                for credential,code in [(user["token"],401),(viewer,403)]:
                    assert api(url,ledger,fields,credential)[0]==code
                assert api(url,ledger,dict(fields,owner=other["account"]["id"]),issuer)[0]==409
                assert api(url,ledger,dict(fields,amount=99),issuer)[0]==400
                stock=lambda:server.handle(db,"GET","/v1/inventory",{},player)["inventory"]["stock"]["structure"]["amount"]
                before=stock()
                with ThreadPoolExecutor(5) as pool:
                    rows=list(pool.map(lambda _:ok(api(url,ledger,fields,issuer))["receipt"],range(5)))
                assert all(r==rows[0] for r in rows) and stock()==before+2
                assert rows[0]["operator"]=="duty_staff" and rows[0]["reason"]=="missed_reward"
                assert api(url,ledger,dict(fields,key="different_key"),issuer)[1]["error"]=="already_compensated"
                assert api(url,ledger,dict(fields,amount=1),issuer)[1]["error"]=="key_conflict"
                assert rows[0]["id"] in [r["id"] for r in ok(api(url,path,token=viewer))["receipts"]]
                print("OPS_AUDIT_PASS incident",m["id"],"before",before,"after",stock(),"receipt",rows[0]["id"],
                      "viewer GET only, player denied, wrong owner denied, 5 concurrent retries one credit, reason+operator retained, no credentials in diagnostics")
            finally:http.shutdown();worker.join()

if __name__=="__main__":run()
