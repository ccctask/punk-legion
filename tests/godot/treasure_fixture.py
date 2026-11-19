"""M24-only real loopback HTTP fixture. No database, account or ENet state."""
from copy import deepcopy
from http.server import BaseHTTPRequestHandler
import json
import re
import socket
import time
import xml.etree.ElementTree as ET

from http_fixture import Fixture

KINDS = ('create', 'select', 'confirm-solo', 'confirm-duo', 'cancel')


def case_kind(case):
    return next((x for x in KINDS if case.endswith('-' + x)), 'create')


def overview(kind, case):
    """Current public response fields; deterministic new test values, not old saves."""
    mine = dict(name='Copper', mine=True, robots=['r-z', 'r-a'],
                names={'r-z': 'Zinc', 'r-a': 'Amber'}, points=4, confirmed=False)
    duo = kind in ('select', 'confirm-duo')
    group = dict(id='group-' + case, phase='forming', revision=3,
                 point_cap=12 if duo else 24, unit_cap=6 if duo else 12,
                 confirmed=False, members=[mine])
    if kind == 'confirm-solo':
        mine.update(robots=[], names={}, points=0)
    if duo:
        group['members'].append(dict(name='Tin', mine=False, robots=['friend-r'],
                                     names={'friend-r': 'Tin'}, points=2, confirmed=False))
    return dict(event=dict(id='event-' + case, name='Copper', active=True), played=False,
                roster=[dict(id='r-z', name='Zinc', points=2), dict(id='r-a', name='Amber', points=2)],
                group=None if kind == 'create' else group, last=None,
                salvage=dict(day=20771, misses=0, chance_percent=20, part_space=20,
                             available=True, guaranteed=False))


def refreshed(view, kind, scenario):
    data = deepcopy(view)
    if scenario == 'positive':
        if kind == 'create':
            data['roster'].append(dict(id='unrelated-r', name='Other', points=3))
        elif kind == 'confirm-duo':
            data['group']['members'][1]['confirmed'] = True
        elif kind == 'cancel':
            data['roster'][0]['points'] = 3
        else:
            data['roster'][0]['name'] = 'Display rename'
    elif scenario == 'changed':
        if kind == 'create':
            data['event']['id'] += '-new'
        elif kind == 'select':
            data['group']['revision'] += 1
        elif kind == 'confirm-solo':
            data['roster'][0]['points'] = 3
        elif kind == 'confirm-duo':
            data['group']['members'][1].update(robots=['different-r'], points=3)
        elif kind == 'cancel':
            data['group']['id'] += '-new'
    elif scenario == 'admission':
        data['admission'] = dict(id='fixture-admission', secret='public-fixture-only')
    elif scenario == 'empty':
        data.update(roster=[], group=None, last=None)
    return data


class TreasureHandler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.0'

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *_):
        pass

    def _serve(self):
        match = re.fullmatch(r'/treasure-case/([a-z0-9-]+)/v1/treasure(/(?:create|select|confirm|cancel))?', self.path)
        if not match:
            self.send_error(404)
            return
        case, suffix = match.group(1), match.group(2) or ''
        kind = case_kind(case)
        scenario = case[:-(len(kind) + 1)]
        length = int(self.headers.get('Content-Length', '0'))
        if not 0 <= length <= 4096:
            raise ValueError('Fixture request too large')
        body = json.loads(self.rfile.read(length)) if length else None
        with self.server.lock:
            key = (case, self.command)
            number = self.server.counts.get(key, 0) + 1
            self.server.counts[key] = number
        self.server.log(dict(event='request_begin', case=case, method=self.command,
                             suffix=suffix, body=body, number=number,
                             body_field_types={key: type(value).__name__ for key, value in body.items()} if isinstance(body, dict) else {}))
        status, raw = 200, None
        view = overview(kind, case)
        if self.command == 'GET':
            held = (scenario == 'initial' and number == 1) or number == 2 or (scenario == 'retire' and number == 3)
            if held:
                release = self.server.control / f'{case}.get{number}.release'
                until = time.monotonic() + (8.0 if scenario == 'timeout' else 10.0)
                while not release.exists() and time.monotonic() < until:
                    if self.server.stop_event.wait(.01):
                        self.server.log(dict(event='handler_stopped', case=case, number=number))
                        return
                self.server.log(dict(event='held_request_released', case=case, number=number,
                                     explicit=release.exists()))
            if number == 2:
                if scenario == 'failed':
                    status, raw = 500, {'error': 'fixture_read_failed'}
                elif scenario == 'bad-json':
                    raw = b'['
                elif scenario == 'bad-structure':
                    raw = {'treasure': {'event': {}}}
                elif scenario == 'bad-member':
                    view['group']['members'][1]['points'] = 'not-a-number'
                else:
                    view = refreshed(view, kind, scenario)
            if scenario == 'unknown' and self.server.counts.get((case, 'POST'), 0):
                view['group'] = overview('confirm-solo', case)['group']
        elif self.command == 'POST':
            if not suffix or body is None:
                raise ValueError('POST fixture requires an actual operation body')
            if scenario == 'unknown':
                self.server.log(dict(event='simulated_commit_response_withheld', case=case,
                                     method='POST', number=number))
                # Preserve a live connection past the real seven-second client
                # deadline. No forced reset/native-connect-error side effect.
                self.server.stop_event.wait(8.0)
                self.close_connection = True
                return
        else:
            raise ValueError('Unexpected HTTP method')
        payload = raw if isinstance(raw, bytes) else json.dumps(raw if raw is not None else {'treasure': view}).encode()
        self.server.log(dict(event='response_attempt', case=case, method=self.command,
                             number=number, status=status, bytes=len(payload)))
        try:
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(payload)
            self.wfile.flush()
            self.server.log(dict(event='response_sent', case=case, method=self.command,
                                 number=number, status=status))
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            self.server.log(dict(event='client_closed', case=case, method=self.command, number=number))
        finally:
            self.close_connection = True

    def do_GET(self):
        try:
            self._serve()
        except BaseException as exc:
            self.server.log(dict(event='handler_failure', type=type(exc).__name__, message=str(exc)))
            raise

    do_POST = do_GET


