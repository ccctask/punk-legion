"""Compare the original and recovered profile through the dedicated beta's public API."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen


def request(base, path, protocol, token="", body=None):
    headers={"Content-Type":"application/json","X-Punk-Beta-Protocol":str(protocol)}
    if token:
        headers["Authorization"]="Bearer "+token
    data=json.dumps(body).encode() if body is not None else None
    with urlopen(Request(base+path,data,headers),timeout=8) as response:
        return json.load(response)


def inspect(base, credentials,protocol):
    token=request(base,"/v1/sessions",protocol,body=credentials)["token"]
    workshop=request(base,"/v1/workshop",protocol,token)["workshop"]
    inventory=request(base,"/v1/inventory",protocol,token)["inventory"]
    store=request(base,"/v1/store",protocol,token)["store"]
    return dict(robots=workshop["robots"], designs=workshop["designs"], orders=store["orders"],
                capacity=workshop["design_capacity"], stock=inventory["stock"],
                blueprints=inventory["blueprints"], free=inventory["parts"])


if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--url",default="http://127.0.0.1:25180")
    cli.add_argument("--protocol",type=int,default=5)
    cli.add_argument("--credentials",type=Path,required=True)
    cli.add_argument("--fixture",type=Path,required=True)
    cli.add_argument("--record",action="store_true",help="Create a new baseline file")
    args=cli.parse_args()
    current=inspect(args.url,json.loads(args.credentials.read_text(encoding="utf8")),args.protocol)
    if args.record:
        with args.fixture.open("x",encoding="utf8") as file:
            json.dump(current,file,sort_keys=True)
    else:
        original=json.loads(args.fixture.read_text(encoding="utf8"))
        if current!=original:
            raise SystemExit("Account diverged in: "+", ".join(k for k in current if current[k]!=original.get(k)))
    digest=hashlib.sha256(json.dumps(current,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    print("BETA_ASSETS_PASS",digest,"robots",len(current["robots"]),"designs",len(current["designs"]),
          "capacity",current["capacity"],"orders",len(current["orders"]))
