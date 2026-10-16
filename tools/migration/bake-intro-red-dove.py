"""Derive the frozen actNo red bitmap; preserve source canvas dimensions/alpha."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASELINE = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
SOURCE = Path(BASELINE['snapshot']) / 'shared/assets/intro/raw/dove.png'
ORIGINAL = ROOT / 'assets/Intro/Images/dove.png'
OUTPUT = ROOT / 'assets/Intro/Images/dove_red.png'
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert digest(SOURCE) == BASELINE['files']['shared/assets/intro/raw/dove.png']['sha256']
assert digest(ORIGINAL) == digest(SOURCE), 'Migration dove no longer matches frozen source'
source = Image.open(SOURCE).convert('RGBA')
alpha = source.getchannel('A')
rgb = source.convert('RGB')

def transform(matrix):
    global rgb
    rgb = rgb.convert('RGB', tuple(value for row in matrix for value in (*row, 0)))

# CSS filter primitives, in source order: sepia(1), saturate(7), hue-rotate(-28deg), brightness(1.15).
transform([[.393, .769, .189], [.349, .686, .168], [.272, .534, .131]])
s = 7
transform([[.213 + .787*s, .715 - .715*s, .072 - .072*s],
           [.213 - .213*s, .715 + .285*s, .072 - .072*s],
           [.213 - .213*s, .715 - .715*s, .072 + .928*s]])
c, s = math.cos(math.radians(-28)), math.sin(math.radians(-28))
transform([[.213 + .787*c - .213*s, .715 - .715*c - .715*s, .072 - .072*c + .928*s],
           [.213 - .213*c + .143*s, .715 + .285*c + .140*s, .072 - .072*c - .283*s],
           [.213 - .213*c - .787*s, .715 - .715*c + .715*s, .072 + .928*c + .072*s]])
transform([[1.15, 0, 0], [0, 1.15, 0], [0, 0, 1.15]])
result = rgb.convert('RGBA')
result.putalpha(alpha)
result.save(OUTPUT, optimize=True)
assert result.size == source.size and result.getchannel('A').tobytes() == alpha.tobytes()
report = {'result': 'PASS', 'sourceCommit': BASELINE['commit'], 'sourceHash': digest(SOURCE),
          'filter': 'sepia(1) saturate(7) hue-rotate(-28deg) brightness(1.15)',
          'productionHashes': {'assets/Intro/Images/dove_red.png': digest(OUTPUT),
                               'assets/Intro/Images/dove.png': digest(ORIGINAL)},
          'size': list(result.size), 'alphaUnchanged': True,
          'boundary': 'Deterministic CSS color-matrix bake with 8-bit channel clamping. Browser Canvas rounding comparison and final NanoVG raster remain pending.'}
(ROOT / 'docs/migration/evidence/intro-red-dove-bake.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
