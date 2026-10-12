"""Export original display-font EM advances and active horizontal kern lookups.

No glyphs are redrawn. This compensates NanoVG's rounded pixel advances while
retaining its font atlas rendering. Only the CSS unicode ranges are exported.
"""
from pathlib import Path
import hashlib
import json
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/font-tooling'))
from fontTools.ttLib import TTFont


def latin(cp):
    return cp <= 255 or 0x2010 <= cp <= 0x2027 or 0x2030 <= cp <= 0x205e


def export_face(path, include):
    font = TTFont(path)
    cmap = {chr(cp): glyph for cp, glyph in font.getBestCmap().items()
            if include(cp) and not unicodedata.combining(chr(cp))}
    reverse = {}
    for char, glyph in cmap.items():
        reverse.setdefault(glyph, []).append(char)
    pairs = {}
    table = font['GPOS'].table
    indexes = sorted({i for feature in table.FeatureList.FeatureRecord
                      if feature.FeatureTag == 'kern' for i in feature.Feature.LookupListIndex})
    for index in indexes:
        lookup = table.LookupList.Lookup[index]
        # Both source fonts use IgnoreMarks. Combining sequences stay on the
        # existing native fallback path rather than claiming full shaping.
        assert lookup.LookupType == 2 and lookup.LookupFlag in (0, 8)
        # A pair uses the first matching subtable within a lookup, then sums
        # adjustments across lookups. Keep zero pairs until selection is done.
        selected = {}
        for sub in lookup.SubTable:
            assert sub.ValueFormat1 == 4 and sub.ValueFormat2 == 0
            if sub.Format == 1:
                for left, record in zip(sub.Coverage.glyphs, sub.PairSet):
                    if left not in reverse:
                        continue
                    for pair in record.PairValueRecord:
                        if pair.SecondGlyph in reverse:
                            selected.setdefault((left, pair.SecondGlyph), pair.Value1.XAdvance)
            else:
                assert sub.Format == 2
                groups = {}
                for right in reverse:
                    groups.setdefault(sub.ClassDef2.classDefs.get(right, 0), []).append(right)
                for left in sub.Coverage.glyphs:
                    if left not in reverse:
                        continue
                    row = sub.Class1Record[sub.ClassDef1.classDefs.get(left, 0)].Class2Record
                    for cls, rights in groups.items():
                        value = row[cls].Value1.XAdvance
                        for right in rights:
                            selected.setdefault((left, right), value)
        for (left, right), value in selected.items():
            if value:
                for a in reverse[left]:
                    for b in reverse[right]:
                        pairs[a+b] = pairs.get(a+b, 0) + value
    advances = {}
    for char, glyph in cmap.items():
        advances.setdefault(font['hmtx'][glyph][0], []).append(char)
    # Deduplicate equivalent character classes after applying GPOS semantics.
    # Keep compact UTF-8 membership strings rather than a 37k-entry pair map.
    lefts = {}
    for pair, value in pairs.items():
        if value:
            lefts.setdefault(pair[0], {}).setdefault(value, []).append(pair[1])
    classes = {}
    for left, groups in lefts.items():
        key = tuple(sorted((value, ''.join(sorted(chars))) for value, chars in groups.items()))
        classes.setdefault(key, []).append(left)
    return {'units': font['head'].unitsPerEm, 'ascent': font['hhea'].ascent, 'descent': -font['hhea'].descent,
            'advances': [[value, ''.join(chars)] for value, chars in advances.items()],
            'kern': [[ ''.join(chars), list(groups)] for groups, chars in classes.items()],
            'characters': len(cmap), 'pairs': sum(value != 0 for value in pairs.values())}


def main():
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
    source = Path(baseline['snapshot']) / 'shared/fonts'
    inputs = {
        'vox-title': (ROOT / 'assets/Fonts/VoxIndustrial-Bold.ttf', lambda cp: True),
        'vox-display': (source / 'BarlowCondensed-BoldItalic.ttf', latin),
        'vox-tabular': (ROOT / 'assets/Fonts/VoxDisplayTabular-BoldItalic.ttf', latin),
    }
    result = {name: export_face(path, include) for name, (path, include) in inputs.items()}
    output = ROOT / 'assets/UI/SourceFontMetrics.json'
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    evidence = {name: {'source': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                       'characters': result[name]['characters'], 'kern_pairs': result[name]['pairs']}
                for name, (path, _) in inputs.items()}
    evidence['bytes'] = output.stat().st_size
    (ROOT / 'docs/migration/evidence/ui-font-metrics-import.json').write_text(
        json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence, ensure_ascii=False))


if __name__ == '__main__':
    main()
