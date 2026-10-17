"""Compare Native diagnostic behavior and list section attribution, never gains."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('baseline', type=Path)
parser.add_argument('sections', type=Path)
args = parser.parse_args()
baseline, sections = [json.loads(p.read_text(encoding='utf-8-sig')) for p in (args.baseline, args.sections)]
assert baseline['status'] == sections['status'] == 'PASS'
assert baseline['sections'] is False and sections['sections'] is True
for key in ('timingSteps', 'counts', 'metadata', 'snapshots', 'randomTail'):
    assert baseline[key] == sections[key], 'Native diagnostic changed ' + key
for key in ('firing', 'ai', 'population', 'bodyCounts'):
    if key in baseline or key in sections:
        assert baseline.get(key) == sections.get(key), 'Native diagnostic changed ' + key
rows = [{'name': name, **row, 'selfPerSimulationStepMs': row['selfMs'] / sections['timingSteps']}
        for name, row in sections['stats'].items()]
assert rows, 'No section timings; instrumented source was not installed'
print(json.dumps({'status': 'PASS_BEHAVIOR_COMPARISON', 'snapshotCount': len(sections['snapshots']),
                  'timingSteps': sections['timingSteps'], 'counts': sections['counts'],
                  'rows': sorted(rows, key=lambda r: -r['selfMs']),
                  'boundary': 'Diagnostic attribution with nested scopes and wrapper overhead. Baseline/sections wall totals must not be used as optimization A/B gains. Not real battle FPS; no rendering/audio/UI. See source result boundary for the included simulation scenario.'}, indent=2))
