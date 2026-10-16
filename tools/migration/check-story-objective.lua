package.path='scripts/?.lua;'..package.path
local now=0;Time={GetSystemTime=function() return now end}
local O=require 'ui.MissionObjective'
local checks,samples=0,0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(a,b,label) Check(math.abs(a-b)<.002,label..': '..tostring(a)..' ~= '..tostring(b)) end
for _,test in ipairs(SOURCE.cases) do
    now=0;local objective=O.New(test.touch)
    for i,op in ipairs(test.ops) do
        if op.at then now=op.at end
        if op.op=='objective' then objective:Objective({title=op.title,hint=op.hint},op.index,6)
        elseif op.op=='retitle' then objective:Retitle(op.title)
        elseif op.op=='done' then objective:Done() end
        local state=objective:State();local expected=test.trace[i];samples=samples+1
        local label=test.name..' at '..now..'/'..i
        Check((state~=nil)==expected.visible,label..' visibility')
        if state then
            for _,key in ipairs({'title','hint','index','total','done'}) do Check(state[key]==expected[key],label..' '..key) end
            for _,key in ipairs({'alpha','x','brightness','fill'}) do Near(state[key],expected[key],label..' '..key) end
        end
    end
end
-- Disposing owns all pending presentation work; old timers cannot touch a new mission.
now=0;local old=O.New();old:Objective({title='old'},1,2)
now=500;old:Objective({title='pending'},2,2);old:Dispose();old:Dispose()
old:Retitle('late');old:Done();old:Objective({title='late'},2,2);now=5000
Check(old:State()==nil and #old.pending==0,'disposed objective rejects late events and clears timers')
local fresh=O.New();Check(fresh:State()==nil,'new mission does not inherit old objective')
fresh:Objective({title='fresh'},1,1);Check(fresh:State().title=='fresh','new mission independently starts')

-- Render actual objective with native drawing adapters; inspect source colors,
-- alpha/transform, exact hint and state save/restore without opening a GPU.
local draw,depth={},0
local function Log(kind,...) draw[#draw+1]={kind,...} end
NVG_ALIGN_LEFT=1
nvgSave=function()depth=depth+1 end;nvgRestore=function()depth=depth-1 end
nvgTranslate=function(_,x,y)Log('translate',x,y)end
nvgGlobalAlpha=function(_,a)Log('alpha',a)end
nvgRotate=function(_,r)Log('rotate',r)end
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgFillPaint','nvgFill','nvgFillColor','nvgStroke','nvgStrokeColor','nvgStrokeWidth'})do _G[name]=function(...)Log(name,...)end end
nvgBoxGradient=function(_,x,y,w,h,r,blur,from,to)Log('glow',blur,from,to);return {}end
package.loaded['ui.SourceDraw']={Color=function(c)return c end,Text=function(_,text,x,y,size,color,font,align,spacing,base,line,shadow)Log('text',text,color,spacing,line,shadow)end}
local paragraph={Draw=function(_,_,text,x,y,width,color)Log('hint',text,color)end}
local function Find(kind)for _,call in ipairs(draw)do if call[1]==kind then return call end end end
now=0;local rendered=O.New();rendered:Objective({title='active',hint='hint'},1,1);now=420
rendered:Draw({},paragraph,38,128,386)
Check(depth==0,'active rendering restores state');Check(Find('glow')[2]==10,'actual normal orange glow radius')
Check(Find('text')[3][1]==244 and Find('text')[3][2]==245 and Find('text')[3][3]==247,'actual normal title CSS RGB')
Check(Find('text')[4]==1 and Find('text')[5]==27.6,'original title tracking/line-height')
rendered:Done();now=620;draw={};rendered:Draw({},paragraph,38,128,386)
Check(depth==0 and Find('glow')[2]==14,'actual green done glow and restored state')
local color=Find('text')[3];Check(color[1]==61 and color[2]==220 and color[3]==132,'actual done green CSS RGB')
Check(Find('hint')[2]=='hint','done presentation retains final hint')

for _,id in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'})do package.preload[id]=function()return {}end end
local Mission=require 'story.Mission';local Rules=require 'story.MissionRules'
local steps={{id='one',kind='talk',title='one',hint='hint'},{id='two',kind='talk',title='two'}}
local rules=Rules.New({steps=steps,spawn={pos={0,0,0}}});local events={};local voiced={}
local m=setmetatable({rules=rules,level={steps=steps,no='01',name='test'},objective=O.New(),player={alive=true},
    voice={Say=function(_,lines)voiced[#voiced+1]=lines end},view={Objective=function()end},radio={Play=function()end}},Mission)
m.ClearEnemies=function()end;m.Banner=function()end
now=0;rules:Go(1);m:Events();Check(m.objective:State().title=='one','actual Mission objective event wired')
rules.retitle='dynamic';m:Events();Check(m.objective:State().title=='dynamic','actual Mission dynamic title wired')
m.player.alive=false;rules.retitle='must not update dead title';now=500;m:Events()
Check(m.objective:State().title=='dynamic','death preserves last actual retitle')
rules:Go(2);m:Events();Check(m.objective:State().title=='dynamic' and m.objective:State().done,'next logical step does not replace old title immediately')
now=1150;Check(m.objective:State().title=='two','death countdown does not stop original wall timer')
m.player.alive=true;rules.retitle=nil;rules:Go(3);m:Events();now=5000
Check(rules:StepSpec()==nil and m.objective:State().title=='two' and m.objective:State().done,'actual final complete retains last objective with nil logical step')
Check(m.objective:State().index==2,'final objective number never becomes out-of-bounds 3 / 2')
rules.finished=true;m.session={HasFocus=function()return true end}
m.radio={Update=function()end};m.voice={Update=function()end}
m.boss={Update=function()rules.retitle='打驾驶舱'end}
m:Update(.016);Check(m.objective:State().title=='打驾驶舱','Boss frame title changes reach actual objective without waiting a physics step')
m.boss={Update=function()end};now=5100;m.objective:Objective({title='new'},2,2)
now=5750;m:Update(.016);Check(m.objective:State().title=='new','unchanged Boss retitle never overrides a delayed source swap')
m.boss=nil
local objective=m.objective;m.voice=nil;m.radio=nil;m.view=nil;m:Dispose()
Check(objective.disposed and m.objective==nil,'actual Mission.Dispose cancels pending objective state')

-- The actual MissionHud must render completion despite StepSpec=nil; its
-- adjacent progress rows remain live and native UI/layout remain adapters.
local methods
local panel={Extend=function()local cls={};methods=cls;return cls end}
package.preload['urhox-libs/UI']=function()return {Panel=panel}end
package.preload['ui.MissionFrame']=function()return {Draw=function()end}end
package.preload['ui.CommsCard']=function()return {}end
package.preload['story.MarkerRules']=function()return {}end
package.preload['ui.SourceParagraph']=function()return {}end
package.preload['ui.MissionBanner']=function()return {Draw=function()end}end
package.loaded['ui.SourceDraw'].Begin=function()end
package.loaded['ui.SourceDraw'].Rect=function()end
package.loaded['ui.SourceDraw'].Line=function()end
nvgScale=function()end
require 'ui.MissionHud'
local drawn=0
local hud=setmetatable({session={story={rules={StepSpec=function()return nil end,stats={},time=10},objective={State=function()return {index=2,total=2}end,Draw=function()drawn=drawn+1 end},level={id='s5',no='05',name='boss'},voice={},player={alive=false}},touch=false},hint={},GetAbsoluteLayout=function()return {x=0,y=0,w=1920,h=1080}end}, {__index=methods})
methods.Render(hud,{})
Check(drawn==1,'actual MissionHud draws retained final objective without logical step')
hud.session.story.boss={cinematic=true};methods.Render(hud,{})
Check(drawn==1,'actual Boss cinematic still hides objective panel')
return {result='PASS',checks=checks,sourceCases=#SOURCE.cases,sourceSamples=samples,
    boundary='Actual frozen StoryHud methods in VM with original touchCopy and CSS/WAAPI timing interpolation versus actual production Lua state/render/wiring. Native drawing/UI/actors are adapters; no Web screenshots, native blur fidelity or natural full-story acceptance.'}
