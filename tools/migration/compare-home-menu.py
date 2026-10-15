"""Unretouched PC crops from original browser and actual UrhoX GPU frames."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
box = (124, 561, 484, 931)
names = ['h5-home-new-menu.png', 'pc-source-new-menu.png']
comparison = Image.new('RGB', (720, 400), '#15171b')
draw = ImageDraw.Draw(comparison)
for i, (name, label) in enumerate(zip(names, ['Original H5 - PC', 'UrhoX + NanoVG - PC'])):
    with Image.open(evidence / name) as source:
        comparison.paste(source.crop(box), (i * 360, 30))
    draw.text((i * 360 + 10, 8), label, fill='white')
comparison.save(evidence / 'pc-home-menu-comparison.png')

frames = []
sheet = Image.new('RGB', (1080, 400), '#15171b')
draw = ImageDraw.Draw(sheet)
for i, (suffix, label) in enumerate([('entry-0', '0 ms'), ('entry-50', '50 ms'), ('', '200 ms')]):
    name = 'pc-source-new-menu' + ('-' + suffix if suffix else '') + '.png'
    with Image.open(evidence / name) as source:
        frame = source.crop(box).convert('RGB')
    frames.append(frame)
    sheet.paste(frame, (i * 360, 30))
    draw.text((i * 360 + 10, 8), label, fill='white')
sheet.save(evidence / 'pc-home-menu-entry-sheet.png')
# Three controlled samples, not a claim of continuous frame-rate performance.
frames[0].save(evidence / 'pc-home-menu-entry.gif', save_all=True,
               append_images=frames[1:], duration=[50, 150, 1000], loop=0)
