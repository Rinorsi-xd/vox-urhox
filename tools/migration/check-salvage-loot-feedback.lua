local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return type(a)=='number' and math.abs(a-b)<1e-7 or a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
dofile('tools/migration/g5-offline-imports.lua').Salvage()
package.loaded['salvage.Cinematics']=nil
dofile('tools/migration/g5-offline-imports.lua').Exclude({'render.CineDeathFilter','render.SalvageCineDust','ui.SourceDraw'})
package.loaded['ui.SourceButtonMotion']={Step=function() end}
package.loaded['core.ResourceData']={Read=function(name) return resources[name] end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={}
package.loaded['ui.SalvageLootMotion']={Event=function() end}
local Run=require 'salvage.Run';local Rules=require 'salvage.RunRules'
local now=1000;Time={GetSystemTime=function() return now end}
local function Make(rules,trauma)
    local trace={};local run=setmetatable({rules=rules,session={trauma=trauma or 0},feed={},
        audio={Event=function() end},fx={Reveal=function() end,Loot=function() end},
        director={Noise=function() end,Hunt=function() end},cine={Flash=function() end,NameCard=function() end},
        view={Hide=function() end}},Run)
    function run:Feed(...) trace[#trace+1]={...} end
    return run,trace
end
for i,case in ipairs(fixtures.rare) do
    now=1000;local rules=Rules.New({loot={},wrecks={},extracts={}},resources['Salvage/RunData.json'].ops[1])
    rules.cargo=case.full and {scrap=400} or {};rules.search={o={g={0,0,0},poi=case.poi},items={{id=case.id,n=1,r=case.r,t=.1,state='hidden'}},i=1,p=0,wait=0,value=0,held=true}
    local run,trace=Make(rules,case.trauma);rules:SearchStep(1,{pos={0,0,0}});run:Events()
    Check(Same(rules.cargo,case.cargo),'rare '..i..' actual rules cargo equals source')
    Check(run.session.trauma==case.afterTrauma,'rare '..i..' source gold/red trauma threshold and preserve high trauma')
    -- The ordinary local feed already exists; compare only the delayed broadcast.
    for j=#trace,1,-1 do if trace[j][1]~='全频道广播' then table.remove(trace,j) end end
    for f,frame in ipairs(case.frames) do
        now=frame.now;run:UpdateFeedback()
        Check(Same(trace,frame.feeds),'rare '..i..' source 1200ms wall clock broadcast frame '..f)
    end
    Check(rules.time==0,'rare '..i..' broadcast advances with paused simulation clock')
    run:UpdateFeedback();Check(Same(trace,case.frames[#case.frames].feeds),'rare '..i..' broadcast emits once')
end
for i,case in ipairs(fixtures.wrecks) do
    local rules=Rules.New({loot={},wrecks={},extracts={}},resources['Salvage/RunData.json'].ops[1],function() return case.seed end)
    rules.objects={{id='W',kind='wreck',model=case.model,name='断坝',g={0,0,0}}};rules.cargo=case.fill==-1 and {scrap=360,alloy=19} or case.fill>0 and {scrap=case.fill} or {}
    local run,trace=Make(rules);local need=case.model=='core' and 6 or resources['Salvage/RunData.json'].wrecks[case.model].time*.5
    rules:Step(need,{alive=true,pos={0,0,0},speed=0,width=5,hold=true});run:Events()
    Check(Same(rules.cargo,case.cargo),'wreck '..i..' actual generated loot/capacity equals source')
    Check(Same(trace,case.feeds),'wreck '..i..' source grouped actual pickup and overflow/empty feeds')
    Check(rules.opened.W and rules.openedCount==1,'wreck '..i..' dismantle consumes once')
end
do
    local rules={time=0,events={{type='reveal',item={id=fixtures.rare[#fixtures.rare].id,n=1,r=5}}},Drain=function(self) local out=self.events;self.events={};return out end}
    now=10;local run,trace=Make(rules);run:Events();Check(#run.pendingBroadcasts==1,'red fallback location schedules broadcast')
    package.loaded['salvage.CineMotion']={};package.loaded['render.SalvageCinematics']={}
    package.loaded['ui.SourceButtonMotion']={Step=function() end}
    local Cine=require 'salvage.Cinematics'
    local cine=setmetatable({run=run,time=0,shake=0,flashTime=0},Cine)
    now=1209;cine:Update(0);Check(#trace==1,'actual cinematic frame preserves 1199ms boundary with zero dt')
    now=1210;cine:Update(0);Check(#trace==2 and trace[2][1]=='全频道广播','actual cinematic frame advances wall-clock cue with paused dt')
    rules.events={{type='reveal',item={id=fixtures.rare[#fixtures.rare].id,n=1,r=5}}};run:Events()
    -- Dispose through the real lifecycle with already absent optional engine adapters.
    run.audio=nil;run.fx=nil;run.cine=nil;run.view=nil;run.director=nil;run.entries={};run:Dispose()
    now=4000;run:UpdateFeedback();Check(run.pendingBroadcasts==nil and #trace==3,'disposed action cancels delayed broadcast')
end
return checks
