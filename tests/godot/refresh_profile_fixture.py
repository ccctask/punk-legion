"""Fresh profile Handler fixture for M01 pages; controls are run-owned files.

No migration, server.main, business response mirrors, or shared runtime access.
"""
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import sqlite3
import sys
import time
import urllib.request

from http_fixture import Fixture

PROFILE = Path(__file__).resolve().parents[2] / 'services/profile'
sys.path.insert(0, str(PROFILE))
import server as profile_server
import production


class ControlledDrop(Exception):
    pass


class ProfileHandler(profile_server.Handler):
    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *_args):
        pass

    def dispatch(self):
        fixture = self.server
        token = self.headers.get('Authorization', '').removeprefix('Bearer ')
        with fixture.lock:
            fixture.request_number += 1
            self.request_id = fixture.request_number
        self.owner = fixture.owner_for(token)
        self.control = fixture.take_control(self.command, self.path, self.owner, self.request_id)
        fixture.log(dict(event='profile_request', id=self.request_id, method=self.command,
                         route=self.path, owner=self.owner, has_bearer=bool(token),
                         protocol=self.headers.get('X-Punk-Beta-Protocol')))
        try:
            if self.control and self.control['effect'] in ('503', '401'):
                # Transport/auth fault, never a synthetic successful business snapshot.
                assert self.command == 'GET'
                status = int(self.control['effect'])
                data = json.dumps({'error': 'session_expired' if status == 401 else 'qa_transport_unavailable'}).encode()
                self.send_response(status)
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Connection', 'close')
                self.end_headers()
                self.wfile.write(data)
            else:
                profile_server.Handler.respond(self)
            fixture.log(dict(event='profile_response_complete', id=self.request_id))
        except ControlledDrop:
            fixture.log(dict(event='profile_expected_drop', id=self.request_id, committed=True))
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError) as exc:
            # Expected only for this exact explicitly cancelled held request.
            allowed = self.control and (fixture.folder / ('cancel-' + str(self.request_id))).is_file()
            fixture.log(dict(event='profile_client_cancel' if allowed else 'profile_handler_failure',
                             id=self.request_id, type=type(exc).__name__))
            if not allowed:
                raise
        except BaseException as exc:
            fixture.log(dict(event='profile_handler_failure', id=self.request_id, type=type(exc).__name__))
            raise
        finally:
            self.close_connection = True

    do_GET = do_POST = dispatch

    def send_response(self, code, message=None):
        self.server.log(dict(event='profile_response_status', id=self.request_id, status=int(code)))
        # Actual Handler.handle has returned and its transaction has committed
        # before Handler.respond reaches send_response. Never intercept handle.
        control = getattr(self, 'control', None)
        if control and code == 200 and control['effect'] in ('hold', 'drop'):
            fixture = self.server
            if self.command == 'POST':
                fixture.save_commit_projection(self.request_id, self.owner)
            fixture.log(dict(event='profile_held', id=self.request_id, method=self.command,
                             route=self.path, owner=self.owner, committed=self.command == 'POST'))
            release = fixture.folder / ('release-' + str(self.request_id))
            deadline = time.monotonic() + 20
            while not release.exists():
                if fixture.stop_event.wait(.01):
                    raise ControlledDrop()
                if time.monotonic() >= deadline:
                    raise TimeoutError('Exact held request release was not supplied')
            if control['effect'] == 'drop':
                self.connection.shutdown(socket.SHUT_RDWR)
                raise ControlledDrop()
        super().send_response(code, message)


