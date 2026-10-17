"""Compare actual Lua layout against frozen H5 browser rectangles."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

evidence = ROOT / 'docs/migration/evidence'
reference = json.loads((evidence / 'source-mobile-editor-20261017.json').read_text(encoding='utf-8'))
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
assert reference['baseline'] == baseline['commit']
for name, digest in reference['sourceHashes'].items():
    assert baseline['files'][name]['sha256'] == digest, name

filename = ROOT / 'scripts/ui/TouchEditorLayout.lua'
source = filename.read_text(encoding='utf-8')

def verify(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    layout = lua.execute(code)
    checks = 0
    for view in reference['layouts']:
        for scale in [1, 2.4, 3]:
            for mode in ['tap', 'aim']:
                actual = layout.Calculate(view['width']*scale, view['height']*scale,
                                          view['width'], view['height'], lua.table(), 1, mode == 'aim', None)
                slots = [r for r in view['states'][mode] if r['action'] == 'me-slot']
                assert actual.slotCount == len(slots), 'visible slots'
                checks += 1
                for index, row in enumerate(slots, 1):
                    rect = actual.slots[index]
                    values = [rect.left/scale, rect.top/scale, rect.width/scale, rect.height/scale]
                    assert all(abs(a-b) <= 1 for a, b in zip(values, row['rect'])), 'slot rectangle'
                    checks += 1
                dock = next(r for r in view['states'][mode] if r['action'] == 'me-dock')
                rect = actual.dock
                values = [rect.left/scale, rect.top/scale, rect.width/scale, rect.height/scale]
                assert all(abs(a-b) <= 1 for a, b in zip(values, dock['rect'])), 'dock rectangle'
                checks += 1
    return checks

checks = verify(source)
negatives = []
for old, new, expected in [
    ('slotCount=10', 'slotCount=narrow and 8 or 10', 'visible slots'),
    ('local dockWidth=587+2/u', 'local dockWidth=(narrow and 505 or 587)+2/u', 'slot rectangle'),
]:
    assert source.count(old) == 1
    try:
        verify(source.replace(old, new))
    except AssertionError as error:
        assert str(error) == expected, str(error)
        negatives.append({'restoredOldBehavior': new, 'rejected': str(error)})
    else:
        raise AssertionError('Old layout incorrectly passed')

report = {'result': 'PASS', 'checks': checks, 'negativeControls': negatives,
          'baseline': reference['baseline'], 'reference': 'source-mobile-editor-20261017.json',
          'productionSha256': hashlib.sha256(filename.read_bytes()).hexdigest(),
          'boundary': 'Actual Lua Calculate versus H5 browser CSS rectangles at four viewports and three UI ratios. No target rendering, pointer input or mobile performance claim.'}
(evidence / 'mobile-hotbar-parity-20261017.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': checks, 'negativeControls': len(negatives)}))
