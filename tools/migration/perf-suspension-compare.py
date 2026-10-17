"""Compare actual Native ABBA output; no timing estimates or synthetic samples."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('directory', type=Path)
args = parser.parse_args()
labels = ['baseline-1', 'candidate-1', 'candidate-2', 'baseline-2']
runs = {label: json.loads((args.directory / f'{label}.json').read_text('utf-8-sig')) for label in labels}
runtime = '0.9.0-beta.40_20261015.121839.6dc5c357cced'
for label, run in runs.items():
    assert run['status'] == 'PASS', f'{label}: status is not PASS'
    assert run['mode'] == label.rsplit('-', 1)[0], f'{label}: mode mismatch'
    assert run['seed'] == 16102026, f'{label}: seed mismatch'
    assert run['runtime'] == runtime, f'{label}: runtime mismatch'
    assert [(s['name'], s['equivalence']) for s in run['scenarios']] == [
        ('six-t3', True), ('rotor-moving-floor', True), ('six-t3', False), ('rotor-moving-floor', False)
    ], f'{label}: scenario order mismatch'
identity_path = args.directory / 'run-identity.json'
provenance = {'runnerIdentityAvailable': identity_path.exists(), 'processEvidenceAvailable': False}
if identity_path.exists():
    identity = json.loads(identity_path.read_text('utf-8-sig'))
    assert identity['runtimeVersion'] == runtime and identity['seed'] == 16102026, 'runner identity mismatch'
    assert identity['order'] == labels, 'runner order mismatch'
    for key in ['baselineCommit', 'runtimePath', 'runtimeSha256', 'probeSha256', 'baselineModuleSha256', 'candidateModuleSha256']:
        assert identity[key], f'runner identity missing {key}'
    for label in labels:
        process = json.loads((args.directory / f'{label}.process.json').read_text('utf-8-sig'))
        assert process['label'] == label and process['mode'] == label.rsplit('-', 1)[0], f'{label}: process mode mismatch'
        assert process['waitForExitCompleted'] is True, f'{label}: process exit not confirmed'
        if process['exitCodeAvailable']:
            assert process['exitCode'] == 0, f'{label}: process failed'
        else:
            assert process['exitCode'] is None, f'{label}: inconsistent missing exit code'
        assert f'-probe-mode={process["mode"]}' in process['arguments'], f'{label}: command mode mismatch'
    provenance['processEvidenceAvailable'] = True
checks = 0
comparisons = []
for i, reference in enumerate(runs['baseline-1']['scenarios']):
    for label in labels[1:]:
        result = runs[label]['scenarios'][i]
        for key in ['name', 'equivalence', 'steps', 'dt', 'metadata', 'stateDigest', 'traceDigest', 'counts', 'snapshots', 'randomTail']:
            assert reference[key] == result[key], f'{label} {reference["name"]} {reference["equivalence"]} differs at {key}'
            checks += 1
    if not reference['equivalence']:
        row = {'scenario': reference['name'], 'steps': reference['steps']}
        for metric in ['stepTotalMs', 'sampleMs', 'applyMs']:
            before = [runs[label]['scenarios'][i][metric] for label in ['baseline-1', 'baseline-2']]
            after = [runs[label]['scenarios'][i][metric] for label in ['candidate-1', 'candidate-2']]
            baseline = sum(before) / len(before)
            candidate = sum(after) / len(after)
            row[metric] = {'baselineRuns': before, 'candidateRuns': after, 'baselineMean': baseline,
                           'candidateMean': candidate, 'changePercent': (candidate / baseline - 1) * 100,
                           'baselineMsPerStep': baseline / reference['steps'], 'candidateMsPerStep': candidate / reference['steps']}
        comparisons.append(row)
result = {'status': 'PASS', 'checks': checks, 'runs': labels, 'timings': comparisons,
          'provenance': provenance,
          'sha256': {label: hashlib.sha256((args.directory / f'{label}.json').read_bytes()).hexdigest() for label in labels},
          'boundary': 'Actual isolated Native Bullet workload. Integer-ms per-call clock and shared machine scheduling may bias timings. Not whole-frame/mobile FPS or sustained performance.'}
path = args.directory / 'verification.json'
path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', 'utf8')
print(json.dumps(result, ensure_ascii=False, indent=2))
