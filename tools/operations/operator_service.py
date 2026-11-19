"""Exact existing-schema gate before the original operator HTTP entry point."""
from contextlib import closing
import json
from pathlib import Path
import runpy
import sqlite3
import sys


def main():
    # No initialize(), validate_version() range, or writable connection here.
    path = Path('/data/player.sqlite')
    if not path.is_file():
        raise ValueError('Existing player.sqlite required')
    import server
    with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=8)) as db:
        version = db.execute('PRAGMA user_version').fetchone()[0]
    if version != server.VERSION:
        raise ValueError('Exact current profile schema required')
    print(json.dumps({'event': 'operator_schema_ready', 'schema': version}), flush=True)
    sys.argv = ['/app/operations.py', '--db', str(path), '--policy', '/run/operator.policy.json', '--port', '24679']
    runpy.run_path('/app/operations.py', run_name='__main__')


if __name__ == '__main__':
    main()
