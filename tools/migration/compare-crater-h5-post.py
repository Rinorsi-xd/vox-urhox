"""Compare actual H5 WebGL pixels with native Runtime output, without source edits."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/migration/evidence'
records = []
for name in ('default', 'exposure', 'no-mist', 'no-bloom', 'odd-resize', 'shafts', 'shafts-blocked'):
    web_path = EVIDENCE / f'crater-h5-post-{name}.png'
    native_path = ROOT / f'.tmp/post-native-{name}.png'
    retained = EVIDENCE / f'crater-native-post-pattern-{name}.png'
    if not native_path.exists():
        native_path = retained
    web = np.asarray(Image.open(web_path).convert('RGB'), dtype=np.int16)
    native = np.asarray(Image.open(native_path).convert('RGB'), dtype=np.int16)
    assert web.shape == native.shape, name
    error = np.abs(web - native)
    # Retain the exact input, since .tmp is disposable.
    retained.write_bytes(native_path.read_bytes())
    records.append(dict(name=name, width=web.shape[1], height=web.shape[0],
                        max_error=int(error.max()), mean_error=float(error.mean()),
                        h5_sha256=hashlib.sha256(web_path.read_bytes()).hexdigest(),
                        native_sha256=hashlib.sha256(retained.read_bytes()).hexdigest()))
lit=np.asarray(Image.open(EVIDENCE/'crater-native-post-pattern-shafts.png').convert('RGB'),dtype=np.int16)
blocked=np.asarray(Image.open(EVIDENCE/'crater-native-post-pattern-shafts-blocked.png').convert('RGB'),dtype=np.int16)
shaft_delta=int(np.max(lit-blocked))
result = dict(cases=records, shaft_visible_delta=shaft_delta, passed=all(r['max_error'] <= 2 for r in records) and shaft_delta>=2,
              limits='Full RGB comparison of diagnostic patterns rendered through the actual H5 Pipeline; not whole-map material, shadow, or animation parity.')
(EVIDENCE / 'crater-h5-native-post-comparison.json').write_text(json.dumps(result, indent=2), encoding='utf-8')

out = Image.new('RGB', (1440, 804), '#161920')
draw = ImageDraw.Draw(out)
for i, (name, label) in enumerate([
    ('crater-h5-post-map-dim', 'H5 reactor 0.6'), ('crater-native-breath-dim', 'UrhoX reactor 0.6'),
    ('crater-h5-post-map-bright', 'H5 reactor 1.0'), ('crater-native-breath-bright', 'UrhoX reactor 1.0')]):
    im = Image.open(EVIDENCE / (name + '.png')); im.thumbnail((720, 380))
    x, y = (i % 2) * 720, (i // 2) * 402
    out.paste(im, (x, y + 22)); draw.text((x + 10, y + 4), label, fill='white')
out.save(EVIDENCE / 'crater-breath-comparison.png')
print(json.dumps(result, indent=2))
assert result['passed'], 'Actual H5 and native postprocessing differ'
