"""Current M24 action producers only. No account, database or HTTP entry points."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
import traceback

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'AGENTS.md').is_file())
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'services/profile'))
import treasure_combat as combat
import workshop

GROUPS = ['J1', 'J2', 'J3', 'R1', 'W1']


class Failed(Exception):
    def __init__(self, classification, assertion, evidence):
        self.data = dict(classification=classification, assertion=assertion, evidence=evidence)
        super().__init__(assertion)


def require(ok, assertion, evidence=None, classification='product_failure'):
    if not ok: raise Failed(classification, assertion, evidence)


def actor(rid, side, utility='', weapon='cannon'):
    definitions = dict(workshop.BASE, weapon=weapon)
    if utility: definitions['utility'] = utility
    workshop.validate_fit(definitions, chassis='crawler')
    row = dict(id=rid, name=rid, paint='base', chassis='crawler', task=None, state='ready',
               slots={slot:dict(id=rid+'/'+slot, definition=value) for slot,value in definitions.items()})
    require(workshop.deployment_for([row], [rid])['units'][0]['chassis'] == rid, 'legal constructor', rid, 'fixture_failure')
    return combat.unit(row, 'owner-'+str(side), side, 0)


def place(unit, point):
    unit['pos'] = list(point)
    unit['target'] = list(point)


def move(state, ids, point):
    """The model input fields used by treasure.command(move), not deadlines."""
    for rid in ids:
        state['units'][rid].update(target=list(point), manual_move=True, focus='', aim_target='')


def snapshot(state):
    keys = ['pos','target','manual_move','hp','shot','next_shot','aim_target','aim_due','last_service',
            'service_charges','jam_charges','last_jam','protected_until','weapon_not_before','repair_not_before',
            'weapon_delayed','repair_delayed']
    return dict(at=state['tick']*combat.STEP, units={rid:{k:copy.deepcopy(u[k]) for k in keys if k in u}
                for rid,u in state['units'].items()}, event_counts={rid:len(u['events']) for rid,u in state['units'].items()})


def setup(jam, moving=False, injured=True):
    units = dict(a=actor('a',0,'jammer' if jam else ''), b=actor('b',0,'jammer' if jam else ''),
                 dummy=actor('dummy',0), tech=actor('tech',1,'repair_arm'), buddy=actor('buddy',1))
    positions = dict(a=[-6.4,0], b=[-6.6,0], dummy=[3,0], tech=[0,0], buddy=[0,3]) if moving else dict(a=[0,0],b=[-1,0],dummy=[5,0],tech=[2,0],buddy=[6.8,0])
    for rid,u in units.items():
        place(u,positions[rid])
        if rid != 'tech': u.update(damage=0, speed=0 if rid in ['buddy','dummy'] else u['speed'])
    if injured: units['buddy']['hp'] -= 20
    state = combat.fresh(41, units, 0)
    return state


def jam_events(state):
    return [e for e in state['units']['tech']['events'] if e['kind']=='jam_received']


def paired(jam, moving=False):
    state = setup(jam, moving)
    tech = state['units']['tech']
    trace, hit, arrival, aim_ready = [], None, None, None
    first_shot = first_repair = next_shot = next_repair = None
    moved_at = None
    withdrew = False
    initial = snapshot(state)
    for _ in range(40):
        before = snapshot(state)
        previous_shot, previous_repair = tech['shot'], tech['last_service']
        combat.step(state)
        after = snapshot(state)
        if tech['shot'] != previous_shot:
            if first_shot is None: first_shot = tech['shot']
            elif next_shot is None: next_shot = tech['shot']
        if tech['last_service'] != previous_repair:
            if first_repair is None: first_repair = tech['last_service']
            elif next_repair is None: next_repair = tech['last_service']
        if jam and hit is None and jam_events(state): hit = dict(before=before, after=after, event=copy.deepcopy(jam_events(state)[0]))
        trace.append(dict(before=before,after=after))
        if moving and moved_at is None and first_shot is not None and first_repair is not None:
            moved_at = state['tick']*combat.STEP
            move(state, ['tech'], [-1,0])
            move(state, ['a','b'], [-4,0])
        if moving and moved_at is not None:
            if not withdrew and state['tick']*combat.STEP >= moved_at+combat.STEP-1e-8:
                move(state,['a','b'],[-9,0]); withdrew=True
            if arrival is None and math.dist(tech['pos'],[-1,0]) < .01:
                arrival = state['tick']*combat.STEP
            if arrival is not None and aim_ready is None and tech['aim_target']:
                aim_ready = tech['aim_due']
        if (not moving and first_shot is not None and first_repair is not None) or (moving and next_shot is not None and next_repair is not None): break
    return dict(initial=initial, trace=trace, hit=hit, first_weapon=first_shot,first_repair=first_repair,
                next_weapon=next_shot,next_repair=next_repair,move_started=moved_at,arrived=arrival,aim_ready=aim_ready,
                pulses=copy.deepcopy(jam_events(state)),remaining_jam=sum(state['units'][x]['jam_charges'] for x in ['a','b']),
                final=snapshot(state), events={rid:copy.deepcopy(u['events']) for rid,u in state['units'].items()})


def pair_group(moving):
    base, jam = paired(False,moving), paired(True,moving)
    evidence = dict(baseline=base,jammed=jam,tick=combat.STEP)
    action_keys = ['next_weapon','next_repair'] if moving else ['first_weapon','first_repair']
    require(all(branch[k] is not None for branch in [base,jam] for k in action_keys), 'actions observed', evidence, 'fixture_failure')
    require(jam['hit'] is not None, 'natural first pulse observed', evidence, 'fixture_failure')
    require(abs(jam['hit']['after']['units']['tech']['protected_until']-jam['hit']['event']['at']-workshop.PARTS['jammer']['jam_protection'])<=1e-6,'original protection deadline exact',evidence)
    if moving:
        require(jam['first_weapon']==base['first_weapon'] and jam['first_repair']==base['first_repair'],'both branches established same real prior actions',evidence,'fixture_failure')
        due_weapon=jam['first_weapon']+combat.STEP*math.ceil(workshop.PARTS['cannon']['attack_interval']/combat.STEP)
        due_repair=jam['first_repair']+workshop.PARTS['repair_arm']['repair_interval']
        hit=jam['hit']; at=hit['event']['at']
        evidence['independent_due']=dict(weapon=due_weapon,repair=due_repair)
        require(abs(hit['before']['units']['tech']['next_shot']-due_weapon)<=1e-6 and abs(hit['before']['units']['tech']['last_service']+workshop.PARTS['repair_arm']['repair_interval']-due_repair)<=1e-6,'own pre-hit pending deadlines from real actions',evidence,'fixture_failure')
        require(hit['before']['units']['tech']['manual_move'] and hit['after']['units']['tech']['pos'] != hit['before']['units']['tech']['pos'], 'hit while movement progresses', evidence, 'fixture_failure')
        require(at < min(due_weapon,due_repair) and jam['arrived'] is not None and jam['arrived'] < due_weapon and jam['aim_ready'] is not None and jam['aim_ready'] < due_weapon, 'pending and relock before original due', evidence,'fixture_failure')
        require(abs(base['next_weapon']-due_weapon)<=combat.STEP+1e-6 and abs(base['next_repair']-due_repair)<=combat.STEP+1e-6,'baseline original deadlines',evidence,'fixture_failure')
        require(abs(hit['after']['units']['tech']['weapon_not_before']-(due_weapon+1))<=1e-6 and abs(hit['after']['units']['tech']['repair_not_before']-(due_repair+1))<=1e-6,'pending deadlines each plus one',evidence)
    else:
        # Natural prepare_weapon aim in the unjammed first tick, not disrupt's claimed oracle.
        due_weapon=base['trace'][0]['after']['units']['tech']['aim_due']
        due_repair=base['trace'][0]['before']['at']
        evidence['independent_due']=dict(weapon=due_weapon,repair=due_repair)
        require(due_weapon>due_repair and jam['hit']['after']['units']['tech']['aim_due']==due_weapon,'natural first aim established',evidence,'fixture_failure')
        require(abs(jam['hit']['after']['units']['tech']['weapon_not_before']-due_weapon-1)<=1e-6 and abs(jam['hit']['after']['units']['tech']['repair_not_before']-due_repair-1)<=1e-6,'natural action deadlines each plus one',evidence)
    require(len(jam['pulses'])==1 and jam['remaining_jam']==7,'shared protection one pulse/charge',evidence)
    require(all(abs(jam[k]-base[k]-1)<=combat.STEP+1e-6 for k in action_keys),'actual actions each delayed once',evidence)
    return evidence


def idle_and_restore():
    state=setup(True, injured=False)
    combat.step(state)
    require(len(jam_events(state))==1,'idle pulse',snapshot(state),'fixture_failure')
    original_protection=state['units']['tech']['protected_until']
    require(abs(original_protection-jam_events(state)[0]['at']-workshop.PARTS['jammer']['jam_protection'])<=1e-6,'idle original protection exact',snapshot(state))
    move(state,['a','b'],[-9,0])
    saved=json.loads(json.dumps(state,allow_nan=False))
    original_deadlines=snapshot(state)
    require(saved==state,'JSON roundtrip retains all original model fields',original_deadlines)
    while state['tick']*combat.STEP < 4.25:
        combat.step(state);combat.step(saved)
        require(state['units']['tech']['protected_until']==saved['units']['tech']['protected_until']==original_protection,'original protection retained during parallel advance',snapshot(state))
    require(saved==state and len(jam_events(state))==1,'parallel restore no pulse replay/protection extension',snapshot(state))
    at=state['tick']*combat.STEP
    require(at>state['units']['tech']['protected_until'],'protection original expiry crossed',snapshot(state),'fixture_failure')
    for branch in [state,saved]: branch['units']['buddy']['hp']-=8
    combat.step(state);combat.step(saved)
    require(state==saved and state['units']['tech']['last_service']==at,'idle repair no stored penalty',snapshot(state))
    return dict(serialization='current-model JSON',before=original_deadlines,at_injury=at,final=snapshot(state),events=state['units']['tech']['events'])


def clamp():
    units=dict(a=actor('a',0,'repair_arm'),b=actor('b',0,'repair_arm'),hurt=actor('hurt',0),foe=actor('foe',1))
    for rid,p in dict(a=[0,0],b=[0,1],hurt=[1,0],foe=[9,7]).items(): place(units[rid],p)
    units['foe'].update(damage=0,speed=0)
    units['hurt']['hp']-=3.25
    units['hurt']['last_damage']=-10 # Declared initial quiet-age generator, no output event/history.
    state=combat.fresh(47,units,0);before=snapshot(state)
    combat.step(state)
    output=[e for u in units.values() for e in u['events'] if e['kind']=='field_repair_output']
    received=[e for e in units['hurt']['events'] if e['kind']=='field_repair_received']
    evidence=dict(initial=before,final=snapshot(state),output=output,received=received)
    require(units['hurt']['hp']==units['hurt']['max_hp'] and len(output)==len(received)==1 and output[0]['amount']==received[0]['amount']==3.25 and output[0]['actor']==received[0]['actor'] and output[0]['target']==received[0]['target']=='hurt','effective clamp and paired identity',evidence)
    require(sorted(units[x]['service_charges'] for x in ['a','b'])==[3,4],'one healer charge',evidence)
    return evidence


def weapon(weapon_name,distance):
    units=dict(gun=actor('gun',0,weapon=weapon_name),dummy=actor('dummy',1))
    place(units['gun'],[0,0]);place(units['dummy'],[distance,0])
    speeds={rid:u['speed'] for rid,u in units.items()}
    for u in units.values():u['speed']=0
    units['dummy']['damage']=0
    state=combat.fresh(53,units,0);shots=[]
    for _ in range(8):
        old=units['gun']['shot'];old_hp=units['dummy']['hp']
        combat.step(state)
        if units['gun']['shot']!=old:shots.append(dict(at=units['gun']['shot'],damage=old_hp-units['dummy']['hp']))
    return dict(weapon=units['gun']['parts']['weapon'],distance=distance,initial_distance=distance,final_distance=math.dist(units['gun']['pos'],units['dummy']['pos']),original_speeds=speeds,fixture_speeds={rid:u['speed'] for rid,u in units.items()},shots=shots,final=snapshot(state))


def weapons():
    data={name+'_'+str(d):weapon(name,d) for name in ['rivet_repeater','cannon'] for d in [3,4]}
    r,c=data['rivet_repeater_3']['shots'],data['cannon_3']['shots']
    require(len(r)>len(c)>0 and all(s['damage']>0 for s in r+c) and max(s['damage'] for s in r)<min(s['damage'] for s in c),'close frequent lower-damage repeater',data)
    require(not data['rivet_repeater_4']['shots'] and data['cannon_4']['shots'],'four-meter cannon role',data)
    return data


def fixture_only():
    states=[setup(False),setup(True),setup(False,True),setup(True,True),setup(True,injured=False)]
    qualified=[actor('qualify-'+name,0,weapon=name) for name in ['rivet_repeater','cannon']]+[actor('repair-a',0,'repair_arm'),actor('repair-b',0,'repair_arm')]
    return dict(prepared=True,not_behavior_pass=True,planned_groups=GROUPS,constructors=len(states),ticks=[s['tick'] for s in states],
                initial=[snapshot(s) for s in states],additional_legal_actors=qualified,no_step=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--fixture-only',action='store_true')
    args=parser.parse_args()
    report=dict(passed=False,model='python',step=combat.STEP,groups=[],remaining=GROUPS.copy())
    try:
        if args.fixture_only:
            report.update(fixture_only());report['scope']='constructor qualification only';report['remaining']=GROUPS.copy()
        else:
            for name,fn in [('J1',lambda:pair_group(False)),('J2',lambda:pair_group(True)),('J3',idle_and_restore),('R1',clamp),('W1',weapons)]:
                item=dict(name=name,passed=False)
                try:item.update(evidence=fn(),passed=True)
                except Failed as exc:item.update(exc.data)
                except Exception as exc:item.update(classification='tool_failure',error=dict(type=type(exc).__name__,message=str(exc),traceback=traceback.format_exc()))
                report['groups'].append(item);report['remaining'].remove(name)
                if not item['passed']:break
            report['passed']=len(report['groups'])==5 and all(g['passed'] for g in report['groups'])
    except Exception as exc:report['first_error']=dict(type=type(exc).__name__,message=str(exc),traceback=traceback.format_exc())
    report['actual_profile_imports']={str(Path(m.__file__).resolve()):hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest() for m in list(sys.modules.values()) if getattr(m,'__file__',None) and Path(m.__file__).resolve().parent==ROOT/'services/profile'}
    args.output.write_text(json.dumps(report,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=report['passed'],prepared=report.get('prepared',False),groups=len(report['groups']))))
    return 0 if report['passed'] or report.get('prepared') else 1


if __name__=='__main__':raise SystemExit(main())
