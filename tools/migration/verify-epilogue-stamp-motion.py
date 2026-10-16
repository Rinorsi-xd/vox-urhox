"""Source CSS/timer contract versus actual Epilogue render and retirement."""
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

source = json.loads(subprocess.check_output(['node', 'tools/migration/source-epilogue-stamp-motion.mjs'], encoding='utf-8'))
resource = json.loads((ROOT / 'assets/Story/Boss/Epilogue.json').read_text(encoding='utf-8'))
fixture = (ROOT / 'tools/migration/check-epilogue-pages.lua').read_text(encoding='utf-8').split('local function Panel(bg,shot)')[0]
paths = ['scripts/ui/Epilogue.lua', 'scripts/ui/EpilogueMotion.lua']
current = [(ROOT / p).read_text(encoding='utf-8') for p in paths]
old_root = ROOT / '.tmp/outgame-cached-1792128891583'
old_identity = json.loads((old_root / 'identity.json').read_text(encoding='utf-8'))['identity']['scripts']
old = []
for path in paths:
    data = (old_root / path).read_bytes()
    assert hashlib.sha256(data).hexdigest() == old_identity[path.removeprefix('scripts/')], 'Frozen bb6e production drift'
    old.append(data.decode('utf-8-sig'))


def ease(t, controls):
    if t <= 0 or t >= 1:
        return min(1, max(0, t))
    x1, y1, x2, y2 = controls
    lo, hi = 0, 1
    for _ in range(55):
        u = (lo + hi) / 2
        x = 3 * (1-u)**2*u*x1 + 3*(1-u)*u*u*x2 + u**3
        if x < t:
            lo = u
        else:
            hi = u
    u = (lo + hi) / 2
    return 3*(1-u)**2*u*y1 + 3*(1-u)*u*u*y2 + u**3


