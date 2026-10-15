"""Check the actual October 15 source helper against shipping Lua brand changes."""
import hashlib
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z'
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
sys.path.insert(0, str(ROOT / '.tmp/font-tooling'))
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont

COMMIT = 'b276064942ae09c0227ec28d4cfda1d5ff006455'
checks = []


def check(value, name):
    assert value, name
    checks.append(name)


def read(relative, root=ROOT):
    return (root / relative).read_text(encoding='utf-8')


source_text = read('shared/scene/hangarTextures.js', SOURCE)
source_name = re.search(r"export const HANGAR_NAME = '([^']+)'", source_text)[1]
check(source_name == 'CONSTRUCT ERA 轨道改装机库', 'frozen source hangar brand')
check('<b>构装纪元</b>' in read('shared/ui/home.js', SOURCE), 'frozen source home title')
check('<b>构装纪元</b>' in read('three/index.html', SOURCE), 'frozen source boot title')
check('<title>构装纪元 CONSTRUCT ERA</title>' in read('three/index.html', SOURCE), 'frozen source window title')
for file, literal in [('scripts/ui/HomeChrome.lua', "D.Text(vg,'构装纪元'"),
                      ('scripts/ui/BootLoading.lua', "D.Text(vg,'构装纪元'"),
                      ('scripts/app/HangarApp.lua', 'graphics.windowTitle="构装纪元 CONSTRUCT ERA"')]:
    check(literal in read(file), file + ' follows source title')

lua = LuaRuntime()
canvas = lua.execute(read('scripts/render/HangarCanvas.lua'))
cases = [{'width': limit, 'size': size, 'measured': measured}
         for limit, size in [(1548, 100), (808, 76), (2048 * .92, 150)]
         for measured in [0, limit - 1, limit, limit + 1, limit * 1.75]]
node_code = r"""
const fs=require('fs');const input=JSON.parse(fs.readFileSync(0,'utf8'));
const text=fs.readFileSync(input.source,'utf8');
const helper=text.slice(text.indexOf('function fitFont('),text.indexOf('// 机库名'));
const run=new Function('ctx','text','w','weight','size',
    'const HANGAR_DISPLAY="source-display";'+helper+';fitFont(ctx,text,w,weight,size);return ctx.font;');
console.log(JSON.stringify(input.cases.map(c=>run({measureText:()=>({width:c.measured})},input.name,c.width,700,c.size))));
"""
completed = subprocess.run(['node', '-e', node_code], input=json.dumps({
    'source': str(SOURCE / 'shared/scene/hangarTextures.js'), 'name': source_name, 'cases': cases}),
    text=True, encoding='utf-8', capture_output=True, check=True)
source_fonts = json.loads(completed.stdout)
for i, (case, font) in enumerate(zip(cases, source_fonts)):
    canvas.Width = lambda *args, measured=case['measured']: measured
    actual = canvas.FitFont(None, source_name, case['width'], case['size'])
    expected = int(re.search(r' ([0-9]+)px ', font)[1])
    check(actual == expected, f'actual H5/Lua fitFont boundary {i}')
    case['sourceFont'] = font
    case['luaSize'] = actual

lua.globals().require = lambda module: canvas if module == 'render.HangarCanvas' else lua.table_from({'Draw': lambda *args: None})
signs = lua.execute(read('scripts/render/HangarBaySigns.lua'))
check(signs.NAME == source_name, 'runtime wall and floor share exact source hangar name')
for font_name in ['SmileySans-Oblique.ttf', 'VoxIndustrial-Bold.otf']:
    font = TTFont(ROOT / 'assets/Fonts' / font_name)
    codepoints = {cp for cmap in font['cmap'].tables if cmap.isUnicode() for cp in cmap.cmap}
    check(all(ord(char) in codepoints for char in '构装纪元轨道改装机库'), font_name + ' has new brand glyphs')
    font.close()

paths = ['scripts/ui/HomeChrome.lua', 'scripts/ui/BootLoading.lua', 'scripts/app/HangarApp.lua',
         'scripts/render/HangarCanvas.lua', 'scripts/render/HangarBaySigns.lua', 'tools/migration/export-hangar.cjs']
paths += ['assets/Hangar/' + name + '.png' for name in ['bay', 'mark', 'signBack', 'signDoor', 'mark-t3', 'bay-t3']]
result = {'sourceCommit': COMMIT, 'sourcePath': str(SOURCE), 'checks': checks, 'fitCases': cases,
          'scope': 'source text/formula/font/asset hashes; native UI appearance and GPU acceptance remain separate',
          'targetSha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'sourceSha256': {p: hashlib.sha256((SOURCE / p).read_bytes()).hexdigest() for p in [
              'shared/ui/home.js', 'three/index.html', 'shared/scene/hangarTextures.js', 'shared/scene/hangarLayout.js']}}
evidence = ROOT / 'docs/migration/evidence/brand-source-2026-10-15.json'
evidence.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'{len(checks)} brand source checks PASS; {evidence}')
