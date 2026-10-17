"""Validate frozen Native effects ABBA and separate Native equivalence evidence."""
import argparse
import json
import re
from pathlib import Path


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


p = argparse.ArgumentParser(description=__doc__)
p.add_argument('directory', type=Path)
p.add_argument('labels', nargs=4, help='Uninstrumented timing A1 B1 B2 A2')
p.add_argument('--equivalence', nargs=2, required=True, metavar=('A_LABEL', 'B_LABEL'))
args = p.parse_args()
fixture = read_json(args.directory / 'identity.json')


def load(label, expected_mode, expected_variant):
    assert re.fullmatch(r'[A-Za-z0-9_-]+', label), 'Invalid evidence label'
    item = read_json(args.directory / f'{label}.identity.json')
    data = read_json(args.directory / f'{label}.json')
    validation = read_json(args.directory / f'{label}.validation.json')
    process = read_json(args.directory / f'{label}.process.json')
    assert validation['valid'] is True and not validation['nativeErrors'], (label, 'Native errors')
    assert process['completedWithinDeadline'] is True, (label, 'Process deadline')
    assert process['exitCode'] in (None, 0), (label, 'Native process exit')
    for stream in ('stdout', 'stderr'):
        log = (args.directory / f'{label}.{stream}.log').read_text(encoding='utf-8-sig')
        assert not re.search(r'\bERROR:', log), (label, 'INVALID_NATIVE_ERROR', stream)
    assert item['variant'] == expected_variant, (label, 'Variant order')
    assert item['mode'] == data['mode'] == expected_mode, (label, 'Mode')
    assert item['label'] == data['label'] == label, (label, 'Label')
    assert data['status'] == 'PASS' and data['seed'] == 17102026, (label, 'Probe status/seed')
    assert len(data['scenarios']) == 1, (label, 'Single scenario required')
    value = data['scenarios'][0]
    assert item['scenario'] == value['name'], (label, 'Scenario')
    assert value['frames'] == (180 if expected_mode == 'equivalence' else 480), (label, 'Frames')
    assert value['collectorRunning'] is True and not value['stages'], (label, 'Normal GC/no wrappers')
    for key in ('resourceInputs', 'runtimeInputs'):
        assert item[key] == fixture[key] and item[key], (label, 'Frozen inputs', key)
    assert item['runtimeSha256'] == fixture['runtimeInputs']['UrhoXRuntime.exe'], (label, 'Runtime exe')
    assert item['sourceManifest'] == fixture['sourceManifest'], (label, 'Manifest')
    assert item['resourcePrefix'] == fixture['resources'], (label, 'Resource prefix')
    assert item['sourceHashes'] == fixture['snapshots'][expected_variant]['hashes'], (label, 'Source snapshot')
    return item, data, value


loaded = [load(label, 'timing', variant) for label, variant in zip(args.labels, 'ABBA')]
equivalent = [load(label, 'equivalence', variant) for label, variant in zip(args.equivalence, 'AB')]
assert len(set(args.labels + args.equivalence)) == 6, 'Evidence labels must be unique'
ref_identity = loaded[0][0]
for item, _, _ in loaded + equivalent:
    for key in ('runtime', 'runtimeSha256', 'runtimeInputs', 'resourcePrefix', 'resourceInputs', 'sourceManifest', 'scenario'):
        assert item[key] == ref_identity[key], ('Environment/workload mismatch', key)
    changed = {key for key in set(item['sourceHashes']) | set(ref_identity['sourceHashes'])
               if item['sourceHashes'].get(key) != ref_identity['sourceHashes'].get(key)}
    assert changed <= {'scripts/render/CombatEffects.lua'}, ('Non-target source drift', changed)
assert fixture['beforeSha256'] != fixture['candidateSha256'], 'Candidate must differ'
for variant, sha in [('A', fixture['beforeSha256']), ('B', fixture['candidateSha256'])]:
    assert fixture['snapshots'][variant]['hashes']['scripts/render/CombatEffects.lua'] == sha

workload_keys = ('name', 'frames', 'batches', 'peakBatches', 'groundCalls', 'randomTail',
                 'zapAgeSamples', 'zapsMax', 'zapsActiveFrames')
values = [entry[2] for entry in loaded]
for value in values:
    assert value['totalMs'] >= 0, 'Negative elapsed time'
    for key in workload_keys:
        assert value[key] == values[0][key], ('Timing workload/state drift', key)
for key in workload_keys + ('geometryDigest', 'stateDigest', 'geometryCalls'):
    assert equivalent[0][2][key] == equivalent[1][2][key], ('Native equivalence drift', key)
for key in ('nativeCopy', 'batchBoundaries'):
    assert equivalent[0][1][key] and equivalent[0][1][key] == equivalent[1][1][key], ('Native boundary/copy drift', key)

baseline = sum(values[i]['totalMs'] for i in (0, 3)) / sum(values[i]['frames'] for i in (0, 3))
candidate = sum(values[i]['totalMs'] for i in (1, 2)) / sum(values[i]['frames'] for i in (1, 2))
report = {
    'status': 'PASS', 'labels': args.labels, 'equivalenceLabels': args.equivalence,
    'scenario': values[0]['name'], 'ABBA_totalMs': [value['totalMs'] for value in values],
    'baselineMsPerUpdate': baseline, 'candidateMsPerUpdate': candidate,
    'changePercent': (candidate / baseline - 1) * 100 if baseline else None,
    'zapAgeSamples': values[0]['zapAgeSamples'],
    'boundary': 'Clean Native controlled Effects.Update wall time, frozen A/B resources and scripts, normal GC. '
                'Separate Native state/geometry equivalence required. No real-match Web/TapTap/845 FPS acceptance '
                'or proof this scenario matches natural effects composition.',
}
print(json.dumps(report, indent=2))
