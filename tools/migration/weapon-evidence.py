from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
frames = [('laser-desktop-active', 'Laser T4 / T5: moving bands + orbiting motes'),
          ('mg-mobile-active', 'Gatling T4 / T5: full-speed muzzle vortex'),
          ('sniper-mobile-active', 'Sniper T4 / T5: charging orb + rail arcs'),
          ('laser-mobile-offline', 'Laser: offline, dim flow + ejected battery'),
          ('laser-mobile-boot', 'Laser: reboot sweep + spring return')]
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 18)
w, h = 700, 340
sheet = Image.new('RGB', (w*2, (h+32)*3), '#151b23')
draw = ImageDraw.Draw(sheet)
for i, (name, label) in enumerate(frames):
    im = Image.open(root / f'current-weapon-{name}.png').convert('RGB')
    # Crop retains both complete weapons and some real hall context.
    iw, ih = im.size
    im = im.crop((int(iw*.32), int(ih*.37), int(iw*.82), int(ih*.79))).resize((w, h), Image.Resampling.LANCZOS)
    x, y = i % 2*w, i//2*(h+32)
    sheet.paste(im, (x, y+32)); draw.text((x+10, y+6), label, font=font, fill='#dcecff')
im = Image.open(root / 'current-combat-mobile.png').convert('RGB').resize((w, h), Image.Resampling.LANCZOS)
sheet.paste(im, (w, (h+32)*2+32))
draw.text((w+10, (h+32)*2+6), 'Same TrialSession: actual mounted shot + target', font=font, fill='#dcecff')
sheet.save(root / 'weapon-states.png')

origin, placed, phase = [np.asarray(Image.open(root / f'weapon-flow-{name}.png').convert('RGB'), dtype=float)
                         for name in ('origin', 'placement', 'phase')]
ih, iw = origin.shape[:2]
box = (slice(int(ih*.35), int(ih*.75)), slice(int(iw*.3), int(iw*.85)))
placement_delta, phase_delta = abs(origin-placed)[box], abs(placed-phase)[box]
stats = dict(placement_delta_max=float(placement_delta.max()), placement_delta_mean=float(placement_delta.mean()),
             phase_delta_mean=float(phase_delta.mean()), phase_pixels_gt20=int((phase_delta.max(axis=2)>20).sum()))
assert stats['placement_delta_max'] <= 2, stats
assert stats['phase_pixels_gt20'] > 1000, stats
(root / 'weapon-flow-pixels.json').write_text(json.dumps(stats, indent=2), encoding='utf-8')
print(json.dumps(stats, indent=2))
print(root / 'weapon-states.png')
