"""Unwrap the frozen WOFF2 as OpenType, retaining original CFF hints/outlines."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/font-tooling'))
from fontTools.ttLib import TTFont


def main():
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
    source = Path(baseline['snapshot']) / 'shared/fonts/AlimamaShuHeiTi/AlimamaShuHeiTi-Bold.woff2'
    font = TTFont(source, recalcTimestamp=False)
    tables = ('CFF ', 'cmap', 'hmtx', 'hhea', 'GPOS')
    original = {tag: font.getTableData(tag) for tag in tables}
    font.flavor = None
    output = ROOT / 'assets/Fonts/VoxIndustrial-Bold.otf'
    font.save(output)
    imported = TTFont(output, recalcTimestamp=False)
    preserved = {tag: imported.getTableData(tag) == data for tag, data in original.items()}
    assert all(preserved.values()), 'Original outlines, hints or layout tables changed'
    evidence = {'baseline': baseline['commit'], 'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'glyphs': len(font.getGlyphOrder()),
                'preserved_tables': preserved, 'conversion': 'WOFF2 decompression only; original OpenType CFF outlines and hints retained'}
    (ROOT / 'docs/migration/evidence/industrial-font-import.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence))


if __name__ == '__main__':
    main()
