"""Unretouched paragraph crops from original CSS and the real native workshop."""
from pathlib import Path
import json
import math
import hashlib
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
data = json.loads((root / 'tools/migration/fixtures/source-paragraphs-1920.json').read_text(encoding='utf-8'))
for relative, expected in data['source_hashes'].items():
    assert hashlib.sha256((Path('D:/Rino_Project/Vox/shared') / relative).read_bytes()).hexdigest() == expected, 'Original source changed; recapture paragraph fixture'
source = Image.open(evidence / 'h5-paragraphs-workshop-1920.jpg').convert('RGB')
native = Image.open(evidence / 'pc-source-workshop-1920.png').convert('RGB')
sheet = Image.new('RGB', (640, 6 * 110), '#15171b')
draw = ImageDraw.Draw(sheet)
for row, sample in enumerate(data['samples'][:6]):
    r = sample['box']
    # Identical source coordinates; preserve the physical glyph pixels.
    box = (math.floor(r['x']) - 8, math.floor(r['y']) - 8,
           math.floor(r['x']) + 300, math.floor(r['y']) + 72)
    for col, (picture, label) in enumerate([(source, 'Original H5'), (native, 'UrhoX / NanoVG')]):
        sheet.paste(picture.crop(box), (col * 320 + 6, row * 110 + 25))
        draw.text((col * 320 + 6, row * 110 + 6), f'{label} / card {row + 1}', fill='white')
sheet.save(evidence / 'pc-paragraphs-comparison.png')
print(evidence / 'pc-paragraphs-comparison.png')
