"""Pure synthetic boundaries and one in-memory non-credential DPAPI sentinel. No Docker/HTTP."""
from argparse import Namespace
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import operator_access as host
from operator_store import dpapi, sha


def main():
    output = Path(sys.argv[1]).resolve()
    output.mkdir(parents=True, exist_ok=False)
    result = {'scope': 'pure CLI/control and non-credential DPAPI sentinel only', 'checks': []}
    try:
        sentinel = b'PunkLegion non-credential development sentinel'
        assert dpapi(dpapi(sentinel, True), False) == sentinel
        result['checks'].append('current-user DPAPI sentinel roundtrip; no store or credential generated')
        compile((host.STABLE/'operations.py').read_text('utf-8'), 'operations.py', 'exec')
        # Test the real production dispatch function without importing server/module graphs or starting HTTP.
        import ast
        tree = ast.parse((host.STABLE/'operations.py').read_text('utf-8'))
        dispatch = next(x for x in tree.body if isinstance(x, ast.FunctionDef) and x.name == 'dispatch')
        class Fault(Exception):
            def __init__(self, status, code): self.status, self.code = status, code
        class Inventory:
            pass
        Inventory.Fault = Fault
        class Server:
            @staticmethod
            def transaction(_): raise AssertionError('Rejected request entered write transaction')
        env = {'authenticate': lambda *_: ('viewer', 'viewer'), 'inventory': Inventory, 'server': Server}
        exec(compile(ast.Module(body=[dispatch], type_ignores=[]), 'actual_dispatch', 'exec'), env)
        for method, route, status in [('POST','/ops/compensations',403),('DELETE','/ops/nope',404)]:
            try: env['dispatch']('not-a-db', {}, '', method, route, {})
            except Fault as exc: assert exc.status == status
            else: raise AssertionError('Expected rejection')
        result['checks'].append('actual production route/role rejects before any transaction')
        policy = output/'not-a-policy.json'
        for role, rw in [('viewer', False), ('compensator', True)]:
            args = Namespace(action='diagnose', role=role, scope='qa', db_volume='punk-operator-qa-control-player-profiles')
            config, expected, actual_rw = host.make_config(args, policy)
            assert actual_rw == rw
            mounts = []
            for destination, spec in expected.items():
                m = {'Destination': destination, 'Type': spec['type'], 'RW': rw if destination=='/data' else False}
                if spec['type']=='volume': m.update(Name=spec['source'], Source='/var/lib/docker/volumes/'+spec['source']+'/_data')
                else:
                    path = spec['source'].replace('\\','/')
                    m['Source']='/run/desktop/mnt/host/'+path[0].lower()+path[2:]
                mounts.append(m)
            config_path=output/'synthetic-compose.json'
            info={'Config':{'Labels':{'com.docker.compose.project':host.PROJECT,'com.docker.compose.service':'operator','com.docker.compose.project.config_files':str(config_path),'com.docker.compose.project.working_dir':str(host.STABLE)},'Cmd':['python','-B','-u','/app/operator_service.py'],'Entrypoint':[],'Env':['SOLO_SPOOL_DIR=/queues/solo','PARTY_SPOOL_DIR=/queues/party','CAMP_SPOOL_DIR=/queues/camp','ROOM_OUTBOX_DIR=/queues/room']},'Image':host.IMAGE,'HostConfig':{'ReadonlyRootfs':True,'NetworkMode':'none','Init':True,'PortBindings':{},'Memory':134217728,'NanoCpus':250000000.0,'RestartPolicy':{'Name':'no'}},'NetworkSettings':{'Ports':{}},'Mounts':list(reversed(mounts))}
            assert host.check_identity(info,config_path,expected,rw)==host.mounts_by_destination(info['Mounts'])
            changed=copy.deepcopy(info);changed['Mounts'][0]['RW']=True
            try: host.check_identity(changed,config_path,expected,rw)
            except ValueError: pass
            else: raise AssertionError('Unexpected writable queue/source accepted')
        result['checks'].append('dual DB RO/RW config, reordered full Mounts/Desktop paths/numeric CPU representation accepted; wrong RW rejected')
        assert host.host_path('/run/desktop/mnt/host/c/Users/example') == host.host_path('C:\\Users\\example')
        # Real run() control path with a synthetic transport, no subprocess/HTTP invocation.
        original_run, original_load = host.owned_capture, host.load
        calls=[]
        state={'exists':False,'info':None}
        fake_token='non-credential-test-sentinel'
        host.load=lambda *_:(fake_token,json.dumps({'compensator':{'role':'compensator','sha256':sha(fake_token.encode())}}).encode())
        def transport(argv, **kwargs):
            calls.append(argv)
            if argv[:2]==['docker','ps']: text='a'*64+'\n' if state['exists'] else ''
            elif argv[:3]==['docker','image','inspect']: text=json.dumps([{'Id':host.IMAGE}])
            elif argv[:3]==['docker','volume','inspect']: text='[]'
            elif 'up' in argv:
                state['exists']=True
                cfgpath=Path(argv[argv.index('-f')+1]); cfg=json.loads(cfgpath.read_text('utf-8'))
                expected={}
                for m in cfg['services']['operator']['volumes']:
                    expected[m['target']]={'type':m['type'],'source':m['source'] if m['type']=='bind' else cfg['volumes'][m['source']]['name']}
                value=copy.deepcopy(info)
                value['Config']['Labels']['com.docker.compose.project.config_files']=str(cfgpath)
                value['Mounts']=[]
                for dest,spec in expected.items():
                    row={'Destination':dest,'Type':spec['type'],'RW':dest=='/data','Source':spec['source']}
                    if spec['type']=='volume':row['Name']=spec['source']
                    value['Mounts'].append(row)
                value['State']={'Running':True};state['info']=value;text='created'
            elif argv[:2]==['docker','inspect']: text=json.dumps([state['info']])
            elif argv[:2]==['docker','exec']: text=json.dumps({'state':'unknown','reason':'synthetic transport loss'})
            elif 'down' in argv: state['exists']=False;text='removed'
            elif argv[:2]==['docker','logs']: text=''
            else: raise AssertionError('Unexpected transport operation')
            return subprocess.CompletedProcess(argv,0,text,'')
        try:
            host.owned_capture=transport
            args=host.parser().parse_args(['compensate','--store',str(output/'no-store'),'--scope','qa','--db-volume','punk-operator-qa-control-player-profiles','--out',str(output/'unknown'),'--incident','incident_fixture','--owner','owner_fixture','--key','key_fixture','--reason','missed_reward','--resource','structure','--amount','2'])
            assert host.run(args)==1
        finally:
            host.owned_capture=original_run;host.load=original_load
        actual=json.loads((output/'unknown/result.json').read_text('utf-8'))
        assert actual['request_state']=='unknown' and not actual['remaining_ids'] and actual['temporary_policy_removed']
        assert sum(x[:2]==['docker','exec'] for x in calls)==1
        assert (output/'unknown/submission.json').is_file()
        assert fake_token not in (output/'unknown/result.json').read_text('utf-8')
        result['checks'].append('real host run path unknown POST: exactly one exec, durable key/fingerprint, no retry, exact owned cleanup and policy removal')
        result['passed']=True
    except BaseException as exc:
        result.update(passed=False, first_error={'type':type(exc).__name__,'reason':str(exc)})
        raise
    finally:
        (output/'selftest-result.json').write_bytes((json.dumps(result,indent=2)+'\n').encode())
    print(json.dumps(result))


if __name__=='__main__':main()
