package.path='scripts/?.lua;tools/migration/?.lua;'..package.path
local checks={};local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Copy(value) if type(value)~='table' then return value end;local out={};for k,v in pairs(value) do out[k]=Copy(v) end;return out end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-8 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
require('g5-offline-imports').Exclude(excluded)
package.loaded['core.ResourceData']={Read=ReadResource}
local Widget={};Widget.__index=Widget
function Widget:Extend(name)
    local c={name=name};c.__index=c
    return setmetatable(c,{__index=self,__call=function(t,p)local o=setmetatable({props=p or {},children={},state={}},t);for _,v in ipairs(o.props.children or {}) do o:AddChild(v) end;return o end})
end
function Widget:AddChild(v) self.children[#self.children+1]=v end
function Widget:ClearChildren() self.children={} end
function Widget:Destroy() end
function Widget:SetStyle(p) for k,v in pairs(p) do self.props[k]=v end end
local Panel=Widget:Extend('Panel')
package.loaded['urhox-libs/UI']={Panel=Panel,ScrollView=Panel}
package.loaded['ui.SalvageButton']=Panel;package.loaded['ui.SalvageItem']=Panel
package.loaded['ui.SalvagePaint']={Page=Panel,Surface=Panel,Text=Panel}
package.loaded['ui.SourceParagraph']={New=function() return {} end}
package.loaded['ui.InventorySearch']=Panel
package.loaded['ui.SalvageQuantity']={Create=function() return Panel{} end}
local function Number(n) return tostring(math.floor(n)):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','') end
package.loaded['ui.SourceDraw']={Number=Number}
local sounds={};package.loaded['audio.UiSound']={Play=function(s) sounds[#sounds+1]=s end}
package.loaded['storage.CloudStorage']={Queue=function() end}
FILE_READ=1;FILE_WRITE=2
local fs={};local failWrites=false;local writes=0
fileSystem={FileExists=function(_,path) return fs[path]~=nil end}
function File(path,mode)
    local value=mode==FILE_READ and fs[path] or mode==FILE_WRITE and not failWrites and '' or nil
    return {size=value and #value or 0,IsOpen=function() return value~=nil end,ReadString=function() return value end,
        WriteString=function(_,text) value=text end,Flush=function() fs[path]=value;writes=writes+1 end,Dispose=function() end}
end
local Store=require 'storage.BlueprintStore'
local Lobby=require 'app.SalvageLobby'
local Page=require 'ui.SalvagePage'
local function Find(node,predicate)
    if predicate(node) then return node end
    for _,child in ipairs(node.children) do local found=Find(child,predicate);if found then return found end end
end
local serial=0
local function Owner(config)
    serial=serial+1;local items={};for _,row in ipairs(config.items) do items[row[1]]=row[2] end
    local notes={};local app={lobby='salvage',blueprint={name='测试战车',List=function() return {} end,ToTable=function() return {parts={}} end},
        bays={active=1,Slots=function() return {} end},toasts={Push=function(_,text,kind) notes[#notes+1]={text,kind} end}}
    local lobby=setmetatable({app=app,data={v=1,credits=1234,items=items,op=1,stats={raids=3,extracted=2,lost=1}},store=Store.New('g5-natural-'..serial),
        Usage=function() return config.usage end},Lobby);app.salvageLobby=lobby
    return {app=app,width=1920,height=1080,Track=function(v) return v end,salvage={tab='market',market='sell',selected=false,shopCategory='all',gear={'repair'},qty=1}},notes
end
for _,g in ipairs(golden.sales) do
    local owner,notes=Owner(g.config);local lobby=owner.app.salvageLobby;sounds={};local before=writes
    local page=Page.Create(owner);local button=Find(page,function(w) return w.props.text=='卖掉全部货物' end)
    Check((button~=nil)==g.visible,'source dump visibility '..g.config.name)
    Check(lobby:CargoSale().gain==g.quote,'source dump quote '..g.config.name)
    if button then button.props.onClick() end
    Check(Same(lobby.data.items,g.items),'source dump remaining stock '..g.config.name)
    Check(lobby.data.credits==g.credits,'source dump credits '..g.config.name)
    Check(Same(notes,g.notes) and Same(sounds,g.sounds),'source dump sound and feedback '..g.config.name)
    Check(writes-before==(g.visible and 1 or 0),'dump uses one atomic save '..g.config.name)
    Check(owner.salvage.gear[1]==(lobby:Owned('repair')>0 and 'repair' or nil),'dump preserves carried gear '..g.config.name)
    if g.visible then
        local saved=lobby.store:Read('stash',Lobby.Valid)
        Check(saved.credits==g.credits and Same(saved.items,g.items),'dump actual store roundtrip '..g.config.name)
        local old=writes;Page.SellCargo(owner)
        Check(writes==old and #notes==#g.notes and #sounds==#g.sounds,'repeat dump cannot sell twice '..g.config.name)
    end
end
for _,sell in ipairs({false,true}) do
    local owner=Owner(golden.sales[1].config);owner.salvage.market=sell and 'sell' or 'buy';owner.salvage.selected='ration'
    local page=Page.Create(owner)
    Check(Find(page,function(w) return w.props.text=='卖掉全部货物' end)==nil,'selected item suppresses dump '..tostring(sell))
    local before=Copy(owner.app.salvageLobby.data);Page.SellCargo(owner)
    Check(Same(before,owner.app.salvageLobby.data),'stale dump callback rejects selected item '..tostring(sell))
end
local owner=Owner(golden.sales[1].config);owner.salvage.market='buy';local page=Page.Create(owner)
Check(Find(page,function(w) return w.props.text=='卖掉全部货物' end)==nil,'purchase page suppresses dump')
local before=Copy(owner.app.salvageLobby.data);Page.SellCargo(owner);Check(Same(before,owner.app.salvageLobby.data),'stale dump callback rejects purchase mode')
local owner,notes=Owner(golden.sales[1].config);local lobby=owner.app.salvageLobby;local previous=lobby.data;local original=Copy(previous);sounds={};failWrites=true
Page.SellCargo(owner);failWrites=false
Check(lobby.data==previous and Same(lobby.data,original),'dump file-open failure rolls back whole state')
Check(#sounds==0 and #notes==1 and notes[1][2]=='bad','failed dump shows error without success sound')
Check(lobby.store:Read('stash',Lobby.Valid)==nil,'failed dump writes no false durable stock')
lobby.Save=function() error('disk exception') end;local ok,err=lobby:SellCargo()
Check(not ok and err:find('disk exception',1,true) and lobby.data==previous,'dump thrown save rolls back whole state')
local owner=Owner(golden.sales[1].config);local lobby=owner.app.salvageLobby;lobby.Usage=nil
owner.app.blueprint.ToTable=function() return {parts={{'cube'},{'cube'}}} end
owner.app.bays.Slots=function() return {{parts={{'cube'}}},{parts={{'cube'},{'cube'},{'cube'}}}} end
Check(lobby:Usage()['part:cube']==5,'real garage usage includes current and other saved cars once')
Check(lobby:SellCargo() and lobby.data.items['part:cube']==10 and lobby.data.items.repair==7,'dump preserves actual installed parts and carried gear inventory')

local currentConfig={};local driverCalls=0
package.loaded['combat.CarUnit']={New=function(_,_,options)
    return {alive=not currentConfig.failUnit,name=options.name,spawnAt=options.spawn,hitAt=0,vehicle={Place=function() end},SavePose=function() end,Dispose=function() end,
        Position=function(self) return self.spawnAt.pos end}
end}
package.loaded['combat.EnemyDriver']={New=function() driverCalls=driverCalls+1;return {} end}
package.loaded['salvage.Director']=nil;local Director=require 'salvage.Director'
for _,g in ipairs(golden.encounters) do
    local c=g.config;currentConfig=c;local trace,surfaceCalls,cache={},{},{};local pos={c.distance or 200,0,0};local entries={{unit={alive=true}}}
    for i=1,c.alive+c.dead do entries[#entries+1]={unit={alive=i<=c.alive}} end
    local enc={id='case',name='测试遭遇',kind=c.kind,g={0,0,0},squad={'rat','dozer','rat'},left=c.emptyLeft and {} or {'rat','dozer','rat'},units={},state='dormant',
        triggerR=300,ring={20,50},posts={{10,20},{30,40}},route={{0,0,0},{10,0,10},{20,0,20},{30,0,30},{40,0,40}},reward=1}
    local run={entries=entries,player={Position=function() return pos end},world={units={}},session={},rules={heat=0,time=10,op={enemyHp=1},rand=function() return .5 end,
        AddExtra=function(_,o) cache[#cache+1]=o end},Center=function(_,u,at) u.vehicle:Place(at.pos,at.yaw);u:SavePose() end,Environment=function() return {} end,
        cine={Elite=function() trace[#trace+1]={'elite'} end,NameCard=function(_,...) trace[#trace+1]={'card',...} end,Flash=function(_,...) trace[#trace+1]={'flash',...} end},
        fx={Loot=function(_,...) trace[#trace+1]={'loot',...} end},Feed=function(_,...) trace[#trace+1]={'feed',...} end}
    local d=setmetatable({run=run,world=run.world,entries=entries,encounters={enc},timer=0,huntLeft=60},Director)
    d.Surface=function(_,x,z,nest) surfaceCalls[#surfaceCalls+1]={x,z,nest==true};if c.noSurface then return nil end;return {x,0,z} end
    for i,f in ipairs(g.frames) do
        d:Step(.25);local spawned={};local alive=0
        for n=2,#entries do if entries[n].unit.alive then alive=alive+1 end end
        for _,entry in ipairs(enc.units) do spawned[#spawned+1]={kind=entry.kind,pos=entry.unit.spawnAt.pos,yaw=entry.unit.spawnAt.yaw,wp=entry.wp} end
        local caches={};for _,o in ipairs(cache) do caches[#caches+1]={id=o.id,tier=o.tier,g=o.g,loot=o.loot} end
        local label='source encounter '..c.name..' frame '..i..' '
        Check(enc.state==f.state and Same(enc.left,f.left) and (enc.alerted==true)==f.alerted,label..'activation')
        Check(Same(spawned,f.spawned) and alive==f.alive,label..'partial alive budget')
        Check(Same(surfaceCalls,f.surfaceCalls),label..'surface and RNG traversal')
        Check(Same(trace,f.trace),label..'event order')
        Check(Same(caches,f.cache),label..'deferred clear reward')
    end
end

package.loaded['app.EndlessSession']=nil;package.loaded['app.TrialSession']=nil
local Endless=require 'app.EndlessSession';local Trial=require 'app.TrialSession'
for _,g in ipairs(golden.keys) do
    local code=g.code=='Enter' and KEY_RETURN or KEY_KP_ENTER;local calls=0
    input={focus=true,minimized=false,GetKeyPress=function(_,key) return not g['repeat'] and key==code end}
    local session=setmetatable({},Trial);session.endless=setmetatable({run={NextWave=function() calls=calls+1;return true end},session=session,Events=function() end},Endless)
    local resumed=0;session.Resume=function() resumed=resumed+1 end
    session:PollKeys(false)
    Check(calls==g.next and resumed==g.next,'real PollKeys to Endless.NextWave '..g.code..' repeat '..tostring(g['repeat']))
end
for _,block in ipairs({'typing','unfocused','minimized','dialog'}) do
    local calls=0;input={focus=block~='unfocused',minimized=block=='minimized',GetKeyPress=function(_,key) return key==KEY_KP_ENTER end}
    local session=setmetatable({dialog=block=='dialog' and {} or nil},Trial)
    session.endless=setmetatable({NextWave=function() calls=calls+1 end},Endless);session:PollKeys(block=='typing')
    Check(calls==0,'keypad Enter respects real polling gate '..block)
end
return checks
