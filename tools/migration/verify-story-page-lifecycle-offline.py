"""Run actual StoryPage departure through the engine UI traversal, no GPU."""
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
env = runpy.run_path(str(ROOT / 'tools/migration/verify-workshop-shop-offline.py'))
lua = env['lua']
def section(source, begin, end):
    start = source.index(begin)
    return source[start:source.index(end, start)]


def install_engine(sources):
    renderer = section(sources['UI/Core/UI.lua'],
                       'local function renderWidgetTree(widget, nvg)',
                       '--- Render a widget subtree')
    visibility = section(sources['UI/Core/Widget.lua'],
                         'function Widget:IsVisible()', '--- Show widget')
    panel = section(sources['UI/Widgets/Panel.lua'],
                    'function Panel:CustomRenderChildren(nvg, renderFn)',
                    '-- ============================================================================\n-- Stateless')
    lua.execute('''
local renderingFixed_=false
local function hasTransform() return false end
local function trySaveNVGState() return true end
local function restoreNVGState() end
local Widget=require('urhox-libs/UI').Panel
local Panel=Widget
''' + visibility + panel + renderer + '\nRenderStoryTree=renderWidgetTree')
    return {name: hashlib.sha256(text.encode()).hexdigest()
            for name, text in [('renderer', renderer), ('visibility', visibility), ('panel', panel)]}


