"""Compare actual browser and Runtime captures; never redraw game pixels.

The browser capture is JPEG, so this measures tolerance, not pixel equality.
Fixtures use the source CSS rectangle at (160,120), cropped from (80,40).
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

evidence = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
source_name, native_name = 'h5-menu-shadow-contrast.jpg', 'pc-menu-shadow-1.png'
source = Image.open(evidence / source_name).convert('RGB')
native = Image.open(evidence / native_name).convert('RGB')
assert source.size == native.size == (480, 490)
y, x = np.indices((490, 480))
mask = ((x < 79) | (x > 400) | (y < 79) | (y > 414)) & (x > 20) & (x < 460) & (y > 20) & (y < 485)
error = np.abs(np.asarray(source).astype(float) - np.asarray(native).astype(float))[mask]
report = {
    'source': source_name, 'native': native_name, 'scope': 'menu exterior shadow on neutral gray, 1x only',
    'limitations': 'Browser JPEG compression; not full UI parity or actual browser DPR 2 verification',
    'samples': int(mask.sum()), 'mean_absolute_error_255': float(error.mean()),
    'p90': float(np.percentile(error, 90)), 'p99': float(np.percentile(error, 99)),
    'maximum': float(error.max()), 'passed': bool(error.mean() < 1 and np.percentile(error, 99) <= 3),
}
(evidence / 'pc-menu-shadow-comparison.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
sheet = Image.new('RGB', (960, 520), '#15171b')
draw = ImageDraw.Draw(sheet)
for i, (picture, label) in enumerate([(source, 'Original H5 / Chromium'), (native, 'UrhoX / NanoVG')]):
    sheet.paste(picture, (480 * i, 30))
    draw.text((480 * i + 10, 8), label, fill='white')
sheet.save(evidence / 'pc-menu-shadow-comparison.png')
print(json.dumps(report, indent=2))
assert report['passed'], 'Menu shadow exterior drifted from source capture'
