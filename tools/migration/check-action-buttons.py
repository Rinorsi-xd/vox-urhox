"""Exercise actual project button classes and engine pointer/click methods, no GPU."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source_names = ['shared/ui/home.js', 'shared/ui/shell.js']
source_hashes = {}
for name in source_names:
    source_hashes[name] = sha(Path(baseline['snapshot']) / name)
    assert source_hashes[name] == baseline['files'][name]['sha256']
home = (Path(baseline['snapshot']) / source_names[0]).read_text(encoding='utf-8')
assert "b.addEventListener( 'click', () => this.h.onCta( b.dataset.cta ) )" in home
assert "[ 'Enter', 'NumpadEnter', 'Space' ].includes( e.code )" in home

files = []
for path in sorted((root / 'scripts').rglob('*.lua')):
    text = path.read_text(encoding='utf-8')
    relative = path.relative_to(root).as_posix()
    # The sound detector intentionally compares the original ancestor identity.
    if relative not in ['scripts/ui/ActionButton.lua', 'scripts/audio/UiSound.lua']:
        assert 'UI.Button' not in text, relative
        assert 'urhox-libs/UI/Widgets/Button' not in text, relative
    if relative != 'scripts/ui/GarageHud.lua' and ("require('ui.ActionButton')" in text or "require 'ui.ActionButton'" in text):
        files.append(relative)
assert len(files) == 23 and 'scripts/ui/SourceSelectionBar.lua' in files, files

# Preserve every property, callback, rendering function and class body from e31.
old = root / '.tmp/outgame-cached-1792089242755'
unchanged = []
subsequent = {
    'scripts/ui/MissionChoice.lua': 'docs/migration/evidence/story-choice-presentation-offline.json',
    'scripts/ui/StoryPage.lua': 'docs/migration/evidence/story-page-lifecycle-offline.json',
}
portrait_reports = ['story-result-rows', 'story-result-quote', 'comms-portraits']
for report_name in portrait_reports:
    evidence = json.loads((root / f'docs/migration/evidence/{report_name}-offline.json').read_text(encoding='utf-8'))
    assert evidence['result'] == 'PASS', report_name
    assert evidence.get('sourceCommit', evidence.get('source', {}).get('commit')) == baseline['commit'], report_name
    for field in ['production', 'productionHashes']:
        for name, expected_hash in evidence.get(field, {}).items():
            assert expected_hash == sha(root / name), (report_name, name)
    if report_name != 'story-result-quote':
        hashes = evidence.get('production', evidence.get('productionHashes', {}))
        assert hashes['scripts/ui/MissionResult.lua'] == sha(root / 'scripts/ui/MissionResult.lua'), report_name


def canonical_result_portrait(text):
    old_path = "'UI/Faces/'..(r.grade=='B' and 'nono_deadpan' or 'nono_smile')..'.png'"
    new_path = "require('ui.CommsPortrait').Path('nono',r.grade=='B' and 'deadpan' or 'smile')"
    assert text.count(old_path) == 1, 'exact historical result portrait expression'
    return text.replace(old_path, new_path)


portrait_guard_negatives = 0
for name in files:
    if name == 'scripts/ui/SourceSelectionBar.lua':
        continue  # New independently source-checked module, not an e31 conversion.
    if name in subsequent:
        evidence = json.loads((root / subsequent[name]).read_text(encoding='utf-8'))
        assert evidence.get('result', evidence.get('status')) == 'PASS', name
        assert evidence.get('source', evidence.get('baseline', {}))['commit'] == baseline['commit'], name
        assert evidence.get('production', evidence.get('productionHashes', {}))[name] == sha(root / name), name
        continue  # Still loaded and exercised by the full native Button matrix below.
    prior = (old / name).read_text(encoding='utf-8')
    expected = prior.replace("require 'urhox-libs/UI/Widgets/Button'", "require 'ui.ActionButton'")
    expected = expected.replace("require('urhox-libs/UI/Widgets/Button')", "require('ui.ActionButton')")
    expected = expected.replace('UI.Button:Extend(', "require('ui.ActionButton'):Extend(")
    if name == 'scripts/ui/MissionResult.lua':
        expected = canonical_result_portrait(expected)
        actual = (root / name).read_text(encoding='utf-8')
        for invalid in [actual.replace('panel.age=panel.age+(dt or 0)', 'panel.age=0'),
                        actual.replace('session.wantsReturn=true', 'session.wantsReturn=false'),
                        actual.replace("Path('nono',", "Path('huhu',")]:
            assert invalid != actual and invalid != expected, 'unrelated result change must remain rejected'
            portrait_guard_negatives += 1
    assert expected == (root / name).read_text(encoding='utf-8'), name
    if name != 'scripts/ui/MissionResult.lua':
        unchanged.append(name)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().TEST_MODULES = lua.table_from([p[8:-4].replace('/', '.') for p in files])
resources = {}
for name in ['UI/Outgame.json', 'UI/SourceHomeMenu.json']:
    resources[name] = json.loads((root / 'assets' / name).read_text(encoding='utf-8'))

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

lua.globals().TEST_RESOURCES = table(resources)
widget = (root / 'urhox-libs/UI/Core/Widget.lua').read_text(encoding='utf-8')
extend = re.search(r'function Widget:Extend\(name\).*?\nend', widget, re.S).group()
ui = (root / 'urhox-libs/UI/Core/UI.lua').read_text(encoding='utf-8')
handlers = '\n'.join(re.search(r'function UI\.'+name+r'\([^\n]*\).*?\nend', ui, re.S).group()
                     for name in ['HandlePointerDown', 'HandlePointerUp', 'HandlePointerCancel', 'HandleKeyDown'])
lua.globals().ENGINE_EXTEND = extend
lua.globals().ENGINE_HANDLERS = handlers
result = lua.execute((root / 'tools/migration/check-action-buttons.lua').read_text(encoding='utf-8'))
engine = ['urhox-libs/UI/Widgets/Button.lua', 'urhox-libs/UI/Core/PointerEvent.lua',
          'urhox-libs/UI/Core/Widget.lua', 'urhox-libs/UI/Core/UI.lua']
report = {'result': 'PASS', 'checks': result['checks'], 'classes': list(result['classes'].values()),
          'matrixCases': result['matrixCases'], 'oldRightClickReproduced': result['oldRightClickReproduced'],
          'sourceCommit': baseline['commit'], 'sourceHashes': source_hashes,
          'productionHashes': {p: sha(root / p) for p in ['scripts/ui/ActionButton.lua', *files]},
          'engineReferenceHashes': {p: sha(root / p) for p in engine},
          'unchangedExceptButtonBase': unchanged,
          'subsequentSourceParityReports': subsequent,
          'canonicalResultPortraitReports': portrait_reports,
          'canonicalResultPortraitNegativeCases': portrait_guard_negatives,
          'boundary': 'Actual PointerEvent and complete engine Button module, extracted actual Widget.Extend and UI pointer/key dispatch methods, all 23 project button modules loaded and all descendant Button classes including MissionChoice exercised. Original 20 e31 modules retain exact base-only transformation. MissionResult permits only the exact additional canonical Nono path expression; three unrelated timing/callback/speaker changes remain rejected. Its rows/render/callback coverage and portrait resolver/dependencies bind to fresh story-result-rows and comms-portraits reports at the frozen commit. Fresh story-result-quote covers actual Mission/StoryComms audio semantics, not MissionResult rendering. MissionChoice subsequent source layout/animation coverage binds to fresh story-choice-presentation. New SourceSelectionBar has separate source parity coverage. Layout/native rendering and focus/hit-test edges adapted. Frozen H5 native click/keyboard listener contract inspected; browser DOM activation and actual public page navigation require root Web regression. Native keyboard behavior covered separately in button-keyboard-offline.json. No GPU or performance acceptance.'}
out = root / 'docs/migration/evidence/action-buttons-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: report[k] for k in ['result', 'checks', 'classes', 'matrixCases', 'oldRightClickReproduced']}, indent=2))
