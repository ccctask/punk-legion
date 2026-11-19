"""Strict catalog evidence comparison; production rules remain the authority."""
import argparse
import copy
import hashlib
import importlib
import json
import math
from pathlib import Path
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'AGENTS.md').is_file())
CASE_NAMES = ['valid_wheel', 'overweight_only', 'duplicate_entity', 'explicit_27cp']


class Rejected(Exception):
    def __init__(self, kind, path, **details):
        self.evidence = dict(kind=kind, path=path, **details)
        super().__init__(kind + ': ' + path)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def finite(value, path='$'):
    if type(value) in (int, float):
        if type(value) is float and not math.isfinite(value):
            raise Rejected('NonFinite', path, type=type(value).__name__, value=repr(value))
    elif isinstance(value, dict):
        for key in sorted(value): finite(value[key], path + '.' + str(key))
    elif isinstance(value, list):
        for index, item in enumerate(value): finite(item, path + '[' + str(index) + ']')


def compare(left, right, path='$'):
    finite(left, path)
    finite(right, path)
    numeric = type(left) in (int, float) and type(right) in (int, float)
    if not numeric and type(left) is not type(right):
        raise Rejected('TypeDifference', path, left_type=type(left).__name__, right_type=type(right).__name__, left=left, right=right)
    if isinstance(left, dict):
        if left.keys() != right.keys():
            key = sorted(set(left) ^ set(right))[0]
            raise Rejected('KeyDifference', path + '.' + key, left_has=key in left, right_has=key in right)
        for key in sorted(left): compare(left[key], right[key], path + '.' + key)
    elif isinstance(left, list):
        if len(left) != len(right): raise Rejected('LengthDifference', path, left=len(left), right=len(right))
        for index, (a, b) in enumerate(zip(left, right)): compare(a, b, path + '[' + str(index) + ']')
    elif left != right:
        raise Rejected('ValueDifference', path, left_type=type(left).__name__, right_type=type(right).__name__, left=left, right=right)


def fixture(version=None):
    """Only creates trusted input identities/definitions, never computes rules."""
    if version is None:
        version = json.loads((ROOT / 'services/profile/workshop_catalog.json').read_text(encoding='utf-8'))['version']
    def unit(prefix, weapon='rivet_repeater'):
        mapping = {prefix + '/hull': 'wheel', prefix + '/core': 'boiler', prefix + '/head': 'visor', prefix + '/weapon': weapon}
        request = dict(version=version, chassis=prefix + '/hull', slots={s: prefix + '/' + s for s in ['core', 'head', 'weapon']})
        return request, mapping
    def sample(name, count, weapon='rivet_repeater', duplicate=False):
        units, inventory = [], {}
        for index in range(count):
            request, mapping = unit(name + '/' + str(index), weapon)
            units.append(request)
            inventory.update(mapping)
        if duplicate: units.append(copy.deepcopy(units[0]))
        return dict(name=name, units=units, inventory=inventory)
    return dict(cases=[sample('valid_wheel', 1), sample('overweight_only', 1, 'cannon'),
                       sample('duplicate_entity', 1, duplicate=True), sample('explicit_27cp', 9)])


def controls(catalog):
    results = []
    original_damage = catalog['parts']['cannon']['damage']
    different_damage = original_damage + 1
    if different_damage == original_damage: different_damage = -original_damage
    assert different_damage != original_damage
    for name, change, kind, path in [
        ('numeric_difference', lambda c: c['parts']['cannon'].__setitem__('damage', different_damage), 'ValueDifference', '$.parts.cannon.damage'),
        ('bool_is_not_number', lambda c: c['chassis']['crawler']['slots']['utility'].__setitem__('optional', 1), 'TypeDifference', '$.chassis.crawler.slots.utility.optional'),
        ('nonfinite', lambda c: c['parts']['cannon'].__setitem__('damage', float('nan')), 'NonFinite', '$.parts.cannon.damage')]:
        changed = copy.deepcopy(catalog)
        change(changed)
        try: compare(catalog, changed)
        except Rejected as exc:
            assert exc.evidence['kind'] == kind and exc.evidence['path'] == path, exc.evidence
            results.append(dict(name=name, passed=False, control_satisfied=True, rejection=exc.evidence))
        else: raise Rejected('ControlNotRejected', name)
    return results


