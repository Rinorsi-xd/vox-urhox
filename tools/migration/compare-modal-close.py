"""Contact sheet and GIF from actual GPU retirement samples, no repainted UI."""
from pathlib import Path
from PIL import Image, ImageDraw

evidence = Path(__file__).resolve().parents[2] / 'docs/migration/evidence'
times = [0, 20, 40, 80, 120, 159, 160]
frames = []
sheet = Image.new('RGB', (1280, 640), '#15171b')
draw = ImageDraw.Draw(sheet)
for i, time in enumerate(times):
    with Image.open(evidence / f'pc-dialog-close-{time}.png') as raw:
        frame = raw.convert('RGB').crop((640, 250, 1280, 850))
    frames.append(frame)
    x, y = i % 4 * 320, i // 4 * 320
    sheet.paste(frame.resize((320, 300)), (x, y + 20))
    draw.text((x + 8, y + 4), f'{time} ms', fill='white')
sheet.save(evidence / 'pc-modal-close-sheet.png')
frames[0].save(evidence / 'pc-modal-close.gif', save_all=True,
               append_images=frames[1:], duration=[20, 20, 40, 40, 39, 1, 1000], loop=0)
