package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local assertions=0
local function Check(ok,msg) assertions=assertions+1;assert(ok,msg) end
local function Near(a,b,msg) Check(math.abs(a-b)<1e-8,msg..' '..tostring(a)..' / '..tostring(b)) end
local now=100
Time={GetSystemTime=function(self)assert(self==Time);return now*1000 end}
local commands={}
local function Record(name,...)commands[#commands+1]={name,...}end
local D={white={255,255,255,255},Color=function(c)return c end,Begin=function()end,HudFont=function()end}
for _,name in ipairs({'Path','Text','Rect','Gradient','Line'})do D[name]=function(...)Record(name,...)end end
D.Width=function(_,t,size,_,spacing)return utf8.len(t)*(size*.6+(spacing or 0))end
package.loaded['ui.SourceDraw']=D
package.loaded['core.Coord']={Vec=function(x,y,z)return {x=-x,y=y,z=z}end}
package.loaded['combat.ArenaData']={}
local Objective=require 'ui.MatchObjectives'
for i,c in ipairs(MATCH_OBJECTIVE_CASES)do
    local player=c.player;player.Position=function()return player.pos end
    local camera={node={WorldToLocal=function(_,p)return {z=c.behind and -1 or 1}end},WorldToScreenPoint=function(_,p)return {x=(-p.x/100*.5+.5),y=(-p.y/100*.5+.5)}end}
    local s={camera={GetCamera=function()return camera end},battle={mode='conquest',rules={state='live',points=c.states},objectives={points=c.points},player=player}}
    local marks,cap=Objective.Data(s,c.w,c.h)
    Check(#marks==#c.expected.marks,'source mark count '..i)
    for j,m in ipairs(marks)do local e=c.expected.marks[j]
        for _,key in ipairs({'x','y','dist','v'})do Near(m[key],e[key],'source objective '..i..' '..key)end
        for _,key in ipairs({'id','off','owner','contested'})do Check(m[key]==e[key],'source marker field '..key)end
    end
    Check((cap and cap.id)==(c.expected.cap and c.expected.cap.id),'source inside replaces mark '..i)
end
for _,c in ipairs({{v=.2,count={blue=1,red=0},want='正在占领'},{v=-.2,count={blue=1,red=0},want='正在清除敌方节点'},{v=1,owner='blue',count={blue=1,red=0},want='已占领 · 守住它'},{v=1,owner='blue',count={blue=1,red=1},want='正在被抢'},{v=0,contested=true,count={blue=1,red=1},want='争夺中 · 进度暂停'}})do Check(Objective.CapText(c)==c.want,'capture text '..c.want)end
NVG_CW=1;NVG_ROUND=1;NVG_HOLE=2;NVG_DESTINATION_OUT=8;NVG_COPY=9;NVG_COLOR_GAMMA=1;NVG_ALIGN_CENTER=2;FILTER_BILINEAR=1;TEXTURE_RENDERTARGET=1
NVG_DESTINATION_IN=10
for _,name in ipairs({'nvgSave','nvgRestore','nvgTranslate','nvgScale','nvgRotate','nvgBeginPath','nvgMoveTo','nvgLineTo','nvgClosePath','nvgCircle','nvgRect','nvgEllipse','nvgArc','nvgFillColor','nvgFill','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgLineCap','nvgLineJoin','nvgPathWinding','nvgGlobalAlpha','nvgFillPaint','nvgGlobalCompositeOperation','nvgBeginFrame','nvgEndFrame','nvgSetRenderTarget','nvgSetColorSpace','nvgIntersectScissor'})do _G[name]=function(...)Record(name,...)end end
nvgRGBA=function(...)return {...}end;nvgRadialGradient=function(...)return {...}end;nvgImagePattern=function(...)return {...}end
local Minimap=require 'ui.MatchMinimap'
local units={{team='blue',alive=true,pos={0,0,0},me=true},{team='red',alive=true,pos={119.99,0,0}},{team='red',alive=true,pos={120,0,0}},{team='red',alive=true,pos={120.01,0,0}},{team='blue',alive=true,pos={300,0,0}},{team='red',alive=true,pos={310,0,0}},{team='red',alive=false,pos={0,0,0}}}
for i,u in ipairs(units)do Check(Minimap.Visible(u,units)==({false,true,false,false,true,true,false})[i],'minimap ally120m visibility '..i)end
for _,square in ipairs({false,true})do for x=-600,1000,23 do for y=-600,1000,37 do
    local ax,ay,out=Minimap.Clamp(x,y,20,square);local dx,dy=x-236,y-236;local l=192
    local len=square and math.max(math.abs(dx),math.abs(dy)) or math.sqrt(dx*dx+dy*dy)
    Near(ax,len<=l and x or 236+dx/len*l,'clamp x');Near(ay,len<=l and y or 236+dy/len*l,'clamp y');Check(out==(len>l),'clamp out')
end end end
local x,y=Minimap.Project({170,0,170},{0,0,0});Near(x,24,'world+x left');Near(y,24,'world+z north')
local callbacks={};local retired=0;local videos=0;local deletes=0
function SubscribeToEvent(sender,event,callback)callbacks[sender]=callback end
function UnsubscribeFromEvent(sender,event)callbacks[sender]=nil end
function nvgCreate()return {}end
function nvgCreateFont()return 1 end
function nvgDelete()end
function nvgCreateImage()return 44 end
function nvgDeleteImage()end
function nvgCreateVideo()videos=videos+1;return videos end
function nvgDeleteVideo()deletes=deletes+1 end
Graphics={GetRGBAFormat=function()return 1 end}
Texture2D={new=function()
    return {SetNumLevels=function()end,SetSRGB=function()end,SetSize=function(_,w,h)Check(w==472 and h==472,'fixed canvas472');return true end,SetFilterMode=function()end}
end}
package.loaded['render.RenderTargetLifetime']={Retire=function()retired=retired+1 end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return false end}
local me={team='blue',alive=true,Position=function()return {0,0,0}end,vehicle={Yaw=function()return .5 end}}
local s={app={store={Read=function(_,_,validator)Check(validator({style='square'}),'typed minimap preference');return {style='square'}end}},yaw=90,battle={entries={{unit=me}},player=me,mode='escort',rules={s=3},objectives={path={{0,0,0},{10,0,0},{20,0,0}},At=function()return {pos={10,0,0}}end}}}
local mm=Minimap.New(s);mm:Update(100);Check(mm.requested,'new canvas queued');Near(mm.view,-math.pi/2,'view source yaw radians')
callbacks[mm.vg]();Check(mm.frames==1 and not mm.requested,'source33ms canvas render')
local vg=mm.vg;mm:Update(100.01);Check(not mm.requested,'33ms throttle');mm:Update(100.034);Check(mm.requested,'after33ms update')
mm:Paint(vg);mm.style='round';mm:Paint(vg)
mm.points={{id='A',pos={800,0,900},radius=22,v=.5,contested=true,owner='blue'}};mm:Paint(vg)
mm:Draw(123);mm:Draw(123);Check(videos==1,'retained texture bridge')
me.alive=false;me.Position=function()return {100,0,100}end;mm:Update(101);Near(mm.at[1],0,'dead minimap keeps last position')
mm:Dispose();mm:Dispose();Check(retired==1 and deletes==1 and callbacks[vg]==nil,'canvas disposed once with event unsubscribe')
local Feed=require 'ui.MatchFeed';local owner={}
for i=1,8 do Feed.Push(owner,{name='我方'..i,team='blue',me=i==8},{name='敌方',team='red'},'mg',i)end
Check(#owner.killFeed==5 and owner.killFeed[1].at==4,'feed bounded at five FIFO');Check(owner.killFeed[5].mine,'local highlighted');Check(owner.killFeed[5].weapon=='加特林','source weapon label')
Feed.Update(owner,10.999);Check(#owner.killFeed==5,'first not expired');Feed.Update(owner,11);Check(#owner.killFeed==4,'seven second expiry');Feed.Clear(owner);Check(#owner.killFeed==0,'restart clears')
Feed.Push(owner,nil,{name='落坑',team='red',me=false},'',20);Feed.Update(owner,20.3);Feed.Draw(1,owner,1920)
local saw=false;for _,cmd in ipairs(commands)do if cmd[1]=='Text' and cmd[3]=='被击毁' then saw=true end end;Check(saw,'environment kill draws no fake killer')
Objective.Ring(1,50,50,.8);Objective.Cap(1,{id='A',v=.5,count={blue=1,red=0}},1920,.25)
local Motion=require 'ui.CombatFeedbackMotion';local motion=Motion.New();local tick=0
motion:Kill('敌人',true,100,100,{k=1,cx=960,cy=540,width=1920,height=1080},function()return .5 end)
for _=1,240 do motion:Update(1/60,1,function()tick=tick+1 end,1/60)end
Check(tick==22,'all22cube score ticks once');Near(motion.score.shown,300,'score300')
motion:Update(.01,1,nil,5);motion:Kill('下一个',true,100,100,{k=1,cx=960,cy=540,width=1920,height=1080},function()return .5 end);Check(motion.streak==1,'real clock ends4.5s streak during slow motion')
for _,name in ipairs({'scene.TrackAssets','physics.Space','combat.CarUnit','combat.Debris','drive.Vehicle','combat.VehicleRay'})do package.loaded[name]={}end
local World=require 'drive.TrackWorld';local Metrics=require 'drive.TrialMetrics'
package.loaded['urhox-libs/UI']={GetViewportSize=function()return 1920,1080 end}
package.loaded['ui.ReticleTarget']={Update=function()end}
package.loaded['ui.ReticleState']={Layout=function()return {k=1,cx=960,cy=540,width=1920,height=1080}end}
local Overlay=require 'ui.DriveOverlay'
for _,pending in ipairs({false,true})do
    local player={};local target={alive=false,spec={},name='延迟击毁',lastHitBy=player,Position=function()return {10,0,20}end}
    local world=setmetatable({feedbackPlayer=player,fx={},stats={kills=0},metrics=Metrics.New(),time=10,units={}},World)
    if pending then world.metrics:Damage(9.9,target,50,{10,0,20},false)end
    world:RecordKill(target,{10,0,20})
    Check(world.metrics.pending[target].killed,'death creates independent pending event')
    Near(world.metrics.damage,pending and 50 or 0,'zero kill event adds no damage')
    local calls={kill=0,confirm=0,pop=0}
    local session={world=world,feedbackAudio={Kill=function()calls.kill=calls.kill+1 end},ConfirmKill=function()calls.confirm=calls.confirm+1 end}
    local overlay=setmetatable({session=session,feedback=Motion.New(),partCounts={},pops={},tags={},tagRefs={},vitals={},Project=function()return 100,100 end,PopDamage=function()calls.pop=calls.pop+1 end,AimMarker=function()end},Overlay)
    overlay:Update(1/60);Check(calls.kill==1 and calls.confirm==1 and calls.pop==1,'actual metrics to overlay emits all kill routes once')
    Check(world.metrics.pending[target]==nil,'kill consumed same update')
    overlay:Update(1/60);Check(calls.kill==1 and calls.confirm==1 and calls.pop==1,'later frame does not repeat death')
    Near(overlay.feedback.score.target,300,'independent delayed death score300')
    local ally={lastHitBy={}};world:RecordKill(ally,{0,0,0});Check(world.metrics.pending[ally]==nil,'other attacker retains source filter')
end
return {assertions=assertions,sourceCases=#MATCH_OBJECTIVE_CASES}
