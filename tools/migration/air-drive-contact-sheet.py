"""Compare independently replayed native states, not continuous animation frames."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
cases = [
    ('HeavyLift-mobile-idle', 'Grounded / lift disabled'),
    ('HeavyLift-mobile-active', 'Altitude hold / forward vectoring'),
    ('HeavyLift-mobile-cut', 'Lift cutoff / gravity'),
    ('HoverSide-mobile-active', 'Side-mounted hover / raised target'),
    ('HoverBottom-desktop-active', 'Bottom-mounted hover / raised target'),
]
w, h = 680, 360
sheet = Image.new('RGB', (w * 2, (h + 34) * 3), '#17202b')
draw = ImageDraw.Draw(sheet)
for i, (suffix, label) in enumerate(cases):
    x, y = (i % 2) * w, (i // 2) * (h + 34)
    with Image.open(root / f'current-air-{suffix}.png') as im:
        sheet.paste(im.convert('RGB').resize((w, h), Image.Resampling.LANCZOS), (x, y + 34))
    draw.text((x + 12, y + 10), label, fill='white')
sheet.save(root / 'air-drive-states.png')
