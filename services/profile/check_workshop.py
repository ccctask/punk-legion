"""M09 validates catalogue parity, owned IDs, atomic costs, competing fits and session recovery."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import re
import secrets
import tempfile
import uuid
import server
import workshop
from inventory import Fault

def check_catalog():
    source = (Path(__file__).resolve().parents[2]/"game/loadout/catalog.gd").read_text(encoding="utf-8-sig")
    for name, end in (("CHASSIS","const PARTS"),("PARTS","# Trusted")):
        block = source.split("const "+name+" := ",1)[1].split(end,1)[0]
        assert json.loads(re.sub(r",\s*([}\]])",r"\1",block)) == workshop.CATALOG[name.lower()]
    assert int(re.search(r"const VERSION := (\d+)",source)[1]) == workshop.CATALOG["version"]

def check_schema_two(path):
    with server.transaction(path) as db:
        db.execute("CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT UNIQUE,salt BLOB,digest BLOB,session TEXT UNIQUE)")
        db.execute("CREATE TABLE robots(id TEXT PRIMARY KEY,owner TEXT,name TEXT,task TEXT,assignment TEXT UNIQUE)")
        db.execute("INSERT INTO accounts VALUES ('owner','old',X'00',X'00',NULL)")
        db.execute("INSERT INTO robots VALUES ('old-hull','owner','v2','guard','in-progress')")
        server.inventory.create_tables(db)
        server.inventory.seed(db,"owner")
        db.execute("INSERT INTO parts VALUES ('legacy-part','owner','cannon')")
        db.execute("UPDATE stocks SET amount=7 WHERE resource='structure' AND owner='owner'")
        db.execute("PRAGMA user_version=2")
    server.initialize(path)
    server.initialize(path)
    with server.transaction(path) as db:
        state = workshop.view(db,"owner")
        assert state["stock"]["structure"] == 7 and state["robots"][0]["id"] == "old-hull"
        assert state["robots"][0]["task"] == "guard" and len(state["robots"][0]["slots"]) == 3
        assert state["available"] == [{"id":"legacy-part","definition":"cannon"}]

def run():
    check_catalog()
    full = [{"id":str(i),"task":None,"slots":{s:{"id":f"{i}:{s}","definition":p} for s,p in workshop.BASE.items()}} for i in range(workshop.ROBOT_CAP)]
    assert workshop.ROBOT_CAP > workshop.SQUAD_CAP
    assert len(workshop.deployment_for(full)["units"]) == 12
    expensive = [dict(r,slots={**r["slots"],"core":{"id":"c"+r["id"],"definition":"reinforced_boiler"}}) for r in full]
    assert len(workshop.deployment_for(expensive)["units"]) == 8
    try:
        workshop.deployment_for(expensive,[r["id"] for r in expensive[:9]])
        assert False, "over-budget roster"
    except Fault as failure:
        assert failure.code == "point_limit"
    with tempfile.TemporaryDirectory() as tmp:
        # The development regression starts from the full current schema.
        # Historical v2 checks remain a separate entry point.
        path = Path(tmp)/"profile.sqlite"
        server.initialize(path)
        credentials = {"name":"assembler","password":secrets.token_urlsafe()}
        account = server.login(path,credentials,True)
        auth = "Bearer " + account["token"]
        other = "Bearer " + server.login(path,{**credentials,"name":"outsider"},True)["token"]
        def get():
            return server.handle(path,"GET","/v1/workshop",{},auth)["workshop"]
        def op(action, fields, actor=None):
            try:
                return server.handle(path,"POST","/v1/workshop/"+action,fields,actor or auth)["receipt"]
            except Fault as e:
                return e.code
        def cmd(**fields):
            return dict(key=uuid.uuid4().hex,**fields)
        stock = get()["stock"]
        draft = cmd(name="Visor",version=1,slots={**workshop.BASE,"head":"visor"})
        design = op("design",draft)
        assert op("design",draft) == design
        assert op("design",cmd(name="Bad",version=1,slots={**workshop.BASE,"weapon":"drill","head":"visor"})) == "exclusive"
        assert op("design",cmd(name="Bad",version=1,slots={**workshop.BASE,"head":"boiler"})) == "interface"
        build = cmd(design=design["design"],name="One")
        with ThreadPoolExecutor(4) as pool:
            receipts = list(pool.map(lambda _: op("build",build),range(4)))
        first = receipts[0]
        assert all(r == first for r in receipts)
        second = op("build",cmd(design=design["design"],name="Two"))
        assert first["robot"] != second["robot"] and set(first["installed"].values()).isdisjoint(second["installed"].values())
        assert op("build",build,other) == "unknown_design"
        assert get()["stock"] == {k:v+2*workshop.build_cost(draft["slots"])[k] for k,v in stock.items()}
        starter = account["robots"][0]["id"]
        starter_eye = get()["robots"][0]["slots"]["head"]["id"]
        eye = op("refit",cmd(robot=starter,slot="head",expected=starter_eye,item=""))
        assert eye["returned"] == starter_eye and len(get()["deployment"]["units"]) == 2
        def swap(receipt):
            return op("refit",cmd(robot=receipt["robot"],slot="head",expected=receipt["installed"]["head"],item=starter_eye))
        with ThreadPoolExecutor(2) as pool:
            raced = list(pool.map(swap,[first,second]))
        assert sum(isinstance(r,dict) for r in raced) == 1 and "item_unavailable" in raced
        win = next(r for r in raced if isinstance(r,dict))
        assert win["returned"] in {r["id"] for r in get()["available"]}
        assign = server.handle(path,"POST","/v1/robots/"+win["robot"]+"/assign",{"task":"repair"},auth)
        assert any(r["task"] == "repair" for r in assign["robots"])
        before = get()
        invalid = cmd(robot=win["robot"],slot="head",expected=starter_eye,item="")
        assert op("refit",invalid) == "robot_busy" and get() == before
        assert op("refit",invalid,other) == "unknown_robot"
        assert op("build",cmd(design=design["design"],name="Three"))["operation"] == "build"
        before = get()
        assert op("build",cmd(design=design["design"],name="Four")) == "insufficient_stock" and before == get()
        server.initialize(path)
        auth = "Bearer "+server.login(path,credentials,False)["token"]
        assert get() == before
        # Fill the real bag, then prove equal-size swaps remain possible.
        with server.transaction(path) as db:
            owner = account["account"]["id"]
            while len(workshop.view(db,owner)["available"]) < server.inventory.PART_CAP:
                db.execute("INSERT INTO parts VALUES (?,?,?)",(uuid.uuid4().hex,owner,"cannon"))
        before = get()
        cannon = next(r for r in before["available"] if r["definition"] == "cannon")
        robot = next(r for r in before["robots"] if not r["task"] and "weapon" in r["slots"])
        equipped = robot["slots"]["weapon"]["id"]
        assert op("refit",cmd(robot=robot["id"],slot="weapon",expected=equipped,item="")) == "parts_full" and get() == before
        swap = op("refit",cmd(robot=robot["id"],slot="weapon",expected=equipped,item=cannon["id"]))
        assert swap["returned"] == equipped and len(get()["available"]) == server.inventory.PART_CAP
        print("OWNED_PASS distinct_entities replay cost rollback swap race assignment reconnect catalogue")
if __name__ == "__main__":
    run()
