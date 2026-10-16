"""Frozen source image identity, CSS geometry, original Holo fit and Lua consumers."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
import tinycss2
from PIL import Image, ImageChops
from lupa.lua54 import LuaRuntime

baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
snapshot = Path(baseline['snapshot'])
source_hashes = {}
production_files = ['scripts/ui/CommsPortraitLayout.lua', 'scripts/ui/CommsPortrait.lua',
                    'scripts/ui/CommsCard.lua', 'scripts/audio/StoryComms.lua',
                    'scripts/story/Tutorial.lua', 'scripts/app/OpeningHost.lua',
                    'scripts/ui/IntroPage.lua', 'scripts/ui/MatchComms.lua',
                    'scripts/combat/BattleController.lua', 'scripts/ui/MissionResult.lua',
                    'assets/Shaders/BLGL/UI/CommsPortrait.shader']
input_hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in production_files}


def target_path(name):
    folder = 'Story/Boss' if name == 'chairman_cut' else 'Intro/Images' if name.startswith('nono_') else 'UI/Faces'
    return f'assets/{folder}/{name}.png'

def source(relative):
    data = (snapshot / relative).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    assert digest == baseline['files'][relative]['sha256'], relative
    source_hashes[relative] = digest
    return data

css = tinycss2.parse_stylesheet(source('shared/css/storyHud.css').decode('utf-8'), skip_comments=True, skip_whitespace=True)
rules = {}
for rule in css:
    if rule.type == 'qualified-rule':
        selector = tinycss2.serialize(rule.prelude).strip()
        rules[selector] = {d.name: tinycss2.serialize(d.value).strip() for d in
                           tinycss2.parse_declaration_list(rule.content, skip_comments=True, skip_whitespace=True)
                           if d.type == 'declaration'}

def image_rect(selector):
    rule = rules[selector]
    return {key: float(rule[prop].removesuffix('px')) for key, prop in
            [('x', 'left'), ('y', 'top'), ('w', 'width'), ('h', 'height')]}

rects = {'nono': image_rect('.sh-cview canvas, .sh-cview img'),
         'huhu': image_rect('.sh-comms.huhu .sh-cview canvas, .sh-comms.huhu .sh-cview img'),
         'boss': image_rect('.sh-comms.boss .sh-cview canvas, .sh-comms.boss .sh-cview img')}
images = {}
pixel_checks = []
for name in ['nono_talk', 'nono_smile', 'nono_deadpan', 'nono_stamp', 'huhu_talk', 'huhu_smug', 'huhu_angry', 'huhu_flustered', 'chairman_cut']:
    folder = 'story/boss' if name == 'chairman_cut' else 'story/huhu/pilot' if name.startswith('huhu') else 'intro/raw'
    extension = 'webp' if name == 'chairman_cut' else 'png'
    relative = f'shared/assets/{folder}/{name}.{extension}'
    source(relative)
    original = Image.open(snapshot / relative).convert('RGBA')
    target_relative = target_path(name)
    target_bytes = (ROOT / target_relative).read_bytes()
    input_hashes[target_relative] = hashlib.sha256(target_bytes).hexdigest()
    target = Image.open(ROOT / target_relative).convert('RGBA')
    assert original.size == target.size, name+' size'
    # getbbox on RGBA alone ignores RGB differences when alpha difference is zero.
    difference = ImageChops.difference(original, target)
    assert all(channel.getbbox() is None for channel in difference.split()), name+' decoded pixels'
    if name != 'chairman_cut':
        assert hashlib.sha256((snapshot / relative).read_bytes()).digest() == hashlib.sha256(target_bytes).digest(), name+' byte identity'
    images[name] = {'name': name, 'width': original.width, 'height': original.height}
    pixel_checks.append({'name': name, 'target': target_relative, 'sha256': input_hashes[target_relative],
                         'size': list(original.size), 'decodedPixels': 'MATCH',
                         'alphaBounds': original.getchannel('A').getbbox()})
(ROOT / '.tmp/comms-portraits-input.json').write_text(json.dumps({'images': list(images.values())}), encoding='utf-8')
subprocess.run(['node', 'tools/migration/check-comms-portraits-source.mjs'], check=True)
frozen = json.loads((ROOT / '.tmp/comms-portraits-source.json').read_text(encoding='utf-8'))
contain = []
for name, image in images.items():
    who = 'boss' if name == 'chairman_cut' else name.split('_')[0]
    rect = rects[who]
    scale = min(rect['w']/image['width'], rect['h']/image['height'])
    width, height = image['width']*scale, image['height']*scale
    contain.append({'name': name, 'who': who, 'rect': {'x': rect['x']+(rect['w']-width)/2,
                   'y': rect['y']+(0 if who == 'boss' else rect['h']-height), 'w': width, 'h': height}})
inset = [float(value.removesuffix('px')) for value in rules['.sh-fox']['inset'].split()]
assert inset == [30, 22, 54]
emblems = []
for height in [196, 180]:
    width, available = 150-2*inset[1], height-inset[0]-inset[2]
    scale = min(width, available)/64
    emblems.append({'height': height, 'x': inset[1]+(width-64*scale)/2,
                    'y': inset[0]+(available-64*scale)/2, 'scale': scale})
lua = LuaRuntime(unpack_returned_tuples=True)

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

for name, value in [('SOURCE', frozen), ('IMAGES', images), ('RECTS', rects), ('CONTAIN', contain), ('EMBLEMS', emblems)]:
    lua.globals()[name] = table(value)
checks = lua.execute((ROOT / 'tools/migration/check-comms-portraits.lua').read_text(encoding='utf-8'))
assert input_hashes == {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in input_hashes}, 'Production inputs changed while checks ran'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': baseline['commit'],
          'sourceHashes': {**frozen['sourceHashes'], **source_hashes}, 'sourceFitCases': len(frozen['cases']),
          'images': pixel_checks, 'cssRects': rects, 'svgEmblems': emblems,
          'productionHashes': input_hashes,
          'boundary': 'Actual frozen HoloPortrait.render fit uniforms, parsed frozen CSS, decoded pixels, actual Lua layout and CommsCard fallback/boss/SVG consumers and StoryComms dependency list. Actual CommsPortrait.Draw affine checks for Web/native both RT copies, nonzero opening rectangles, state restore and unflipped fallback. GPU sampling, render-target bridge, responsive parent composition and actual Web appearance remain unverified.'}
output = ROOT / 'docs/migration/evidence/comms-portraits-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
