"""Verify the frozen H5 body font and explicit native fallback faces.

Run verify-loading-flow.ps1 first. Uses the existing development fonttools install;
the game itself does not depend on Python or fonttools.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/font-tooling'))
from fontTools.ttLib import TTCollection, TTFont

evidence = root / 'docs/migration/evidence'
paths = json.loads((evidence / 'loading-selected-fonts.json').read_text(encoding='utf-8'))
system = Path(os.environ['SystemRoot']) / 'Fonts'
result = []
baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source = Path(baseline['snapshot']) / 'shared/fonts/AlimamaShuHeiTi/AlimamaShuHeiTi-Bold.woff2'
assert paths['body'] == paths['bold'] == 'Fonts/VoxIndustrial-Bold.otf'
selected = root / 'assets' / paths['body']
with TTFont(source, recalcTimestamp=False) as src, TTFont(selected, recalcTimestamp=False) as dst:
    tables = ('CFF ', 'cmap', 'hmtx', 'hhea', 'GPOS')
    assert all(src.getTableData(tag) == dst.getTableData(tag) for tag in tables)
    observed = paths['bodyMetrics']
    assert observed['ascent'] == dst['hhea'].ascent / dst['head'].unitsPerEm
    assert observed['descent'] == -dst['hhea'].descent / dst['head'].unitsPerEm
    assert observed['bufferBytes'] == len(dst.getTableData('cmap')) + len(dst.getTableData('hmtx'))
    result.append({'source': str(source), 'selected': str(selected), 'baseline': baseline['commit'],
                   'tables_identical': True, 'body_metrics_verified': observed,
                   'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                   'selected_sha256': hashlib.sha256(selected.read_bytes()).hexdigest()})
inline = json.loads((evidence / 'pc-inline-font.json').read_text(encoding='utf-8'))
with TTCollection(system / 'simsun.ttc', lazy=True) as src, TTCollection(inline['path'], lazy=True) as dst:
    target = next(font for font in src.fonts if font['name'].getDebugName(1) == 'SimSun')
    assert all(target.reader[tag] == dst.fonts[0].reader[tag] for tag in target.reader.keys())
    assert inline['ascent'] == target['hhea'].ascent / target['head'].unitsPerEm
    assert inline['descent'] == -target['hhea'].descent / target['head'].unitsPerEm
    cmap = target.getBestCmap()
    advances = {target['hmtx'][cmap[cp]][0] / target['head'].unitsPerEm for cp in range(32, 127)}
    assert advances == {inline['advance']}
    result.append({'source': str(system / 'simsun.ttc'), 'selected': inline['path'], 'face': 'SimSun',
                   'tables_identical': True, 'ascii_advance_em': inline['advance'], 'source_css_13px_advance': 7})
with TTFont(paths['code'], lazy=True) as font:
    assert font['name'].getDebugName(1) == 'Consolas'
    cmap = font.getBestCmap()
    advances = {font['hmtx'][cmap[cp]][0] for cp in range(32, 127)}
    assert len(advances) == 1
    advance = advances.pop() / font['head'].unitsPerEm
    assert advance == paths['codeAdvance']
    result.append({'source': paths['code'], 'face': 'Consolas', 'ascii_advance_em': advance})
symbol = json.loads((evidence / 'pc-help-symbol-font.json').read_text(encoding='utf-8'))
with TTFont(symbol['path'], lazy=True) as font:
    units = font['head'].unitsPerEm
    assert symbol['ascent'] == font['OS/2'].usWinAscent / units
    assert symbol['descent'] == font['OS/2'].usWinDescent / units
    glyph = font.getBestCmap()[0x21c4]
    assert font['hmtx'][glyph][0] / units == 1
    result.append({'source': symbol['path'], 'face': font['name'].getDebugName(1),
                   'glyph': 'U+21C4', 'advance_em': 1, 'windows_metrics_verified': True})
(evidence / 'pc-system-font-tables.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'result': 'PASS', 'faces': len(result), 'tables_identical': True, 'code_advance_em': advance}))
