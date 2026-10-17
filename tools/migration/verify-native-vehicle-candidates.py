"""Verify archived Native candidates; does not start a Runtime or modify gameplay."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/migration/evidence/native-vehicle-allocation-2026-10-17'
LABELS = ['helper-allocation-timing-1', 'clear-scalar-candidate-1',
          'math3-scalar-candidate-1', 'math3-abba-A1', 'math3-abba-B1',
          'math3-abba-B2', 'math3-abba-A2']


def read(name):
    return json.loads((EVIDENCE / name).read_text(encoding='utf-8-sig'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def main():
    baseline = read(LABELS[0] + '.json')
    baseline_launch = read(LABELS[0] + '.launch.json')
    baseline_identity = read('baseline-source-identity.json')
    source_changes = {}
    for identity_name, allowed_path in [('clear-source-identity.json', 'scripts/drive/LegControl.lua'),
                                        ('math3-source-identity.json', 'scripts/core/Math3.lua')]:
        identity = read(identity_name)
        assert identity['sourceHashes'].keys() == baseline_identity['sourceHashes'].keys()
        changed = [path for path, value in identity['sourceHashes'].items()
                   if baseline_identity['sourceHashes'][path] != value]
        assert changed == [allowed_path], changed
        source_changes[identity_name] = changed
    assert digest(EVIDENCE / 'before/LegControl.lua') == baseline_identity['sourceHashes']['scripts/drive/LegControl.lua']
    assert digest(EVIDENCE / 'before/Math3.lua') == baseline_identity['sourceHashes']['scripts/core/Math3.lua']
    assert digest(EVIDENCE / 'clear-candidate-LegControl.lua') == read('clear-source-identity.json')['sourceHashes']['scripts/drive/LegControl.lua']
    assert digest(EVIDENCE / 'math3-candidate.lua') == read('math3-source-identity.json')['sourceHashes']['scripts/core/Math3.lua']
    state_keys = ['metadata', 'snapshots', 'finalState', 'bodyWrap']
    rows = []
    for label in LABELS:
        result, launch = read(label + '.json'), read(label + '.launch.json')
        assert result['status'] == 'PASS' and result['collectorRestored']
        assert not result['allocation']['invalid'] and not result['helperTiming']['invalid']
        assert len(result['allocation']['frames']) == 24 and result['normalGcSteps'] == 600
        assert launch['runtimeSha256'] == baseline_launch['runtimeSha256']
        assert launch['probeHashes'] == baseline_launch['probeHashes']
        comparisons = {key: canonical(result[key]) == canonical(baseline[key]) for key in state_keys}
        assert all(comparisons.values()), (label, comparisons)
        for field in ['helperTiming', 'allocation']:
            owner_rows = 'rows' if field == 'helperTiming' else 'totals'
            actual = {row['name']: row for row in result[field][owner_rows]}
            expected = {row['name']: row for row in baseline[field][owner_rows]}
            assert actual.keys() == expected.keys()
            assert all(row['errors'] == 0 and row['calls'] == expected[name]['calls']
                       for name, row in actual.items())
        for frame in result['allocation']['frames']:
            assert abs(sum(row['selfKiB'] for row in frame['rows']) - frame['measuredKiB']) < 1e-9
            assert abs(frame['measuredKiB'] + frame['unscopedKiB'] - frame['netKiB']) < 1e-9
        timing = {row['name']: row for row in result['helperTiming']['rows']}
        rows.append({'label': label, 'status': result['status'], 'stateMatches': comparisons,
                     'normalGcWallMs': result['normalGcWallMs'],
                     'legSelfMs': timing['drive.LegControl.Step']['selfMs'],
                     'netKiB': sum(frame['netKiB'] for frame in result['allocation']['frames']),
                     'raycastCalls': timing['physics.Space.Raycast']['calls'],
                     'bodyWrap': result['bodyWrap']})
    report = {
        'status': 'PASS', 'candidateDecision': 'REJECTED_NO_RELIABLE_CPU_GAIN',
        'productionChanged': False, 'runs': rows, 'sourceChanges': source_changes,
        'allCollectorRestored': True, 'allStatesAndCallCountsEqual': True,
        'runtimeSha256': baseline_launch['runtimeSha256'],
        'productionRetainsBaseline': {path: digest(ROOT / path) == baseline_identity['sourceHashes'][path]
                                     for path in ['scripts/drive/LegControl.lua', 'scripts/core/Math3.lua']},
        'evidenceHashes': {str(path.relative_to(EVIDENCE)).replace('\\', '/'): digest(path)
                           for path in EVIDENCE.rglob('*') if path.is_file() and path.name != 'verification.json'},
        'boundary': 'All seven real Native runs retain exact parsed JSON numeric/state data, metadata, snapshots, final state and owner call counts. No tolerance or discarded A1 sample. Same eight vehicles/seed and 600 normal-GC steps, plus separate bounded no-GC allocation capture. Integer wall measurements include instrumentation and host scheduling; the noisy ABBA cannot establish a repeatable CPU improvement or Web/device FPS gain. Production candidate not applied.'
    }
    assert all(report['productionRetainsBaseline'].values())
    output = EVIDENCE / 'verification.json'
    assert not output.exists(), 'Preserve existing verification'
    output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['status', 'candidateDecision', 'productionChanged', 'runs']}))


if __name__ == '__main__':
    main()
