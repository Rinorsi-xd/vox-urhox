local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return type(a)=='number' and math.abs(a-b)<1e-9 or a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=function(name) return assert(resources[name],name) end}
local Imports=dofile('tools/migration/g5-offline-imports.lua')
Imports.Salvage()
package.loaded['salvage.Director']=nil
Imports.Exclude({'combat.CarUnit','combat.EnemyDriver','ui.SalvageLootMotion'})
package.loaded['combat.DriverActions'].Apply=function() end
package.loaded['drive.RotorMotion'].Weapons=function() end
local Run=require 'salvage.Run'
local Rules=require 'salvage.RunRules'
local Director=require 'salvage.Director'
local Loot=require 'salvage.Loot'
input={GetKeyDown=function() return false end};KEY_E=1
local function AttachStep(u,pos)
    local body={translation=function() return {x=pos[1],y=pos[2],z=pos[3]} end,
        linvel=function() return {x=0,y=0,z=0} end,rotation=function() return {} end}
    u.vehicle={native={},mass=10,body=body,rotors={},StepRotors=function() end,Step=function() end}
    u.weapons={fx={},Step=function() end}
    -- This death-order fixture has no damaged structure; recovery is covered separately.
    function u:RegenerateStructure() end
    function u:Flush() assert(not self.disposed,'Flush after Dispose');if self.kill then self.alive=false end end
end
for i,case in ipairs(fixtures.cases) do
    local trace,removed,tags={},{},{}
    local draws=0
    local function Random() local value=((draws*37+case.mask*11+case.offset)%100)/100;draws=draws+1;return value end
    local rules=Rules.New({loot={},wrecks={},extracts={}},resources['Salvage/RunData.json'].ops[1],Random)
    rules.kills=7
    local player={alive=true,Position=function() return {10000,2,10000} end,
        spec={bounds={min={0,0,0},max={2,2,2}}},vehicle={native={},mass=10}}
    AttachStep(player,{10000,2,10000})
    local run=setmetatable({begun=true,landed=true,protectionEnded=true,rules=rules,player=player,
        entries={{unit=player}},session={controls={held={}},pointer={captured=false},hud={overlay={tags=tags}},
            effects={Consume=function() end},weaponAudio={Consume=function() end}},
        world={units={player}},view={Update=function() end},
        fx={Target=function() end,Update=function() end},explosion={},feed={},
        cine={Command=function(_,command) return command end}},Run)
    function run:Feed(...) trace[#trace+1]={'feed',...} end
    function run.explosion:Explode(...) trace[#trace+1]={'explode',...} end
    function run:Events() end
    function rules:Heat(n) trace[#trace+1]={'heat',n} end
    local director=setmetatable({run=run,entries=run.entries,world=run.world},Director)
    function director:Step() end
    run.director=director
    local groups={}
    for j=1,3 do groups[j]={name='post-'..(j-1),kind='camp',units={}} end
    for _,item in ipairs(case.input) do
        local u={key=item.key,name=item.name,alive=case.mode=='fall' or item.alive,elite=item.elite,
            spec={bounds={radius=item.radius},weapons={1},motion={load=1,topSpeed=1}}}
        AttachStep(u,item.pos)
        function u:Position() assert(not self.disposed,'Position after Dispose');return item.pos end
        function u:Dispose() assert(not self.disposed,'Duplicate Dispose');self.disposed=true;removed[#removed+1]=self.key end
        local enc=groups[item.group+1]
        local e={unit=u,kind=item.kind,def={name=item.name},enc=enc,why=item.why~='' and item.why or nil,
            driver={Step=function() return {},nil,false end}}
        run.entries[#run.entries+1]=e;run.world.units[#run.world.units+1]=u
        tags[#tags+1]={unit=u};enc.units[#enc.units+1]=e
    end
    if case.mode=='fall' then
        run:BeforeStep(1/60,{firing=false},nil)
        for j,item in ipairs(case.input) do
            local u=run.entries[j+1].unit
            Check(u.alive==item.alive,'case '..i..' actual BeforeStep strict -300m boundary actor '..j)
            Check(item.alive and not u.kill or not item.alive and u.kill=='掉出地图',
                'case '..i..' actual BeforeStep fall reason actor '..j)
        end
    end
    run:AfterStep(0)
    Check(Same(trace,case.trace),'case '..i..' source death, explosion, feed and encounter order')
    local count=#trace;run:AfterStep(0)
    Check(#trace==count,'case '..i..' second actual step cannot repeat settlement')
    Check(rules.kills==case.kills,'case '..i..' each dead actor counted once')
    local remaining,worldRemaining,tagRemaining={},{},{}
    for j=2,#run.entries do remaining[#remaining+1]=run.entries[j].unit.key end
    for j=2,#run.world.units do worldRemaining[#worldRemaining+1]=run.world.units[j].key end
    for _,tag in ipairs(tags) do tagRemaining[#tagRemaining+1]=tag.unit.key end
    Check(Same(remaining,case.remaining),'case '..i..' source live entries retained in insertion order')
    Check(Same(worldRemaining,case.remaining),'case '..i..' actual Director.Remove keeps world units consistent')
    Check(Same(tagRemaining,case.remaining),'case '..i..' actual Director.Remove removes only dead HUD tags')
    Check(#removed==case.kills-7,'case '..i..' actual Director.Remove disposes each dead actor once')
    Check(draws==0,'case '..i..' death settlement consumes no reward RNG')
    local actual={}
    for _,o in ipairs(rules.objects) do
        rules:Open(o)
        local items={}
        for _,item in ipairs(rules.search.items) do items[#items+1]={id=item.id,n=item.n,r=item.r,t=item.t} end
        actual[#actual+1]={id=o.id,name=o.name,elite=o.elite,g=o.g,items=items}
    end
    Check(Same(actual,case.loot),'case '..i..' actual Rules.Open/Loot.FromTable preserves remnant identity and reward sequence')
    Check(draws==case.draws,'case '..i..' source RNG draw count unchanged through all generated remnants')
    if #rules.objects>0 then
        local o=rules.objects[1];local expected=case.loot[1].items
        local before=draws;rules:Open(o)
        Check(draws==before,'case '..i..' reopened remnant reuses search items without rerolling')
        local items={};for _,item in ipairs(rules.search.items) do items[#items+1]={id=item.id,n=item.n,r=item.r,t=item.t} end
        Check(Same(items,expected),'case '..i..' generated K identity selects original persisted items')
    end
    rules.cargo=case.initialCargo
    local picked={}
    for _,o in ipairs(rules.objects) do
        rules:Open(o)
        local search=rules.search
        for _=1,30 do
            if search.done then break end
            rules:SearchStep(10,{pos=o.g})
        end
        Check(search.done,'case '..i..' actual generated remnant search completes')
        local items={}
        for _,item in ipairs(search.items) do items[#items+1]={id=item.id,n=item.n,state=item.state,left=item.left} end
        picked[#picked+1]={id=o.id,value=search.value,items=items}
    end
    Check(Same(picked,case.picked),'case '..i..' actual SearchStep pickups and full-cargo leftovers match source _reveal')
    Check(Same(rules.cargo,case.cargo),'case '..i..' actual picked cargo matches source after all ordered remnants')
    Check(draws==case.draws,'case '..i..' revealing generated loot consumes no further RNG')
end
return checks