class TreasureFixture(Fixture):
    """Reuse the signed fixture's bind/start/stop/join/probe lifecycle unchanged."""
    def __init__(self, folder):
        self.control = folder / 'treasure-control'
        self.control.mkdir()
        (folder / 'treasure-samples.json').write_text(
            json.dumps({kind: overview(kind, 'policy-' + kind) for kind in KINDS}, indent=2),
            encoding='utf8')
        super().__init__(folder)
        self.RequestHandlerClass = TreasureHandler


def engine_error_evidence(log, xml):
    """One native configuration-fault error, never a generic ERROR ignore rule."""
    case = 'test_recheck_sync_start_error_retires_request_before_recovery'
    begin, end = 'TREASURE_SYNC_BEGIN case=' + case, 'TREASURE_SYNC_END case=' + case
    error = "ERROR: Invalid URL scheme: 'ftp://'."
    source = 'at: _parse_url (scene/main/http_request.cpp:60)'
    errors = [line for line in log.splitlines() if re.search(r'SCRIPT ERROR|^ERROR:', line)]
    valid_markers = log.count(begin) == log.count(end) == 1 and log.index(begin) < log.index(end)
    span = log.split(begin, 1)[1].split(end, 1)[0] if valid_markers else ''
    cases = [x for x in ET.parse(xml).getroot().iter('testcase') if x.get('name') == case] if xml.exists() else []
    case_passed = len(cases) == 1 and all(cases[0].find(x) is None for x in ('failure', 'error', 'skipped'))
    allowed = valid_markers and case_passed and errors == [error] and span.count(error) == 1 and span.count(source) == 1
    return dict(unexpected=not allowed, expected_native_error_verified=allowed,
                case=case, expected_error=error, expected_source=source,
                actual_error_lines=errors, actual_case_passed=case_passed,
                marker_pair_unique=valid_markers,
                scope='Only treasure normal suite; exact native line/source/count plus passing GUT count+text assertions')


def validate_journal(path):
    """Once, after all handlers joined: complete rows and actual wire integers."""
    raw = path.read_text(encoding='utf8') if path.exists() else ''
    errors, rows = [], []
    if not raw or not raw.endswith('\n'):
        errors.append('Missing journal or incomplete final line')
    for number, line in enumerate(raw.splitlines(), 1):
        try:
            row = json.loads(line)
            if not isinstance(row, dict) or not isinstance(row.get('event'), str):
                raise ValueError('Complete row is not an event object')
            rows.append(row)
        except (ValueError, TypeError) as exc:
            errors.append(f'Row {number}: {type(exc).__name__}')
    expected = {
        'positive-select': dict(group='group-positive-select', revision=3, robots=['r-z', 'r-a']),
        'positive-confirm-duo': dict(group='group-positive-confirm-duo', risk=True, revision=3),
    }
    proof = []
    for case, wanted in expected.items():
        actual = [x for x in rows if x['event'] == 'request_begin' and x.get('method') == 'POST' and x.get('case') == case]
        valid = len(actual) == 1 and actual[0].get('body') == wanted and type(actual[0]['body'].get('revision')) is int
        if valid and 'risk' in wanted:
            valid = type(actual[0]['body'].get('risk')) is bool
        if not valid:
            errors.append('Actual wire body/integer/order mismatch: ' + case)
        proof.append(dict(case=case, passed=valid, body=actual[0].get('body') if len(actual) == 1 else None,
                          revision_type=type(actual[0]['body'].get('revision')).__name__ if len(actual) == 1 else None))
    return dict(passed=not errors, complete_row_count=len(rows), errors=errors,
                actual_wire_revision_proof=proof, events=rows,
                scope='One final JSON journal check, not a product assertion per poll/row')
