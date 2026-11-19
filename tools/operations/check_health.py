"""Exercise sampling against an isolated HTTP server and regular files, with a controlled clock."""
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import sqlite3
from tempfile import TemporaryDirectory
from threading import Thread
import time

import health


class Profile(BaseHTTPRequestHandler):
    def log_message(self,*_):
        pass

    def do_GET(self):
        assert self.path=="/v1/beta/compat"
        self.send_response(self.server.status)
        self.end_headers()
        self.wfile.write(b'{"server_now":1}')


def run():
    with TemporaryDirectory() as folder, ThreadingHTTPServer(("127.0.0.1",0),Profile) as server:
        server.status=200
        Thread(target=server.serve_forever,daemon=True).start()
        root=Path(folder)
        for queue in health.QUEUES:
            (root/queue).mkdir()
        path=root/"health.sqlite"
        profile="http://127.0.0.1:"+str(server.server_port)
        stamp=int(time.time())
        pending=root/"solo/a.result.json"
        pending.write_bytes(b"opaque receipt")
        os.utime(pending,(stamp-200,stamp-200))
        (root/"solo/a.progress.json").touch()
        with closing(sqlite3.connect(path)) as db:
            health.initialize(db)
            health.record(db,(stamp-health.RETENTION-1,1,0,0,0,1))
            server.status=503
            for index in range(3):
                row=health.collect(profile,root,stamp+index*30)
                assert row[1]==0 and row[3]==1 and row[4]>=200 and row[5]==1
                transitions=health.record(db,row)
                assert len(transitions)==(2 if index==2 else 0)
                assert health.record(db,row)==[]
        report=health.report(path,50,stamp+61)
        assert len(report["samples"])==3 and report["active"]==["profile_unreachable","result_overdue"]
        assert pending.read_bytes()==b"opaque receipt"
        # Simulate authority delivery, not a write by the sampler.
        pending.unlink()
        server.status=200
        with closing(sqlite3.connect(path)) as db:
            row=health.collect(profile,root,stamp+90)
            assert row[1:2]==(1,) and row[3:]==(0,0,1)
            assert len(health.record(db,row))==2
            (root/"camp").rmdir()
            for n in range(3):
                health.record(db,health.collect(profile,root,stamp+120+n*30))
        result=health.report(path,50,stamp+280)
        assert result["stale"] and result["active"]==["queues_unreadable"] and len(result["events"])==5
        server.shutdown()
    print("HEALTH_PASS HTTP 503 and stale result trigger separate alerts at three samples; idempotent timestamp, reopened DB, recovery, missing queue, retention and stale-query detection")


if __name__=="__main__":
    run()