class RefreshProfileFixture(Fixture):
    def __init__(self, folder, *, solo=False, test_payments=False):
        assert type(test_payments) is bool
        self.private = folder / 'private-profile'
        self.private.mkdir(exist_ok=False)
        self.old_environment = {key:os.environ.get(key) for key in ('SOLO_SPOOL_DIR','PARTY_SPOOL_DIR','CAMP_SPOOL_DIR','ROOM_OUTBOX_DIR','WORLD_CALENDAR_FILE','PUNK_TEST_PAYMENTS')}
        self.original_now = production.now
        try:
            for key in ('SOLO_SPOOL_DIR','PARTY_SPOOL_DIR','CAMP_SPOOL_DIR','ROOM_OUTBOX_DIR'):
                target = self.private / key.lower()
                target.mkdir(exist_ok=False)
                os.environ[key] = str(target.resolve())
            os.environ['PUNK_TEST_PAYMENTS'] = '1' if test_payments else '0'
            os.environ['WORLD_CALENDAR_FILE'] = str(PROFILE / 'config/calendar.json')
            self.path = self.private / 'fresh.sqlite'
            assert not self.path.exists()
            profile_server.initialize(self.path)
            self.room_key = secrets.token_urlsafe(32) if solo else ''
            if solo:
                self.room_key_file = self.private / 'room-key'
                with self.room_key_file.open('x', encoding='utf8') as stream:stream.write(self.room_key)
            self.request_number = 0
            self.token_owners = {}
            self.clock_offset = 0
            production.now = self.production_now
            super().__init__(folder, handler=ProfileHandler)
        except BaseException:
            production.now = self.original_now
            self.restore_environment()
            raise

    def restore_environment(self):
        for key, value in self.old_environment.items():
            if value is None:os.environ.pop(key, None)
            else:os.environ[key] = value

    def owner_for(self, token):
        if not token:
            return ''
        with closing(sqlite3.connect(self.path.resolve().as_uri() + '?mode=ro', uri=True)) as db:
            row = db.execute('SELECT id FROM accounts WHERE session=?', (hashlib.sha256(token.encode()).hexdigest(),)).fetchone()
        owner = row[0] if row else ''
        assert not owner or owner in self.token_owners.values(), 'Only this run owners are allowed'
        return owner

    def handle_error(self, request, client_address):
        self.log(dict(event='profile_handler_failure', type=type(sys.exception()).__name__))

    def production_now(self):
        marker = self.folder / 'clock.json'
        if marker.exists():
            value = json.loads(marker.read_text('utf8'))
            assert set(value) == {'advance_seconds'}
            offset = value['advance_seconds']
            assert type(offset) is int and 0 <= offset <= 7200
            self.clock_offset = offset
        return self.original_now() + self.clock_offset

    def take_control(self, method, route, owner, request_id):
        marker = self.folder / 'arm.json'
        with self.lock:
            if not marker.exists():
                return None
            value = json.loads(marker.read_text('utf8'))
            assert set(value) == {'method', 'route', 'owner', 'effect'}
            assert value['effect'] in ('hold', 'drop', '503', '401')
            assert value['method'] in ('GET', 'POST') and value['route'].startswith('/v1/')
            assert value['owner'] in self.token_owners.values()
            if (method, route, owner) != (value['method'], value['route'], value['owner']):
                return None
            assert value['effect'] in ('hold', 'drop') or method == 'GET'
            marker.rename(self.folder / ('consumed-' + str(request_id) + '.json'))
            return value

    def save_commit_projection(self, request_id, owner):
        # Fixed RO columns from the fresh DB; no secret/session/account fields.
        with closing(sqlite3.connect(self.path.resolve().as_uri() + '?mode=ro', uri=True)) as db:
            rows = db.execute('SELECT id,intent,state FROM shop_orders WHERE owner=? ORDER BY rowid', (owner,)).fetchall()
            receipts = db.execute("SELECT id,business_key,operation FROM receipts WHERE owner=? AND operation='base_edit' ORDER BY rowid", (owner,)).fetchall()
        (self.folder / ('commit-' + str(request_id) + '.json')).write_text(json.dumps({'orders':[dict(zip(('id','intent','state'), row)) for row in rows], 'receipts':[dict(zip(('id','key','operation'), row)) for row in receipts]}), 'utf8')

    def api(self, route, fields=None, token=''):
        headers = {'Content-Type': 'application/json', 'X-Punk-Beta-Protocol': '5'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        payload = None if fields is None else json.dumps(fields).encode()
        request = urllib.request.Request('http://127.0.0.1:' + str(self.port) + route,
                                         data=payload, headers=headers)
        with urllib.request.urlopen(request, timeout=5) as response:
            assert response.status == 200
            return json.load(response)

    def start(self):
        super().start()
        accounts = []
        for suffix in ('one', 'two'):
            credentials = dict(name='refresh_' + suffix + '_' + secrets.token_hex(5),
                               password=secrets.token_urlsafe(20))
            response = self.api('/v1/accounts', credentials)
            owner = response['account']['id']
            self.token_owners[response['token']] = owner
            accounts.append(dict(**credentials, token=response['token'], owner=owner))
        # This file is private test input, never copied into public reports.
        (self.private / 'accounts.json').write_text(json.dumps(accounts), 'utf8')
        self.log(dict(event='profile_fixture_ready', database_source='fresh initialize + two normal accounts',
                      owners=[item['owner'] for item in accounts]))

    def close(self):
        try:
            result = super().close()
            with closing(sqlite3.connect(self.path.resolve().as_uri() + '?mode=ro', uri=True)) as db:
                result['database_integrity_ok'] = db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
            result['fresh_database_retained_as_private_evidence'] = True
            return result
        finally:
            production.now = self.original_now
            self.restore_environment()
