"""Compare independently captured H5 Canvas and native NanoVG RTs.

Native RT PNGs contain premultiplied gamma RGB; normalize only this comparison
copy. The runtime shader performs the equivalent decode when displaying them.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
sheet = Image.new('RGB', (1280, 1510), '#171a20')
draw = ImageDraw.Draw(sheet)
draw.text((16, 12), 'H5 original Canvas', fill='white')
draw.text((656, 12), 'UrhoX NanoVG (unpremultiplied for comparison)', fill='white')
metrics = {}
top = 40
for kind in ['stats', 'blueprint', 'mark', 'bay']:
    source = Image.open(evidence / f'h5-panel-{kind}-renamed.png').convert('RGBA')
    raw = np.array(Image.open(evidence / f'native-panel-{kind}-renamed.png').convert('RGBA'), dtype=np.float64)
    raw[:, :, :3] = np.clip(raw[:, :, :3]*255/np.maximum(raw[:, :, 3:4], 1), 0, 255)
    native = Image.fromarray(np.round(raw).astype('uint8'))
    for column, im in enumerate([source, native]):
        back = Image.new('RGBA', im.size, '#171a20')
        back.alpha_composite(im)
        height = round(im.height*620/im.width)
        sheet.paste(back.convert('RGB').resize((620, height), Image.Resampling.LANCZOS), (column*640+10, top))
    top += height + 16
    if kind == 'bay':
        a = np.array(source)[210:860,650:1500,3] > 40
        b = np.array(native)[210:860,650:1500,3] > 40
        metrics['bay_number_07_mask_iou'] = float((a & b).sum()/(a | b).sum())
        assert metrics['bay_number_07_mask_iou'] > .99, 'Bay number differs from original outline'
sheet.crop((0,0,1280,top)).save(evidence / 'pc-hangar-panels-comparison.png')
(evidence / 'hangar-panels-pixels.json').write_text(json.dumps(metrics, indent=2)+'\n', encoding='utf8')
print(json.dumps(metrics))
