"""Pair captured H5/native frames without changing their color or composition."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--label', default='final')
args = parser.parse_args()
assert args.label.replace('-', '').isalnum()
w, h, title = 816, 432, 26
sheet = Image.new('RGB', (w * 2, (h + title) * 3), '#15191e')
draw = ImageDraw.Draw(sheet)
for row, view in enumerate(('fort', 'ship', 'interior')):
    for col, (suffix, label) in enumerate((('source-formal', 'H5 original'), ('native-' + args.label, 'UrhoX current'))):
        with Image.open(root / f'crater-{suffix}-{view}.png') as frame:
            assert frame.size == (2040, 1080), 'Camera framing requires matching capture dimensions'
            sheet.paste(frame.convert('RGB').resize((w, h), Image.Resampling.LANCZOS), (col * w, row * (h + title) + title))
        draw.text((col * w + 10, row * (h + title) + 6), f'{label} / {view}', fill='white')
sheet.save(root / 'crater-formal-comparison.png')
print(root / 'crater-formal-comparison.png')
