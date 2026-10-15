"""Validate a complete original-browser export, then import PNGs byte-for-byte.

Run export-source-thumbnails.mjs and use its localhost export button first.
No color keying, alpha reconstruction, resizing, or native rerendering is used.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json
import math
import shutil

root = Path(__file__).resolve().parents[2]
staging = root / '.tmp/source-thumbnails'
manifest = json.loads((staging / 'manifest.json').read_text(encoding='utf-8'))
source = Path(manifest['source'])
defs = json.loads((root / 'assets/Parts/Catalog.json').read_text(encoding='utf-8'))['parts']
expected = {part['id'] for part in defs}
records = {item['id']: item for item in manifest['images']}
# This exact source build renders its single-sided chin from above as transparent.
# Preserve its output instead of inventing artwork or relaxing other image checks.
source_empty = {
    'trHeadChin': {
        'png': 'bbedd78c21f09dbe399f21121a1bc53eb5e4462ad422155fc88ca09b0feb62a8',
        'renderer': 'db6b4f06e944a96761baa3e004ba3897f3cb6172f7dd5574d62c741377f1c926',
        'model': '6fda6cc17e78444f5099c76919c93b42f0414171bbd7ad87d0900f4e2fa84aa8',
    },
}
assert expected == records.keys() and len(records) == manifest['count'], 'Source catalog differs'
assert manifest['size'] == 112 and manifest['renderer'] == 'three/src/ui/thumbnails.js'
assert manifest['renderer'] in manifest['sourceFiles'], 'Original renderer was not served'
for filename, digest in manifest['sourceFiles'].items():
    location = (source / filename).resolve()
    assert location.is_relative_to(source.resolve()), 'Invalid source provenance path'
    assert hashlib.sha256(location.read_bytes()).hexdigest() == digest, f'Source changed: {filename}'

images, evidence = {}, []
for part in defs:
    name = part['id']
    assert name.replace('_', '').isalnum(), f'Invalid part ID: {name}'
    file = staging / f'{name}.png'
    data = file.read_bytes()
    assert hashlib.sha256(data).hexdigest() == records[name]['sha256'], f'PNG changed: {name}'
    image = Image.open(file)
    assert image.size == (112, 112) and image.mode == 'RGBA', f'Invalid image: {name}'
    alpha = image.getchannel('A')
    histogram = alpha.histogram()
    assert histogram[0] > 112 * 112 * .25, f'Missing transparent surround: {name}'
    visible_pixels = sum(histogram[1:])
    if visible_pixels <= 20:
        exception = source_empty.get(name)
        assert exception and visible_pixels == 0, f'Unexpected empty thumbnail: {name}'
        assert records[name]['sha256'] == exception['png'], f'Empty source image changed: {name}'
        assert manifest['sourceFiles']['three/src/ui/thumbnails.js'] == exception['renderer']
        assert manifest['sourceFiles']['shared/assets/trooper/trooper.glb'] == exception['model']
    assert all(alpha.getpixel(p) == 0 for p in [(0, 0), (111, 0), (0, 111), (111, 111)]), f'Opaque corners: {name}'
    images[name] = image.copy()
    evidence.append(dict(id=name, sha256=records[name]['sha256'], bytes=len(data),
                         transparent_pixels=histogram[0], partial_alpha_pixels=sum(histogram[1:255]),
                         opaque_pixels=histogram[255], source_empty=visible_pixels == 0))

target = root / 'assets/UI/Parts'
old_bytes = sum(file.stat().st_size for name in expected
                if (file := target / f'{name}.png').is_file())
for name in expected:
    shutil.copyfile(staging / f'{name}.png', target / f'{name}.png')
    assert hashlib.sha256((target / f'{name}.png').read_bytes()).hexdigest() == records[name]['sha256']

# Checkerboard proof of all alpha edges; the runtime consumes the untouched PNGs.
cols, tile_w, tile_h = 12, 124, 140
sheet = Image.new('RGB', (cols * tile_w, math.ceil(len(defs) / cols) * tile_h), '#15171b')
draw = ImageDraw.Draw(sheet)
for i, part in enumerate(defs):
    x, y = i % cols * tile_w + 6, i // cols * tile_h + 6
    for py in range(0, 112, 8):
        for px in range(0, 112, 8):
            draw.rectangle((x + px, y + py, x + px + 7, y + py + 7), fill='#353a42' if (px + py) % 16 else '#242830')
    sheet.paste(images[part['id']], (x, y), images[part['id']])
    draw.text((x, y + 116), part['id'], fill='white')
out = root / 'docs/migration/evidence'
sheet.save(out / 'source-thumbnails-alpha.png')
manifest.update(images=evidence, validation=dict(result='PASS', count=len(evidence),
                previous_bytes=old_bytes, current_bytes=sum(r['bytes'] for r in evidence),
                byte_identical_import=True, all_images_rgba=True, all_corners_transparent=True,
                source_empty_images=[r['id'] for r in evidence if r['source_empty']]))
(out / 'source-thumbnails-import.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps(manifest['validation'], indent=2))
