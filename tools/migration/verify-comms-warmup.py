import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
fixture = (ROOT / 'tools/migration/check-comms-warmup.lua').read_text(encoding='utf-8')
warmup = (ROOT / 'scripts/ui/CommsWarmup.lua').read_text(encoding='utf-8')
card = (ROOT / 'scripts/ui/CommsCard.lua').read_text(encoding='utf-8')
loading_page = (ROOT / 'scripts/ui/LoadingPage.lua').read_text(encoding='utf-8')
loading_fixture = (ROOT / 'tools/migration/check-loading-comms-warmup.lua').read_text(encoding='utf-8')
picker = (ROOT / 'scripts/story/TutorialFirstLine.lua').read_text(encoding='utf-8')
picker_fixture = (ROOT / 'tools/migration/check-tutorial-first-line.lua').read_text(encoding='utf-8')
data = json.loads((ROOT / 'assets/UI/Tutorial.json').read_text(encoding='utf-8'))


def run(warmup_source=warmup, card_source=card):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().WARMUP_SOURCE = warmup_source
    lua.globals().CARD_SOURCE = card_source
    lua.globals().print = lambda *args: None
    return lua.execute(fixture)


result = run()
render_lua = LuaRuntime(unpack_returned_tuples=True)
render_lua.globals().LOADING_PAGE_SOURCE = loading_page
render_result = render_lua.execute(loading_fixture)
picker_lua = LuaRuntime(unpack_returned_tuples=True)
picker_lua.globals().DATA = picker_lua.table_from(data, recursive=True)
picker_lua.globals().PICKER_SOURCE = picker
picker_result = picker_lua.execute(picker_fixture)
controls = [
    ('single-frame completion', warmup.replace('if self.frames<2 then', 'if self.frames<1 then'), card),
    ('borrowed-owner disposal', warmup.replace('if self.created and not self.retained and self.portrait then', 'if self.portrait then'), card),
    ('lost presentation reset', warmup, card.replace('portrait:ResetPresentation();portraits[portrait.who]=portrait', 'portraits[portrait.who]=portrait')),
    ('stale owner adoption', warmup.replace('Card.GetPortrait(self.who)==self.expected and', 'true and'), card.replace(' or portraits[portrait.who]~=expected', '')),
]
negative = []
for name, variant, card_variant in controls:
    assert variant != warmup or card_variant != card, name
    try:
        run(variant, card_variant)
    except Exception as error:
        negative.append({'name': name, 'rejected': True, 'error': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control survived: ' + name)
for name, variant in [
    ('skip saved Resume', picker.replace('not rules:Resume({})', 'true')),
    ('mutate live rules', picker.replace('rules=Rules.New(tutorial.data,record,nil)', 'rules=tutorial.rules')),
    ('ignore touch lines', picker.replace('TouchMode.Enabled() and spec.touchLines or spec.lines', 'spec.lines')),
]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().DATA = lua.table_from(data, recursive=True)
    lua.globals().PICKER_SOURCE = variant
    try:
        lua.execute(picker_fixture)
    except Exception as error:
        negative.append({'name': name, 'rejected': True, 'error': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control survived: ' + name)
render_block = """    local flow=self.owner
    if flow.commsWarmup and flow.pageVisible and not flow.failed and (flow.phase=='loading' or flow.phase=='ready') then
        flow.commsWarmup:Draw(vg)
    end
"""
assert render_block in loading_page
for name, variant in [
    ('missing covered draw', loading_page.replace(render_block, '')),
    ('draw after opaque cover', loading_page.replace(render_block, '').replace('    self:DrawTransition(vg,logicalW,logicalH);nvgRestore(vg)', render_block + '    self:DrawTransition(vg,logicalW,logicalH);nvgRestore(vg)')),
]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().LOADING_PAGE_SOURCE = variant
    try:
        lua.execute(loading_fixture)
    except Exception as error:
        negative.append({'name': name, 'rejected': True, 'error': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control survived: ' + name)

files = ['scripts/ui/CommsWarmup.lua', 'scripts/ui/CommsCard.lua', 'scripts/ui/LoadingPage.lua',
         'tools/migration/check-comms-warmup.lua', 'tools/migration/verify-comms-warmup.py']
files.append('tools/migration/check-loading-comms-warmup.lua')
files += ['scripts/story/TutorialFirstLine.lua', 'scripts/story/TutorialRules.lua', 'assets/UI/Tutorial.json', 'tools/migration/check-tutorial-first-line.lua']
report = {'result': 'PASSED', 'checks': result['count'] + render_result['count'] + picker_result['count'],
          'lifecycleChecks': result['count'], 'renderOrderChecks': render_result['count'],
          'firstLineChecks': picker_result['count'], 'firstLineScenarios': picker_result['scenarios'], 'negativeControls': negative,
          'counts': dict(result['counts']),
          'productionSha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files},
          'boundary': 'Actual CommsWarmup, CommsCard, CommsPortrait, CommsPortraitLayout, ResourceGate, LoadingPage, BootLoading and TutorialFirstLine with real TutorialRules/Tutorial.json; substituted engine allocation, download, UI constructor and NanoVG calls. Tests ownership, exact first-card state/material values, repeated-load counts, draw-before-opaque-cover ordering and read-only prediction of the first tutorial line. No GPU shader-order, Native/Web timing, visual or Snapdragon845 acceptance.'}
output = ROOT / 'docs/migration/evidence/comms-warmup-offline.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
