"""Compare frozen real-game frames with only the combat point light toggled."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
results = {}
for quality in ('desktop', 'mobile'):
    on = Image.open(ROOT / f'combat-presentation-{quality}-light-on.png').convert('RGB')
    off = Image.open(ROOT / f'combat-presentation-{quality}-light-off.png').convert('RGB')
    a, b = np.asarray(on).astype(np.int16), np.asarray(off).astype(np.int16)
    delta = np.abs(a - b).max(axis=2)
    # Road below the car: excludes the muzzle sprite and every HUD element.
    w, h = on.size
    rect = (int(w*.35), int(h*.73), int(w*.67), int(h*.84))
    x0, y0, x1, y1 = rect
    road = delta[y0:y1, x0:x1]
    results[quality] = {'size': [w, h], 'road_rect': rect,
        'changed_pixels_gt_2': int((delta > 2).sum()),
        'road_changed_pixels_gt_2': int((road > 2).sum()),
        'road_max_difference': int(road.max())}
    assert (road > 2).sum() > 500, 'Point light must illuminate scene surfaces'
    if quality == 'desktop':
        crop = (int(w*.32), int(h*.40), int(w*.70), int(h*.86))
        first, second = off.crop(crop), on.crop(crop)
        panel = Image.new('RGB', (first.width*2, first.height+32), '#151b23')
        panel.paste(first, (0, 32)); panel.paste(second, (first.width, 32))
        draw = ImageDraw.Draw(panel)
        draw.text((12, 9), 'Point light OFF', fill='white')
        draw.text((first.width+12, 9), 'Point light ON - same frame / same effects', fill='white')
        panel.save(ROOT / 'combat-presentation-comparison.png')
(ROOT / 'combat-presentation-pixels.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps(results))
