"""Local mobile QA link, restricted to one loopback room and one emulator client."""
import argparse
import heapq
import json
from pathlib import Path
import select
import socket
import time

def run():
    p=argparse.ArgumentParser()
    p.add_argument("--listen",type=int,required=True)
    p.add_argument("--room",type=int,required=True)
    p.add_argument("--mode-file",type=Path,required=True)
    p.add_argument("--report",type=Path,required=True)
    a=p.parse_args()
    front=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    front.bind(("127.0.0.1",a.listen))
    back=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    back.connect(("127.0.0.1",a.room))
    client=None
    pending=[]
    order=0
    counts={}
    while True:
        mode=a.mode_file.read_text().strip()
        if mode=="stop": break
        if mode not in ("normal","impaired"):
            time.sleep(.01)
            continue
        q=counts.setdefault(mode,{"up":0,"down":0,"dropped_up":0,"dropped_down":0})
        now=time.monotonic()
        while pending and pending[0][0]<=now:
            _,_,sock,data,addr=heapq.heappop(pending)
            if addr: sock.sendto(data,addr)
            else: sock.send(data)
        for sock in select.select([front,back],[],[],.006)[0]:
            data,peer=sock.recvfrom(65535)
            if sock is front:
                client=peer
                dst,addr,direction=back,None,"up"
            elif client:
                dst,addr,direction=front,client,"down"
            else:
                continue
            q[direction]+=1
            if mode=="impaired" and q[direction]%12==0:
                q["dropped_"+direction]+=1
                continue
            order+=1
            delay=.15 if mode=="impaired" else 0
            heapq.heappush(pending,(time.monotonic()+delay,order,dst,data,addr))
    front.close()
    back.close()
    a.report.write_text(json.dumps(counts,indent=2))

if __name__=="__main__": run()
