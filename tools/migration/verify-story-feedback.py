"""Frozen H5 prompt/dead callers, real Lua capture rules and MissionHud render."""
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

source = json.loads(subprocess.check_output(['node', 'tools/migration/story-feedback-source.mjs'], text=True, encoding='utf-8'))
css_report_path = ROOT / 'docs/migration/evidence/story-feedback-css.json'
css_reference = json.loads(css_report_path.read_text(encoding='utf-8'))
css_tool_path = ROOT / 'tools/migration/check-story-feedback-css.cjs'
assert css_reference['result'] == 'PASS'
assert css_reference['toolSha256'] == hashlib.sha256(css_tool_path.read_bytes()).hexdigest(), 'Rerun actual source CSS sampler'
assert css_reference['source']['commit'] == source['source']['commit']
source['browserCss'] = css_reference
production = (ROOT / 'scripts/ui/MissionPrompt.lua').read_text(encoding='utf-8')
hud_code = (ROOT / 'scripts/ui/MissionHud.lua').read_text(encoding='utf-8')
legacy_ref = '48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/ui/MissionHud.lua'
legacy_bytes = subprocess.check_output(['git', 'show', legacy_ref])


def convert(lua, value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(lua, item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(lua, item) for item in value])
    return value


def run(code, hud_text):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().SOURCE = convert(lua, source)
    lua.globals().PromptCode = code
    lua.globals().HudCode = hud_text
    return dict(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local checks,failures=0,{}
local function Check(ok,label)checks=checks+1;if not ok then failures[#failures+1]=label end end
local function Near(a,b,label)Check(type(a)=='number' and math.abs(a-b)<.00002,label)end
local now,depth=0,0;Time={GetSystemTime=function()return now end}
NVG_ALIGN_LEFT=1;NVG_ALIGN_RIGHT=2;NVG_ALIGN_CENTER=4;NVG_CW=1
local calls={}
local function Log(kind,...)calls[#calls+1]={kind=kind,args={...}}end
local methods
package.preload['urhox-libs/UI']=function()return {Panel={Extend=function()methods={};return methods end}}end
package.loaded['ui.SourceDraw']={Begin=function()end,Color=function(c)return c end,
 Text=function(_,text,x,y,size,color,font,align,spacing,baseline,line,shadows)Log('text',text,x,y,size,color,font,align,spacing,line,shadows)end,
 Rect=function(_,x,y,w,h,color)Log('rect',x,y,w,h,color)end,Line=function()end}
for _,name in ipairs({'ui.MissionFrame','ui.SourceParagraph','ui.CommsCard','story.MarkerRules','ui.MissionBanner'})do
 package.preload[name]=function()return {Draw=function()end}end
end
nvgSave=function()depth=depth+1 end;nvgRestore=function()depth=depth-1 end
nvgRGBA=function(...)return {...}end
for _,name in ipairs({'nvgBeginPath','nvgCircle','nvgRect','nvgArc','nvgFillColor','nvgFillPaint','nvgFill',
 'nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgTranslate','nvgScale','nvgGlobalAlpha'})do
 _G[name]=function(_,...)Log(name,...)end
end
nvgRadialGradient=function(_,...)Log('radial',...);return {}end
nvgBoxGradient=function(_,...)Log('glow',...);return {}end
local Prompt=assert(load(PromptCode))();package.loaded['ui.MissionPrompt']=Prompt
assert(load(HudCode))()
local Capture=require 'story.CaptureRules'
local function Rules(input)
 local spec={kind=input.kind,pos={0,2,0},r=9,site='A',title='夺回采集器',trigger=30,guards={},counter={{}}}
 local r={inside=input.inside,blocked=input.blocked,install=(input.progress or 0)*2.4,progress=input.progress or 0,stats={},time=10,
  StepSpec=function()return spec end,Emit=function()end,Near=function()return input.inside end}
 if input.kind=='capture' then
  r.cap=Capture.New();r.cap.phase=input.phase;r.cap.p=input.progress;r.cap.scrub=input.progress*1.6
  local enemies={};for _=1,input.enemies do enemies[#enemies+1]={0,2,0}end
  r.cap:Update(r,0,{pos=input.inside and {0,2,0} or {100,2,0},size={},enemyPositions=enemies,enemyTags={counter=input.enemies}})
 end
 return r
end
local function FindText(text)
 for _,call in ipairs(calls)do if call.kind=='text' and call.args[1]==text then return call.args end end
end
local function Find(kind,test)
 for _,call in ipairs(calls)do if call.kind==kind and (not test or test(call.args))then return call.args end end
end
local function Hud(r,alive,touch)
 return setmetatable({session={story={rules=r,voice={},level={id='s1',no='01',name='test'},player={alive=alive}},touch=touch},
  GetAbsoluteLayout=function()return {x=0,y=0,w=1920,h=1080}end},{__index=methods})
end
for index,test in ipairs(SOURCE.cases)do
 local r=Rules(test.input);local actual=Prompt.Select(r,test.input.touch);local expected=test.expected
 local label='case '..index..' '..test.input.kind
 Check((actual~=nil)==expected.visible,label..' visible')
 if actual and expected.visible then
  for _,key in ipairs({'title','sub','key','blocked'})do Check(actual[key]==expected[key],label..' '..key)end
  Near(actual.progress,expected.progress,label..' progress')
 end
 now=0;local hud=Hud(r,true,test.input.touch);methods.Render(hud,{})
 now=1000;calls={};methods.Render(hud,{})
 Check(depth==0,label..' UI save/restore')
 if expected.visible then
  Check(FindText(expected.title)~=nil,label..' actual MissionHud title')
  Check(FindText(expected.sub)~=nil,label..' actual MissionHud subtitle')
  Check((FindText('G')~=nil)==expected.key,label..' actual MissionHud key')
  local circle=Find('nvgCircle');Near(circle and circle[3],35.7,label..' SVG radius scaled 84/80')
  local title=FindText(expected.title)
  if title then Near(title[4],20,label..' title size');Near(title[8],2,label..' title tracking')end
  local sub=FindText(expected.sub);if sub then Check(sub[6]=='vox-body',label..' body font');Near(sub[4],13,label..' subtitle size')end
  local arc=Find('nvgArc')
  if expected.progress>0 then
   Check(arc~=nil,label..' actual ring progress')
   if arc then Near(arc[5]-arc[4],2*math.pi*expected.progress,label..' actual ring angle')end
   Check(Find('nvgStrokeColor',function(a)local c=a[1];return c[1]==255 and c[2]==(expected.blocked and 59 or 106) and c[3]==(expected.blocked and 70 or 19) and c[4]==255 end)~=nil,label..' actual arc source color')
  end
 else Check(#calls<=4,label..' no prompt geometry while hidden')end
end
for index,test in ipairs(SOURCE.deaths)do
 local p=Prompt.Dead(test.sec);Check((p~=nil)==test.visible,'death '..index..' visible')
 if p then
  Check(p.label==test.label,'death '..index..' original ceil/text');Near(p.progress,test.progress,'death '..index..' original progress')
  local r=Rules({kind='reach',inside=false});r.respawnLeft=test.sec
  now=0;local hud=Hud(r,false,false);methods.Render(hud,{})
  now=1000;calls={};methods.Render(hud,{})
  Check(FindText(test.label)~=nil,'death '..index..' actual MissionHud countdown')
  local title=FindText('战车损毁');Check(title and title[4]==46 and title[5][2]==213,'death '..index..' original title style')
  Check(Find('rect',function(a)return a[3]==260 and a[4]==3 end)~=nil,'death '..index..' track')
  if test.progress>0 then Check(Find('rect',function(a)return math.abs(a[3]-260*test.progress)<.0001 and a[4]==3 and a[5][2]==107 end)~=nil,'death '..index..' original bar fill')end
  Check(depth==0,'death '..index..' restores frame')
 end
end
-- Opacity uses original .2s/.3s CSS ease against wall time, including hidden
-- retained DOM content; a new HUD does not inherit the old HUD's timers.
local r=Rules({kind='install',inside=true,blocked=false,progress=0});local p=Prompt.New()
local _,pa,_,da=p:State(r,false,true,0);Near(pa,0,'prompt fade starts transparent');Near(da,0,'alive death hidden')
local Ease=require('ui.SourceButtonMotion').Ease
local _,middle=p:State(r,false,true,100);Near(middle,Ease(.5,'ease'),'source prompt ease midpoint')
local _,full=p:State(r,false,true,200);Near(full,1,'prompt fade completes 200ms')
r.inside=false;local retained,started=p:State(r,false,true,300);Check(retained~=nil,'hide retains source prompt content');Near(started,1,'hide starts from visible')
local _,half=p:State(r,false,true,400);Near(half,1-Ease(.5,'ease'),'prompt fade out midpoint')
local _,hidden=p:State(r,false,true,500);Near(hidden,0,'prompt hidden at 200ms')
local _,_,dead,start=p:State(r,false,false,500);Check(dead~=nil,'death content ready');Near(start,0,'death starts transparent')
local _,_,_,mid=p:State(r,false,false,650);Near(mid,Ease(.5,'ease'),'source death ease midpoint')
local _,_,_,endAlpha=p:State(r,false,false,800);Near(endAlpha,1,'death completes 300ms')
local _,_,_,respawn=p:State(r,false,true,800);Near(respawn,1,'respawn begins fade out')
local _,_,_,clear=p:State(r,false,true,1100);Near(clear,0,'respawn hides death at 300ms')
local fresh=Prompt.New();local _,newAlpha=fresh:State(r,false,true,9999);Near(newAlpha,0,'new mission has no previous fade')
-- Independently sampled original Chrome CSS, including reversal shortening.
for _,sequence in ipairs(SOURCE.browserCss.sequences)do
 local state=Prompt.New();local rules=Rules({kind='install',inside=false,blocked=false,progress=0});local alive=true
 for index,op in ipairs(sequence.ops)do
  if op.on~=nil then if sequence.selector=='.sh-prompt' then rules.inside=op.on else alive=not op.on end end
  local _,pa,_,da=state:State(rules,false,alive,op.at)
  Near(sequence.selector=='.sh-prompt' and pa or da,sequence.samples[index].opacity,'actual source browser CSS '..sequence.selector..' '..index)
  local tween=sequence.selector=='.sh-prompt' and state.promptFade or state.deadFade
  Check(math.abs(tween.duration-sequence.samples[index].duration)<.004,'actual CSS reversal duration '..sequence.selector..' '..index)
 end
end
for _,sample in ipairs(SOURCE.browserCss.blinking)do
 local function Blink(at)
  calls={};Prompt.DrawDead({},Prompt.Dead(1.5),1920,1080,1,at)
  return FindText('信号丢失 · SIGNAL LOST')[5][4]/255
 end
 local actual=Blink(sample.at);local match=math.abs(actual-sample.opacity)<.00001
 -- Chromium's double precision timeline can place the exact 600ms boundary
 -- on the preceding step. Preserve the independently sampled one-ms bound.
 if not match and sample.at%200==0 then match=math.abs(Blink(sample.at-1)-sample.opacity)<.00001 or math.abs(Blink(sample.at+1)-sample.opacity)<.00001 end
 Check(match,'actual source CSS blink '..sample.at)
end
for _,test in ipairs(SOURCE.deathTraces)do
 local rules=Rules(test.input);local state=Prompt.New()
 for _,sample in ipairs(test.trace)do
  if not sample.alive then rules.install=math.max(0,rules.install-.5*.8)end
  local prompt=state:State(rules,test.input.touch,sample.alive,sample.at)
  Check(prompt and prompt.title==sample.prompt.title,'actual death caller retains prompt title')
  Near(prompt and prompt.progress,sample.prompt.progress,'actual death caller retains prompt progress')
 end
end
return {checks=checks,failures=table.concat(failures,'\n'),cases=#SOURCE.cases,deaths=#SOURCE.deaths}
'''))


result = run(production, hud_code)
assert not result['failures'], result['failures']
negative = {}
for name, prompt, hud in [
    ('actual-pinned-48ef-hud', production, legacy_bytes.decode('utf-8-sig')),
    ('wrong-capture-key', production.replace('key=false,', 'key=true,'), hud_code),
    ('old-install-static-title', production.replace("progress>0 and '正在安装采集器…' or ", ''), hud_code),
    ('old-death-fractional-text', production.replace("math.ceil(sec)..' 秒后从上一个检查点重新空投'", "string.format('%.1f 秒后从检查点重新空投',sec)"), hud_code),
    ('missing-css-reverse-shortening', production.replace('t.nominal*factor', 't.nominal'), hud_code),
    ('resampling-prompt-during-death', production.replace("alive and M.Select(r,touch) or not alive and self.promptFade.target==1 and self.prompt or nil", "M.Select(r,touch)"), hud_code),
]:
    output = run(prompt, hud)
    assert output['failures'], f'Negative control did not fail: {name}'
    negative[name] = output['failures'].splitlines()

css = source['css']
assert css['.sh-prompt']['top'] == '63%'
assert css['.sh-prompt svg']['width'] == '84px'
assert css['.sh-prompt circle']['stroke-width'] == '5'
assert css['.sh-prompt b']['font'] == '400 20px var(--display)'
assert css['.sh-prompt small']['font'] == '400 13px var(--body)'
assert css['.sh-prompt']['transition'] == 'opacity .2s'
assert css['.sh-dead']['transition'] == 'opacity .3s'
assert css['.sh-dbar']['width'] == '260px' and css['.sh-dbar']['height'] == '3px'
assert css['.sh-dead b']['font'] == 'italic 400 46px var(--display)'
assert css['.sh-dead small']['font'] == '400 15px var(--body)'


def sha(relative):
    return hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()


report = {
    'result': 'PASS', 'checks': result['checks'] + 10, 'sourceCases': result['cases'], 'deathCases': result['deaths'],
    'source': source['source'], 'sourceCss': css, 'negativeControls': negative,
    'productionHashes': {name: sha(name) for name in [
        'scripts/ui/MissionPrompt.lua', 'scripts/ui/MissionHud.lua', 'scripts/story/CaptureRules.lua', 'scripts/ui/SourceButtonMotion.lua']},
    'inputs': {name: sha(name) for name in [
        'tools/migration/story-feedback-source.mjs', 'tools/migration/verify-story-feedback.py', 'tools/migration/check-story-feedback-css.cjs']},
    'historicalNegativeFixture': {'git': legacy_ref, 'sha256': hashlib.sha256(legacy_bytes).hexdigest()},
    'evidenceReportHashes': {'docs/migration/evidence/story-feedback-css.json': sha('docs/migration/evidence/story-feedback-css.json')},
    'boundary': 'Actual SHA-verified frozen StoryHud.prompt/dead, StoryMission.update and KINDS.capture.update versus actual production CaptureRules, selector, opacity and MissionHud.Render. DOM, native UI/VG and unrelated gameplay use adapters. No browser/native screenshots, font raster, blur fidelity, natural S1/S4/death, GPU or performance acceptance. New HUD is not in immutable 8b optimization acceptance package.'
}
output = ROOT / 'docs/migration/evidence/story-feedback-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({**report, 'negativeControls': {key: len(items) for key, items in negative.items()}}, ensure_ascii=False, indent=2))