def production_cases(data, workshop):
    from inventory import Fault
    assert [c['name'] for c in data['cases']] == CASE_NAMES
    results = []
    for case in data['cases']:
        rows, fits = [], []
        for request in case['units']:
            slots = {slot: dict(id=entity, definition=case['inventory'][entity]) for slot, entity in request['slots'].items()}
            row = dict(id=request['chassis'], chassis=case['inventory'][request['chassis']], task=None, state='ready', slots=slots)
            rows.append(row)
            try:
                value = workshop.validate_fit({s: p['definition'] for s, p in slots.items()}, chassis=row['chassis'])
                fits.append(dict(ok=True, value=value, points=workshop.robot_points(row)))
            except Fault as exc: fits.append(dict(ok=False, status=exc.status, code=exc.code))
        if any(not fit['ok'] for fit in fits):
            squad = dict(not_applicable=True, reason='fit_rejected')
        else:
            try:
                deployment = workshop.deployment_for(rows, [r['id'] for r in rows])
                squad = dict(ok=True, deployment=deployment)
            except Fault as exc: squad = dict(ok=False, status=exc.status, code=exc.code)
        results.append(dict(name=case['name'], fits=fits, squad=squad))
    return results


def validate_samples(data, gd, py):
    assert [s['name'] for s in gd] == CASE_NAMES == [s['name'] for s in py]
    a, b = gd[0], py[0]
    assert a['unit']['ok'] and a['squad']['ok'] and b['fits'] == [dict(ok=True, value=None, points=3)]
    assert a['unit']['totals'] == dict(mass=4, payload=4, power=4, supply=6, heat=2, cooling=4, points=3)
    assert a['squad']['points'] == b['squad']['deployment']['points'] == 3
    assert a['squad']['units'] == len(b['squad']['deployment']['units']) == 1
    sample = data['cases'][0]
    request = sample['units'][0]
    assert a['unit']['entity_id'] == request['chassis']
    assert a['unit']['chassis'] == sample['inventory'][request['chassis']]
    compare({slot: sample['inventory'][entity] for slot, entity in request['slots'].items()}, a['unit']['parts'])
    assert sorted(a['unit']['entities']) == sorted([request['chassis']] + list(request['slots'].values()))
    compare(sample['inventory'], b['squad']['deployment']['inventory'])
    compare(sample['units'], b['squad']['deployment']['units'])
    assert gd[1]['unit']['code'] == gd[1]['squad']['code'] == 'weight'
    assert py[1]['fits'] == [dict(ok=False, status=400, code='weight')]
    assert py[1]['squad'] == dict(not_applicable=True, reason='fit_rejected')
    assert gd[2]['squad']['code'] == 'duplicate' and py[2]['squad'] == dict(ok=False, status=409, code='unit_unavailable')
    assert len(data['cases'][3]['units']) == 9 and len({r['chassis'] for r in data['cases'][3]['units']}) == 9
    assert gd[3]['squad']['code'] == 'point_limit' and py[3]['squad'] == dict(ok=False, status=409, code='point_limit')
    assert len(py[3]['fits']) == 9 and all(f == dict(ok=True, value=None, points=3) for f in py[3]['fits'])


def evaluate(export, fixture_path):
    if not export.is_file(): raise Rejected('MissingExport', str(export))
    gd = json.loads(export.read_text(encoding='utf-8'))
    data = json.loads(fixture_path.read_text(encoding='utf-8'))
    assert set(gd) == {'catalog', 'samples', 'finite_control', 'fixture_sha256'}
    assert gd['fixture_sha256'] == sha(fixture_path)
    assert gd['finite_control'] == dict(rejected=True, path='$.parts.cannon.damage')
    sys.path.insert(0, str(ROOT / 'services/profile'))
    workshop = importlib.import_module('workshop')
    source = ROOT / 'services/profile/workshop_catalog.json'
    expected = json.loads(source.read_text(encoding='utf-8'))
    compare(expected, workshop.CATALOG)
    compare(expected, gd['catalog'])
    py = production_cases(data, workshop)
    validate_samples(data, gd['samples'], py)
    return dict(passed=True, scope='Catalog and four resolved-input samples only; no DB ownership or combat equivalence',
                source=dict(workshop_path=workshop.__file__, workshop_sha256=sha(workshop.__file__), json_path=str(source), json_sha256=sha(source),
                            catalog_gd_sha256=sha(ROOT / 'game/loadout/catalog.gd'), export_sha256=sha(export), fixture_sha256=sha(fixture_path)),
                gd_samples=gd['samples'], python_samples=py, comparison_controls=controls(expected), godot_finite_control=gd['finite_control'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compare-only', action='store_true', required=True)
    parser.add_argument('--export', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    try: result = evaluate(args.export, args.fixture)
    except Rejected as exc: result = dict(passed=False, rejection=exc.evidence)
    except Exception as exc: result = dict(passed=False, error=dict(type=type(exc).__name__, message=str(exc)))
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    print(json.dumps(dict(passed=result['passed'], report=str(args.report))))
    return 0 if result['passed'] else 3


if __name__ == '__main__': raise SystemExit(main())
