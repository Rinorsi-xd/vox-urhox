"""Inspect original-font text textures alongside the preserved previous export."""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]
page = Image.new('RGB', (1200, 11 * 116), '#20242b')
draw = ImageDraw.Draw(page)
for index, number in enumerate(range(4, 37)):
    x, y = (index % 3) * 400, (index // 3) * 116
    draw.text((x + 4, y + 2), f'texture-{number}: previous | original GameFont', fill='white')
    for column, directory in enumerate(('.tmp/track-gamefont-before-20261015', 'assets/Track')):
        image = Image.open(ROOT / directory / f'texture-{number}.png').convert('RGB')
        image.thumbnail((194, 94))
        page.paste(image, (x + 3 + column * 200, y + 19))
page.save(ROOT / 'docs/migration/evidence/track-game-font-contact-sheet.png')
