"""Compare frozen Native ray-cache runs offline; never starts a Runtime."""
import argparse
import hashlib
import json
import math
import struct
from collections import Counter
from pathlib import Path

EXPECTED_FILTERS = [
    'miss', 'valid-nearest', 'excluded-nearest', 'trigger-nearest',
    'dynamic-nearest', 'kinematic-nearest', 'skip-owner-nearest',
    'collision-mask', 'equal-distance-2', 'equal-distance-3', 'equal-distance-5',
]
EXACT_FIELDS = [
    'metadata', 'snapshots', 'finalState', 'captureState', 'filterCases',
    'capturedRays', 'bodyWrap', 'steps', 'normalGcSteps',
]
EXPECTED_OWNERS = {
    'drive.Vehicle.Step', 'drive.Vehicle.StepRotors', 'drive.Vehicle.PostStep',
    'drive.RaySuspension.Sample', 'drive.RaySuspension.Apply', 'drive.ContactControl.Step',
    'drive.ChassisStability.Step', 'drive.HoverControl.Step', 'drive.HoverControl.Motion',
    'drive.ThrusterControl.Step', 'drive.WingControl.Step', 'drive.LegControl.Step',
    'drive.LegControl.Cast', 'drive.MechControl.Step', 'drive.LegHitboxes.Update',
    'drive.MechHitboxes.Update', 'physics.Space.Raycast', 'physics.Space.Step',
    'physics.Body.Wrap', 'combat.WeaponSystem.Step', 'combat.EnemyDriver.Step',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def first_difference(a, b, path='$'):
    if type(a) is not type(b):
        return f'{path}: types differ ({type(a).__name__}, {type(b).__name__})'
    if isinstance(a, dict):
        if a.keys() != b.keys():
            return f'{path}: keys differ'
        for key in a:
            result = first_difference(a[key], b[key], f'{path}.{key}')
            if result:
                return result
    elif isinstance(a, list):
        if len(a) != len(b):
            return f'{path}: lengths differ ({len(a)}, {len(b)})'
        for index, (left, right) in enumerate(zip(a, b)):
            result = first_difference(left, right, f'{path}[{index}]')
            if result:
                return result
    elif a != b:
        return f'{path}: {a!r} != {b!r}'
    return None


def read_string(record, offset):
    require(offset + 4 <= len(record), 'Truncated packed string length')
    size = struct.unpack_from('<I', record, offset)[0]
    end = offset + 4 + size
    require(end <= len(record), 'Truncated packed string')
    record[offset + 4:end].decode('utf-8')
    return end


def ray_records(path):
    data = path.read_bytes()
    require(data[:11] == b'VOX_RAY_V1\0', f'{path}: wrong ray header')
    offset, records = 11, []
    while offset < len(data):
        require(offset + 4 <= len(data), f'{path}: truncated record length')
        size = struct.unpack_from('<I', data, offset)[0]
        offset += 4
        require(size >= 70 and offset + size <= len(data), f'{path}: truncated/invalid record')
        record = data[offset:offset + size]
        require(all(math.isfinite(v) for v in struct.unpack_from('<7d', record)), 'Nonfinite ray input')
        require(record[64] in (0, 1), 'Invalid fixedOnly flag')
        cursor = read_string(record, 65)
        require(cursor < len(record) and record[cursor] in (0, 1), 'Invalid hit flag')
        hit = record[cursor]
        cursor += 1
        if hit:
            require(cursor + 60 <= len(record), 'Truncated hit values')
            require(all(math.isfinite(v) for v in struct.unpack_from('<7d', record, cursor)), 'Nonfinite ray result')
            cursor = read_string(record, cursor + 60)
        require(cursor == len(record), 'Trailing/missing packed ray fields')
        records.append(record)
        offset += size
    require(records, f'{path}: empty ray capture')
    return records


def counters(run):
    timing = run['helperTiming']
    require(timing['invalid'] is False, 'Invalid timing observer')
    result = {}
    for row in timing['rows']:
        name = row['name']
        require(name not in result, f'Duplicate timing owner {name}')
        require(row['errors'] == 0, f'Timing errors in {name}')
        require(type(row['calls']) is int and row['calls'] >= 0, f'Invalid calls in {name}')
        result[name] = row['calls']
    require(set(result) == EXPECTED_OWNERS, 'Missing/changed timing owners')
    allocation = run['allocation']
    require(allocation['invalid'] is False, 'Invalid allocation observer')
    require(not allocation['issues'], 'Allocation observer issues')
    names = allocation['names']
    require(len(names) == len(set(names)) == allocation['bindingCount'], 'Invalid allocation owner names')
    require(set(names) == set(result), 'Allocation/timing owner sets differ')
    frames = []
    for frame in allocation['frames']:
        require(len(frame['rows']) == len(names), 'Missing allocation owner row')
        require(all(row['errors'] == 0 for row in frame['rows']), 'Allocation owner errors')
        require(frame['used'] is True, 'Unused allocation frame')
        require(all(type(row['calls']) is int and row['calls'] >= 0 for row in frame['rows']), 'Invalid allocation call count')
        frames.append({'number': frame['number'], 'used': frame['used'],
                       'calls': dict(zip(names, (row['calls'] for row in frame['rows'])))})
    require(len(frames) == run['steps'], 'Allocation frame count differs from steps')
    return {'normalGcOwners': result, 'allocationFrames': frames}


def load_run(path):
    run = json.loads(path.read_text(encoding='utf-8-sig'),
                     parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f'Invalid JSON number {value}')))
    require(run['status'] == 'PASS', f'{path}: probe did not complete')
    require(run['collectorRestored'] is True, f'{path}: collector not restored')
    require(run['stateSnapshotsDeepFrozen'] is True, f'{path}: deep-frozen state marker required')
    for field in EXACT_FIELDS:
        require(field in run, f'{path}: missing {field}')
    require(len(run['metadata']) == 8, 'Eight-car fixture required')
    for car in run['metadata']:
        require(all(field in car for field in ['team', 'role', 'variant', 'parts', 'mass', 'spawn', 'wheels', 'legs', 'mechLegs']), 'Incomplete vehicle metadata')
    require(run['snapshots'], 'Missing frozen snapshots')
    require(run['finalState']['step'] < run['captureState']['step'], 'Missing post-timing capture progression')
    for snapshot in run['snapshots'] + [run['finalState'], run['captureState']]:
        require(type(snapshot['step']) is int and len(snapshot['cars']) == 8, 'Incomplete vehicle snapshot')
        require(all('state' in car and 'telemetry' in car for car in snapshot['cars']), 'Missing snapshot vehicle fields')
        for car, metadata in zip(snapshot['cars'], run['metadata']):
            state = car['state']
            require(all(field in state for field in ['p', 'q', 'lv', 'av', 'chassis', 'rotors', 'steer', 'hoverHeightScale', 'liftTilt']), 'Incomplete vehicle state')
            require(all(axis in state['p'] and axis in state['lv'] and axis in state['av'] for axis in ['x', 'y', 'z']), 'Incomplete position/velocity')
            require(all(axis in state['q'] for axis in ['x', 'y', 'z', 'w']), 'Incomplete quaternion')
            require(car['telemetry'], 'Empty telemetry')
            if metadata['legs']:
                require('legs' in state and 'states' in state['legs'], 'Missing nested leg state')
    require([case['name'] for case in run['filterCases']] == EXPECTED_FILTERS, 'Missing or changed 11 filter fixtures')
    require(run['filterCases'][0]['hit'] is False, 'Missing miss result')
    for case in run['filterCases'][1:]:
        require(all(field in case['hit'] for field in ['point', 'normal', 'dist', 'ownerType', 'bodyId', 'collider']), 'Missing filter hit fields')
    calls = counters(run)
    records = ray_records(Path(str(path) + '.rays.bin'))
    require(len(records) == run['capturedRays'], 'Ray count differs from complete binary records')
    require(type(run['normalGcWallMs']) is int and run['normalGcWallMs'] > 0, 'Missing measured wall time')
    return run, calls, records