def run(epilogue, motion):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({k: convert(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(v) for v in value])
        return value

    lua.globals().RESOURCE = convert(resource)
    lua.globals().EPILOGUE_SOURCE = epilogue
    lua.globals().MOTION_SOURCE = motion
    lua.execute(fixture)
    result = lua.execute(r'''
local drawStack,drawState,texts={},{alpha=1,scale=1},{}
function nvgSave()drawStack[#drawStack+1]={alpha=drawState.alpha,scale=drawState.scale}end
function nvgRestore()drawState=table.remove(drawStack)end
function nvgGlobalAlpha(_,alpha)drawState.alpha=alpha end
function nvgScale(_,x,y)assert(x==y);drawState.scale=drawState.scale*x end
function nvgTranslate()end
local D=package.loaded['ui.SourceDraw']
D.Text=function(_,text,_,_,_,color)
 texts[text]={alpha=drawState.alpha*(color and color[4] or 255)/255,scale=drawState.scale}
end
package.loaded['core.ResourceData']={Read=function()return RESOURCE end}
package.loaded['ui.EpilogueMotion']=assert(load(MOTION_SOURCE))()
local Epilogue=assert(load(EPILOGUE_SOURCE))()
local exits=0
local root={AddChild=function(self,page)page.parent=self;page.Destroy=function()end end,RemoveChild=function(_,page)page.parent=nil end}
local function New()return Epilogue.Attach({},root,function()exits=exits+1 end)end
local function Render(ep)texts={};ep.page:Render(1);assert(#drawStack==0,'balanced actual drawing state');return texts end
local ep=New();local deal
for _,scene in ipairs(RESOURCE.data.scenes)do if scene.panel and scene.panel.deal then deal=scene.panel end end
local entry={panel=deal,at=0};ep.motion:Add(entry,true,0)
ep.rules.current={kind='panel'}
local approvals={}
for _,age in ipairs({1.5999,1.6,1.6001,1.615,1.65,1.675,1.71,1.75,1.8,1.82,2.5})do
 ep.rules.time=age;ep.rules.age=age
 local text=Render(ep)['董事长批准'];approvals[#approvals+1]={age=age,draw=text~=nil,alpha=text and text.alpha or 0,scale=text and text.scale or 0}
end
ep:Dispose()
ep=New()
for index,step in ipairs(ep.rules.steps)do if step.kind=='stamp' then ep.rules.index=index;ep.rules.current=step;break end end
ep.rules.time=50;ep.rules.age=.5;ep.rules.events={{kind='stamp'}};ep:Update(0,true)
local before=Render(ep)['已驳回']~=nil
ep.rules:Finish();ep:Update(0,true)
local outro={}
for _,age in ipairs({0,.001,.1,.2,.4,.6,.7999,.8})do
 ep.rules.age=age;ep.rules.time=50+age
 local text=Render(ep)['已驳回'];outro[#outro+1]={age=age,draw=text~=nil,alpha=text and text.alpha or 0}
end
ep:Update(0,true);assert(not ep.active and exits==1,'retirement callback occurs once after 800ms')
ep=New();ep.rules:Finish();ep:Update(0,true)
local earlySkipStamp=Render(ep)['已驳回']~=nil;ep:Dispose()
return {approvals=approvals,outro=outro,before=before,earlySkipStamp=earlySkipStamp}
''')

    def plain(v):
        if hasattr(v, 'items'):
            values = dict(v)
            if values and all(isinstance(k, int) for k in values):
                return [plain(values[k]) for k in sorted(values)]
            return {k: plain(x) for k, x in values.items()}
        return v
    return plain(result)


def mismatches(result):
    failures = []
    approval = source['approval']
    for row in result['approvals']:
        elapsed = row['age'] - approval['delay']
        expected_scale = 2.4 - 1.4*ease(elapsed/approval['scaleDuration'], approval['scaleEase'])
        expected_alpha = .9*ease(elapsed/approval['opacityDuration'], approval['opacityEase'])
        if row['draw'] != (elapsed >= 0) or abs(row['alpha'] - expected_alpha) > 2e-5 or elapsed >= 0 and abs(row['scale'] - expected_scale) > 2e-5:
            failures.append('approval-' + str(row['age']))
    for row in result['outro']:
        expected = (1-ease(row['age']/source['outro']['duration'], source['outro']['ease'])) * 242/255
        if not row['draw'] or abs(row['alpha']-expected) > 2e-5:
            failures.append('outro-' + str(row['age']))
    if not result['before']:
        failures.append('stamp-before-outro')
    if result['earlySkipStamp']:
        failures.append('skip-before-stamp')
    return failures


actual = run(*current)
assert not mismatches(actual), mismatches(actual)
previous = run(*old)
old_failures = mismatches(previous)
assert any(v.startswith('approval-') for v in old_failures)
assert any(v.startswith('outro-') for v in old_failures)
mutants = {
    'missing-approval-motion': [current[0], current[1].replace('return 2.4-1.4*Ease(elapsed/.22,.2,1.6,.4,1),.9*Ease(elapsed/.15,.25,.1,.25,1)', 'return 1,.9')],
    'missing-outro-stamp': [current[0].replace('if stampAge then', "if r.current.kind=='stamp' then"), current[1]],
    'linear-outro': [current[0], current[1].replace('return 1-Ease(age/.8,.25,.1,.25,1)', 'return math.max(0,1-age/.8)')],
    'stamp-on-early-skip': [current[0].replace('or o.stampAt and r.time-o.stampAt', "or r.current.kind=='finish' and 1"), current[1]],
}
negative = {}
for name, code in mutants.items():
    failures = mismatches(run(*code))
    assert failures, name
    negative[name] = failures
hashes = lambda names: {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in names}
checks = sum(2 + (row['age'] >= source['approval']['delay']) for row in actual['approvals']) + 2*len(actual['outro']) + 3
report = {'result': 'PASS', 'checks': checks, 'source': source['source'], 'actualDraws': actual,
          'previousPackage': {'snapshot': str(old_root.relative_to(ROOT)), 'production': {p: old_identity[p.removeprefix('scripts/')] for p in paths}, 'mismatchedCases': old_failures},
          'negativeControls': negative,
          'productionHashes': hashes(paths + ['scripts/ui/IntroComicMotion.lua', 'assets/Story/Boss/Epilogue.json']),
          'testInputs': hashes(['tools/migration/source-epilogue-stamp-motion.mjs', 'tools/migration/verify-epilogue-stamp-motion.py', 'tools/migration/check-epilogue-pages.lua']),
          'boundary': 'Complete frozen playEpilogue with DOM/timer adapters and verified CSS, versus actual Lua Epilogue attach/update/render/finish/dispose with UI/voice/drawing adapters. Approval scale/opacity and final-stamp presence through CSS-eased 800ms overlay fade, early skip and one retirement callback only. Actual bb6e negative control plus four mutations. No GPU pixels, audio listening, natural S4/S5 completion or natural ending acceptance.'}
(ROOT / 'docs/migration/evidence/epilogue-stamp-motion-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'actualDraws'}, ensure_ascii=False, indent=2))
