"""Place unretouched H5 and native help-panel pixels at the same crop coordinates."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
fixture = json.loads((root / 'tools/migration/fixtures/source-help-1920.json').read_text(encoding='utf-8'))
for relative, digest in fixture['source_hashes'].items():
    assert hashlib.sha256((Path('D:/Rino_Project/Vox/shared') / relative).read_bytes()).hexdigest() == digest
r = fixture['card']
box = (r['x'], r['y'], r['x'] + r['w'], r['y'] + r['h'])
sheet = Image.new('RGB', (r['w'] * 2, r['h'] + 28), '#111317')
draw = ImageDraw.Draw(sheet)
for column, (filename, title) in enumerate([
    ('h5-help-1920.jpg', 'Original H5 / 1920 x 1080'),
    ('pc-dialog-help.png', 'UrhoX NanoVG / 1920 x 1080'),
]):
    x = column * r['w']
    draw.text((x + 10, 8), title, fill='white')
    sheet.paste(Image.open(evidence / filename).convert('RGB').crop(box), (x, 28))
sheet.save(evidence / 'pc-help-comparison.png')
print(evidence / 'pc-help-comparison.png')
