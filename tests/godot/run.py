"""Select three production-code GUT groups in an isolated dependency-closed project."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
import threading
import xml.etree.ElementTree as ET
import zipfile
from process_owner import owned_run, identity
from http_fixture import Fixture

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
ENGINE=Path('C:/Users/alienware/AppData/Local/PunkLegion/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
ENGINE_SHA='bd9e27c6994a128aaab45cdda4d372de87b91900618ba2de55c6aa29248d5b56'
ROOTS=['loadout/rules.gd','net/party_mission.gd','party/lobby.tscn','owned/apply_preview.tscn','camp/defense_alerts.tscn']
GROUPS={'rules':'test_rules.gd','scene':'test_scene.gd','async':'test_async.gd','alerts':'test_alerts.gd','treasure':'test_treasure.gd','refresh':'test_refresh.gd','refresh_pages':'test_refresh_pages.gd','refresh_loot':'test_refresh_loot.gd','motion':'test_motion.gd','authority_motion':'test_authority_motion.gd'}
EXPECTED={'rules':3,'scene':1,'async':2,'alerts':3,'treasure':15,'refresh':7,'refresh_pages':5,'refresh_loot':1,'motion':12,'authority_motion':16}
OPTIONAL_RES={'runtime_endpoints.cfg':'Endpoints checks file existence; optional release endpoint configuration is absent in the non-private-beta isolated pilot'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text('utf8'))

def checked_engine(value):
    path=Path(value).expanduser().resolve()
    if not path.is_file():
        raise ValueError('Godot engine file not found: '+str(path)+'; pass --engine with the pinned Godot 4.6.1 console executable')
    if sha(path)!=ENGINE_SHA:
        raise ValueError('Godot engine SHA256 mismatch: '+str(path)+'; expected '+ENGINE_SHA)
    return path


def verify_engine_identity(manifest):
    assert manifest.get('console_launcher_sha256')==ENGINE_SHA,'Workspace engine SHA256 differs; prepare a new run-id'
    assert manifest.get('console_launcher') and Path(manifest['console_launcher']).resolve()==ENGINE,'Workspace engine path differs from --engine; prepare a new run-id'


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2),'utf8')

def file_map(folder):
    return {p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*')
        if p.is_file() and '.godot' not in p.relative_to(folder).parts}

def profile_sources():
    return {p.relative_to(ROOT).as_posix():sha(p) for p in (ROOT/'services/profile').rglob('*')
            if p.is_file() and p.suffix in ('.py','.json') and not p.name.startswith('check') and '__pycache__' not in p.parts}


def protected(groups=None):
    frozen=ROOT/'build/private-beta/snapshots/rc-1076'
    game=closure(['client/page_refresh.tscn'],base_roots=[]) if groups==['refresh'] else file_map(ROOT/'game')
    result=dict(game=game,snapshot=file_map(frozen),
        apk_sha256=sha(ROOT/'build/private-beta/PunkLegion-beta-1076.apk'))
    if groups in (['refresh_pages'],['refresh_loot']):result['profile_sources']=profile_sources()
    if groups==['refresh_loot']:result['solo_server_settings_sha256']=sha(ROOT/'deploy/server.godot')
    return result

def inventory(timeout=20):
    command="@{free_kib=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory;processes=@(Get-CimInstance Win32_Process|Where-Object {$_.Name -match '^(godot.*|adb|emulator|qemu-system.*)[.]exe$'}|Select-Object ProcessId,ParentProcessId,Name)}|ConvertTo-Json -Depth 4"
    return json.loads(subprocess.check_output(['powershell.exe','-NoProfile','-NonInteractive','-Command',command],timeout=timeout).decode('utf8'))

def closure(extra_roots=(),base_roots=None):
    pending=list(ROOTS if base_roots is None else base_roots)+list(extra_roots);found={}
    while pending:
        relative=pending.pop()
        if relative in found:continue
        path=ROOT/'game'/relative
        assert path.is_file() and path.resolve().is_relative_to((ROOT/'game').resolve()),relative
        found[relative]=sha(path)
        if base_roots==['project.godot']:
            for suffix in ('.uid','.import'):
                sidecar=Path(str(path)+suffix)
                if sidecar.is_file():pending.append(sidecar.relative_to(ROOT/'game').as_posix())
        if path.suffix in ('.gd','.tscn','.tres','.godot'):
            for target in re.findall(r'res://([^"\s\)]+)',path.read_text('utf8')):
                if not (ROOT/'game'/target).is_file():
                    assert target in OPTIONAL_RES,(relative,target)
                    continue
                pending.append(target)
    return found

def root_for(run_id):
    assert re.fullmatch('[a-z0-9][a-z0-9-]{0,80}',run_id)
    return ROOT/'build/qa'/run_id

def verify_project(folder):
    manifest=read(folder/'manifest.json');stage=folder/'project'
    verify_engine_identity(manifest)
    assert sha(ENGINE)==ENGINE_SHA
    assert protected(manifest.get('selected_groups',list(manifest['groups'])))==read(folder/'protected-before.json'),'Production source, frozen input or APK changed'
    assert all(sha(stage/key)==value for key,value in manifest['project_files'].items())
    assert all(sha(ROOT/'game'/key)==value for key,value in manifest['production_closure'].items())
    if manifest.get('selected_groups') in (['refresh_pages'],['refresh_loot']):
        assert profile_sources()==manifest['profile_sources'],'Real Handler production closure changed'
        assert all(sha(HERE/name)==digest for name,digest in manifest['page_fixture_sources'].items())
    for name in ['support.gd',*manifest['groups'].values()]:
        assert sha(stage/'qa'/name)==sha(HERE/name),'Workspace test changed after staging: '+name
    return manifest

def prepare(run_id,groups):
    folder=root_for(run_id);assert not folder.exists(),'Never overwrite a previous run workspace'
    started=time.monotonic();pre=inventory()
    assert pre['free_kib']>=4200000 and not pre['processes'],'One Godot/editor at a time, no ADB/AVD pre-existing'
    assert sha(ENGINE)==ENGINE_SHA
    folder.mkdir(parents=True)
    write(folder/'protected-before.json',protected(groups));write(folder/'host-before.json',pre)
    assert groups and all(g in GROUPS for g in groups)
    assert 'treasure' not in groups or groups==['treasure'],'M24 is a single isolated selected suite'
    assert 'refresh' not in groups or groups==['refresh'],'M01 refresh is a single isolated selected suite'
    assert 'refresh_pages' not in groups or groups==['refresh_pages'],'M01 pages are an exclusive actual-scene suite'
    assert 'refresh_loot' not in groups or groups==['refresh_loot'],'G is an exclusive real Solo suite'
    assert 'motion' not in groups or groups==['motion'],'M04 motion is an exclusive component/scene suite'
    assert 'authority_motion' not in groups or groups==['authority_motion'],'B authority motion is an exclusive rule suite'
    enabled={'authority_motion':GROUPS['authority_motion']} if groups==['authority_motion'] else {'motion':GROUPS['motion']} if groups==['motion'] else {'refresh_loot':GROUPS['refresh_loot']} if groups==['refresh_loot'] else {'refresh_pages':GROUPS['refresh_pages']} if groups==['refresh_pages'] else {'refresh':GROUPS['refresh']} if groups==['refresh'] else {key:value for key,value in GROUPS.items() if key not in ('refresh','refresh_pages','refresh_loot','motion','authority_motion') and (key!='treasure' or 'treasure' in groups)}
    page_roots=['profile/profile.tscn','base/base.tscn','owned/workshop.tscn','store/store.tscn','world/world.tscn','friends/friends.tscn']
    motion_roots=['battle/motion_track.tscn','battle/unit.tscn','expedition/expedition.tscn','armory/outing.tscn','pump/outing.tscn','factory/outing.tscn']
    authority_roots=['net/solo_mission.gd','net/party_mission.gd','net/armory_mission.gd','net/pump_mission.gd','net/factory_mission.gd','net/camp_mission.gd','net/exercise.gd']
    extra_roots=authority_roots if groups==['authority_motion'] else motion_roots if groups==['motion'] else ['owned/workshop.tscn'] if groups==['refresh_loot'] else page_roots if groups==['refresh_pages'] else ['client/page_refresh.tscn'] if groups==['refresh'] else ['treasure/treasure.tscn'] if 'treasure' in groups else []
    production_roots=['project.godot',*authority_roots] if groups==['authority_motion'] else ['project.godot',*motion_roots] if groups==['motion'] else ['project.godot','owned/workshop.tscn'] if groups==['refresh_loot'] else ['project.godot',*page_roots] if groups==['refresh_pages'] else extra_roots if groups==['refresh'] else ROOTS+extra_roots
    stage=folder/'project';stage.mkdir();sources=closure(extra_roots,base_roots=['project.godot'] if groups in (['refresh_pages'],['refresh_loot'],['motion'],['authority_motion']) else [] if groups==['refresh'] else None)
    for relative,digest in sources.items():
        target=stage/relative;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/'game'/relative,target);assert sha(target)==digest
    qa=stage/'qa';qa.mkdir()
    for name in ['support.gd',*enabled.values()]:shutil.copyfile(HERE/name,qa/name)
    if groups==['refresh_loot']:shutil.copyfile(HERE/'refresh_solo_host.gd',qa/'refresh_solo_host.gd')
    (qa/'empty').mkdir();control=qa/'control';control.mkdir()
    (control/'test_pending.gd').write_text('extends GutTest\nfunc test_required_case_is_pending():\n\tpending("Expected guard rejection, not product coverage")\n','utf8')
    lock=read(HERE/'vendor/gut.lock.json');archive=HERE/'vendor/gut-9.6.1.zip'
    assert lock['version']=='9.6.1' and sha(archive)==lock['archive_sha256']
    prefix='Gut-'+lock['commit']+'/addons/gut/'
    with zipfile.ZipFile(archive) as package:
        for item in package.infolist():
            if not item.filename.startswith(prefix) or item.is_dir():continue
            relative='addons/gut/'+item.filename[len(prefix):]
            target=stage/relative;assert target.resolve().is_relative_to((stage/'addons/gut').resolve())
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(package.read(item))
    user_dir='PunkLegionQA/GutPilot/'+run_id
    (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="PunkLegion Isolated GUT Pilot"\nconfig/features=PackedStringArray("4.6", "GL Compatibility")\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+user_dir+'"\n[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=540\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n','utf8')
    if groups in (['refresh_pages'],['refresh_loot'],['motion'],['authority_motion']):
        project=(ROOT/'game/project.godot').read_text('utf8')
        project=project.replace('config/name="PunkLegion"','config/name="PunkLegion"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+user_dir+'"')
        if groups==['refresh_loot']:
            assert 'common/physics_ticks_per_second=20' in (ROOT/'deploy/server.godot').read_text('utf8')
            if re.search(r'^common/physics_ticks_per_second=',project,re.M):project=re.sub(r'^common/physics_ticks_per_second=.*$', 'common/physics_ticks_per_second=20',project,flags=re.M)
            elif '[physics]' in project:project=project.replace('[physics]','[physics]\ncommon/physics_ticks_per_second=20')
            else:project+='\n[physics]\ncommon/physics_ticks_per_second=20\n'
        (stage/'project.godot').write_text(project,'utf8')
    write(folder/'manifest.json',dict(source_ref='current workspace exact dependency closure',production_roots=production_roots,selected_groups=groups,
        production_closure=sources,profile_sources=profile_sources() if groups in (['refresh_pages'],['refresh_loot']) else {},
        page_fixture_sources={name:sha(HERE/name) for name in ('refresh_profile_fixture.py','http_fixture.py','run.py','process_owner.py',*(['refresh_solo_host.gd'] if groups==['refresh_loot'] else []))} if groups in (['refresh_pages'],['refresh_loot']) else {},framework=lock,console_launcher=str(ENGINE),console_launcher_sha256=ENGINE_SHA,
        optional_absent={path:reason for path,reason in OPTIONAL_RES.items() if not (ROOT/'game'/path).exists()},
        project_files=file_map(stage),user_dir=user_dir,groups=enabled,expected_tests={key:EXPECTED[key] for key in enabled},
        formal_apk_scope='Unchanged protection only; this pilot does not execute signed APK1076'))
    assembly_seconds=time.monotonic()-started
    # Import only the small test project. Job ownership also covers an implicitly spawned ADB child.
    import_budget=90-(time.monotonic()-started) if groups in (['refresh_pages'],['refresh_loot'],['motion'],['authority_motion']) else 90
    if groups in (['motion'],['authority_motion']):import_budget-=33 # Original Owner 8+5 tail and final inventory <=20, inside prepare budget.
    assert import_budget>0,'Preparation work deadline exhausted before import'
    imported=owned_run([ENGINE,'--headless','--editor','--path',stage,'--import'],folder/'import',dict(os.environ),import_budget)
    text=(folder/'import/godot.log').read_text('utf8',errors='replace')
    write(folder/'prepare.json',dict(assembly_seconds=assembly_seconds,import_seconds=imported['elapsed_seconds'],
        total_seconds=time.monotonic()-started,exit_code=imported['exit_code'],timed_out=imported['timed_out'],
        protected_unchanged=protected(groups)==read(folder/'protected-before.json'),host_after=inventory()))
    assert imported['exit_code']==0 and not imported['timed_out']
    assert 'SCRIPT ERROR' not in text and not re.search(r'^ERROR:',text,re.M),text[-1500:]
    # Import-generated .uid are explicitly manifested alongside GUT class cache; production closure unchanged.
    manifest=read(folder/'manifest.json');manifest['project_files']=file_map(stage);write(folder/'manifest.json',manifest)
    verify_project(folder)
    print('PILOT_PREPARE_PASS',run_id,len(sources),'production files')

def junit(path):
    if not path.exists():return dict(present=False,tests=0,failures=0,errors=0,skipped=0,failure_cases=[])
    tree=ET.parse(path).getroot();cases=list(tree.iter('testcase'))
    skipped=sum(1 for case in cases if case.find('skipped') is not None or case.get('status') in ('pending','skipped'))
    return dict(present=True,tests=len(cases),failures=sum(1 for case in cases if case.find('failure') is not None),
        errors=sum(1 for case in cases if case.find('error') is not None),skipped=skipped,
        failure_cases=[dict(name=case.get('name'),message=ET.tostring(case.find('failure'),encoding='unicode')) for case in cases if case.find('failure') is not None])

def run(args):
    begin_all=time.monotonic()
    folder=root_for(args.run_id);manifest=verify_project(folder);stage=folder/'project'
    groups=args.groups.split(',');assert groups and len(groups)==len(set(groups)) and all(g in GROUPS for g in groups)
    assert all(g in manifest['groups'] for g in groups),'Selected group was not prepared'
    assert 'treasure' not in groups or groups==['treasure'] and args.mode=='normal','M24 uses only its single normal suite; old controls unchanged'
    assert 'refresh_pages' not in groups or groups==['refresh_pages'] and args.mode=='normal','M01 pages normal only'
    assert 'refresh' not in groups or groups==['refresh'] and args.mode=='normal','M01 refresh uses its single normal suite; old controls unchanged'
    assert 'refresh_loot' not in groups or groups==['refresh_loot'] and args.mode=='normal','G uses only real normal-mode Solo'
    assert 'motion' not in groups or groups==['motion'] and args.mode=='normal','M04 motion normal only'
    assert 'authority_motion' not in groups or groups==['authority_motion'] and args.mode=='normal','B authority motion normal only'
    assert not args.treasure_recheck or groups==['treasure'] and args.mode=='normal','Failed-function filter is M24-only'
    assert not args.refresh_pages_recheck or groups==['refresh_pages'] and args.mode=='normal','Fixed P5 filter is M01 pages-only'
    assert args.mode!='negative' or len(groups)==1,'Negative controls select exactly one real group'
    assert args.mode!='timeout' or groups==['async'] and args.timeout<=3,'Timeout control requires async only and an explicit <=3s engine deadline'
    out=folder/'runs'/args.label;assert re.fullmatch('[a-z0-9-]+',args.label) and not out.exists()
    out.mkdir(parents=True)
    pre=inventory();assert not pre['processes'] and pre['free_kib']>=4200000
    write(out/'host-before.json',pre)
    fixture=None;resource=None;report={};began=begin_all if groups in (['refresh_pages'],['refresh_loot'],['motion'],['authority_motion']) else time.monotonic()
    runners={name:sha(HERE/name) for name in ['run.py','process_owner.py','http_fixture.py']}
    solo_thread=None;solo_job={};solo_errors=[];solo_stop=None;solo_port=None;solo_cleanup={}
    if groups in (['refresh_pages'],['refresh_loot']):runners['refresh_profile_fixture.py']=sha(HERE/'refresh_profile_fixture.py')
    if groups==['refresh_loot']:runners['refresh_solo_host.gd']=sha(HERE/'refresh_solo_host.gd')
    if groups==['treasure']:runners['treasure_fixture.py']=sha(HERE/'treasure_fixture.py')
    xml=out/'junit.xml'
    try:
        if groups in (['refresh_pages'],['refresh_loot']):
            assert os.environ.get('BETA_REQUIRE_PROTOCOL','0')=='0','Page fixture must explicitly use debug-compatible policy'
            os.environ['BETA_REQUIRE_PROTOCOL']='0'
            from refresh_profile_fixture import RefreshProfileFixture
            fixture=RefreshProfileFixture(out,solo=groups==['refresh_loot'],test_payments=groups==['refresh_pages']);fixture.start()
            write(out/'http-resource.json',dict(owner_pid=os.getpid(),port=fixture.port,host='127.0.0.1',shared=False,purpose='fresh DB production Handler; debug headers, not release protocol validation'))
        elif groups==['treasure']:
            from treasure_fixture import TreasureFixture
            fixture=TreasureFixture(out);fixture.start()
            write(out/'http-resource.json',dict(owner_pid=os.getpid(),port=fixture.port,host='127.0.0.1',shared=False,purpose='M24 no-account real HTTP fixture, not a gameplay service'))
        elif groups not in (['alerts'],['motion'],['authority_motion']) or args.mode!='normal':
            fixture=Fixture(out);fixture.start()
            write(out/'http-resource.json',dict(owner_pid=os.getpid(),port=fixture.port,host='127.0.0.1',shared=False,purpose='isolated scheduler GET transport; no database or gameplay' if groups==['refresh'] else 'isolated current-run preview HTTP fixture'))
        tests=['res://qa/'+GROUPS[g] for g in groups]
        if args.mode=='empty':tests=[]
        if args.mode=='skip':tests=['res://qa/control/test_pending.gd']
        command=[ENGINE,'--headless','--path',stage,'--script','res://addons/gut/gut_cmdln.gd',
            '-gconfig=','-gexit','-gdisable_colors','-gjunit_xml_file='+str(xml)]
        command += ['-gtest='+','.join(tests)] if tests else ['-gdir=res://qa/empty']
        if args.treasure_recheck or args.refresh_pages_recheck:command += ['-gunit_test_name=test_recheck_']
        env=dict(os.environ,PILOT_HTTP_URL='http://127.0.0.1:'+str(fixture.port) if fixture else '',PILOT_HTTP_EVENTS=str(out/'http-events.jsonl'),PILOT_ALERT_EVENTS=str(out/'alert-events.jsonl'),
            PILOT_NEGATIVE_GROUP=groups[0] if args.mode=='negative' else '',PILOT_FORCE_TIMEOUT='1' if args.mode=='timeout' else '')
        if groups in (['refresh_pages'],['refresh_loot']):
            env.update(PILOT_PAGE_CONTROL=str(out),PILOT_PAGE_ACCOUNTS=str(fixture.private/'accounts.json'),PROFILE_URL='http://127.0.0.1:'+str(fixture.port))
        if groups==['refresh']:
            env['PILOT_REFRESH_CONTROL']=str(out)
        if groups==['treasure']:
            env.update(PILOT_TREASURE_CONTROL=str(fixture.control),PILOT_TREASURE_SAMPLES=str(out/'treasure-samples.json'))
        if groups==['refresh_loot']:
            evidence=out/'loot-evidence';evidence.mkdir(exist_ok=False)
            with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as available:
                available.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
                available.bind(('127.0.0.1',0));solo_port=available.getsockname()[1]
            solo_stop=out/'solo-stop'
            env.update(SOLO_PORT=str(solo_port),SOLO_PROFILE_URL='http://127.0.0.1:'+str(fixture.port),
                ROOM_AUTH_FILE=str(fixture.room_key_file),SOLO_SAVE_DIR=str(fixture.private/'solo-save'),
                PILOT_SOLO_STOP=str(solo_stop),PILOT_LOOT_EVIDENCE=str(evidence))
            host_command=[ENGINE,'--headless','--path',stage,'--log-file',out/'solo-internal.log',
                '--script','res://qa/refresh_solo_host.gd','--','--solo-server']
            host_budget=args.timeout-(time.monotonic()-began)
            assert host_budget>0,'G work deadline exhausted before server'
            def serve_solo():
                try:solo_job['result']=owned_run(host_command,out/'solo-engine',env,host_budget)
                except BaseException as error:solo_errors.append(dict(type=type(error).__name__,detail=str(error)))
            solo_thread=threading.Thread(target=serve_solo,name='m01-g-owned-solo',daemon=False)
            write(out/'solo-resource.json',dict(owner_pid=os.getpid(),host='127.0.0.1',udp_port=solo_port,
                shared=False,physics_hz=20,save_directory=str(fixture.private/'solo-save'),key_file=str(fixture.room_key_file)))
            solo_thread.start()
            ready_deadline=min(began+args.timeout,time.monotonic()+10)
            host_log=out/'solo-engine/godot.log'
            while True:
                text=host_log.read_text('utf8',errors='replace') if host_log.exists() else ''
                if 'SOLO_READY port='+str(solo_port) in text and 'REFRESH_SOLO_HOST_READY physics_hz=20' in text:break
                assert solo_thread.is_alive(),'Solo server ended before readiness: '+str(solo_errors)
                assert time.monotonic()<ready_deadline,'Solo readiness exceeded bounded common work'
                time.sleep(.02)
        engine_budget=args.timeout-(time.monotonic()-began) if groups in (['refresh_pages'],['refresh_loot'],['motion'],['authority_motion']) else args.timeout
        if groups in (['motion'],['authority_motion']):engine_budget-=13 # Reserve the original Owner tail inside the business budget.
        assert engine_budget>0,'Page suite deadline exhausted before Godot'
        resource=owned_run(command,out/'engine',env,engine_budget)
        result=junit(xml);log=(out/'engine/godot.log').read_text('utf8',errors='replace')
        unexpected_errors=bool(re.search(r'SCRIPT ERROR|^ERROR:',log,re.M))
        native_error_evidence=None
        if groups==['treasure']:
            from treasure_fixture import engine_error_evidence
            native_error_evidence=engine_error_evidence(log,xml)
            unexpected_errors=native_error_evidence['unexpected']
        expected=sum(EXPECTED[g] for g in groups)
        if args.treasure_recheck:expected=2
        if args.refresh_pages_recheck:expected=1
        passed=resource['exit_code']==0 and not resource['timed_out'] and not unexpected_errors and result['present'] and result['tests']==expected and result['skipped']==result['failures']==result['errors']==0
        report=dict(run_id=args.run_id,label=args.label,mode=args.mode,groups=groups,passed=passed,
            source_ref=manifest['source_ref'],production_closure=manifest['production_closure'],profile_sources=manifest.get('profile_sources',{}),framework=manifest['framework'],
            console_launcher=str(ENGINE),console_launcher_sha256=ENGINE_SHA,runtime_version_log=log.splitlines()[0] if log.splitlines() else '',
            process_image_sha256=resource['process_image_sha256'],peak_godot_executables=resource['peak_godot_executables'],
            peak_owned_processes=resource['peak_owned_processes'],runner_source_sha256=runners,
            staged_test_source_sha256={key:value for key,value in manifest['project_files'].items() if key.startswith('qa/')},
            workspace_test_sha256={name:sha(HERE/name) for name in ['support.gd',*manifest['groups'].values()]},
            raw_engine_exit=resource['exit_code'],timed_out=resource['timed_out'],junit=result,expected_tests=expected,
            script_or_engine_error=unexpected_errors,execution_seconds=resource['elapsed_seconds'],
            expected_native_error_evidence=native_error_evidence,
            selected_groups=groups,selected_test_paths=tests,classification='passed' if passed else 'failed; inspect raw evidence',
            selected_function_filter='test_recheck_' if args.treasure_recheck or args.refresh_pages_recheck else '',
            model_interventions_inside_run=0,max_simultaneous_engine_instances=2 if groups==['refresh_loot'] else 1,resource_file='engine/process.json',
            apk_scope='Unchanged guard only; no signed Android package was executed')
    except BaseException as exc:
        report.update(passed=False,classification='runner/tool failure',error=type(exc).__name__,detail=str(exc))
        raise
    finally:
        clean_started=time.monotonic()
        if groups==['refresh_loot']:
            try:
                if solo_thread is not None:
                    with solo_stop.open('x',encoding='utf8') as stop:stop.write('stop this owned host')
                    solo_thread.join(timeout=max(.1,30-(time.monotonic()-clean_started)))
                    assert not solo_thread.is_alive(),'Owned Solo supervision thread did not end'
                    assert not solo_errors,solo_errors
                    host=solo_job.get('result')
                    assert host and host['exit_code']==0 and not host['timed_out'] and not host['job_pids_after_cleanup'] and not host['same_instances_still_alive'],'Solo host Job/exit failure'
                    host_text=(out/'solo-engine/godot.log').read_text('utf8',errors='replace')
                    assert not re.search(r'SCRIPT ERROR|^ERROR:',host_text,re.M),'Solo host native/script ERROR'
                    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as released:
                        released.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
                        released.bind(('127.0.0.1',solo_port))
                    solo_cleanup=dict(thread_alive=False,job=host,udp_port=solo_port,udp_released=True,errors=[])
                else:solo_cleanup=dict(not_started=True,errors=solo_errors)
            except BaseException as error:
                solo_cleanup=dict(cleanup_failed=True,thread_alive=bool(solo_thread and solo_thread.is_alive()),
                    errors=solo_errors,error=type(error).__name__,detail=str(error),job=solo_job.get('result'))
            write(out/'solo-cleanup.json',solo_cleanup)
        try:http_cleanup=fixture.close() if fixture else dict(not_started=True)
        except BaseException as exc:http_cleanup=dict(cleanup_failed=True,error=type(exc).__name__,detail=str(exc))
        protected_unchanged=protected(groups)==read(folder/'protected-before.json')
        host=inventory(timeout=max(.1,min(20,30-(time.monotonic()-clean_started)))) if groups in (['refresh_loot'],['motion'],['authority_motion']) else inventory();write(out/'cleanup.json',dict(http=http_cleanup,host=host,protected_unchanged=protected_unchanged,
            godot_job_empty=not resource or not resource['job_pids_after_cleanup'],solo=solo_cleanup,cleanup_seconds=time.monotonic()-clean_started))
        report.update(total_seconds=time.monotonic()-began,protected_unchanged=protected_unchanged,host_after=host)
        runner_unchanged=all(sha(HERE/name)==value for name,value in runners.items())
        safe=(groups not in (['refresh_loot'],['motion'],['authority_motion']) or time.monotonic()-clean_started<=30) and not solo_cleanup.get('cleanup_failed') and protected_unchanged and not host['processes'] and not http_cleanup.get('cleanup_failed') and not (resource or {}).get('job_pids_after_cleanup',[])
        report['passed']=bool(report.get('passed')) and safe and runner_unchanged
        if groups==['refresh_loot']:
            report['solo_server']=solo_cleanup
            if not safe:report['classification']='G cleanup or protected source observation failed'
        if groups==['treasure']:
            from treasure_fixture import validate_journal
            journal=validate_journal(out/'http-events.jsonl');events=journal.pop('events')
            report['journal_validation']=journal
            report['passed']=bool(report['passed']) and journal['passed']
        else:
            events=[json.loads(line) for line in (out/'http-events.jsonl').read_text('utf8').splitlines()] if (out/'http-events.jsonl').exists() else []
        report['http_event_counts']={event:sum(row['event']==event for row in events) for event in {row['event'] for row in events}}
        if groups in (['refresh_pages'],['refresh_loot']) and any(row['event']=='profile_handler_failure' for row in events):
            report.update(passed=False,classification='M01 real profile Handler fixture failure')
        if groups==['refresh'] and any(row['event']=='refresh_handler_failure' for row in events):
            report.update(passed=False,classification='M01 refresh fixture handler failure; inspect original event')
        if groups==['treasure'] and any(row['event']=='handler_failure' for row in events):
            report.update(passed=False,classification='M24 fixture handler failure; inspect raw event')
        control=False
        if resource and not report.get('script_or_engine_error') and safe and runner_unchanged:
            result=report.get('junit',{})
            if args.mode=='negative':
                target={'rules':('test_loadout_ownership_interface_and_budget','Real production totals'),
                    'scene':('test_real_lobby_read_gate_draft_and_pointer_request','Real pointer input produced'),
                    'async':('test_preview_real_http_failure_and_explicit_refresh_success','A real matching 200 plan')}[groups[0]]
                failures=result.get('failure_cases',[])
                control=resource['exit_code']!=0 and not resource['timed_out'] and result.get('tests')==sum(EXPECTED[g] for g in groups) and result.get('errors')==result.get('skipped')==0 and len(failures)==1 and failures[0]['name']==target[0] and target[1] in failures[0]['message']
            elif args.mode=='empty':
                control=not resource['timed_out'] and not report['selected_test_paths'] and result.get('tests')==0
            elif args.mode=='skip':
                control=not resource['timed_out'] and result.get('present') and result.get('tests')==result.get('skipped')==1 and result.get('failures')==result.get('errors')==0
            elif args.mode=='timeout':
                control=resource['timed_out'] and any(row['event']=='request_begin' and row['robot']=='http-preview-timeout' for row in events)
        report.update(control_satisfied=control,runner_unchanged_during_run=runner_unchanged,wrapper_exit_code=0 if report['passed'] else 3)
        if args.mode!='normal':report['classification']='expected control rejection verified' if control else 'control verification failed; inspect original failure'
        write(out/'report.json',report)
    print(json.dumps(dict(label=args.label,mode=args.mode,passed=report['passed'],junit=report.get('junit'),engine_exit=report.get('raw_engine_exit'),timed_out=report.get('timed_out'))))
    return 0 if report['passed'] else 3

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','run'])
    parser.add_argument('--run-id',required=True);parser.add_argument('--label',default='cold');parser.add_argument('--groups',default='rules,scene,async')
    parser.add_argument('--mode',choices=['normal','negative','empty','skip','timeout'],default='normal');parser.add_argument('--timeout',type=float,default=60)
    parser.add_argument('--engine',default=str(ENGINE),help='Pinned Godot 4.6.1 console executable; checked before workspace writes or engine startup')
    parser.add_argument('--treasure-recheck',action='store_true',help='Only the two root-approved A05 failed functions via the fixed GUT test_recheck_ filter')
    parser.add_argument('--refresh-pages-recheck',action='store_true',help='Only root-approved M01 P5 via fixed test_recheck_ filter, expected one case')
    args=parser.parse_args();assert 0<args.timeout<=(120 if args.groups=='refresh_pages' else 540 if args.groups=='refresh_loot' else 90)
    try:ENGINE=checked_engine(args.engine)
    except (ValueError,OSError) as exc:parser.error(str(exc))
    if args.action=='prepare':prepare(args.run_id,args.groups.split(','))
    else:sys.exit(run(args))
