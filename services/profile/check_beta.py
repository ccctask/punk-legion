"""M23 compatibility and retry probes. Optional --live targets the dedicated local beta sandbox."""
import argparse
import json
import os
import secrets
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request,urlopen
from check_production import serve

def request(url,route,protocol=None,body=None):
    headers={"Content-Type":"application/json"}
    if protocol is not None:headers["X-Punk-Beta-Protocol"]=str(protocol)
    msg=Request(url+route,data=json.dumps(body).encode() if body is not None else None,headers=headers)
    try:
        with urlopen(msg,timeout=4) as http:return http.status,json.load(http)
    except HTTPError as error:return error.code,json.load(error)


def run(url):
    policy=request(url,"/v1/beta/compat")[1]
    assert policy["protocol_max"]==5
    floor=policy["protocol_min"]
    who={"name":"beta_"+secrets.token_hex(5),"password":secrets.token_urlsafe()}
    for version in (*range(floor),6,"invalid"):
        assert request(url,"/v1/accounts",version,who)==(426,{"error":"beta_update_required"})
    assert request(url,"/v1/accounts",floor,who)[0]==200
    for version in range(floor,6):
        assert request(url,"/v1/sessions",version,who)[0]==200
    print("BETA_COMPAT_PASS supported protocol range",floor,".. 5; invalid versions rejected before writes")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--live")
    args=parser.parse_args()
    if args.live:
        run(args.live)
    else:
        with TemporaryDirectory() as tmp,serve(Path(tmp)/"profile.sqlite") as base:
            run(base)
            assert request(base,"/v1/profile",None)[0]==401
            with patch.dict(os.environ,{"BETA_PROTOCOL_MIN":"5","BETA_REQUIRE_PROTOCOL":"1"}):
                run(base)
                assert request(base,"/v1/beta/compat",4)[0]==426
                assert request(base,"/v1/profile",None)[0]==426
                assert request(base,"/v1/beta/compat",None)[1]["protocol_min"]==5
                print("BETA_POLICY_PASS unversioned health discovery, versioned player reads, unversioned internal room auth untouched")
