"""Export original title glyph contours for real VG stroke and per-letter motion."""
from pathlib import Path
import hashlib
import json
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/font-tooling'))
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen, RecordingPen
from fontTools.pens.qu2cuPen import Qu2CuPen
from fontTools.pens.areaPen import AreaPen

baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
relative = 'shared/fonts/ZCOOLQingKeHuangYou-Regular.ttf'
source = Path(baseline['snapshot']) / relative
assert hashlib.sha256(source.read_bytes()).hexdigest() == baseline['files'][relative]['sha256']
font = TTFont(source)
glyphs = font.getGlyphSet()
units = font['head'].unitsPerEm
text = '繁荣！秩序带薪年假……*加入星际前途维和先锋零件大师英雄成为——战地机修已损毁出动123砰轰NO!滋？扣款击绩效 +（感谢友军炮火）'
result = {'units': units, 'ascent': font['hhea'].ascent / units, 'descent': -font['hhea'].descent / units, 'glyphs': {}}
for char in sorted(set(text)):
    name = font.getBestCmap()[ord(char)]
    raw = DecomposingRecordingPen(glyphs)
    glyphs[name].draw(raw)
    cubic = RecordingPen()
    raw.replay(Qu2CuPen(cubic, max_err=0.2, all_cubic=True))
    contours, contour = [], []
    for command, points in cubic.value:
        contour.append((command, points))
        if command in ('closePath', 'endPath'):
            area = AreaPen(glyphs)
            for op, values in contour:
                getattr(area, op)(*values)
            commands = []
            for op, values in contour:
                commands.append([{'moveTo': 'm', 'lineTo': 'l', 'curveTo': 'c', 'closePath': 'z', 'endPath': 'z'}[op]] +
                                [round(value / units, 7) for point in values for value in (point[0], -point[1])])
            contours.append({'hole': area.value > 0, 'commands': commands})
            contour = []
    assert not contour
    result['glyphs'][char] = {'advance': font['hmtx'][name][0] / units, 'contours': contours}
out = ROOT / 'assets/Intro/Fonts/TitleGlyphs.json'
out.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
proof = {'result': 'PASS', 'baseline': baseline['commit'], 'source': relative, 'sourceSha256': baseline['files'][relative]['sha256'],
         'glyphs': len(result['glyphs']), 'bytes': out.stat().st_size, 'outputSha256': hashlib.sha256(out.read_bytes()).hexdigest(),
         'policy': 'Original decomposed contours, quadratic-to-cubic maximum error 0.2 original font units. No replacement typography.'}
(ROOT / 'docs/migration/evidence/intro-title-glyph-import.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
print(json.dumps(proof))
