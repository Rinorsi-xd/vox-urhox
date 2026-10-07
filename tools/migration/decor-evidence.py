"""Compare fixed native GPU timestamps and assemble existing rendered captures."""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageChops, ImageDraw, ImageFont
root = Path(__file__).resolve().parents[2]
out = root/'docs/migration/evidence'
frames = {name: Image.open(out/f'decor-motion-{name}.png').convert('RGB')
          for name in ['zero','turn','side','repeat']}
def changes(a, b, box=None):
    diff = ImageChops.difference(a, b)
    if box:
        diff = diff.crop(box)
    return sum(1 for p in diff.get_flattened_data() if max(p) > 2)
report = {'scope': 'fixed native renders, source animation formulas ported; not full H5 pixel parity',
          'repeat_changed_pixels': changes(frames['side'],frames['repeat']), 'regions': {}}
for name,box in {'orange_holo':(90,140,280,305),'blue_holo':(440,140,630,305),
                 'radar':(760,110,1020,320),'beacon':(1200,165,1270,225),
                 'stationary_base':(90,335,280,410)}.items():
    report['regions'][name] = changes(frames['zero'],frames['side'],box)
assert report['repeat_changed_pixels'] == 0, 'Fixed shader timestamp must be repeatable'
for key in ['orange_holo','blue_holo','radar','beacon']:
    assert report['regions'][key] > 30, f'{key} has no visible animation'
report['base_region_note'] = 'Base colour also depends on frame postprocessing; this region is not a geometry motion assertion.'
files=['scripts/parts/Materials.lua','scripts/parts/PartAssets.lua',
       'assets/Shaders/BLGL/VoxHoloPaint.shader','assets/Shaders/BLGL/VoxDecor.shader',
       'assets/Shaders/BLGL/VoxDecorDouble.shader','assets/Shaders/BLGL/lib/VoxDecorMotion.shaderinc',
       'assets/Shaders/BLGL/lib/VoxDecorSurface.shaderinc']
report['targetHashes']={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in files}
source=Path('D:/Rino_Project/Vox/three/src/parts/materials.js')
report['source']={'path':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
sheet=Image.new('RGB',(1440,486),(16,20,26));draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype(str(root/'assets/Fonts/MiSans-Regular.ttf'),18)
for i,(name,label) in enumerate([('zero','原生渲染 · 0.00 秒'),('side','原生渲染 · 1.95 秒')]):
    sheet.paste(frames[name].resize((720,450)),(i*720,36));draw.text((i*720+16,8),label,font=font,fill='white')
sheet.save(out/'decor-motion-comparison.png')
(out/'decor-motion-pixels.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(report['regions']), 'repeat:',report['repeat_changed_pixels'])
