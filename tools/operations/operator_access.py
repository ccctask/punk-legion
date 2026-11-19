"""One operator request in one owned sidecar; no business retry or credential argv."""
import argparse
from contextlib import contextmanager
from decimal import Decimal
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from operator_store import StoreFailure, initialize, load, require, save_new, sha
from operator_process import owned_capture

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'AGENTS.md').is_file())
STABLE = ROOT / 'build/private-beta/operations/1077-operator-r1'
PROJECT = 'punk-private-beta-1077-operator-r1'
IMAGE = 'sha256:dc6fda7547e249e2734ddd3bc4b781af9598436e1898b3b9f9b2cf2ee726acc8'
CURRENT_DB = 'punk-private-beta-1076-delivery-r2_player-profiles'
QUEUES = {'room': 'room-results', 'solo': 'solo-missions', 'party': 'party-missions', 'camp': 'camp-battles'}
IDENT = re.compile(r'[A-Za-z0-9_-]{8,96}')


def host_path(value):
    """Recognize only explicit Windows drive / Docker Desktop host translations."""
    value = value.replace('\\', '/').rstrip('/')
    for prefix in ('/run/desktop/mnt/host/', '/host_mnt/'):
        if value.startswith(prefix):
            tail = value[len(prefix):]
            if re.match(r'^[A-Za-z]/', tail):
                value = tail[0] + ':' + tail[1:]
            break
    return value.lower() if re.match(r'^[A-Za-z]:/', value) else value


def mounts_by_destination(mounts):
    require(len({x['Destination'] for x in mounts}) == len(mounts), 'Duplicate mount destination')
    return {x['Destination']: x for x in mounts}


def check_owner(value, config):
    labels = value['Config']['Labels']
    require(labels.get('com.docker.compose.project') == PROJECT
            and labels.get('com.docker.compose.service') == 'operator'
            and host_path(labels.get('com.docker.compose.project.config_files', '')) == host_path(str(config))
            and host_path(labels.get('com.docker.compose.project.working_dir', '')) == host_path(str(STABLE)),
            'Container ownership/config labels mismatch')


def check_identity(value, config, expected, rw):
    check_owner(value, config)
    require(value['Image'] == IMAGE, 'Container ImageID mismatch')
    hc = value['HostConfig']
    require(hc['ReadonlyRootfs'] is True and hc['NetworkMode'] == 'none' and hc['Init'] is True,
            'Root/network/init isolation mismatch')
    require(not hc.get('PortBindings') and not value['NetworkSettings'].get('Ports'), 'Host ports forbidden')
    require(hc['Memory'] == 134217728 and Decimal(str(hc['NanoCpus'])) == Decimal(250000000)
            and hc['RestartPolicy']['Name'] == 'no', 'Resource/restart mismatch')
    actual = mounts_by_destination(value['Mounts'])
    require(set(actual) == set(expected), 'Mount inventory mismatch')
    for dest, spec in expected.items():
        m = actual[dest]
        require(m['Type'] == spec['type'] and m['RW'] is (rw if dest == '/data' else False),
                'Mount type/permission mismatch: ' + dest)
        require((m['Name'] == spec['source']) if spec['type'] == 'volume'
                else host_path(m['Source']) == host_path(spec['source']), 'Mount source mismatch: ' + dest)
    require(value['Config']['Cmd'] == ['python', '-B', '-u', '/app/operator_service.py'], 'Entrypoint command mismatch')
    require(value['Config'].get('Entrypoint') in (None, []), 'Unexpected image entrypoint')
    environment = dict(x.split('=', 1) for x in value['Config']['Env'])
    require(all(environment.get(name) == '/queues/' + queue for name, queue in
                {'SOLO_SPOOL_DIR': 'solo', 'PARTY_SPOOL_DIR': 'party', 'CAMP_SPOOL_DIR': 'camp', 'ROOM_OUTBOX_DIR': 'room'}.items()),
            'Spool environment mismatch')
    return actual


@contextmanager
def machine_lock():
    import msvcrt
    with (STABLE / 'operator.lock').open('a+b') as f:
        if f.tell() == 0:
            f.write(b'1'); f.flush()
        f.seek(0)
        msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            f.seek(0); msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='action', required=True)
    init = sub.add_parser('init-credentials')
    init.add_argument('--store', type=Path, required=True)
    init.add_argument('--scope', choices=['current', 'qa'], required=True)
    for action in ('diagnose', 'compensate'):
        s = sub.add_parser(action)
        s.add_argument('--store', type=Path, required=True)
        s.add_argument('--scope', choices=['current', 'qa'], required=True)
        s.add_argument('--db-volume', required=True)
        s.add_argument('--out', type=Path, required=True)
        s.add_argument('--incident', required=True)
        if action == 'diagnose':
            s.add_argument('--role', choices=['viewer', 'compensator'], default='viewer')
        else:
            s.add_argument('--owner', required=True)
            s.add_argument('--key', required=True)
            s.add_argument('--reason', choices=['missed_reward', 'duplicate_charge', 'rollback_reconciliation'], required=True)
            s.add_argument('--resource', choices=['structure', 'components', 'energy'], required=True)
            s.add_argument('--amount', type=int, choices=range(1, 4), required=True)
    return p


