local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return type(a)=='number' and math.abs(a-b)<1e-8 or a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
dofile('tools/migration/g5-offline-imports.lua').Salvage()
package.loaded['salvage.Cinematics']=nil
dofile('tools/migration/g5-offline-imports.lua').Exclude({'render.CineDeathFilter','render.SalvageCineDust'})
package.loaded['core.ResourceData']={Read=function(name) return resources[name] end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={}
package.loaded['ui.SourceDraw']={};package.loaded['ui.SalvageLootMotion']={Event=function() end}
package.loaded['render.SalvageCinematics']={}
local Vec={};Vec.__index=Vec
local function V(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},Vec) end
Vec.__add=function(a,b) return V(a.x+b.x,a.y+b.y,a.z+b.z) end
Vec.__sub=function(a,b) return V(a.x-b.x,a.y-b.y,a.z-b.z) end
Vec.__mul=function(a,b) return V(a.x*b,a.y*b,a.z*b) end
function Vec:Lerp(b,t) return V(self.x+(b.x-self.x)*t,self.y+(b.y-self.y)*t,self.z+(b.z-self.z)*t) end
Vector3=setmetatable({ZERO=V(0,0,0)},{__call=function(_,...) return V(...) end})
local Rules=require 'salvage.RunRules'
local Run=require 'salvage.Run'
local Cine=require 'salvage.Cinematics'
local Motion=require 'salvage.CineMotion'
for ci,case in ipairs(fixtures.cases) do
    local trace={};local r=Rules.New({loot={},wrecks={},extracts={{id='A',name='测试撤离点',x=-10,y=2,z=30,radius=12,wait=case.wait,loud=case.loud}}},{vaults=0},function() return 0 end)
    local cine=setmetatable({approachShot=Motion.New(),view={Ship=function() end}},Cine)
    local run=setmetatable({rules=r,session={},feed={},
        audio={Event=function() end},director={Noise=function(_,at,radius) trace[#trace+1]={'noise',at,radius} end,Hunt=function(_,n,at) trace[#trace+1]={'hunt',n,at} end},
        cine={Approach=function(_,e,wait) cine:Approach(e,wait);trace[#trace+1]={'approach',e.g,wait,cine.approach.wait} end,
            NameCard=function(_,title,sub,seconds) trace[#trace+1]={'card',title,sub,seconds*1000} end,
            Extract=function(_,e) trace[#trace+1]={'extract',e.g,e.name} end}},Run)
    local feed=Run.Feed
    function run:Feed(title,text,color) feed(self,title,text,color);trace[#trace+1]={'feed',title,text,color} end
    for fi,frame in ipairs(case.frames) do
        local step=frame.step;local pos=step.inside and {10,2,30} or {100,2,30}
        r:Step(step.dt,{alive=true,pos=pos,width=2,speed=0});run:Events()
        local label='case '..ci..' frame '..fi..' '
        Check(Same(r.ex and r.ex.left,frame.left),label..'source retained countdown')
        Check((r.extracts[1].called==true)==frame.called,label..'signal once')
        Check(r.finished==frame.extracting,label..'source extraction timing')
        Check(Same(trace,frame.trace),label..'actual source callback order/text/remaining duration')
    end
    Check(Same(run.feed[1].color,{61,220,132,255}),'case '..ci..' green extraction notice')
end
for i,shot in ipairs(fixtures.shots) do
    local cine=setmetatable({approachShot=Motion.New(),view={Ship=function() end}},Cine)
    cine:Approach({g={10,2,30},wait=20},shot.wait)
    local a=cine.approach;Motion.Approach(cine.approachShot,shot.t,a.E,a.wait)
    local r=cine.approachShot;local label='shot '..i..' '
    Check(Same(a.wait,shot.clamped),label..'source 3..6 second clamp')
    Check(Same({r.ship.x,r.ship.y,r.ship.z},shot.ship),label..'source ship position')
    Check(Same({r.rx,r.ry,r.rz},shot.rotation),label..'source ship rotation')
    Check(r.dust==shot.dust,label..'source arrival dust gate')
end
-- Actual update fallback uses the retained pre-decrement wait when no approach event was consumed.
local observed
local cine=setmetatable({run={rules={ex={e={g={0,0,0},wait=20},left=1.9,approachWait=2}}},
    time=0,shake=0,flashTime=0,approachShot=Motion.New(),view={Ship=function() end},
    bars={},hud={},namecard={},caption={},skip={}},Cine)
local realApproach=Cine.Approach
function cine:Approach(exit,wait) observed=wait;realApproach(self,exit,wait) end
package.loaded['ui.SourceButtonMotion'].Step=function() end
cine:Update(.1)
Check(observed==2 and cine.approach.wait==3,'actual update uses preserved remaining wait')
-- Real EndlessSession.Events -> real SourceToasts.Push; rendering is not involved.
package.loaded['urhox-libs/UI']={};package.loaded['ui.SourceRichText']={}
package.loaded['endless.Data']={config={}};package.loaded['endless.Run']={}
package.loaded['combat.EnemyDriver']={};package.loaded['combat.DrillRaiderDriver']={}
package.loaded['combat.ShieldQuery']={Contains=function() return false end};package.loaded['construction.Blueprint']={}
package.loaded['parts.Defs']={PARTS={laser={name='激光炮'}}}
dofile('tools/migration/g5-offline-imports.lua').Exclude({'endless.Audio','drive.SpawnSpecCache','endless.View',
    'endless.SpawnPresentation','drive.VehicleSpec','render.NodeVisibility','Config'})
local Session=require 'app.EndlessSession';local Toasts=require 'ui.SourceToasts'
local toasts=Toasts.New()
local endless=setmetatable({run={state='rest',Drain=function() return fixtures.events end},
    view={Event=function() end},audio={Event=function() end},session={app={toasts=toasts}}},Session)
endless:Events()
Check(#toasts.items==#fixtures.notices,'actual event consumer toast count, zero credits silent')
for i,expected in ipairs(fixtures.notices) do
    local item=toasts.items[i]
    Check(item.text==expected[1] and item.kind==expected[2],'toast '..i..' source text/kind')
    Check(item.hold*1000==expected[3],'toast '..i..' source lifetime')
end
for i,gate in ipairs(fixtures.gates) do
    local trace={}
    local run={respawnAt=gate.respawnAt,time=10,state=gate.state,
        NextWave=function() trace[#trace+1]={'next'};return false end,
        BeginEdit=function() trace[#trace+1]={'edit'};return false end}
    local session=setmetatable({run=run,player={Position=function() return {0,0,0} end},
        session={app={toasts={Push=function(_,...) trace[#trace+1]={'toast',...} end}}}},Session)
    local result
    if gate.entry=='nextWave' then result=session:NextWave() else result=session:EnterEdit() end
    Check((result==true)==gate.result,'gate '..i..' source return')
    Check(Same(trace,gate.trace),'gate '..i..' source entry order/toast/ceil, no edit or next before respawn')
end
local retained=setmetatable({feed={},rules={time=4}},Run)
retained:Feed('test','default')
Check(Same(retained.feed[1].color,{122,216,255,255}),'source default feed tint')
return checks
