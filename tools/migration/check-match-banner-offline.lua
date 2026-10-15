package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local assertions=0
local function Check(ok,message) assertions=assertions+1;assert(ok,message) end
local function Equal(a,b,path)
    path=path or ''
    Check(type(a)==type(b),path..' type '..type(a)..' / '..type(b))
    if type(a)=='table' then
        for k,v in pairs(a) do Equal(v,b[k],path..'.'..tostring(k)) end
        for k in pairs(b) do Check(a[k]~=nil,path..' missing '..tostring(k)) end
    else Check(a==b,path..' '..tostring(a)..' / '..tostring(b)) end
end
local now=100
Time={}
function Time:GetSystemTime() assert(self==Time,'Time.GetSystemTime is a static singleton API');return now*1000 end
function GetTime() return {GetSystemTime=function() error('Use Time:GetSystemTime(), not instance Time.GetSystemTime') end} end
local Banner=require 'ui.MatchBanner'
for i,c in ipairs(MATCH_BANNER_SOURCE_CASES) do
    local r=c.rules;r.c={bonus=60};r.Final=function(self)return self.final end;r.Owned=function(_,team)return team=='blue' and 2 or 1 end
    local item=Banner.ForEvent({mode=c.mode,rules=r},c.event,c.world)
    if item then item.mini=item.mini==true end
    Equal(item,c.expected,'source event '..i..' '..c.mode..' '..c.event.type)
