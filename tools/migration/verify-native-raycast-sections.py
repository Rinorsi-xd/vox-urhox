"""Verify archived raycast diagnostics without starting a Runtime."""
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/migration/evidence/native-raycast-sections-2026-10-17'


def read(name):
    return json.loads((EVIDENCE / name).read_text(encoding='utf-8-sig'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ray_records(path):
    data = path.read_bytes()
    assert data[:11] == b'VOX_RAY_V1\0'
    offset, records = 11, []
    while offset < len(data):
        size = struct.unpack_from('<I', data, offset)[0]
        offset += 4
        records.append(data[offset:offset + size])
        offset += size
    assert offset == len(data)
    return records


def without_leg_state(value):
    value = json.loads(json.dumps(value))
    for car in value['cars']:
        car['state'].pop('legs', None)
    return value


def main():
    section = read('raycast-sections-1.json')
    before, single, shadow = [read(name + '.json') for name in ['closest-A1', 'closest-B1', 'closest-shadow-1']]
    old = json.loads((ROOT / 'docs/migration/evidence/native-vehicle-allocation-2026-10-17/helper-allocation-timing-1.json').read_text())
    for run in [section, before, single, shadow]:
        assert run['status'] == 'PASS' and run['collectorRestored']
        assert not run['helperTiming']['invalid'] and not run['allocation']['invalid']
        assert all(row['errors'] == 0 for row in run['helperTiming']['rows'])
    keys = ['metadata', 'snapshots', 'finalState', 'bodyWrap']
    assert all(section[key] == old[key] for key in keys)
    assert all(section[key] == before[key] for key in ['metadata', 'snapshots', 'bodyWrap'])
    # GetState retains nested leg references; post-timing capture mutates those tables.
    assert without_leg_state(section['finalState']) == without_leg_state(before['finalState'])
    shadow_keys = keys + ['captureState', 'filterCases', 'capturedRays']
    assert all(shadow[key] == before[key] for key in shadow_keys)
    assert single['metadata'] == before['metadata']
    assert single['filterCases'] == before['filterCases'] and len(before['filterCases']) == 11
    assert single['snapshots'] != before['snapshots'] and single['finalState'] != before['finalState']
    assert single['captureState'] != before['captureState']
    baseline_records = ray_records(EVIDENCE / 'closest-A1.json.rays.bin')
    shadow_records = ray_records(EVIDENCE / 'closest-shadow-1.json.rays.bin')
    assert len(baseline_records) == len(shadow_records) == 66417
    assert Counter(baseline_records) == Counter(shadow_records)
    assert digest(EVIDENCE / 'closest-A1.json.rays.bin') != digest(EVIDENCE / 'closest-B1.json.rays.bin')
    assert shadow['shadowDifferences'] == 1 and shadow['capturedRays'] == 66417
    first = shadow['firstDifferences'][0]
    assert first['original']['dist'] == first['alternative']['dist']
    assert first['original']['point'] == first['alternative']['point']
    assert first['original']['collider'] != first['alternative']['collider']
    assert first['original']['normal'] != first['alternative']['normal']
    launch_hashes = {read(name + '.launch.json')['runtimeSha256'] for name in
                     ['raycast-sections-1', 'closest-A1', 'closest-B1', 'closest-shadow-1']}
    assert len(launch_hashes) == 1
    rows = {row['name']: row for row in section['helperTiming']['rows']}
    assert rows['physics.Space.Raycast']['calls'] == 68158
    assert rows['ray.Query']['calls'] == 68158 and rows['ray.Result']['calls'] == 50367
    assert sum(rows[name]['selfMs'] for name in ['physics.Space.Raycast', 'ray.Input', 'ray.Query', 'ray.Select', 'ray.Result']) == rows['physics.Space.Raycast']['ms']
    report = {
        'verification': 'PASS', 'candidateDecision': 'REJECTED_BEHAVIOR_DIFFERENCE',
        'productionSpaceUnchanged': digest(ROOT / 'scripts/physics/Space.lua') == digest(EVIDENCE / 'baseline-Space.lua'),
        'sectionMatchesFrozenVehicleState': True, 'shadowMatchesBaselineState': True,
        'shadowRayRecordMultisetEqual': True, 'shadowRayRecordSequenceEqual': baseline_records == shadow_records,
        'crossProbeFinalStateBoundary': 'Nested leg tables retained by GetState mutate during the later capture phase; only other timed final fields are compared across probes with different capture lengths. Section matches old baseline fully; A and shadow match fully.',
        'filterCasesEqual': True, 'filterCaseCount': 11, 'singleVehicleStateEqual': False,
        'singleCapturedRays': single['capturedRays'], 'baselineCapturedRays': before['capturedRays'],
        'normalGcWallMs': {'sections': section['normalGcWallMs'], 'A': before['normalGcWallMs'], 'B': single['normalGcWallMs']},
        'raySections': [row for row in section['helperTiming']['rows'] if row['name'].startswith('ray.') or row['name'] == 'physics.Space.Raycast'],
        'firstSameInputDifference': first,
        'evidenceHashes': {str(path.relative_to(EVIDENCE)): digest(path) for path in EVIDENCE.rglob('*') if path.is_file() and path.name != 'verification.json'},
        'boundary': 'Same-input query shadow comparison runs after all timing/allocation capture. All 66417 complete packed request/result records match baseline as a multiset, with different order. Closest-hit candidate diverges on an equal-distance terrain seam despite 11 small filter/tie fixtures passing. No ABBA or production change after failed behavior gate. Integer wall timings include observers and scheduling; not Web/device FPS.'
    }
    output = EVIDENCE / 'verification.json'
    assert not output.exists(), 'Preserve previous verification'
    output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['verification', 'candidateDecision', 'productionSpaceUnchanged', 'firstSameInputDifference']}))


if __name__ == '__main__':
    main()
