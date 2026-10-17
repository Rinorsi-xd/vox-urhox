"""Exercise the actual comparator against recorded output and invalid identities."""
import contextlib
import copy
import io
import json
import runpy
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
recorded = root / 'docs/migration/evidence/perf-suspension-2026-10-16'
labels = ['baseline-1', 'candidate-1', 'candidate-2', 'baseline-2']
raw = {label: json.loads((recorded / f'{label}.json').read_text('utf8')) for label in labels}
checks = 0
with tempfile.TemporaryDirectory(prefix='perf-suspension-identity-') as directory:
    path = Path(directory)
    def check(changed=None, value=None, expected_failure=False):
        global checks
        fixture = copy.deepcopy(raw)
        if changed:
            fixture['candidate-1'][changed] = value
        for label, data in fixture.items():
            (path / f'{label}.json').write_text(json.dumps(data), 'utf8')
        sys.argv = ['perf-suspension-compare.py', str(path)]
        failure = None
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                runpy.run_path(str(root / 'tools/migration/perf-suspension-compare.py'), run_name='__main__')
        except AssertionError as error:
            failure = error
        assert (failure is not None) == expected_failure, (changed, failure)
        checks += 1
    check()
    for field, invalid in [('mode', 'baseline'), ('seed', 0), ('runtime', 'wrong-runtime'), ('status', 'FAIL')]:
        check(field, invalid, expected_failure=True)
    identity = {'baselineCommit': 'fixture', 'runtimePath': 'fixture', 'runtimeSha256': 'fixture',
                'probeSha256': 'fixture', 'baselineModuleSha256': 'fixture', 'candidateModuleSha256': 'fixture',
                'runtimeVersion': raw['baseline-1']['runtime'], 'seed': 16102026, 'order': labels}
    (path / 'run-identity.json').write_text(json.dumps(identity), 'utf8')
    for label in labels:
        mode = label.rsplit('-', 1)[0]
        process = {'label': label, 'mode': mode, 'waitForExitCompleted': True, 'exitCodeAvailable': False,
                   'exitCode': None, 'arguments': [f'-probe-mode={mode}']}
        (path / f'{label}.process.json').write_text(json.dumps(process), 'utf8')
    check()
    process_path = path / 'candidate-1.process.json'
    process = json.loads(process_path.read_text('utf8'))
    process['waitForExitCompleted'] = False
    process_path.write_text(json.dumps(process), 'utf8')
    check(expected_failure=True)
    process['waitForExitCompleted'] = True
    process['arguments'] = ['-probe-mode=baseline']
    process_path.write_text(json.dumps(process), 'utf8')
    check(expected_failure=True)
print(json.dumps({'status': 'PASS', 'comparatorFixtureChecks': checks, 'boundary': 'Fixture identities test validation only; no Native execution or new performance measurements.'}))
