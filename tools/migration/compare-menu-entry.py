"""Actual paused source CSS and native menu frames, no replacement drawing.

Browser JPEG captures are full viewport; crop locally to preserve edge pixels.
Native DPR2 is verified separately by Runtime, not compared to browser DPR1.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
times = [0, 10, 25, 50, 100, 150, 200]
y, x = np.indices((490, 480))
exterior = ((x < 78) | (x > 402) | (y < 78) | (y > 426)) & (x > 20) & (x < 460) & (y > 20) & (y < 485)
# Inside the card's side padding: no glyphs, icons or hover fill.
interior = (((x >= 82) & (x <= 85)) | ((x >= 395) & (x <= 398))) & (y >= 106) & (y <= 398)
report = {'scope': 'Actual source CSS and native menu at 1x; JPEG tolerance, not full UI parity',
          'source_css_sha256': hashlib.sha256(Path('D:/Rino_Project/Vox/shared/css/style.css').read_bytes()).hexdigest(),
          'frames': []}
fixture = json.loads((root / 'tools/migration/fixtures/source-menu-entry.json').read_text(encoding='utf-8'))
assert fixture['source_css_sha256'] == report['source_css_sha256'], 'Original CSS changed; recapture browser reference'
frames = []
sheet = Image.new('RGB', (1280, 694), '#15171b')
draw = ImageDraw.Draw(sheet)
for time in times:
    source = Image.open(evidence / f'h5-menu-entry-{time}.jpg').convert('RGB')
    assert source.size == (1280, 720), 'Expected original full browser viewport'
    source = source.crop((80, 40, 560, 530))
    native = Image.open(evidence / f'pc-menu-entry-1-{time}.png').convert('RGB')
    assert native.size == source.size
    error = np.abs(np.asarray(source).astype(float) - np.asarray(native).astype(float))
    row = {'time': time}
    for name, mask in [('background', interior), ('shadow', exterior)]:
        diff = error[mask]
        row[name] = {'mean_absolute_error_255': float(diff.mean()), 'p99': float(np.percentile(diff, 99)), 'max': float(diff.max())}
    row['passed'] = all(row[key]['mean_absolute_error_255'] < 1.5 and row[key]['p99'] <= 4 for key in ('background', 'shadow'))
    report['frames'].append(row)
    frame = Image.new('RGB', (960, 520), '#15171b')
    frame_draw = ImageDraw.Draw(frame)
    for i, (picture, label) in enumerate([(source, 'Original H5'), (native, 'UrhoX / NanoVG')]):
        frame.paste(picture, (i * 480, 30))
        frame_draw.text((i * 480 + 10, 8), f'{label} / {time} ms', fill='white')
        if time in [10, 25, 50, 200]:
            col = [10, 25, 50, 200].index(time)
            sheet.paste(picture.resize((320, 327)), (col * 320, i * 347 + 20))
            draw.text((col * 320 + 8, i * 347 + 4), f'{label} / {time} ms', fill='white')
    frames.append(frame)
sheet.save(evidence / 'pc-menu-entry-comparison.png')
frames[0].save(evidence / 'pc-menu-entry-comparison.gif', save_all=True, append_images=frames[1:],
               duration=[100, 150, 250, 500, 500, 500, 1500], loop=0)
report['animation_note'] = 'GIF deliberately slowed for inspection; not frame pacing evidence'
report['passed'] = all(row['passed'] for row in report['frames'])
(evidence / 'pc-menu-entry-comparison.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
assert report['passed'], 'Menu opacity/group background or shadow differs from source'
