"""Strict matching uninstrumented Native effects ABBA, not whole-game FPS."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('directory', type=Path)
p.add_argument('labels', nargs=4)
args = p.parse_args()
identities, values = [], []
for label in args.labels:
    item = json.loads((args.directory / f'{label}.identity.json').read_text(encoding='utf-8-sig'))
    data = json.loads((args.directory / f'{label}.json').read_text(encoding='utf-8-sig'))
    assert data['status'] == 'PASS' and data['mode'] == 'timing' and data['seed'] == 17102026
    for stream in ['stdout', 'stderr']:
        log = (args.directory / f'{label}.{stream}.log').read_text(encoding='utf-8-sig')
        assert 'ERROR:' not in log, (label, 'INVALID_NATIVE_ERROR', stream)
    identities.append(item)
    values.append(data['scenarios'][0])
assert [x['variant'] for x in identities] == ['A', 'B', 'B', 'A'], 'ABBA identity order'
ref = identities[0]
for item in identities:
    for key in ['runtimeSha256', 'resourcePrefix', 'sourceManifest', 'scenario', 'mode']:
        assert item[key] == ref[key], ('identity', key)
    different = {key for key in set(item['sourceHashes']) | set(ref['sourceHashes'])
                 if item['sourceHashes'].get(key) != ref['sourceHashes'].get(key)}
    assert different <= {'scripts/render/CombatEffects.lua'}, ('non-target drift', different)
assert identities[1]['sourceHashes']['scripts/render/CombatEffects.lua'] == identities[2]['sourceHashes']['scripts/render/CombatEffects.lua']
assert ref['sourceHashes']['scripts/render/CombatEffects.lua'] == identities[3]['sourceHashes']['scripts/render/CombatEffects.lua']
assert ref['sourceHashes']['scripts/render/CombatEffects.lua'] != identities[1]['sourceHashes']['scripts/render/CombatEffects.lua']
for value in values:
    assert value['collectorRunning'] and not value['stages'], 'Normal GC and no timing wrappers'
    for key in ['name', 'frames', 'batches', 'peakBatches', 'groundCalls', 'randomTail', 'zapAgeSamples', 'zapsMax', 'zapsActiveFrames']:
        assert value[key] == values[0][key], ('workload/state drift', key)
baseline = sum(values[i]['totalMs'] for i in [0, 3]) / sum(values[i]['frames'] for i in [0, 3])
candidate = sum(values[i]['totalMs'] for i in [1, 2]) / sum(values[i]['frames'] for i in [1, 2])
report = {'status': 'PASS', 'labels': args.labels, 'scenario': values[0]['name'],
          'ABBA_totalMs': [x['totalMs'] for x in values], 'baselineMsPerUpdate': baseline,
          'candidateMsPerUpdate': candidate, 'changePercent': (candidate / baseline - 1) * 100 if baseline else None,
          'zapAgeSamples': values[0]['zapAgeSamples'],
          'boundary': 'Clean Native CustomGeometry controlled Effects.Update workload, uninstrumented normal-GC ABBA. No real match Web/TapTap/845 FPS acceptance or proof this scenario matches natural effect composition.'}
print(json.dumps(report, indent=2))
