"""Locked action producer probe; construction qualification is not behavior acceptance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time
import traceback

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'AGENTS.md').is_file())
sys.path.insert(0,str(ROOT/'tests/godot'))
from process_owner import owned_run, identity
ENGINE=Path('C:/Users/alienware/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/PunkLegion/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
ENGINE_SHA='bd9e27c6994a128aaab45cdda4d372de87b91900618ba2de55c6aa29248d5b56'
GROUPS=['J1','J2','J3','R1','W1']
GD_SOURCES=['battle/simulation.gd','battle/field.gd','net/solo_mission.gd','loadout/catalog.gd','loadout/rules.gd']

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,v):Path(p).write_text(json.dumps(v,indent=2,ensure_ascii=False,allow_nan=False)+'\n',encoding='utf-8')
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def clean(j):return not j['timed_out'] and not j['job_pids_after_cleanup'] and not j['same_instances_still_alive']

def verify(lock):
    paths=sorted(str(p.resolve()) for base in ['game','services'] for p in (ROOT/base).rglob('*') if p.is_file() and not any(s in p.parts for s in ['.godot','__pycache__','.git']) and p.suffix!='.pyc')
    assert len(lock['production'])==515 and len(lock['protected'])==11
    assert sorted(lock['production'])==paths,'Production path set changed'
    mismatch={k:[p for p,d in lock[k].items() if not Path(p).is_file() or sha(p)!=d] for k in ['production','protected','tools','runtime']}
    assert not any(mismatch.values()),mismatch
    required=[HERE/n for n in ['probe.gd','probe.py','run.py','README.md']]+[ROOT/'tests/godot/README.md',ROOT/'tests/godot/process_owner.py']
    assert all(str(p.resolve()) in lock['tools'] for p in required),'Exact tool closure missing'
    assert lock['runtime'][str(ENGINE)]==ENGINE_SHA and str(Path(sys.executable).resolve()) in lock['runtime']
    assert str(ENGINE.with_name('Godot_v4.6.1-stable_win64.exe')) in lock['runtime']
    return mismatch

def phase(command,folder,deadline,maximum):
    remaining=deadline-time.monotonic()
    assert remaining>0,'Common work deadline exhausted'
    return owned_run(command,folder,dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),min(maximum,remaining))

def assert_job(job,folder):
    assert clean(job),'Owned job not clean'
    assert job['exit_code']==0,dict(exit_code=job['exit_code'],log=str(folder/'godot.log'))
    assert not re.search(r'SCRIPT ERROR|Parse Error|(^|\n)ERROR:',(folder/'godot.log').read_text(encoding='utf-8-sig')),'Engine/script error'

def prepare(work,run_id):
    stage=work/'project'
    for rel in GD_SOURCES:
        dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'game'/rel,dest)
    (stage/'qa').mkdir();shutil.copyfile(HERE/'probe.gd',stage/'qa/probe.gd')
    (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="PunkLegionActionContract"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="PunkLegionQA/'+run_id+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    manifest=dict(files={str(p.relative_to(stage)):sha(p) for p in stage.rglob('*') if p.is_file()},import_performed=False,cache_copied=False,expected_userdata=str(Path(os.environ['APPDATA'])/'PunkLegionQA'/run_id),userdata_basis='Configured only; not observed',data_source='New synthetic legal model constructors; no account, DB or old data')
    write(work/'stage-manifest.json',manifest)
    return stage,manifest

def worker(args,lock,work):
    start=time.monotonic()
    result=dict(passed=False,prepared=False,mode=args.mode,phases={},remaining_models=['godot','python'],worker_identity=identity(os.getpid()))
    try:
        query="[pscustomobject]@{free_kib=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory;processes=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^(Godot.*|adb|emulator|qemu-system.*|python.*)[.]exe$'} | Select-Object ProcessId,Name,CreationDate,ExecutablePath)} | ConvertTo-Json -Depth 5 -Compress"
        folder=work/'host-before';result['phases']['host_before']=job=phase(['powershell.exe','-NoProfile','-NonInteractive','-Command',query],folder,args.deadline,8)
        assert_job(job,folder);result['host_before']=read(folder/'godot.log')
        assert result['host_before']['free_kib']>=512*1024,'Insufficient memory'
        stage,manifest=prepare(work,args.run_id);result['stage']=manifest
        folder=work/'python-compile'
        code="from pathlib import Path;import sys;[compile(Path(p).read_text(encoding='utf-8'),p,'exec') for p in sys.argv[1:]];print('STATIC_COMPILE_OK')"
        result['phases']['python_compile']=job=phase([sys.executable,'-B','-c',code,str(HERE/'probe.py'),str(HERE/'run.py')],folder,args.deadline,5)
        assert_job(job,folder)
        folder=work/'check-only'
        result['phases']['check_only']=job=phase([str(ENGINE),'--headless','--path',str(stage),'--check-only','--script','res://qa/probe.gd'],folder,args.deadline,15)
        assert_job(job,folder)
        assert all(sha(stage/n)==d for n,d in manifest['files'].items()),'Stage drift'
        for model in ['godot','python']:
            report_path=work/(model+'-report.json')
            command=[str(ENGINE),'--headless','--path',str(stage),'--script','res://qa/probe.gd','--',str(report_path)] if model=='godot' else [sys.executable,'-B',str(HERE/'probe.py'),'--output',str(report_path)]
            if args.mode=='qualification':command.append('--fixture-only')
            folder=work/model;result['phases'][model]=job=phase(command,folder,args.deadline,20 if model=='godot' else 10)
            if not report_path.is_file():raise AssertionError('Missing '+model+' report')
            result[model]=report=read(report_path);result['remaining_models'].remove(model)
            if model=='python':assert report['actual_profile_imports'] and all(lock['production'].get(p)==d for p,d in report['actual_profile_imports'].items()),'Actual Python import drift'
            assert_job(job,folder)
            if args.mode=='qualification':
                assert report.get('prepared') is True and report.get('no_step') is True and report['passed'] is False and not report['groups'],'Qualification must not advance behavior'
                assert all(row['at']==0 for row in report['initial']),'Qualification advanced clock'
            else:assert report['passed'] is True and [row['name'] for row in report['groups']]==GROUPS and all(row['passed'] for row in report['groups']) and report['remaining']==[],'Incomplete/failed behavior contract'
        assert time.monotonic()<=args.deadline
        result['prepared' if args.mode=='qualification' else 'passed']=True
    except BaseException as exc:result['first_error']=dict(type=type(exc).__name__,message=str(exc),traceback=traceback.format_exc())
    finally:
        try:result['source_drift']=verify(lock)
        except BaseException as exc:result.update(passed=False,prepared=False,source_error=dict(type=type(exc).__name__,message=str(exc)))
        result['elapsed_seconds']=time.monotonic()-start
        result['resource_terminal']=dict(owned_jobs=[dict(phase=n,clean=clean(j),seen=j.get('seen',[]),remaining=j['job_pids_after_cleanup'],same_instances=j['same_instances_still_alive']) for n,j in result['phases'].items()],db_http_docker_adb=False)
        write(work/'worker-result.json',result)
    return 0 if result['passed'] or result['prepared'] else 1

def main():
    start=time.monotonic();p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-id',required=True);p.add_argument('--mode',choices=['qualification','formal'],required=True)
    p.add_argument('--input-lock',type=Path,required=True);p.add_argument('--approval',type=Path,required=True)
    p.add_argument('--worker',action='store_true',help=argparse.SUPPRESS);p.add_argument('--deadline',type=float,help=argparse.SUPPRESS)
    args=p.parse_args();assert re.fullmatch(r'[a-z0-9][a-z0-9-]{3,80}',args.run_id)
    work=ROOT/'build/qa'/args.run_id;lock,grant=read(args.input_lock),read(args.approval)
    assert grant['approved'] is True and grant['input_lock_sha256']==sha(args.input_lock) and grant['mode']==args.mode
    assert grant['work']==work.relative_to(ROOT).as_posix() and grant['case_names']==GROUPS
    verify(lock)
    if args.worker:
        assert args.deadline and work.is_dir();return worker(args,lock,work)
    assert not work.exists(),'Fresh run directory required'
    work.mkdir();seconds=30 if args.mode=='qualification' else 60;hard=40 if args.mode=='qualification' else 75
    argv=[sys.executable,'-B',str(Path(__file__).resolve()),'--run-id',args.run_id,'--mode',args.mode,'--input-lock',str(args.input_lock.resolve()),'--approval',str(args.approval.resolve()),'--worker','--deadline',str(start+seconds)]
    result=dict(passed=False,prepared=False,mode=args.mode,owner_identity=identity(os.getpid()),input_lock_sha256=sha(args.input_lock),approval_sha256=sha(args.approval),budget=dict(work=seconds,worker_hard=hard-5,owner_hard=hard))
    try:
        result['job']=owned_run(argv,work/'owner',dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),max(.01,start+hard-5-time.monotonic()))
        report=read(work/'worker-result.json');accepted=clean(result['job']) and result['job']['exit_code']==0
        result['passed']=accepted and report['passed'];result['prepared']=accepted and report['prepared']
    except BaseException as exc:result['first_error']=dict(type=type(exc).__name__,message=str(exc),traceback=traceback.format_exc())
    finally:
        try:result['source_drift']=verify(lock)
        except BaseException as exc:result.update(passed=False,prepared=False,source_error=dict(type=type(exc).__name__,message=str(exc)))
        result['elapsed_seconds']=time.monotonic()-start
        if time.monotonic()>start+hard:result.update(passed=False,prepared=False,budget_exceeded=True)
        write(work/'result.json',result)
    print(json.dumps(dict(passed=result['passed'],prepared=result['prepared'],work=str(work))))
    return 0 if result['passed'] or result['prepared'] else 1

if __name__=='__main__':raise SystemExit(main())
