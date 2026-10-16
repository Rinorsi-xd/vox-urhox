"""Compare frozen JS public page/toast callbacks with actual Lua UI owners."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
subprocess.run(['node', 'tools/migration/check-ui-sounds-source.cjs'], check=True)
oracle = json.loads((ROOT / '.tmp/ui-sounds-source.json').read_text(encoding='utf-8'))
paths = ['scripts/ui/SourceToasts.lua', 'scripts/ui/SalvagePage.lua', 'scripts/ui/GarageHud.lua']
sources = {p: (ROOT / p).read_text(encoding='utf-8') for p in paths}
fixture = (ROOT / 'tools/migration/check-hangar-cue-hooks.lua').read_text(encoding='utf-8')


def run(candidate):
    env = runpy.run_path(str(ROOT / 'tools/migration/verify-garage-acquire-entry-offline.py'))
    lua = env['lua']

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().HOOK_SOURCES = table(candidate)
    lua.globals().HOOK_ORACLE = table(oracle)
    return lua.execute(fixture)


checks = run(sources)
negative = []
for name, file, old, new in [
    ('missing-home-whoosh', paths[2], "require('audio.UiSound').Play('whoosh')", 'do end'),
    ('ignore-salvage-quiet', paths[1], 'if not (options and options.quiet) then', 'if true then'),
    ('warn-sounds-as-error', paths[0], "if kind=='bad' then", "if kind=='bad' or kind=='warn' then"),
]:
    assert old in sources[file], name
    candidate = dict(sources)
    candidate[file] = candidate[file].replace(old, new, 1)
    try:
        run(candidate)
    except Exception:
        negative.append(name)
    else:
        raise AssertionError('Negative control escaped: ' + name)

# Negative runs invoke prerequisite fixtures; refresh their evidence against final production.
runpy.run_path(str(ROOT / 'tools/migration/verify-garage-acquire-entry-offline.py'))
hashes = lambda names: {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in names}
report = {'result': 'PASS', 'checks': checks, 'negativeControls': negative,
          'sourceCommit': oracle['commit'], 'sourceHashes': oracle['sourceHashes'],
          'productionHashes': hashes(paths + ['scripts/ui/SalvageBuy.lua', 'scripts/audio/UiSound.lua', 'assets/UI/Sounds.json']),
          'inputs': hashes(['tools/migration/check-hangar-cue-hooks.lua', 'tools/migration/check-hangar-cue-hooks.py', 'tools/migration/check-ui-sounds-source.cjs']),
          'boundary': 'Actual GarageHud.Create installed SetTab, SalvagePage.Tab and SourceToasts.Push versus eight frozen JS tab and four toast cases. Widget/cache/audio devices are adapted. No GPU, listening, transition-go coverage or mobile performance acceptance.'}
output = ROOT / 'docs/migration/evidence/hangar-cue-hooks-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
