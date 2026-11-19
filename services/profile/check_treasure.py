"""Fixed-clock M24 authority checks, including invalid operations and recovery points."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import secrets
import tempfile
from unittest.mock import patch

import inventory
import server
import treasure


def run(db):
    clock=[1800000000.]
    def api(route,fields=None,token=""):
        return server.handle(db,"GET" if fields is None else "POST",route,fields or {},"Bearer "+token,"authority")
    def error(code,fn):
        try:fn()
        except inventory.Fault as exc:assert exc.code==code,(exc.code,code)
        else:raise AssertionError("expected "+code)
    with patch("time.time",side_effect=lambda:clock[0]),patch.dict(os.environ,{"TREASURE_EPOCH":str(int(clock[0]))}):
        server.initialize(db)
        users=[server.handle(db,"POST","/v1/accounts",{"name":"cache_user"+str(i),"password":secrets.token_urlsafe()},"") for i in range(4)]
        def get(i,action="",body=None):
            return api("/v1/treasure"+action,body,users[i]["token"])["treasure"]
        def create(i,friend=""):
            return get(i,"/create",dict(event=get(i)["event"]["id"],friend=friend))["group"]["id"]
        def confirm(i,gid):
            return get(i,"/confirm",dict(group=gid,risk=True,robots=[users[i]["robots"][0]["id"]]))
        def seat(i,action="",**order):
            body={**admissions[i]}
            if action:body.update(seq=order.pop("seq"),order=dict(action=action,robot=users[i]["robots"][0]["id"],**order))
            return api("/internal/treasure/"+("command" if action else "poll"),body,"authority")["state"]
        e=get(0)["event"]
        assert e["active"] and e==api("/v1/world",token=users[0]["token"])["world"]["treasure"]
        assert treasure.event(clock[0]+treasure.OPEN)["active"] is False
        assert treasure.event(clock[0]+treasure.PERIOD)["id"]!=e["id"]
        g=create(3); confirm(3,g)
        r=api("/v1/profile",token=users[3]["token"])["robots"][0]
        error("treasure_group_managed",lambda:api("/v1/robots/"+r["id"]+"/finish",dict(outcome="cancelled",assignment=r["assignment"]),users[3]["token"]))
        get(3,"/cancel",dict(group=g))
        assert get(3)["roster"]
        error("friendship_required",lambda:create(0,"cache_user2"))
        for a,b,action in ((0,2,"request"),(2,0,"accept")):api("/v1/friends/"+action,{"friend":"cache_user"+str(b)},users[a]["token"])
        g=create(0,"cache_user2")
        for i in (0,2):
            get(i,"/select",dict(group=g,robots=[users[i]["robots"][0]["id"]],revision=get(i)["group"]["revision"]))
        revision=get(0)["group"]["revision"]
        get(0,"/confirm",dict(group=g,risk=True,revision=revision))
        assert get(2)["group"]["phase"]=="forming" and not get(2)["group"]["confirmed"]
        error("explicit_confirmation_required",lambda:get(2,"/confirm",dict(group=g,risk=False,robots=[users[2]["robots"][0]["id"]])))
        get(2,"/confirm",dict(group=g,risk=True,revision=revision));confirm(1,create(1))
        admissions=[get(i)["admission"] for i in range(3)]
        assert len({row["id"] for row in admissions})==1
        battle=admissions[0]["id"]
        with server.transaction(db) as d:
            before={u["account"]["id"]:d.execute("SELECT COUNT(*) FROM parts WHERE owner=?",(u["account"]["id"],)).fetchone()[0] for u in users}
        t=seat(0)
        cross={**admissions[0],"seq":1,"order":{"action":"extract","robot":users[2]["robots"][0]["id"]}}
        assert api("/internal/treasure/command",cross,"authority")["state"]["error"]=="unit_unavailable"
        error("room_auth_required",lambda:api("/internal/treasure/poll",admissions[0],users[0]["token"]))
        for i,num in [(0,2),(1,1)]:assert not seat(i,"move",seq=num,pos=[0,0])["error"]
        clock[0]+=2
        with ThreadPoolExecutor(2) as executor:
            contestants=list(executor.map(lambda pair:seat(pair[0],"take",seq=pair[1],item="crate0"),[(0,3),(1,2)]))
        assert sorted(r["error"] for r in contestants)==["","item_taken"]
        win=next(i for i,r in enumerate(contestants) if not r["error"])
        lost=1-win
        nums=[3,2,0]
        def command(i,action,**fields):
            nums[i]+=1
            return seat(i,action,seq=nums[i],**fields)
        # Move loser away from the test pickup route; owner of the actual object survives.
        command(lost,"move",pos=[-7 if seat(lost)["side"]==0 else 7,0])
        for index in (1,2):
            pos=seat(win)["items"]["crate"+str(index)]["pos"]
            command(win,"move",pos=pos);clock[0]+=2.5
            res=command(win,"take",item="crate"+str(index))
            if index==1:assert not res["error"]
            else:
                assert res["error"]=="bag_full"
                assert not command(win,"take",item="crate2",replace="crate0")["error"]
        assert command(win,"extract")["error"]=="return_to_exit"
        home=[-7 if seat(win)["side"]==0 else 7,0];command(win,"move",pos=home)
        clock[0]+=4
        terminal=command(win,"extract")
        assert terminal["outcome"]=="extracted" and len(terminal["receipt"]["cargo"])==2
        duplicate=seat(win,"extract",seq=nums[win])
        assert terminal["receipt"]==duplicate["receipt"]
        assert get(win)["played"] and not get(win)["group"]
        error("treasure_already_entered",lambda:create(win))
        clock[0]+=200
        for i in range(3):
            result=get(i)
            assert not result["group"] and result["last"] and (i==win or not result["last"]["cargo"])
        with server.transaction(db) as d:
            assert d.execute("SELECT COUNT(*) FROM receipts WHERE operation='treasure_result'").fetchone()[0]==3
            assert d.execute("SELECT count(*) FROM robots WHERE task IS NOT NULL").fetchone()[0]==0
            ended=json.loads(d.execute("SELECT state FROM treasure_rooms WHERE id=? AND done=1",(battle,)).fetchone()[0])
            assert all(not unit["events"] for unit in ended["units"].values())
            award=terminal["receipt"]["salvage"]
            for owner,count in before.items():
                delta=int(owner==users[win]["account"]["id"] and award["status"]=="awarded")
                assert d.execute("SELECT COUNT(*) FROM parts WHERE owner=?",(owner,)).fetchone()[0]==count+delta
                if delta:
                    assert d.execute("SELECT definition FROM parts WHERE id=? AND owner=?",(award["part_id"],owner)).fetchone()[0]=="reinforced_boiler"
        clock[0]+=treasure.PERIOD
        g=create(3);confirm(3,g);clock[0]+=125
        assert not get(3)["group"] and get(3)["roster"]
        print("TREASURE_RULES_PASS event rotation, opt-in, teammate permissions, queued cancel/expiry, two-client contested pickup, replacement, extraction, replay, zero permanent loss",battle)

if __name__=="__main__":
    with tempfile.TemporaryDirectory() as folder:run(Path(folder)/"player.sqlite")