def make_config(args, policy):
    config = json.loads((STABLE / 'compose.template.json').read_text('utf-8'))
    service = config['services']['operator']
    rw = args.action == 'compensate' or args.role == 'compensator'
    if args.scope == 'qa':
        require(re.fullmatch(r'punk-operator-qa-[a-z0-9][a-z0-9-]*-player-profiles', args.db_volume) is not None,
                'QA requires punk-operator-qa-<new-run-id>-player-profiles namespace')
        prefix = args.db_volume.removesuffix('-player-profiles')
        for queue, suffix in QUEUES.items():
            config['volumes'][queue]['name'] = prefix + '-' + suffix
    else:
        require(args.db_volume == CURRENT_DB, 'Current scope requires the accepted current DB volume')
    expected = {}
    for item in service['volumes']:
        if item['target'] == '/data':
            item['source'] = args.db_volume
            item['read_only'] = not rw
            config['volumes']['database']['name'] = args.db_volume
            # Compose service source references the external volume's logical key.
            item['source'] = 'database'
            expected['/data'] = {'type': 'volume', 'source': args.db_volume}
        elif item['type'] == 'bind':
            item['source'] = str(policy if item['target'] == '/run/operator.policy.json' else STABLE / item['source'])
            expected[item['target']] = {'type': 'bind', 'source': item['source']}
        else:
            expected[item['target']] = {'type': 'volume', 'source': config['volumes'][item['source']]['name']}
    return config, expected, rw