end
local owner={}
Check(Banner.Push(owner,'出击！','ENGAGE','消灭全部敌人','go',1800),'first banner')
Equal(owner.banner.duration,1.8,'source engage duration')
Check(not Banner.Push(owner,'出击！','IGNORED'),'same current title ignored')
for i=1,3 do Check(Banner.Push(owner,'next '..i,'QUEUED'),'three queued notices') end
Check(not Banner.Push(owner,'fourth','DROPPED'),'queue bounded at three')
Equal(#owner.bannerQueue,3,'queue capacity')
Banner.Update(owner,101.799);Equal(owner.banner.text,'出击！','before hold deadline')
local state=Banner.State(owner.banner,1080)
Equal(state.y,259.2,'normal top24%');Equal(state.height,150,'normal height')
Equal(state.color,{255,211,106,255},'go gold');Equal(state.size,76,'normal font')
Check(state.bandAlpha>.9999,'holding band opaque')
Banner.Update(owner,101.95);state=Banner.State(owner.banner,1080)
Check(state.bandAlpha>0 and state.bandAlpha<1,'outgoing band fades')
Check(state.bandScale>.7 and state.bandScale<1,'outgoing band shrinks')
Banner.Update(owner,102.1);Equal(owner.banner.text,'next 1','next source queue after300ms exit')
Equal(#owner.bannerQueue,2,'queue order maintained')
now=102.1;Banner.Clear(owner);Check(owner.banner==nil and #owner.bannerQueue==0,'restart clears previous notifications')
Banner.Push(owner,'点击画面继续','PAUSED','要退出请点右上角「退出对局」','prep',1500,true)
Banner.Update(owner,102.9);state=Banner.State(owner.banner,1080)
Equal(state.y,172.8,'mini top16%');Equal(state.height,96,'mini height');Equal(state.size,44,'mini title44px')
Equal(state.tagSize,11,'mini tag11px');Equal(state.tagSpacing,6,'mini tag6px tracking');Equal(state.spacing,8,'mini final tracking')
Equal(state.color,{255,255,255,255},'paused white lines')
Banner.Update(owner,104);Check(owner.banner==nil,'pause never remains after1.8s real clock')
for _,touch in ipairs({false,true}) do
    for _,size in ipairs({{1920,1080},{2400,1080},{840,378},{1605,388}}) do
        local ref=touch and 600 or 1080;local k=Banner.Scale(size[1],size[2],touch)
        Equal(k,math.min(size[1]/(ref*16/9),size[2]/ref)*(touch and .8 or 1),'frozen surface scale')
        Check(size[1]/k>=ref*16/9 and size[2]/k>=ref,'reference surface expands')
    end
end
local draw={}
local function Record(kind,...) draw[#draw+1]={kind=kind,args={...}} end
for _,name in ipairs({'nvgSave','nvgRestore','nvgTranslate','nvgScale','nvgGlobalAlpha','nvgFontBlur'}) do _G[name]=function(...)Record(name,...)end end
NVG_ALIGN_CENTER=2
local D={white={237,246,255,255},orange={122,216,255,255},muted={145,172,200,255}}
for _,name in ipairs({'Path','Gradient','Rect','Text'}) do D[name]=function(...)Record(name,...)end end
D.Begin=function()end
D.FontMetrics=function(_,size)return size*.8,size*.2 end
D.Width=function(_,text,size,_,spacing)return utf8.len(tostring(text))*size*.6+utf8.len(tostring(text))*(spacing or 0)end
package.loaded['ui.SourceDraw']=D
package.loaded['ui.WorkshopPaint']={Glow=function(...)Record('Glow',...)end}
Banner.Draw('vg',nil,1920,1080);Equal(#draw,0,'ordinary battle draws no banner mask')
now=200;Banner.Push(owner,'出击！','ENGAGE','消灭全部敌人','go',1800);Banner.Update(owner,201)
Banner.Draw('vg',owner.banner,1920,1080)
local text,gradient,glow={},{},{}
for _,row in ipairs(draw) do
    if row.kind=='Text' then text[#text+1]=row.args
    elseif row.kind=='Gradient' then gradient[#gradient+1]=row.args
    elseif row.kind=='Glow' then glow[#glow+1]=row.args end
end
Equal(#text,3,'three source text rows');Equal(text[1][2],'ENGAGE','source tag');Equal(text[2][2],'出击！','source title');Equal(text[3][2],'消灭全部敌人','source subtitle')
Equal(text[1][7],'vox-body','source tag Industrial');Equal(text[2][7],'vox-title','source title Industrial normal');Equal(text[3][7],'vox-body','source subtitle Industrial')
Equal(#gradient,8,'four background stops and two gradient edges')
for i=1,4 do Equal(gradient[i][5],150,'only150px tall backdrop');Equal(gradient[i][2],1920*({0,.22,.5,.78})[i],'full-width gradient span') end
Equal(gradient[1][6][4],0,'left end transparent');Equal(gradient[4][7][4],0,'right end transparent')
Equal(#glow,2,'two source line shadows')
for _,args in ipairs(glow) do Equal(args[2],192,'line left10%');Equal(args[4],1536,'line width80%');Equal(args[5],2,'source line2px');Equal(args[6],14,'source line blur14') end
local function Widget(props)
    local w={props=props or {},children={},node=true}
    function w:AddChild(c)self.children[#self.children+1]=c end
    function w:RemoveChild(c)for i,v in ipairs(self.children)do if v==c then table.remove(self.children,i);return end end end
    function w:SetVisible(on)self.visible=on end
    function w:SetStyle(p)for k,v in pairs(p)do self.props[k]=v end end
    function w:Destroy()self.destroyed=true end
    function w:GetAbsoluteLayout()return {x=0,y=0,w=1920,h=1080}end
    for _,name in ipairs({'Refresh','SetText','Clear'})do w[name]=function()end end
    return w
end
local function Factory()return setmetatable({},{__call=function(_,p)return Widget(p)end})end
local UI={Panel=Widget,GetViewportSize=function()return 1920,1080 end,SetRoot=function(r)UI_ROOT=r end,GetRoot=function()return UI_ROOT end}
UI.Widget={Extend=function()return Factory()end}
package.loaded['urhox-libs/UI']=UI
input={GetKeyDown=function()return false end};KEY_TAB=9
local clicks=0;local s={pointer={captured=false},Resume=function()clicks=clicks+1 end,controls={Clear=function()end}}
local root=Widget();local Controls=require 'ui.DriveControls';local pc=Controls.Create(s,root)
for _,button in ipairs({'left','middle','right'}) do pc.playfield.props.onPointerDown({IsTouch=function()return false end,IsPrimaryButton=function()error('must not restrict source PC click '..button)end}) end
Equal(clicks,3,'every PC pointerdown resumes')
s.pointer.captured=true;pc.playfield.props.onPointerDown({IsTouch=function()return false end});Equal(clicks,3,'captured pointer not recaptured')
s.pointer.captured=false;pc.playfield.props.onPointerDown({IsTouch=function()return true end});Equal(clicks,3,'touch not routed through PC resume')
local function Noop()end
for _,name in ipairs({'combat.ArenaData','construction.Blueprint','combat.CarUnit','combat.EnemyDriver'})do package.loaded[name]={}end
local Battle=require 'combat.BattleController'
for i,c in ipairs(MATCH_BANNER_SOURCE_CASES)do
    if c.event.type=='roundPrep' then c.event.round=c.event.round or 1 end
    local rules=c.rules;rules.Step=Noop;rules.Drain=function()return {c.event}end;rules.t=0;rules.state='live'
    local battle=setmetatable({mode=c.mode,rules=rules,clock=0,events={},entries={},
        sounds={Countdown=Noop,Event=Noop},voice={Event=Noop},objectives={Event=Noop,Update=Noop},world={debris={Clear=Noop}},
        WorldState=function()return c.world end},Battle)
    battle:AfterStep(1/60)
    local actual=battle.banner and {text=battle.banner.text,sub=battle.banner.sub,tag=battle.banner.tag,cls=battle.banner.cls,ms=battle.banner.duration*1000,mini=battle.banner.mini} or nil
    Equal(actual,c.expected,'actual BattleController.AfterStep '..i)
end
local ending=setmetatable({mode='elimination',clock=0,events={},entries={},result={},
    sounds={Countdown=Noop,Event=Noop},voice={Event=Noop},objectives={Event=Noop,Update=Noop},
    session={Pause=Noop},WorldState=function()return {}end,
    rules={state='over',t=0,cfg={prep=5},Step=Noop,Drain=function()return {{type='matchOver'}}end}},Battle)
ending:Banner('pending','ROUND');ending:Banner('next','NEXT');ending:AfterStep(1/60)
Check(ending.banner==nil and #ending.bannerQueue==0,'actual matchOver clears queue')
package.loaded['ui.SourceButton']=Factory();package.loaded['ui.MatchResultButton']=Factory()
package.loaded['ui.MatchScoreboard']={Update=Noop}
package.loaded['ui.MatchObjectives']={Update=Noop}
package.loaded['ui.MatchMinimap']={New=function()return {Update=Noop,Dispose=Noop}end}
local ActualMatchHud=require 'ui.MatchHud'
local match={banner=nil,rules={state='live'}}
local attached=ActualMatchHud.Attach({battle=match},Widget())
now=300;Banner.Push(match,'点击画面继续','PAUSED','要退出请点右上角「退出对局」','prep',1500,true)
now=302;attached.Update(0);Check(match.banner==nil,'MatchHud actual Update expires by wallclock even dt0')
package.loaded['controls.TouchMode']={Apply=Noop}
package.loaded['ui.VoxTheme']={TrimThumbnails=Noop}
for _,name in ipairs({'DriveChrome','DriveMeter','DriveDetails','MechReticle','MissileHud','MvpShow'})do package.loaded['ui.'..name]=Factory()end
package.loaded['ui.DriveOverlay']={New=function()return {layer=Widget(),Update=Noop,aimState='ok'}end}
for _,name in ipairs({'ResetProgress','SniperThreat','MatchHud','EndlessHud'})do package.loaded['ui.'..name]={Attach=function()return {Update=Noop,Dispose=Noop}end}end
package.loaded['ui.GameSettings']={Attach=function()return Widget()end}
package.loaded['ui.DriveReadouts']={New=function()return {SetVisible=Noop,Tick=Noop,Refresh=Noop}end}
package.loaded['ui.ReticleState']={Update=Noop}
local group={kind='mg',weapons={{stats={}}}}
local weapons={groups={group},blocked=0,Group=function()return group end,Readiness=function()return 1 end}
local Hud=require 'ui.DriveHud'
for _,kind in ipairs({'battle','endless','practice'}) do
    for _,captured in ipairs({false,true}) do
        local session={map={id='crater'},vehicle={legMode=false},weapons=weapons,world={},pointer={captured=captured,Suppress=Noop},controls={Clear=Noop},
            combat={player={alive=true}},HasFocus=function()return true end,Resume=Noop}
        if kind=='battle' then session.battle={rules={state='live'}}
        elseif kind=='endless' then session.endless={rules={},run={state='live'}}end
        local hud=Hud.Create(session)
        Equal(hud.pause.visible,kind=='practice' and not captured,'real DriveHud pause '..kind..' '..tostring(captured))
        hud.Dispose()
    end
end
return {assertions=assertions}
