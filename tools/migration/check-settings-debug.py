"""Execute actual settings/debug mouse lifecycle with native UI services adapted."""
import json
from g5_offline import ROOT, LuaRuntime, hashes, negatives

paths = ['scripts/ui/PauseMenu.lua', 'scripts/ui/GameSettings.lua', 'scripts/ui/DebugPanel.lua',
         'scripts/app/DebugActions.lua', 'scripts/main.lua', 'scripts/ui/DialogHost.lua']
before = hashes(paths)
source = (ROOT / 'scripts/main.lua').read_text(encoding='utf-8')
controls = source[source.index('            app.performanceControls={'):source.index('            if app.debugEnabled')]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().performanceControlsSource = controls
for name in paths:
    lua.execute('assert(load(...))', (ROOT / name).read_text(encoding='utf-8'))
result = lua.execute((ROOT / 'tools/migration/check-settings-debug.lua').read_text(encoding='utf-8'))
checks = [result[i] for i in range(1, len(result) + 1)]
rejected = negatives(['tools/migration/check-settings-debug.lua'], [
    ('scripts/ui/PauseMenu.lua', 'Host.Dispose(owner)', 'Host.Close(owner)', 'one actual debug overlay replaces and destroys settings without frozen close'),
    ('scripts/ui/DebugPanel.lua', 'if self.app.performanceControls then right=', 'if false then right=', 'debug including close never overlaps restored PERF'),
], {'performanceControlsSource': controls})
assert before == hashes(paths)
report = {'result': 'PASS', 'checks': checks, 'negativeControls': rejected, 'sha256': before,
          'boundary': 'Actual GameSettings/PauseMenu/DialogHost/DebugPanel/DebugActions and extracted main performanceControls callbacks executed with UI, input and engine services adapted. No F keys used. SourceModal native widget service adapted, including immediate Close/Destroy callbacks. No rendered UI, browser/native click or frame-rate acceptance.'}
out = ROOT / 'docs/migration/evidence/settings-debug-mouse-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'negativeControls': len(rejected), 'evidence': str(out)}))
