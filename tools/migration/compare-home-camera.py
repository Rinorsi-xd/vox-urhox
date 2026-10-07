"""Compare real screenshots at the same 1920x1080 camera pose; no retouching."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
sheet = Image.new('RGB', (1920, 576), '#15171b')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 22)
for index, (filename, label) in enumerate([
    ('h5-camera-hangar.png', 'Original H5 - PC 1920 x 1080'),
    ('pc-camera-hangar.png', 'UrhoX + NanoVG - PC 1920 x 1080'),
]):
    with Image.open(evidence / filename) as picture:
        assert picture.size == (1920, 1080), (filename, picture.size)
        sheet.paste(picture.convert('RGB').resize((960, 540), Image.Resampling.LANCZOS), (index * 960, 36))
    draw.text((index * 960 + 16, 6), label, font=font, fill='#f4f5f7')
sheet.save(evidence / 'pc-home-camera-comparison.png')
print(evidence / 'pc-home-camera-comparison.png')
