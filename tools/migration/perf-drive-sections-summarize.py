"""Archive measured crater diagnostic evidence and verify repeat identities."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / '.tmp/perf-drive-sections-crater-20261016'
DEST = ROOT / 'docs/migration/evidence/drive-sections-crater-20261016'
LABELS = (
    'crater-nofire-baseline-1', 'crater-nofire-sections-1',
    'crater-fire-baseline-1', 'crater-fire-sections-1',
    'crater-noai-baseline-1', 'crater-nofire-baseline-2',
)
KEYS = ('timingSteps', 'counts', 'metadata', 'snapshots', 'randomTail',
        'firing', 'ai', 'population', 'bodyCounts')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    results = {name: json.loads((SOURCE / (name + '.json')).read_text()) for name in LABELS}
    for name, result in results.items():
        assert result['status'] == 'PASS', name
        assert result['bodyCounts'] == {'map': 2064, 'final': 2070}, name
        assert result['population']['byAlive'] == {'6': 600}, name
    comparisons = []
    for a, b in ((LABELS[0], LABELS[1]), (LABELS[2], LABELS[3]), (LABELS[0], LABELS[5])):
        for key in KEYS:
            assert results[a][key] == results[b][key], (a, b, key)
        comparisons.append({'a': a, 'b': b, 'exactKeys': list(KEYS), 'status': 'PASS'})
    DEST.mkdir(parents=True, exist_ok=True)
    files = ['source-identity.json']
    for name in LABELS:
        files.extend(name + suffix for suffix in ('.json', '.launch.json', '.stdout.log', '.stderr.log'))
    for name in files:
        shutil.copyfile(SOURCE / name, DEST / name)
    variants = ['LegGait-baseline.lua', 'LegGait-sections.lua', 'ContactControl-baseline.lua', 'ContactControl-sections.lua']
    for name in variants:
        shutil.copyfile(SOURCE / name, DEST / name)
    for name in ('perf-drive-sections-crater.lua', 'perf-drive-sections-scope.lua'):
        shutil.copyfile(SOURCE / 'scripts' / name, DEST / name)
    identity = json.loads((SOURCE / 'source-identity.json').read_text())
    summaries = []
    for name, result in results.items():
        summaries.append({
            'label': name, 'wallMs': result['wallMs'], 'steps': result['timingSteps'],
            'perStepMs': result['wallMs'] / result['timingSteps'],
            'sections': result['sections'], 'firing': result['firing'], 'ai': result['ai'],
            'shotsIncludingWarmup': result['counts']['shots'], 'bodyCounts': result['bodyCounts'],
            'rows': sorted(({'name': key, **row, 'selfMsPerStep': row['selfMs'] / result['timingSteps'],
                             'inclusiveMsPerStep': row['ms'] / result['timingSteps']}
                            for key, row in result['stats'].items()), key=lambda row: -row['selfMs']),
        })
    asset_paths = ['Crater/Layout.json', 'Crater/VisualHeight.bin', 'Crater/Boulders.json']
    layout = json.loads((ROOT / 'assets/Crater/Layout.json').read_text(encoding='utf-8'))
    asset_paths.extend(part['path'] for part in layout['dataParts']['parts'])
    summary = {
        'status': 'PASS', 'comparisons': comparisons, 'runs': summaries,
        'snapshotSourceHashes': identity['sourceHashes'],
        'assetsAtArchivalSha256': {path: sha(ROOT / 'assets' / path) for path in asset_paths},
        'evidenceSha256': {path.name: sha(path) for path in DEST.iterdir() if path.is_file() and path.name != 'summary.json'},
        'boundary': 'Native headless six T3 variant0 cars at an artificial crater firefight location. Real collision/AI/weapon/damage modules; no objectives, round rules, player controls, render/audio/UI. Instrumented durations include timing/wrapper overhead. Not identical Web roster, not optimization A/B gains or device FPS. Asset hashes captured at archive time, not independently at each launch.',
    }
    (DEST / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'PASS', 'evidence': str(DEST), 'comparisons': len(comparisons),
                      'runs': [{key: value for key, value in row.items() if key != 'rows'} for row in summaries]}, indent=2))


if __name__ == '__main__':
    main()