engine_paths = ['UI/Core/UI.lua', 'UI/Core/Widget.lua', 'UI/Widgets/Panel.lua']
reference = {p: (ROOT / 'urhox-libs' / p).read_text(encoding='utf-8') for p in engine_paths}
archive = json.loads(subprocess.check_output(['node', '-e', '''
const fs=require('node:fs'),c=require('./tools/migration/cached-engine-sources.cjs');
const m=JSON.parse(fs.readFileSync('.tmp/web-engine/http-cache/'+c.snapshots['urhox-libs'].manifest,'utf8'));
const result={};
for(const p of ['UI/Core/UI.lua','UI/Core/Widget.lua','UI/Widgets/Panel.lua']){
 const f=m.files.find(f=>f.fs_path==='urhox-libs/'+p);
 const url='https://tapcode-sce.spark.xd.com/src/urhox-libs/'+c.snapshots['urhox-libs'].client+'/assets/'+f.uuid+'-'+f.hash+f.ext;
 const response=c.read(url);if(!response)throw Error('Missing cached runtime source '+p);
 result[p]=response.body.toString('utf8');
}console.log(JSON.stringify(result));
'''], cwd=ROOT, text=True, encoding='utf-8'))
garage = (ROOT / 'scripts/ui/GarageHud.lua').read_text(encoding='utf-8')
tab_start = garage.index('    s.SetTab=function(tab,options)')
tab_end = garage.index('    s.Run=function(', tab_start)
set_tab = garage[tab_start:tab_end]
update = garage.split('function M.Update(dt)', 1)[1]
assert update.index('then Rebuild(s) end') < update.index("require('ui.StoryPage').Key(s)")
lua.globals().SET_TAB = set_tab
lua.execute(r'''
local UI=require 'urhox-libs/UI'
package.loaded['audio.UiSound']={Play=function()return true end}
function UI.Panel:GetRenderChildren() return self.children end
function UI.Panel:Render() end
function UI.Panel:RenderFullBackground() end
local D=require 'ui.SourceDraw'
function D.Begin()TREE_PAINTS=TREE_PAINTS+1 end
for _,name in ipairs({'nvgMoveTo','nvgLineTo','nvgClosePath','nvgCircle'})do _G[name]=function()end end
KEY_UP=11;KEY_DOWN=12;KEY_W=13;KEY_S=14
KEY_1=21;KEY_2=22;KEY_3=23;KEY_4=24;KEY_5=25
input.focus=true;input.minimized=false
package.loaded['controls.TouchMode']={Enabled=function()return false end}
package.loaded['audio.AudioLevels']={Speaking=function()return false end}
HISTORY={};JOBS={};TREE_DRAWS=0;TREE_CHILD_VISITS=0;TREE_PAINTS=0
package.loaded['render.StoryHolo']={New=function()
 local h={ready=false,disposeCount=0,updates=0}
 function h:Select(level)self.level=level end
 function h:Dispose()self.disposeCount=self.disposeCount+1 end
 function h:Update()self.updates=self.updates+1 end
 function h:Drag()self.drags=(self.drags or 0)+1 end
 function h:Zoom()self.zooms=(self.zooms or 0)+1 end
 function h:Reset()self.resets=(self.resets or 0)+1 end
 HISTORY[#HISTORY+1]=h;return h
end}
VOICES={}
package.loaded['audio.StoryPageVoice']={New=function()
 local v={disposeCount=0}
 function v:Select(level,text,auto)self.level=level;self.text=text;self.auto=auto end
 function v:Text()return self.text end
 function v:Dispose()self.disposeCount=self.disposeCount+1 end
 function v:Update()end
 function v:Play()self.played=true end
 VOICES[#VOICES+1]=v;return v
end}
package.loaded['app.ResourceGate']={New=function()
 local gate={generation=0,cancelCount=0}
 function gate:Cancel()self.generation=self.generation+1;self.cancelCount=self.cancelCount+1 end
 function gate:Start(paths,done)
  local generation=self.generation
  JOBS[#JOBS+1]={finish=function(ok)if generation==self.generation then done(ok)end end,
   rawFinish=done,gate=self,paths=paths}
 end
 return gate
end}
function StoryOwner()
 local s={width=1920,height=1080,tab='story',revision=0,storyLevel=1,
  Track=function(w)return w end,SetNew=function()end,
  app={store={Read=function()return nil end,Write=function()return true end},
   vehicleGate={Cancel=function()end},HomeView=function()end}}
 s.Layout=require 'ui.GarageLayout'
 s.buttons={}
 for _,id in ipairs({'hangar','livery','workshop','shop','help','settings','edit','battle','trial','new'})do s.buttons[id]=UI.Panel{} end
 for _,id in ipairs({'nav','cta','info','loadout','actions','leftArrow','rightArrow','bayScroll','bayStrip'})do s[id]=UI.Panel{} end
 assert(load('local s=...;local app=s.app;local Layout=s.Layout;'..SET_TAB))(s)
 return s
end
function PrepareStoryTree(page)
 local function Prepare(widget)
  widget.renderProps_={}
  local original=widget.Render
  widget.Render=function(self,vg)
   TREE_DRAWS=TREE_DRAWS+1
   if self~=page then TREE_CHILD_VISITS=TREE_CHILD_VISITS+1 end
   if original then original(self,vg)end
  end
  for _,child in ipairs(widget.children)do Prepare(child)end
 end
 Prepare(page);return page
end
function LoadStory(text)
 local module=assert(load(text,'@scripts/ui/StoryPage.lua'))()
 package.loaded['ui.StoryPage']=module;return module
end
function FindStoryButton(page,kind)
 for _,child in ipairs(page.children)do if child.props.storyKind==kind then return child end end
 error('missing story button '..kind)
end
function StoryDrag(page)
 for _,child in ipairs(page.children)do if child.OnWheel then return child end end
 error('missing story drag surface')
end
function SendStoryInput(drag)
 local accepted=drag:OnPointerDown({pointerId=1,x=1,y=1})
 drag:OnPointerMove({pointerId=1,x=4,y=4})
 drag:OnWheel(0,1)
 drag:OnClick({timestamp=1,x=1,y=1});drag:OnClick({timestamp=2,x=1,y=1})
 return accepted
end
''')
old_path = ROOT / '.tmp/outgame-cached-1792106681145/scripts/ui/StoryPage.lua'
d47_path = ROOT / '.tmp/outgame-cached-1792107779538/scripts/ui/StoryPage.lua'
assert hashlib.sha256(d47_path.read_bytes()).hexdigest() == 'b6c7bf5dbcf5444d6526952f6bae699cad24385c0a9eb1b09449f5040cb93166'
check_start = lua.globals().CHECKS
models = []
for model_name, sources in [('reference', reference), ('cached-runtime-urhox-libs-1.0.47', archive)]:
    engine_hashes = install_engine(sources)
    negatives = {}
    for label, historical in [('749', old_path), ('d47', d47_path)]:
        lua.globals().STORY_TEXT = historical.read_text(encoding='utf-8')
        before = dict(lua.execute(r'''
local Story=LoadStory(STORY_TEXT)
local s=StoryOwner();s.page=PrepareStoryTree(Story.Create(s))
RenderStoryTree(s.page,1)
-- Update has already rebuilt; Key changes tab but the mounted tree survives
-- until the next Update, exactly as GarageHud.Update orders these operations.
PRESSED={[KEY_ESCAPE]=true};Story.Key(s);PRESSED={}
local ok,err=pcall(RenderStoryTree,s.page,1)
return {result=ok and 'UNEXPECTED_PASS' or 'REPRODUCED',error=tostring(err),tab=s.tab,visible=s.page:IsVisible()}
'''))
        assert before['result'] == 'REPRODUCED' and 'storyHolo' in before['error'] and before['tab'] == 'battle' and before['visible'], before
        negatives[label] = before
    lua.globals().STORY_TEXT = (ROOT / 'scripts/ui/StoryPage.lua').read_text(encoding='utf-8')
    model_start = lua.globals().CHECKS
    lua.execute(r'''
local Story=LoadStory(STORY_TEXT)
for _,exit in ipairs({'escape','back','external'})do
 local s=StoryOwner();s.page=PrepareStoryTree(Story.Create(s));local old=s.page
 local holo,voice,gate=s.storyHolo,s.storyVoice,s.storyFaceGate;local late=JOBS[#JOBS]
 TREE_DRAWS=0;RenderStoryTree(old,1)
 Check(TREE_DRAWS>8,'actual page and descendants draw before '..exit)
 Check(s.storyPage==old and old:IsVisible(),'mounted story identity stored')
 local drag=StoryDrag(old)
 Check(SendStoryInput(drag) and holo.drags==1 and holo.zooms==1 and holo.resets==1,'active drag wheel and double click remain connected')
 if exit=='escape'then PRESSED={[KEY_ESCAPE]=true};Story.Key(s);PRESSED={}
 elseif exit=='back'then FindStoryButton(old,'back').props.onClick()
 else Story.Leave(s);s.Layout.Apply(s,s.width,s.height,s.safe)end
 Check(old:IsVisible() and s.storyPage==nil,'actual layout can reopen retired mounted root on '..exit)
 Check(s.page==old,'old root still mounted until next Update rebuild')
 Check(s.storyHolo==nil and s.storyVoice==nil and s.storyBrief==nil,'released render dependencies cleared')
 Check(holo.disposeCount==1 and voice.disposeCount==1 and gate.cancelCount==1,'each owned object released once')
 local count=TREE_DRAWS;local paints,children=TREE_PAINTS,TREE_CHILD_VISITS;RenderStoryTree(s.page,1)
 Check(TREE_DRAWS==count+1 and TREE_PAINTS==paints and TREE_CHILD_VISITS==children,'reopened retired root paints nothing and suppresses all descendants same frame')
 Check(not SendStoryInput(drag) and holo.drags==1 and holo.zooms==1 and holo.resets==1,'late pointer wheel and click ignore released dependencies')
 Story.Leave(s);Story.Leave(s)
 Check(holo.disposeCount==1 and voice.disposeCount==1 and gate.cancelCount==1,'repeated leave idempotent')
 late.finish(true);late.rawFinish(true)
 Check(not s.storyFacesReady and s.storyPage==nil,'late completion cannot revive retired page or readiness')
 s.tab='story';s.page=PrepareStoryTree(Story.Create(s));local returned=s.page
 Check(returned~=old and returned:IsVisible() and s.storyPage==returned,'new page mounts visibly after return')
 Check(s.storyHolo~=holo and s.storyVoice~=voice and s.storyFaceGate~=gate,'new owned resources created after return')
 paints,children=TREE_PAINTS,TREE_CHILD_VISITS;RenderStoryTree(old,1)
 Check(TREE_PAINTS==paints and TREE_CHILD_VISITS==children,'old visible root cannot draw against replacement owner resources')
 Check(not SendStoryInput(drag) and not s.storyHolo.drags and not s.storyHolo.zooms and not s.storyHolo.resets,'old pointer callbacks cannot mutate replacement resources')
 late.rawFinish(true)
 Check(not s.storyFacesReady,'previous generation completion cannot mark new page ready')
 JOBS[#JOBS].finish(true)
 Check(s.storyFacesReady,'current generation faces still complete')
 count=TREE_DRAWS;RenderStoryTree(returned,1)
 Check(TREE_DRAWS>count+8,'returned actual page and descendants render')
 FindStoryButton(returned,'voice').props.onClick()
 Check(s.storyVoice.played,'returned voice button remains connected')
 Story.Update(s,.1);Check(s.storyHolo.updates==1,'returned holo update remains connected')
 Story.Leave(s)
end
-- A second Create can replace owner.storyPage while the first root stays mounted.
local s=StoryOwner();s.page=PrepareStoryTree(Story.Create(s));local mounted=s.page
local replacement=PrepareStoryTree(Story.Create(s))
local paints,children=TREE_PAINTS,TREE_CHILD_VISITS;RenderStoryTree(mounted,1)
Check(TREE_PAINTS==paints and TREE_CHILD_VISITS==children,'identity mismatch blocks old mounted root before leave')
Story.Leave(s);s.Layout.Apply(s,s.width,s.height,s.safe)
paints,children=TREE_PAINTS,TREE_CHILD_VISITS;RenderStoryTree(mounted,1)
Check(mounted:IsVisible() and TREE_PAINTS==paints and TREE_CHILD_VISITS==children,'new-page leave cannot reactivate old mounted tree')
Check(not replacement:IsVisible() and s.storyHolo==nil,'replacement leave retires resources and registered root')
''')
    mutation_negatives = {}
    current = (ROOT / 'scripts/ui/StoryPage.lua').read_text(encoding='utf-8')
    for label, old, new, expected in [
        ('missing-root-guard', 'function Page:Render(vg)\n    if not PageActive(self) then return end',
         'function Page:Render(vg)', 'storyHolo'),
        ('missing-descendant-guard',
         'if PageActive(self) then UI.Panel.CustomRenderChildren(self,vg,renderFn) end',
         'UI.Panel.CustomRenderChildren(self,vg,renderFn)', 'brief'),
    ]:
        assert current.count(old) == 1, label
        lua.globals().STORY_TEXT = current.replace(old, new, 1)
        failure = dict(lua.execute(r'''
local Story=LoadStory(STORY_TEXT)
local s=StoryOwner();s.page=PrepareStoryTree(Story.Create(s))
FindStoryButton(s.page,'back').props.onClick()
local ok,err=pcall(RenderStoryTree,s.page,1)
return {result=ok and 'UNEXPECTED_PASS' or 'REPRODUCED',error=tostring(err)}
'''))
        assert failure['result'] == 'REPRODUCED' and expected in failure['error'], failure
        mutation_negatives[label] = failure
    models.append({'name': model_name, 'checks': lua.globals().CHECKS - model_start,
                   'historicalNegatives': negatives, 'engineMethodHashes': engine_hashes,
                   'mutationNegatives': mutation_negatives,
                   'engineSourceHashes': {p: hashlib.sha256(t.encode()).hexdigest() for p, t in sources.items()}})
