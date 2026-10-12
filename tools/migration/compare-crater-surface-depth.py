"""Inspect the searchlight depth regression in real, frozen production renders."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
views = ['fort', 'ship', 'interior', 'deck', 'gate']
sheet = Image.new('RGB', (1280, 365 * len(views)), (24, 26, 30))
draw = ImageDraw.Draw(sheet)
stats = {}
for row, view in enumerate(views):
    frames = []
    for col, state in enumerate(['before', 'after']):
        im = Image.open(ROOT / f'crater-depth-{view}-{state}.png').convert('RGB')
        frames.append(np.asarray(im).astype(np.int16))
        draw.text((640 * col + 8, 365 * row + 5), f'{view} / {state}', fill='white')
        sheet.paste(im.resize((640, 339)), (640 * col, 365 * row + 25))
    diff = np.abs(frames[1] - frames[0])
    stats[view] = {'max_channel_delta': int(diff.max()), 'changed_pixels': int(np.any(diff > 1, axis=2).sum())}
sheet.save(ROOT / 'crater-depth-comparison.png')

crop = (800, 170, 1150, 450)
detail = Image.new('RGB', (2100, 590), (24, 26, 30))
draw = ImageDraw.Draw(detail)
for col, (label, filename) in enumerate([
    ('H5 reference', 'crater-source-formal-ship.png'),
    ('UrhoX before', 'crater-depth-ship-before.png'),
    ('UrhoX corrected', 'crater-depth-ship-after.png'),
]):
    draw.text((col * 700 + 8, 8), label, fill='white')
    detail.paste(Image.open(ROOT / filename).crop(crop).resize((700, 560)), (col * 700, 30))
detail.save(ROOT / 'crater-depth-detail.png')
stats['limits'] = 'Frozen native A/B changes only searchlight housing slope bias. H5 reference has different render scale and animation phase; no whole-scene pixel-parity claim.'
(ROOT / 'crater-surface-depth-pixels.json').write_text(json.dumps(stats, indent=2), encoding='utf8')
assert stats['ship']['changed_pixels'] > 0, 'Depth correction must change actual rendered pixels'
print(json.dumps(stats, indent=2))
