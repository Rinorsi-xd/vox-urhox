local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return type(a)=='number' and math.abs(a-b)<1e-9 or a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=function(path) return resources[path] end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={};package.loaded['ui.SourceDraw']={}
local Rules=require 'salvage.RunRules'
local Run=require 'salvage.Run'
for ci,case in ipairs(fixtures.cases) do
    local trace={};local r=Rules.New({loot={},wrecks={},extracts={}},{vaults=0},function() return 0 end)
    local o={id='vault',kind='crate',ctype='vault',tier=3,g={2,3,4}}
    local s={o=o,title='test',items={},i=1,p=0,wait=0,value=0,crack=0,done=false}
    for _,rarity in ipairs(case.rarities) do s.items[#s.items+1]={id='scrap',r=rarity,t=100,state='hidden'} end
    r.search=s;r.sessions.vault=s
    local run=setmetatable({rules=r,session={trauma=case.initialTrauma},audio={Event=function() end},
        cine={NameCard=function(_,title,sub,seconds) trace[#trace+1]={'card',title,sub,seconds*1000} end,
              Flash=function(_,...) trace[#trace+1]={'flash',...} end},
        fx={Loot=function(_,...) trace[#trace+1]={'beam',...} end},
        director={Noise=function(_,at,radius) trace[#trace+1]={'noise',at,radius} end,
                  Hunt=function(_,n,at) trace[#trace+1]={'hunt',n,at} end},
        view={Hide=function() end},feed={}},Run)
    local heat=r.Heat
    function r:Heat(n) trace[#trace+1]={'heat',n};heat(self,n) end
    for fi,frame in ipairs(case.frames) do
        local step=frame.step
        if step.reopen then r:Open(o) end
        r.time=r.time+step.dt
        r:SearchStep(step.dt,{speed=step.speed,hold=step.hold,pos={0,0,0}})
        run:Events()
        local prefix='case '..ci..' frame '..fi..' '
        Check(Same(r.search and r.search.crack or s.crack,frame.crack),prefix..'crack progress')
        Check(Same(r.heat,frame.heat),prefix..'heat')
        Check(Same(run.session.trauma,frame.trauma),prefix..'camera trauma')
        Check(Same(trace,frame.trace),prefix..'source effect order/parameters')
        -- In production Step clears prompt before the next SearchStep.
        if frame.prompt then Check(Same(r.prompt,frame.prompt),prefix..'source prompt') end
        r.prompt=nil
    end
    local cards,beams=0,0
    for _,event in ipairs(trace) do if event[1]=='card' then cards=cards+1 elseif event[1]=='beam' then beams=beams+1 end end
    Check(cards==1 and beams==1,'case '..ci..' one warning and one opening across re-entry')
end
-- Call real AfterStep: stationary forward projection deliberately remains zero.
input={GetKeyDown=function() return true end}
KEY_E=1
local position={0,0,0}
local unit={alive=true,spec={bounds={min={-1,-1,-1},max={1,1,1}}},
    vehicle={speed=0,mass=1,native={}}}
function unit:Position() return position end
local rules=Rules.New({loot={},wrecks={},extracts={}},{vaults=0},function() return 0 end)
local search={o={id='vault',kind='crate',ctype='vault',tier=3,g={0,0,0}},title='vault',
    items={{id='scrap',r=0,t=100,state='hidden'}},i=1,p=0,wait=0,value=0,crack=0,done=false}
rules.search=search
local run=setmetatable({begun=true,landed=false,rules=rules,player=unit,entries={{unit=unit}},
    session={pointer={captured=true},controls={held={interact=true}}},
    audio={Event=function() end},cine={HoldCar=function() end,NameCard=function() end},
    fx={Target=function() end,Update=function() end},view={Update=function() end},
    director={Step=function() end,Noise=function() end,Hunt=function() end}},Run)
for _,frame in ipairs(fixtures.entry) do
    local step=frame.step
    for i=1,3 do position[i]=step.pos[i] end
    if step.landed~=nil then run.landed=step.landed end
    if step.finished then rules.finished=true end
    if step.rebuild then unit.vehicle={speed=0,mass=1,native={}} end
    if not step.paused then run:AfterStep(step.dt) end
    local label=step.name..' real entry '
    Check(Same(run.speed or 0,frame.speed),label..'source XZ speed')
    Check(Same(run.lastPos,frame.lastPos),label..'retained position copy')
    Check(Same(search.crack,frame.crack),label..'source crack gating')
    if frame.prompt then Check(Same(rules.prompt,frame.prompt),label..'source prompt') end
end
return checks