def run(args):
    require(os.name == 'nt', 'Windows operator host required')
    role = 'compensator' if args.action == 'compensate' else args.role
    require(IDENT.fullmatch(args.incident) is not None, 'Invalid incident')
    if args.action == 'compensate':
        require(IDENT.fullmatch(args.owner) is not None and IDENT.fullmatch(args.key) is not None, 'Invalid owner/key')
    require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]+', args.db_volume) is not None, 'Explicit existing named DB volume required')
    require((args.db_volume == CURRENT_DB) if args.scope == 'current' else args.db_volume != CURRENT_DB,
            'Scope/database volume mismatch')
    token, policy_bytes = load(args.store, role, args.scope)  # All secrets fail before Docker.
    locks = json.loads((STABLE / 'source-lock.json').read_text('utf-8'))
    for rel, expected_sha in locks['files'].items():
        require(sha((STABLE / rel).read_bytes()) == expected_sha, 'Stable source changed: ' + rel)
    out = args.out.resolve()
    require(out.is_relative_to(ROOT / 'build/qa') and not out.exists(), 'Explicit new build/qa output required')
    out.mkdir(parents=True, exist_ok=False)
    policy = out / 'operator.policy.json'
    request = {'method': 'GET', 'route': '/ops/battles/' + args.incident, 'fields': {}, 'token': token}
    if args.action == 'compensate':
        request.update(method='POST', route='/ops/compensations', fields={k: getattr(args, k) for k in ('owner', 'incident', 'reason', 'key', 'resource', 'amount')})
    config, expected, rw = make_config(args, policy)
    config_path = out / 'compose.json'
    save_new(config_path, config)
    base = ['docker', 'compose', '--project-directory', str(STABLE), '-p', PROJECT, '-f', str(config_path)]
    report = {'role': role, 'scope': args.scope, 'db_volume': args.db_volume, 'db_rw': rw,
              'commands': [], 'request_state': 'not_sent', 'cleanup_errors': [], 'container_id': None}
    started = time.monotonic()
    deadline = started + 120
    primary = None
    attempted_up = False
    cid = None
    cleanup_deadline = None

    def redact(value):
        return value.replace(token, '[REDACTED OPERATOR TOKEN]')

    def command(argv, *, stdin=None, timeout=15, cleanup=False, allow_failure=False):
        budget = (cleanup_deadline if cleanup else deadline) - time.monotonic()
        require(budget > 0, 'Operator execution budget exhausted')
        item = {'argv': argv, 'started_monotonic': time.monotonic()}
        report['commands'].append(item)
        try:
            cp = owned_capture(argv, input=stdin, capture_output=True, text=True, encoding='utf-8', errors='replace',
                                timeout=min(timeout, budget), cwd=ROOT)
            item.update(exit=cp.returncode, stdout=redact(cp.stdout), stderr=redact(cp.stderr))
            item['ownership'] = getattr(cp, 'ownership', None)
        except subprocess.TimeoutExpired as exc:
            def text(x):
                return x.decode('utf-8', 'replace') if isinstance(x, bytes) else (x or '')
            item.update(timeout=True, stdout=redact(text(exc.stdout)), stderr=redact(text(exc.stderr)))
            raise RuntimeError('Command timeout; inspect same operation, never retry business request') from None
        finally:
            item['elapsed_seconds'] = time.monotonic() - item['started_monotonic']
        require(allow_failure or cp.returncode == 0, 'Command failed: ' + ' '.join(argv[:3]))
        return cp.stdout

    def find_ids(cleanup=False):
        return command(['docker', 'ps', '-a', '--no-trunc', '--filter', 'label=com.docker.compose.project=' + PROJECT,
                        '--format', '{{.ID}}'], cleanup=cleanup).split()

    try:
        policy.write_bytes(policy_bytes)
        require(not find_ids(), 'Operator project already has a container; do not create or clean someone else')
        # External volume lookup rejects missing volumes instead of silently creating a DB.
        for spec in expected.values():
            if spec['type'] == 'volume':
                command(['docker', 'volume', 'inspect', spec['source']])
        image = json.loads(command(['docker', 'image', 'inspect', IMAGE]))[0]
        require(image['Id'] == IMAGE, 'Local immutable image missing/mismatched')
        attempted_up = True
        command(base + ['up', '-d', '--no-build', '--pull', 'never', 'operator'], timeout=30)
        ids = find_ids()
        require(len(ids) == 1, 'Exactly one owned operator container required')
        cid = ids[0]; report['container_id'] = cid
        info = json.loads(command(['docker', 'inspect', cid]))[0]
        report['container_before'] = info
        report['mounts_by_destination'] = check_identity(info, config_path, expected, rw)
        require(info['State']['Running'], 'Operator failed before request; inspect logs for schema/entry error')
        if request['method'] == 'POST':
            # Durable non-secret record before the one possible write invocation.
            save_new(out / 'submission.json', {'key': args.key, 'fields': request['fields'],
                     'parameter_sha256': sha(json.dumps(request['fields'], sort_keys=True, separators=(',', ':')).encode()),
                     'state': 'about_to_submit_once; outcome must be read from result.json'})
            report['request_state'] = 'unknown'
        raw = command(['docker', 'exec', '-i', cid, 'python', '-B', '/app/operator_client.py'],
                      stdin=json.dumps(request), timeout=35, allow_failure=True)
        result = json.loads(redact(raw))
        report['response'] = result
        report['request_state'] = result['state']
        require(result['state'] == 'responded', 'No confirmed HTTP outcome; preserve original key/fingerprint')
        require(result['status'] == 200, 'Operator HTTP request rejected')
        if request['method'] == 'POST':
            receipt = result['body']['receipt']
            require(receipt['operation'] == 'ops_credit' and receipt['incident'] == args.incident,
                    'Unexpected compensation receipt')
            report['actual_receipt'] = receipt  # changes, never requested, is actual credit.
    except BaseException as exc:
        primary = {'type': type(exc).__name__, 'reason': redact(str(exc))}
        report['primary_error'] = primary
    finally:
        # Separate cleanup budget, including after an execution timeout. No new sampling/write retry.
        cleanup_start = time.monotonic()
        cleanup_deadline = cleanup_start + 60
        if attempted_up:
            try:
                ids = find_ids(cleanup=True)
                require(len(ids) <= 1, 'Ambiguous operator project; no broad cleanup')
                for current in ids:
                    info = json.loads(command(['docker', 'inspect', current], cleanup=True))[0]
                    # Before deleting, prove this exact project/config/working-directory and source.
                    check_owner(info, config_path)
                    if cid is not None:
                        require(current == cid, 'Operator CID changed; refuse cleanup of replacement')
                    report['container_final'] = info
                    try:
                        command(['docker', 'logs', current], cleanup=True, timeout=10, allow_failure=True)
                    except Exception as exc:
                        report['cleanup_errors'].append({'type': type(exc).__name__, 'reason': 'Log capture failed; continuing owned teardown'})
                command(base + ['down', '--timeout', '20'], timeout=30, cleanup=True)
                report['remaining_ids'] = find_ids(cleanup=True)
                require(not report['remaining_ids'], 'Exited operator container remains')
            except BaseException as exc:
                report['cleanup_errors'].append({'type': type(exc).__name__, 'reason': redact(str(exc))})
        try:
            policy.unlink(missing_ok=True)
        except OSError as exc:
            report['cleanup_errors'].append({'type': type(exc).__name__, 'reason': 'Temporary policy removal failed'})
        report['temporary_policy_removed'] = not policy.exists()
        report['cleanup_seconds'] = time.monotonic() - cleanup_start
        report['elapsed_seconds'] = time.monotonic() - started
        report['passed'] = primary is None and not report['cleanup_errors']
        save_new(out / 'result.json', report)
    return 0 if report['passed'] else 1


def main(argv=None):
    args = parser().parse_args(argv)
    if args.action == 'init-credentials':
        initialize(args.store, args.scope)
        print('Operator store initialized; tokens are not displayed.')
        return 0
    with machine_lock():
        return run(args)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except StoreFailure as exc:
        print('Operator store rejected: ' + json.dumps(exc.details, ensure_ascii=True), file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        # Preflight failures contain no decrypted values; never print a traceback/local variables.
        print('Operator preflight rejected: ' + type(exc).__name__, file=sys.stderr)
        sys.exit(1)