paths = ['scripts/ui/StoryPage.lua', 'scripts/ui/GarageHud.lua',
         'scripts/ui/GarageLayout.lua',
         'tools/migration/verify-story-page-lifecycle-offline.py']
report = {'result': 'PASS', 'checks': lua.globals().CHECKS - check_start,
          'baseline': env['oracle']['baseline'], 'models': models,
          'old749Sha256': hashlib.sha256(old_path.read_bytes()).hexdigest(),
          'd47Sha256': hashlib.sha256(d47_path.read_bytes()).hexdigest(),
          'productionHashes': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths},
          'rootCause': 'Actual GarageHud.SetTab calls StoryPage.Leave then GarageLayout.Apply/Visibility; Visibility sets s.page visible for battle, reopening the still-mounted retired StoryPage before the next rebuild. The previous fixture replaced Layout.Apply with an empty function and missed this write.',
          'boundary': 'Actual historical/current StoryPage, extracted actual GarageHud.SetTab and complete actual GarageLayout.Apply/Visibility execute through unmodified reference and cached-runtime 1.0.47 renderWidgetTree, Panel.CustomRenderChildren and Widget visibility methods. Native layout/render/resources and the widget constructor use doubles. Tests include reopened roots and descendants, mounted old/new page identity, repeated leave, old/current callbacks, button/Escape and returned voice/update. No browser, GPU, actual hologram or visual acceptance.'}
output = ROOT / 'docs/migration/evidence/story-page-lifecycle-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
