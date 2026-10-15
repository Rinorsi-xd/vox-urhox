local function Near(a,b) return math.abs(a-b)<2e-5 end
local function Check(actual,expected,label)
    V.assert(#actual==#expected,label..' exact source emission count')
    for i,want in ipairs(expected) do local got=actual[i]
        V.assert(got and Near(got.size,want.size) and got.big==want.big,label..' size and big flag '..i)
        if got then for axis=1,3 do V.assert(Near(got.pos[axis],want.pos[axis]),label..' original position '..i..'/'..axis) end end
    end
end
local function MissionRadio()
    local calls={};local events={};local Rules=require 'story.MissionRules'
    local rules=Rules.New({spawn={pos={0,0,0}},steps={},id='s1'});rules.stats.sites=0
    local Mission=require 'story.Mission';local mission=setmetatable({rules=rules,level={id='s1',no='01',name='坠舰',steps={{kind='install'},{kind='install'},{kind='install'}}},
        radio={Play=function(_,name)calls[#calls+1]=name end},voice={Say=function()end},
        session={Pause=function()end,app={store={Read=function()return {}end,Write=function()return true end}}},
        world={CastRay=function()return nil end},player={Spawn=function()end,vehicle={}},Place=function()end,ClearEnemies=function()end,Spawn=function()end,
        view={TakeIntel=function()end,Collector=function()end,Scrub=function()end,HideBeacon=function()end,Objective=function()end}},Mission)
    local function Cue(event,want)
        rules.events={event};local n=#calls;mission:Events();V.assert(#calls==n+1 and calls[#calls]==want,'real Mission original radio '..event.type)
    end
    Cue({type='intel',id='a'},'pickup')
    Cue({type='collector',step={pos={0,0,0}},pos={20,0,0},yaw=0},'install')
    Cue({type='scrub',id='A'},'pickup');Cue({type='choice'},'open');Cue({type='radio',cue='alert'},'alert')
    Cue({type='fight',step={}},'alert');Cue({type='respawn',at={}},'drop');Cue({type='complete'},'done')
    Cue({type='result',grade='S',time=1},'done')
    local bannerFile=assert(io.open('tools/migration/source-story-banner-fixtures.json'));local bannerFixtures=cjson.decode(bannerFile:read('*a'));bannerFile:close()
    mission.level.en='CRASH SITE';mission.level.name='坠舰陨坑';mission.rules.time=12
    local bannerCount=0
    for _,fixture in ipairs(bannerFixtures.cases) do
        local args=fixture.args;local event=nil
        if args[1]=='剧情模式 · 任务 01' then event={type='begin'}
        elseif args[1]=='采集器上线' then mission.rules.stats.collectors=fixture.collectors;event={type='collector',step={pos={0,0,0}},pos={20,0,0},yaw=0}
        elseif args[1]=='遭遇敌人' then event={type='fight',step={enemies={{},{},{}}}}
        elseif args[1]=='任务 01 · 坠舰陨坑' then event={type='complete'} end
        if event then
            rules.events={event};mission:Events();local b=mission.banner;bannerCount=bannerCount+1
            V.assert(b.kick==args[1] and b.title==args[2] and b.sub==args[3] and b.kind==args[4] and Near(b.untilAt-b.at,args[5]/1000),'actual Mission banner matches frozen source call '..bannerCount)
        end
    end
    V.assert(bannerCount==6,'begin three collectors fight and completion preserve all original banner fields')
    local Banner=require 'ui.MissionBanner'
    for i,frame in ipairs(bannerFixtures.frames) do local state=Banner.State({at=0,untilAt=2.4,kind='install'},frame.age)
        V.assert(Near(state.alpha,frame.alpha) and Near(state.slam,frame.slam) and Near(state.wipe,frame.wipe),'source CSS opacity slam and strip-wipe timing '..i)
    end
    local function HasCue(r,want) local found=false;for _,e in ipairs(r:Drain())do if e.type=='radio' and e.cue==want then found=true end end;return found end
    rules:Ask({id='x',options={{reply={}}}});rules:Choose(1);V.assert(HasCue(rules,'pickup'),'choice confirms original pickup cue')
    rules:Fail('failed',{});V.assert(HasCue(rules,'alert'),'failure sends original alert cue')
    local function Beat(alert)
        local r=Rules.New({steps={{beats={{t=0,spawn={},alert=alert}}}}});r:Go(1);r:Drain();r:Beats(.1,{talking=false});return HasCue(r,'alert')
    end
    V.assert(Beat(nil) and not Beat(false),'original beat spawn alert false is preserved')
    local capture=require('story.CaptureRules').New();local r=Rules.New({steps={{kind='capture',pos={0,0,0},trigger=20,r=10,guards={},counter={},site='A',capSec=1}}});r:Go(1);r:Drain()
    capture:Update(r,1,{alive=true,pos={0,0,0},enemyPositions={}})
    local alert,install=0,0;for _,e in ipairs(r:Drain())do if e.type=='radio' then if e.cue=='alert' then alert=alert+1 elseif e.cue=='install' then install=install+1 end end end
    V.assert(alert==2 and install==1,'capture guard counter and restored site preserve original cues')
    local convoy=require('story.ConvoyRules').New({path={{0,0,0},{0,10,0}},speed=10,checkpoints={.1},cpLines={{}}},{nodes={}},function()return 0 end)
    local r=Rules.New({steps={}});convoy:Update(r,1,{alive=true,pos={0,0,0},enemyPositions={}})
    V.assert(HasCue(r,'install'),'convoy checkpoint preserves original install cue')
end
V.atFrame(43,function()
    MissionRadio()
    local file=assert(io.open('tools/migration/source-story-explosion-fixtures.json'));local fixtures=cjson.decode(file:read('*a'));file:close()
    local Boss=require 'combat.StoryBoss';local Mission=require 'story.Mission'
    for index,c in ipairs(fixtures.cases) do
        local blasts={};local session={trauma=.1};local seed=c.seed;local random=math.random
        math.random=function() seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end
        local boss=setmetatable({session=session,time=12,unit={},step={title='source'},radio={Play=function()end},
            rules={Drain=function()return {{type=c.kind,pos=c.pos,yaw=c.yaw}}end},
            world={layout={enginePit={points={floorCentre=c.center}}}},
            mission={rules={},explosion={Explode=function(_,pos,size,big)blasts[#blasts+1]={pos=pos,size=size,big=big==true}end}},
            Team=function()return {}end,Ground=function(_,x,z)return x*.01+z*.03 end,Capture=function()end,Say=function()end},Boss)
        local ok,err=pcall(Boss.Events,boss);math.random=random;assert(ok,err)
        Check(blasts,c.blasts,'frozen Boss '..c.kind..' '..index)
        V.assert(Near(session.trauma,c.trauma),'source Boss camera impulse '..c.kind..' '..index)
    end
    for index,c in ipairs(fixtures.deaths) do
        local blasts={};local player={pos={0,2,0},alive=false,Position=function(self)return self.pos end}
        local unit={pos={c.distance,2,0},alive=false,spec={bounds={radius=c.radius}},Position=function(self)return self.pos end,Dispose=function()end}
        local entry={unit=unit};for key,value in pairs(c.entry) do entry[key]=value end;entry.scripted=entry.scripted or entry.noBlast
        local mission=setmetatable({player=player,entries={{unit=player},entry},enemyPositions={},world={units={player,unit},layout={nav={}}},
            session={trauma=.1,pointer={captured=false},camera={GetCamera=function()return nil end}},
            voice={Talking=function()return false end},rules={Killed=function()end,Step=function()end},view={Update=function()end},Events=function()end,
            explosion={Explode=function(_,pos,size,big)blasts[#blasts+1]={pos=pos,size=size,big=big==true}end}},Mission)
        Mission.AfterStep(mission,1/60);Check(blasts,c.blasts,'frozen story death '..index)
        V.assert(Near(mission.session.trauma,c.trauma),'source distance-weighted death impulse '..index)
    end
    local ticks=0;local mission=setmetatable({rules={finished=false},player={Position=function()return {0,0,0}end},
        session={camera={GetNode=function()return nil end},HasFocus=function()return true end},
        explosion={Update=function()ticks=ticks+1 end},voice={Update=function()end},radio={Update=function()end}},Mission)
    mission:Update(1/60);V.assert(ticks==1,'active story updates original effect clock')
    mission.rules.finished=true;mission:Update(1/60);V.assert(ticks==1,'source finished pausedUpdate leaves effect clock frozen')
    mission.epilogue={Update=function()end};mission:Update(1/60);V.assert(ticks==1,'epilogue preserves frozen battle effects')
end)
local work=nil ---@type thread|nil
local scene=nil ---@type Scene|nil
local fx=nil ---@type table|nil
local cancelled=nil ---@type table|nil
V.atFrame(96,function()
    local app=VOX_HANGAR.app;app.loadingFlow:Close();app.Update=function()end;app.PostUpdate=function()end
    if app.tutorial then app.tutorial:Dispose();app.tutorial=nil end
    local UI=require 'urhox-libs/UI';local Panel=UI.Panel:Extend('BannerRenderQA')
    function Panel:Render(vg)
        local D=require 'ui.SourceDraw';D.Begin(vg);local box=self:GetAbsoluteLayout()
        D.Rect(vg,box.x,box.y,box.w,box.h,{10,14,20,255})
        require('ui.MissionBanner').Draw(vg,{kick='采集器上线',title='采集器 ②',sub='2 / 3 台已安装',kind='install',at=0,untilAt=2.4},1,'01',box.w,box.h)
    end
    UI.SetRoot(Panel{width='100%',height='100%'},true)
end)
V.atFrame(99,function()
    local image=Image:new();graphics:TakeScreenShot(image);local orange=0
    for y=math.floor(image.height*.11),math.floor(image.height*.4),3 do for x=math.floor(image.width*.25),math.floor(image.width*.75),3 do
        local c=image:GetPixel(x,y);if c.r>.45 and c.g>.1 and c.g<.65 and c.b<.25 then orange=orange+1 end
    end end
    V.assert(orange>30,'actual source three-row installation banner renders orange kick strip and badge')
    image:SavePNG('docs/migration/evidence/story-banner-native.png');image:Dispose();V.finish()
end)
V.atFrame(44,function()
    work=coroutine.create(function()
        scene=Scene:new();scene:CreateComponent('Octree');local yields=0
        fx=require('render.SalvageExplosion').New(scene,nil,{retain=function(value)fx=value end,checkpoint=function()yields=yields+1;coroutine.yield()end})
        V.assert(yields==34,'all 1086 fixed native pool nodes create through 34 bounded checkpoints')
        V.assert(#fx.pools.fire==240 and #fx.pools.core==40 and #fx.pools.smoke==200 and #fx.pools.embers==600,'source pool capacities preserved during sliced creation')
        fx:Explode({0,2,0},4,true);local camera=scene:CreateChild('ExplosionCamera');camera.position=Vector3(0,5,-20)
        fx:Update(1/60,camera,{0,2,0});local alive=0
        for _,pool in pairs(fx.pools) do for _,p in ipairs(pool) do if p.model.enabledEffective then alive=alive+1 end end end
        V.assert(alive>10,'actual GPU pooled models become visible after source big explosion')
        fx:Dispose();fx:Dispose();V.assert(fx.disposed and next(fx.pools)==nil,'completed real effect releases idempotently')
        local job=coroutine.create(function()require('render.SalvageExplosion').New(scene,nil,{retain=function(value)cancelled=value end,checkpoint=function()coroutine.yield()end})end)
        local ok,err=coroutine.resume(job);assert(ok,err)
        V.assert(cancelled~=nil and #cancelled.pools.fire==32,'partial native pool ownership is retained before first yield')
        coroutine.close(job);cancelled:Dispose();cancelled:Dispose()
        V.assert(cancelled.disposed and scene:GetChild('SalvageExplosions')==nil,'cancelled partial construction leaves no native effect root')
        scene:Dispose()
    end)
end)
for frame=45,95 do V.atFrame(frame,function()if work and coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);if not ok then error(err) end end end) end