def verify(paths):
    baseline, baseline_calls, baseline_records = load_run(paths[0])
    baseline_multiset = Counter(baseline_records)
    rows, failures = [], []
    for path in paths:
        row = {'path': str(path.resolve()), 'verification': 'FAIL'}
        try:
            run, calls, records = load_run(path)
            for field in EXACT_FIELDS:
                difference = first_difference(baseline[field], run[field], '$.' + field)
                require(difference is None, difference)
            difference = first_difference(baseline_calls, calls, '$.calls')
            require(difference is None, difference)
            current_multiset = Counter(records)
            row['rayRecordsRemoved'] = sum((baseline_multiset - current_multiset).values())
            row['rayRecordsAdded'] = sum((current_multiset - baseline_multiset).values())
            require(current_multiset == baseline_multiset, 'Complete ray request/result record multiset differs')
            row['verification'] = 'PASS'
            row['rayRecordMultisetEqual'] = True
            row['rayRecordSequenceEqual'] = records == baseline_records
            row['normalGcWallMs'] = run['normalGcWallMs']
            row['normalGcMsPerStep'] = run['normalGcWallMs'] / run['normalGcSteps']
        except (KeyError, ValueError, TypeError, OSError, struct.error, UnicodeError) as error:
            row['failure'] = str(error)
            failures.append({'path': row['path'], 'reason': str(error)})
        for artifact in [path, Path(str(path) + '.rays.bin')]:
            if artifact.is_file():
                row.setdefault('sha256', {})[artifact.name] = digest(artifact)
        rows.append(row)
    return {'verification': 'FAIL' if failures else 'PASS', 'runs': rows, 'failures': failures,
            'boundary': 'Offline exact behavior/call comparison of deep-frozen Native fixture runs. Binary record multisets must match; sequence equality and raw sequence SHA are reported separately. Wall times are observations, not statistical gain, complete battle FPS or device acceptance.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', type=Path, nargs='+', help='Fresh frozen A/B JSON runs; first is reference')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    require(len(args.runs) >= 2, 'Supply reference and at least one comparison')
    require(not args.output.exists(), 'Refusing to overwrite previous verification')
    try:
        report = verify(args.runs)
    except (KeyError, ValueError, TypeError, OSError, struct.error, UnicodeError) as error:
        report = {'verification': 'FAIL', 'failure': str(error), 'runs': [str(path) for path in args.runs]}
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
    raise SystemExit(0 if report['verification'] == 'PASS' else 1)


if __name__ == '__main__':
    main()
