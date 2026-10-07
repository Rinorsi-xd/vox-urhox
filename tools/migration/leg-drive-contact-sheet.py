from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
frames = [('LegT3', p, label) for p, label in [
    ('idle', 'T3 idle'), ('walk1', 'T3 walk +0.50s'),
    ('walk2', 'T3 walk +0.65s'), ('walk3', 'T3 walk +0.80s'),
    ('jump', 'T3 jump'), ('wall', 'T3 wall climb')]]
frames += [('LegT5', 'walk1', 'T5 six legs'), ('LegWaveT5', 'walk1', 'T5 ten legs')]
w, h = 640, 360
sheet = Image.new('RGB', (w*2, (h+32)*4), '#151b23')
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 20)
draw = ImageDraw.Draw(sheet)
for i, (car, phase, label) in enumerate(frames):
    source = root / f'current-leg-{car}-mobile-{phase}.png'
    im = Image.open(source).convert('RGB').resize((w, h), Image.Resampling.LANCZOS)
    x, y = i % 2 * w, i // 2 * (h+32)
    sheet.paste(im, (x, y+32)); draw.text((x+10, y+5), label, font=font, fill='#dcecff')
sheet.save(root / 'leg-drive-states.png')
print(root / 'leg-drive-states.png')
