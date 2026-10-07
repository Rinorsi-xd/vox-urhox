from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
results = {}
for kind in ('Thruster', 'Hover'):
    on = np.asarray(Image.open(root / f'equipment-depth-{kind}-on.png').convert('RGB'), dtype=float)
    off = np.asarray(Image.open(root / f'equipment-depth-{kind}-off.png').convert('RGB'), dtype=float)
    delta = np.abs(on - off)
    h, w = on.shape[:2]
    def region(a, box):
        x0, y0, x1, y1 = box
        return a[int(h*y0):int(h*y1), int(w*x0):int(w*x1)]
    full = region(delta, (.45, .34, .55, .65))
    partial = region(delta, (.675, .34, .72, .65))
    exposed = region(delta, (.633, .32, .655, .47))
    visible = region(delta, (.27, .32, .36, .62))
    inside = np.asarray(Image.open(root / f'equipment-depth-{kind}-inside.png').convert('RGB'), dtype=float)
    stats = dict(visible_delta_mean=float(visible.mean()), full_block_delta_max=float(full.max()),
                 partial_block_delta_max=float(partial.max()), exposed_delta_mean=float(exposed.mean()),
                 inside_mean=float(inside.mean()), inside_blue_minus_red=float((inside[:, :, 2]-inside[:, :, 0]).mean()))
    assert stats['visible_delta_mean'] > 10, stats
    assert stats['full_block_delta_max'] <= 2, stats
    assert stats['partial_block_delta_max'] <= 2, stats
    assert stats['exposed_delta_mean'] > 3, stats
    assert stats['inside_mean'] > 10 and stats['inside_blue_minus_red'] > 5, stats
    results[kind] = stats
(root / 'equipment-depth-pixels.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
print(json.dumps(results, indent=2))

frames = [('HeavyLift', 'active', 'T5 lift + forward thrust'), ('HeavyLift', 'cut', 'Power cut / exhaust cleared'),
          ('HoverBottom', 'active', 'Bottom hover / real ground contact'), ('HoverSide', 'active', 'Side hover / shared flow texture'),
          ('LegT5', 'active', 'T5 planted contact rings'), ('LegT5', 'jump', 'T5 jump / feet clear ground')]
w, h = 680, 360
sheet = Image.new('RGB', (w*2, (h+32)*3), '#151b23')
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 19)
draw = ImageDraw.Draw(sheet)
for i, (car, phase, label) in enumerate(frames):
    im = Image.open(root / f'current-equipment-{car}-mobile-{phase}.png').convert('RGB').resize((w, h), Image.Resampling.LANCZOS)
    x, y = i % 2 * w, i // 2 * (h+32)
    sheet.paste(im, (x, y+32)); draw.text((x+10, y+5), label, font=font, fill='#dcecff')
sheet.save(root / 'equipment-states.png')
print(root / 'equipment-states.png')
