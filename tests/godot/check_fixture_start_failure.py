"""Only verify startup-cleanup branches; no Godot, game API, container or AVD."""
import hashlib
import argparse
import json
from pathlib import Path
import threading
import time
from unittest.mock import patch
from http_fixture import Fixture

ROOT=Path(__file__).resolve().parents[2]
def main(output):
    allowed=(ROOT/'build/qa').resolve()
    assert allowed.is_relative_to(ROOT.resolve())
    output=(ROOT/output).resolve()
    assert output!=allowed and output.is_relative_to(allowed), 'Output must be a new directory inside this workspace build/qa'
    output.mkdir(parents=True,exist_ok=False)
    rows=[]
    for case in ('constructed-not-started','thread-start-raises','thread-already-exited'):
        fixture=Fixture(output);started=time.monotonic();caught=None
        try:
            if case=='thread-start-raises':
                with patch.object(fixture.thread,'start',side_effect=RuntimeError('controlled start failure')):
                    try:fixture.start()
                    except RuntimeError as exc:caught=str(exc)
                assert caught=='controlled start failure'
            elif case=='thread-already-exited':
                fixture.thread=threading.Thread(target=lambda:None)
                fixture.start();fixture.thread.join(timeout=1)
                assert not fixture.thread.is_alive()
        finally:cleanup=fixture.close()
        elapsed=time.monotonic()-started
        assert elapsed<2, 'Startup cleanup must be bounded'
        rows.append(dict(case=case,elapsed_seconds=elapsed,start_error=caught,cleanup=cleanup,passed=True))
    source=Path(__file__).with_name('http_fixture.py')
    report=dict(passed=True,scope='Only unstarted/start-failed/already-exited HTTP fixture cleanup branches',
        fixture_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),cases=rows,
        godot_started=0,containers_started=0,avd_started=0,threads_remaining=[x.name for x in threading.enumerate() if x is not threading.main_thread()])
    assert not report['threads_remaining']
    (output/'report.json').write_text(json.dumps(report,indent=2),'utf8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    main(parser.parse_args().out)
