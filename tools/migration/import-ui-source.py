"""Copy source UI fonts and convert its SVG paths to NanoVG path commands.

No artwork is generated. Source assets remain unchanged; OFL notices travel
with both fonts. Requires fonttools[woff] in .tmp/font-tooling.
"""
from pathlib import Path
import argparse, sys, re, json, shutil, hashlib, subprocess
root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check-source', action='store_true', help='Validate frozen inputs without changing assets')
args = parser.parse_args()
baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
snapshot = (root / baseline['snapshot']).resolve()
source = snapshot / 'shared'
inputs = ['ui/icons.js', 'ui/home.js', 'ui/ui.js', 'css/style.css',
          'fonts/SmileySans-Oblique.ttf.woff2', 'fonts/BarlowCondensed-BoldItalic.ttf',
          'fonts/BarlowCondensed-OFL.txt', 'fonts/SmileySans-OFL.txt']
verified = {}
for relative in inputs:
    path = source / relative
    expected = baseline['files']['shared/' + relative]['sha256']
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise ValueError(f'Frozen UI source hash mismatch: shared/{relative}')
    verified['shared/' + relative] = actual
if args.check_source:
    print(json.dumps({'result': 'PASS', 'commit': baseline['commit'],
                      'snapshot': str(snapshot), 'inputs': verified, 'assets_written': False}))
    sys.exit(0)
sys.path.insert(0, str(root / '.tmp/font-tooling'))
from fontTools.ttLib import TTFont
from fontTools.svgLib.path import parse_path
from fontTools.pens.recordingPen import RecordingPen
fonts = root / 'assets/Fonts'
font = TTFont(source / 'fonts/SmileySans-Oblique.ttf.woff2')
font.flavor = None
font.save(fonts / 'SmileySans-Oblique.ttf')
for name in ['BarlowCondensed-BoldItalic.ttf', 'BarlowCondensed-OFL.txt', 'SmileySans-OFL.txt']:
    shutil.copy2(source / 'fonts' / name, fonts / name)
# NanoVG has no OpenType feature switch. Preserve the source font's actual
# tnum outlines by baking that single substitution into a separately named face.
# The normal display face remains untouched for selectors without tabular-nums.
tabular = TTFont(source / 'fonts/BarlowCondensed-BoldItalic.ttf', recalcTimestamp=False)
cmap = tabular.getBestCmap()
substitutions = {}
gsub = tabular['GSUB'].table
for record in gsub.FeatureList.FeatureRecord:
    if record.FeatureTag == 'tnum':
        for index in record.Feature.LookupListIndex:
            lookup = gsub.LookupList.Lookup[index]
            assert lookup.LookupType == 1, 'Expected source tnum single substitutions'
            for table in lookup.SubTable:
                substitutions.update(table.mapping)
digits = {code: substitutions[cmap[code]] for code in range(ord('0'), ord('9') + 1)}
advances = {chr(code): tabular['hmtx'][glyph][0] for code, glyph in digits.items()}
assert len(set(advances.values())) == 1, 'Source tabular advances must match'
for table in tabular['cmap'].tables:
    if table.isUnicode():
        for code, glyph in digits.items():
            if code in table.cmap:
                table.cmap[code] = glyph
names = {1: 'Vox Display Tabular', 3: 'VoxDisplayTabular-BoldItalic-SourceTnum',
         4: 'Vox Display Tabular Bold Italic', 6: 'VoxDisplayTabular-BoldItalic',
         16: 'Vox Display Tabular'}
for record in tabular['name'].names:
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
tabular_path = fonts / 'VoxDisplayTabular-BoldItalic.ttf'
tabular.save(tabular_path)
font_evidence = {'source': 'shared/fonts/BarlowCondensed-BoldItalic.ttf',
                 'source_commit': baseline['commit'], 'snapshot': baseline['snapshot'],
                 'source_sha256': hashlib.sha256((source/'fonts/BarlowCondensed-BoldItalic.ttf').read_bytes()).hexdigest(),
                 'derived': str(tabular_path.relative_to(root)),
                 'derived_sha256': hashlib.sha256(tabular_path.read_bytes()).hexdigest(),
                 'feature': 'tnum', 'units_per_em': tabular['head'].unitsPerEm,
                 'digit_glyphs': {chr(k): v for k, v in digits.items()}, 'advance_units': advances,
                 'license': 'assets/Fonts/BarlowCondensed-OFL.txt'}
(root/'docs/migration/evidence/ui-tabular-font.json').write_text(json.dumps(font_evidence, indent=2), encoding='utf-8')
text = (source / 'ui/icons.js').read_text(encoding='utf-8')
paths = dict(re.findall(r"^\s*(\w+): '([^']+)'", text, re.M))
result = {}
for name, path in paths.items():
    pen = RecordingPen()
    parse_path(path, pen)
    result[name] = [[op, *[round(v, 6) for p in points for v in p]] for op, points in pen.value]
output = root / 'assets/UI/SourceIcons.json'
output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
subprocess.run(['node', str(root/'tools/migration/import-source-help.cjs'), '--write'], cwd=root, check=True)
manifest = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [source/'ui/icons.js', source/'ui/home.js', source/'ui/ui.js', source/'css/style.css',
                      source/'fonts/SmileySans-Oblique.ttf.woff2', source/'fonts/BarlowCondensed-BoldItalic.ttf']}
(root/'docs/migration/evidence/ui-source-import.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Imported {len(result)} source vector icons, 2 OFL fonts and source tnum font variant')
from source_font_metrics import main as import_font_metrics
import_font_metrics()
import runpy
runpy.run_path(str(Path(__file__).with_name('import-ui-shadow.py')), run_name='__main__')
