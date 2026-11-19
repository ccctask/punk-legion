"""A separately approved, immutable-source catalog run with a fresh minimal stage."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time
import traceback

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'AGENTS.md').is_file())
sys.path.insert(0, str(ROOT / 'tests/godot'))
from process_owner import owned_run, identity
import contract

ENGINE = Path('C:/Users/alienware/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/PunkLegion/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
ENGINE_SHA = 'bd9e27c6994a128aaab45cdda4d372de87b91900618ba2de55c6aa29248d5b56'


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def read(path): return json.loads(Path(path).read_text(encoding='utf-8'))
def drift(files): return [p for p, digest in files.items() if not Path(p).is_file() or contract.sha(p) != digest]
def clean(job): return not job['timed_out'] and not job['job_pids_after_cleanup'] and not job['same_instances_still_alive']


def production_files():
    return sorted(str(p.resolve()) for base in ['game', 'services'] for p in (ROOT / base).rglob('*')
                  if p.is_file() and not any(s in p.parts for s in ['.godot', '__pycache__', '.git']) and p.suffix != '.pyc')


def verify(lock):
    mismatch = {key: drift(lock[key]) for key in ['inputs', 'other_sources', 'protected']}
    assert not any(mismatch.values()), mismatch
    assert production_files() == sorted(lock['production_files']), 'Production file set changed'
    return mismatch


def prepare(work, run_id):
    stage = work / 'project'
    (stage / 'loadout').mkdir(parents=True)
    (stage / 'qa').mkdir()
    for name in ['catalog.gd', 'rules.gd']:
        shutil.copyfile(ROOT / 'game/loadout' / name, stage / 'loadout' / name)
    shutil.copyfile(HERE / 'export_catalog.gd', stage / 'qa/export_catalog.gd')
    (stage / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="PunkLegionCatalogContract"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="PunkLegionQA/' + run_id + '"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    write(work / 'fixture.json', contract.fixture())
    manifest = dict(stage_files={str(p.relative_to(stage)): contract.sha(p) for p in stage.rglob('*') if p.is_file()},
                    fixture_sha256=contract.sha(work / 'fixture.json'), import_performed=False, cache_copied=False,
                    expected_userdata=str(Path(os.environ['APPDATA']) / 'PunkLegionQA' / run_id), userdata_basis='Configured custom_user_dir, not an observed engine path', data_source='This run generated synthetic trusted inputs, no account/DB/old user data')
    write(work / 'stage-manifest.json', manifest)
    return stage, manifest


def phase(command, out, deadline, maximum):
    remaining = deadline - time.monotonic()
    assert remaining > 0, 'Common work deadline exhausted'
    return owned_run(command, out, dict(os.environ, PYTHONDONTWRITEBYTECODE='1'), min(maximum, remaining))


def host(work, deadline):
    script = "[pscustomobject]@{free_kib=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory;processes=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^(Godot.*|adb|emulator|qemu-system.*|python.*)[.]exe$'} | Select-Object ProcessId,Name,CreationDate,ExecutablePath)} | ConvertTo-Json -Depth 5 -Compress"
    job = phase(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script], work / 'host-before', deadline, 8)
    assert clean(job) and job['exit_code'] == 0
    value = json.loads((work / 'host-before/godot.log').read_text(encoding='utf-8-sig'))
    assert value['free_kib'] >= 512 * 1024
    return dict(job=job, snapshot=value)


def worker(args, lock, work):
    began = time.monotonic()
    result = dict(passed=False, phases={}, started_utc=time.time(), worker_identity=identity(os.getpid()))
    try:
        result['host_before'] = host(work, args.deadline)
        stage, manifest = prepare(work, args.run_id)
        result['stage'] = manifest
        check = [str(args.engine), '--headless', '--path', str(stage), '--check-only', '--script', 'res://qa/export_catalog.gd']
        result['phases']['check_only'] = phase(check, work / 'check-only', args.deadline, 20)
        assert clean(result['phases']['check_only']) and result['phases']['check_only']['exit_code'] == 0
        assert not re.search(r'SCRIPT ERROR|Parse Error|(^|\n)ERROR:', (work / 'check-only/godot.log').read_text(encoding='utf-8'))
        for name, digest in manifest['stage_files'].items(): assert contract.sha(stage / name) == digest
        export = work / 'catalog-export.json'
        actual = [str(args.engine), '--headless', '--path', str(stage), '--script', 'res://qa/export_catalog.gd', '--', str(work / 'fixture.json'), str(export)]
        result['phases']['export'] = phase(actual, work / 'export', args.deadline, 30)
        assert clean(result['phases']['export']) and result['phases']['export']['exit_code'] == 0
        assert not re.search(r'SCRIPT ERROR|Parse Error|(^|\n)ERROR:', (work / 'export/godot.log').read_text(encoding='utf-8'))
        result['comparison'] = contract.evaluate(export, work / 'fixture.json')
        write(work / 'comparison.json', result['comparison'])
        missing = work / 'never-produced.json'
        assert not missing.exists()
        command = [sys.executable, '-B', str(HERE / 'contract.py'), '--compare-only', '--export', str(missing), '--fixture', str(work / 'fixture.json'), '--report', str(work / 'missing-export.json')]
        result['phases']['missing_export'] = job = phase(command, work / 'missing-export-cli', args.deadline, 5)
        rejected = read(work / 'missing-export.json')
        assert clean(job) and job['exit_code'] == 3
        assert rejected == dict(passed=False, rejection=dict(kind='MissingExport', path=str(missing)))
        result['missing_export_control'] = dict(passed=False, control_satisfied=True, original=rejected)
        actual_imports = {str(Path(m.__file__).resolve()): contract.sha(m.__file__) for m in list(sys.modules.values())
                          if getattr(m, '__file__', None) and Path(m.__file__).resolve().parent == (ROOT / 'services/profile').resolve()}
        frozen = dict(lock['other_sources'], **lock['inputs'])
        assert actual_imports and all(frozen.get(p) == digest for p, digest in actual_imports.items())
        result['actual_profile_imports'] = actual_imports
        assert time.monotonic() <= args.deadline
        result['passed'] = True
    except BaseException as exc:
        result['first_error'] = dict(type=type(exc).__name__, message=str(exc), traceback=traceback.format_exc())
    finally:
        try: result['source_drift'] = verify(lock)
        except BaseException as exc:
            result['passed'] = False
            result['source_error'] = dict(type=type(exc).__name__, message=str(exc))
        result['elapsed_seconds'] = time.monotonic() - began
        result['no_db_http_enet_docker_adb'] = True
        write(work / 'worker-result.json', result)
    return 0 if result['passed'] else 1


def main():
    began = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--engine', type=Path, default=ENGINE)
    parser.add_argument('--input-lock', type=Path, required=True)
    parser.add_argument('--approval', type=Path, required=True)
    parser.add_argument('--worker', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--deadline', type=float, help=argparse.SUPPRESS)
    args = parser.parse_args()
    assert re.fullmatch(r'[a-z0-9][a-z0-9-]{3,80}', args.run_id)
    assert args.engine.is_file() and contract.sha(args.engine) == ENGINE_SHA
    lock, grant = read(args.input_lock), read(args.approval)
    work = ROOT / 'build/qa' / args.run_id
    assert grant['approved'] is True and grant['input_lock_sha256'] == contract.sha(args.input_lock)
    assert grant['work'] == work.relative_to(ROOT).as_posix() and grant['case_names'] == contract.CASE_NAMES
    verify(lock)
    if args.worker:
        assert args.deadline and work.is_dir()
        return worker(args, lock, work)
    assert not work.exists(), 'New run directory required; never overwrite evidence'
    work.mkdir()
    hard_stop = began + 75
    argv = [sys.executable, '-B', str(Path(__file__).resolve()), '--run-id', args.run_id, '--engine', str(args.engine.resolve()),
            '--input-lock', str(args.input_lock.resolve()), '--approval', str(args.approval.resolve()), '--worker', '--deadline', str(began + 60)]
    result = dict(passed=False, owner_identity=identity(os.getpid()), started_utc=time.time(), input_lock_sha256=contract.sha(args.input_lock), approval_sha256=contract.sha(args.approval),
                  budget=dict(work_seconds=60, cleanup_seconds=15, hard_seconds=75), argv=argv)
    try:
        result['job'] = owned_run(argv, work / 'owner', dict(os.environ, PYTHONDONTWRITEBYTECODE='1'), max(.01, hard_stop - 5 - time.monotonic()))
        report = read(work / 'worker-result.json')
        result['passed'] = clean(result['job']) and result['job']['exit_code'] == 0 and report['passed']
    except BaseException as exc:
        result['first_error'] = dict(type=type(exc).__name__, message=str(exc), traceback=traceback.format_exc())
    finally:
        try: result['source_drift'] = verify(lock)
        except BaseException as exc:
            result['passed'] = False
            result['source_error'] = dict(type=type(exc).__name__, message=str(exc))
        result['elapsed_seconds'] = time.monotonic() - began
        result['passed'] = bool(result['passed'] and time.monotonic() <= hard_stop)
        write(work / 'result.json', result)
    print(json.dumps(dict(passed=result['passed'], work=str(work))))
    return 0 if result['passed'] else 1


if __name__ == '__main__': raise SystemExit(main())
