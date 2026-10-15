"""Controlled native GPU frames: old vehicle sinks, new vehicle rises."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
names = ['01-start', '02-sink', '03-replaced', '04-rise', '05-overshoot', '06-rest']
labels = ['Old car: 0 ms', 'Old car: 100 ms', 'Replace: 200 ms',
          'New car: 150 ms', 'New car: 300 ms', 'New car: 450 ms']
frames = []
sheet = Image.new('RGB', (1440, 600), '#15171b')
draw = ImageDraw.Draw(sheet)
for i, (name, label) in enumerate(zip(names, labels)):
    with Image.open(evidence / ('pc-car-lift-' + name + '.png')) as image:
        frames.append(image.convert('RGB').resize((960, 540)))
    x, y = (i % 3) * 480, (i // 3) * 300
    sheet.paste(frames[-1].resize((480, 270)), (x, y + 30))
    draw.text((x + 12, y + 8), label, fill='white')
sheet.save(evidence / 'pc-car-lift-sheet.png')
frames[0].save(evidence / 'pc-car-lift.gif', save_all=True, append_images=frames[1:],
               duration=[100, 100, 150, 150, 150, 900], loop=0)
