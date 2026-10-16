package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local now=1000;Time={GetSystemTime=function() return now end}
local config=goldens.config
package.loaded['endless.Data']={config=config}
package.loaded['Config']={TIERS=goldens.tiers}
for _,name in ipairs({'endless.Run','combat.CarUnit','combat.EnemyDriver','combat.DrillRaiderDriver','combat.ShieldQuery','core.Math3','construction.Blueprint'}) do package.loaded[name]={} end
local Session=require 'app.EndlessSession'
local Banner=require 'ui.EndlessBanner'
for _,row in ipairs(goldens.batches) do
    config.tierLimits=row.tierLimits
    local seen={};local paused=0;local supplies=0;local saved=0;local consumed=0
    local session={Pause=function() paused=paused+1 end,app={toasts={Push=function() end}},camera={GetNode=function() return {} end}}
    local run={state='rest',Drain=function() return row.events end}
    local e=setmetatable({session=session,run=run,view={Event=function() consumed=consumed+1 end},
        audio={Event=function() end,Play=function(_,cue) if cue=='supply_open' then supplies=supplies+1 end end},
        Persist=function() saved=saved+1 end},Session)
    local push=e.Banner;e.Banner=function(self,text) seen[#seen+1]=text;push(self,text) end
    e:Events()
    Check(#seen==#row.notices,'source event count '..row.name)
    for i,text in ipairs(row.notices) do Check(seen[i]==text,'source exact announcement '..row.name..'/'..i) end
    local clears,saves=0,0;for _,event in ipairs(row.events) do if event.type=='waveClear' then clears=clears+1 elseif event.type=='save' then saves=saves+1 end end
    Check(paused==clears and supplies==clears,'wave clear retains source pointer release equivalent and supply audio '..row.name)
    Check(saved==saves and consumed==#row.events,'all events retain persistence and view routing '..row.name)
end
local owner={};local run={time=0}
for i,row in ipairs(goldens.clock) do
    now=row.now
    if row.kind=='announce' then Banner.Push(owner,row.text,row.ms)
    else run.state=row.state;run.respawnAt=row.respawn>0 and row.respawn or nil;Banner.Update(owner,run) end
    Check((owner.banner and owner.banner.text or '')==row.expected,'source wall clock/respawn '..i)
end
config.tierLimits=false
local queued={{type='tierUp',tier=2}};local e=setmetatable({session={},run={state='rest',Drain=function() local out=queued;queued={};return out end},
    view={Event=function() end},audio={Event=function() end}},Session)
e:Events();Check(e.banner.text=='敌人升到 T2','separate tier event announces immediately')
e.session.Pause=function() end;e.audio.Play=function() end;queued={{type='waveClear',wave=6}};e:Events()
Check(e.banner.text=='第 6 波完成','tier announcement is local to one drain, never leaks into later clear')

-- Actual Run.CheckClear produces tierUp -> shieldRaise -> waveClear -> save.
package.loaded['endless.Run']=nil
package.loaded['endless.Inventory']={Supplies=function() return {{name='source supply'}} end}
package.loaded['endless.Random']={}
local Run=require 'endless.Run'
for _,wave in ipairs({1,5,10,15,20,25}) do
    local before=math.min(5,1+math.floor((wave-1)/5));local r=setmetatable({state='combat',wave=wave,tier=before,queue={},alive={},
        pendingDrops={},dropOrder={},score=0,weaponDrought=0,shield={},inventory={},blueprint={},random=function() return .5 end,events={}},Run)
    r:CheckClear();local types={};for _,event in ipairs(r.events) do types[#types+1]=event.type end
    local expected=wave%5==0 and wave<=20 and 'tierUp,shieldRaise,waveClear,save' or 'shieldRaise,waveClear,save'
    Check(table.concat(types,',')==expected,'actual clear event ordering wave '..wave)
end

-- Exercise the real mounted HUD update, including its early return on stable state.
local function Widget(props)
    local w={props=props or {},children={}}
    function w:AddChild(child) self.children[#self.children+1]=child end
    function w:SetVisible(on) self.visible=on end
    return w
end
local Panel=setmetatable({},{__call=function(_,p) return Widget(p) end})
function Panel:Extend() return Panel end
package.loaded['urhox-libs/UI']={Panel=Panel,GetViewportSize=function() return 1920,1080 end}
package.loaded['ui.SourceDraw']={};package.loaded['ui.EndlessWidgets']={Button=Widget}
local Hud=require 'ui.EndlessHud';local hroot=Widget();local r={state='combat',wave=1,supplies={},time=0}
local endless={run=r};local s={endless=endless};local state=Hud.Attach(s,hroot)
now=20000;Banner.Push(endless,'第 5 波完成 · 敌人升到 T2');state.Update(0)
now=23500;state.Update(0);Check(endless.banner~=nil,'mounted HUD preserves exact source expiration boundary')
now=23501;state.Update(0);Check(endless.banner==nil,'mounted HUD expires banner without physics advancement or state change')
r.respawnAt=4.01;state.Update(0);Check(endless.banner.text=='战车被摧毁 · 5 秒后复原','mounted HUD shows source rounded respawn override')
r.respawnAt=0;state.Update(0);Check(endless.banner.text~='战车被摧毁 · 0 秒后复原','zero respawn does not create false death banner')
return checks
