"""Compare captured source/native pixels without repainting UI content."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
source = Path('D:/Rino_Project/Vox/shared')

def compare(fixture_name, field, original, native, output, padding=0):
    fixture = json.loads((root / 'tools/migration/fixtures' / fixture_name).read_text(encoding='utf-8'))
    for relative, digest in fixture['source_hashes'].items():
        assert hashlib.sha256((source / relative).read_bytes()).hexdigest() == digest, relative
    r = fixture[field]
    box = (math.floor(r['x'])-padding, math.floor(r['y'])-padding,
           math.ceil(r['x']+r['w'])+padding, math.ceil(r['y']+r['h'])+padding)
    w, h = box[2]-box[0], box[3]-box[1]
    sheet = Image.new('RGB', (w*2, h+28), '#111317')
    draw = ImageDraw.Draw(sheet)
    for column, (filename, title) in enumerate([(original, 'Original H5'), (native, 'UrhoX NanoVG')]):
        frame = Image.open(evidence / filename).convert('RGB')
        assert frame.size == (fixture['viewport']['w'], fixture['viewport']['h']), filename
        draw.text((column*w+10, 8), title, fill='white')
        sheet.paste(frame.crop(box), (column*w, 28))
    sheet.save(evidence / output)
    print(output)

compare('source-import-1920.json', 'card', 'h5-import-hint-1920.jpg', 'pc-dialog-import.png', 'pc-import-comparison.png')
compare('source-export-1920.json', 'card', 'h5-export-hint-1920.jpg', 'pc-dialog-export.png', 'pc-export-comparison.png')
compare('source-palette-1920.json', 'palette', 'h5-palette-1920.jpg', 'pc-build-palette.png', 'pc-palette-1920-comparison.png', 12)
compare('source-palette-1440.json', 'palette', 'h5-palette-1440.jpg', 'pc-build-palette-1440.png', 'pc-palette-1440-comparison.png', 12)
