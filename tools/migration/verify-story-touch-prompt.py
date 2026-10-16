"""Compare actual frozen H5 touch prompt decisions to production Lua adapter."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = json.loads(subprocess.check_output(['node', 'tools/migration/story-touch-prompt-source.mjs'], text=True, encoding='utf-8'))
production = ROOT / 'scripts/ui/TouchDriveControls.lua'
legacy = ROOT / '.tmp/outgame-cached-1792115578618/scripts/ui/TouchDriveControls.lua'


def runner(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TouchCode = code
    return lua, lua.execute(r'''
package.path='scripts/?.lua;'..package.path
package.preload['urhox-libs/UI']=function()return {Panel=function(props)return props end}end
package.preload['controls.TouchPreferences']=function()return {Get=function()return {sens=1,size=1,plane='point'}end}end
local captured
package.preload['ui.SourceTouchOverlay']=function()return {Create=function(root,playfield,adapter,actions)
 captured=adapter
 local layer={buttons={},stick={},menu=false,blocked=false,aux='boost',gestures={Held=function()return false end},Relayout=function()end}
 for _,id in ipairs(actions)do layer.buttons[id]={props={},SetVisible=function(self,on)self.visible=on end}end
 layer.Update=function()adapter.Labels(layer)end
 return layer
end}end
local Touch=assert(load(TouchCode))()
return function(case,menu,blocked)
 local controls={held={}}
 local rules={inside=case.inside,blocked=case.blocked,finished=case.finished,completeAt=case.completeAt,
  cap={phase=case.phase},StepSpec=function()return {kind=case.kind}end}
 local session={app={},controls=controls,pointer={captured=true},world={time=2},
  vehicle={spec={wings={},thrusters={}},body={rotation=function()return {x=case.flip and 1 or 0,y=0,z=0}end}},
  weapons={groups={}},story={player={alive=not case.dead},rules=rules},
  HasFocus=function()return true end,Resume=function()return true end}
 if case.salvagePrompt or case.swap then session.salvage={touchPrompt=case.salvagePrompt,touchSwap=case.swap}end
 local layer=Touch.Create(session,{AddChild=function()end})
 layer.flipSince=case.flip and 0 or nil;layer.menu=menu;layer.blocked=blocked;layer.Update()
 local result={role=layer.contextRole,visible=layer.buttons.interact.visible,text=layer.buttons.interact.props.text}
 result.held=captured.Hold('interact',true);result.duringHold=controls.held.interact==true
 result.released=captured.Hold('interact',false);result.afterRelease=controls.held.interact==true
 captured.Hold('interact',true);rules.inside=false;layer.Update()
 result.releaseAfterLeaving=captured.Hold('interact',false);result.stuckAfterLeaving=controls.held.interact==true
 return result
end
''')


def mismatches(code):
    lua, run = runner(code)
    failures = []
    for index, case in enumerate(reference['cases']):
        actual = dict(run(lua.table_from(case), False, False))
        for key in ['role', 'held', 'released', 'afterRelease']:
            if actual.get(key) != case.get(key):
                failures.append({'case': index, 'key': key, 'expected': case.get(key), 'actual': actual.get(key)})
        expected_visible = case.get('role') is not None
        if actual['visible'] != expected_visible:
            failures.append({'case': index, 'key': 'visible'})
        if actual['duringHold'] != case['held'] or actual['stuckAfterLeaving']:
            failures.append({'case': index, 'key': 'hold-lifecycle'})
        for menu, blocked in [(True, False), (False, True)]:
            hidden = dict(run(lua.table_from(case), menu, blocked))
            if hidden['visible']:
                failures.append({'case': index, 'key': 'overlay-hidden'})
    complete = lua.table_from({'kind': 'install', 'inside': True, 'completeAt': 1})
    if dict(run(complete, False, False)).get('role') is not None:
        failures.append({'case': 'completeAt', 'key': 'role'})
    return failures


code = production.read_text(encoding='utf-8-sig')
failures = mismatches(code)
assert not failures, failures
negative = {
    'frozen-49c15': mismatches(legacy.read_text(encoding='utf-8-sig')),
    'wrong-capture-phase': mismatches(code.replace("rules.cap.phase=='scrub'", "rules.cap.phase=='cap'")),
    'missing-install-speed-guard': mismatches(code.replace("step.kind=='install' and not rules.blocked", "step.kind=='install'")),
    'missing-swap-precedence': mismatches(code.replace("salvage and salvage.touchSwap and 'swap' or ", '')),
}
assert all(negative.values()), negative


def sha(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


report = {
    'result': 'PASS', 'cases': len(reference['cases']), 'checks': len(reference['cases']) * 8 + 1,
    'source': reference['source'],
    'productionHashes': {'scripts/ui/TouchDriveControls.lua': sha('scripts/ui/TouchDriveControls.lua')},
    'inputs': {path: sha(path) for path in ['tools/migration/story-touch-prompt-source.mjs', 'tools/migration/verify-story-touch-prompt.py']},
    'negativeControls': negative,
    'boundary': 'Actual frozen StoryHud.prompt, StoryMission.update, capture kind, TouchControls._tickDrive and hold; actual Lua TouchDriveControls adapter. Native UI/physics/DOM adapters. Dead/finished prompt clearing is fixture controlled. No rendered touch hit testing, natural full mission, device performance or visual acceptance.',
}
out = ROOT / 'docs/migration/evidence/story-touch-prompt-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({**report, 'negativeControls': {key: len(value) for key, value in negative.items()}}, indent=2))
