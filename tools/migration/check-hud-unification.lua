-- Source-executed geometry plus isolated production drawing; no gameplay claim.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local State=require 'ui.ReticleState'
local Nav=require 'ui.ReticleNavigation'
local Reticle=require 'ui.MechReticle'
local Missile=require 'ui.MissileHud'
local Feedback=require 'ui.DriveFeedback'
local Frame=UI.Widget:Extend('VoxUnifiedHudAcceptance')
---@type Widget?
local root=nil
local stage='free';local rendered={};local fixture={};local session={};local view={};local scopeRecords={}
local savedText=D.Text
local function Same(a,b) return math.abs(a-b)<.11 end
local function Capture(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'actual unified HUD '..name..' screenshot')
 V.assert(image:SavePNG('docs/migration/evidence/hud-unification-'..name..'.png'),'saved unified HUD '..name);image:Dispose()
end
function HoldUnifiedHudRoot() if root then UI.SetRoot(root) end end
function Frame:Render(vg)
 D.HudFont(vg);local rect=self:GetAbsoluteLayout();local l=State.Layout(rect.w,rect.h)
 D.Rect(vg,0,0,rect.w,rect.h,{20,27,32,255})
 local calls={}
 D.Text=function(ctx,text,x,y,size,color,font,...)
  calls[#calls+1]={text=tostring(text),x=x,y=y,size=size,font=font}
  return savedText(ctx,text,x,y,size,color,font,...)
 end
 view.GetAbsoluteLayout=function() return rect end
 view.Center=Reticle.Center;view.session=session
 view.Scope=function(self,ctx,layout)
  local rectFn,circleFn,lineFn=nvgRect,nvgCircle,D.Line;local records={rects=0,dots={},lines=0,pixel=layout.pixel or 1}
  nvgRect=function(...) records.rects=records.rects+1;return rectFn(...) end
  nvgCircle=function(c,x,y,r) records.dots[#records.dots+1]={x=x,y=y,r=r};return circleFn(c,x,y,r) end
  D.Line=function(...) records.lines=records.lines+1;return lineFn(...) end
  local ok,err=pcall(Reticle.Scope,self,ctx,layout)
  nvgRect,nvgCircle,D.Line=rectFn,circleFn,lineFn;scopeRecords=records;assert(ok,err)
 end
 if stage=='damage' then
  Feedback.Render({owner={session={pointer={captured=false}},pops={
   {text='36',amount=36,x=rect.w*.2,y=rect.h*.3,t=.2,broke=0},
   {text='128',amount=128,x=rect.w*.5,y=rect.h*.3,t=.2,broke=0},
   {text='穿甲 75',amount=75,x=rect.w*.8,y=rect.h*.3,t=.2,pierce=true,broke=0},
   {text='抵抗 24',amount=24,x=rect.w*.2,y=rect.h*.65,t=.2,shield=true,broke=0},
   {text='96',amount=96,x=rect.w*.5,y=rect.h*.65,t=.2,broke=2},
   {text='159',amount=159,x=rect.w*.8,y=rect.h*.65,t=.2,killed=true,broke=0}
  }}},vg)
 else
  Reticle.Render(view,vg)
  if stage=='missile' then Missile.Render({session=session,overlay={focus=true},GetAbsoluteLayout=function() return rect end},vg) end
 end
 D.Text=savedText;rendered[stage]=calls
end
V.atFrame(2,function()
 local file=File('tools/migration/source-hud-unification.json',FILE_READ);fixture=cjson.decode(file:ReadString());file:Dispose()
 for index,case in ipairs(fixture.cases) do
  local l=State.Layout(case.w,case.h,false);local p=Nav.Layout(l,case.head,case.wp);local e=case.expected
  V.assert(Same(p.x,e.x) and Same(p.y,e.y) and Same(p.r,e.r) and Same(p.labelY,e.labelY),'frozen actual compass geometry')
  V.assert(p.label:gsub('[<&]','')==e.label and (p.edge~=0)==e.edge and p.height==(type(e.height)=='number' and e.height or nil),'frozen actual compass label/edge/height '..index)
  local expectedColor=string.format('#%02x%02x%02x',p.color[1],p.color[2],p.color[3])
  V.assert(expectedColor==e.color,'frozen actual compass enemy/objective color')
 end
 for _,case in ipairs(fixture.slotCases) do
  local groups={{kind='mg'},{kind='sniper'},{kind='laser'},{kind='missile'}}
  local l=State.Layout(case.w,case.h,false);local boxes=State.Chips(l,groups,case.selected)
  for i,b in ipairs(boxes) do local e=case.boxes[i]
   V.assert(Same(b.x,e.x) and Same(b.y,e.y) and Same(b.w,e.w) and Same(b.h,e.h),'frozen actual weapon slot geometry')
  end
 end
 for _,case in ipairs(fixture.scaleCases) do
  for _,uiScale in ipairs({1,.7,1.5,3}) do
   local l=State.Layout(case.w/uiScale,case.h/uiScale,case.compact)
   V.assert(math.abs(l.k*uiScale-case.k)<1e-9,'actual frozen compact/PC reticle scale across UI coordinate spaces')
  end
 end
 for kind,zoom in pairs(fixture.zoom) do
  V.assert(State.zoom[kind]==zoom,'actual frozen optical zoom '..kind)
  V.assert(math.abs(math.tan(State.ScopeFov(48,kind)*math.pi/360)*zoom-math.tan(48*math.pi/360))<1e-8,'actual frozen optical FOV '..kind)
  if kind~='sniper' then V.assert(fixture.scopes[kind]=='','source ordinary scope has no overlay '..kind) end
 end
 local pos={0,4,0};local target={20,10,60};local player={alive=true,Position=function() return pos end}
 local rules={begun=true,StepSpec=function() return {kind='reach'} end,Target=function() return target end}
 local mission={player=player,rules=rules,entries={{unit=player}}};local s={story=mission}
 local wp=Nav.Read(s);V.assert(wp and wp.dy==6 and wp.label=='目标' and math.abs(wp.dist-math.sqrt(4000))<1e-6,'real marker selection feeds waypoint from actual player COM')
 target={-20,-4,80};local changed=Nav.Read(s)
 V.assert(changed and changed.dy==-8 and changed.yaw<0,'target switch recomputes real waypoint')
 for _,hide in ipairs({'death','cinematic','complete','epilogue','not-begun'}) do
  player.alive=hide~='death';mission.boss=hide=='cinematic' and {cinematic=true} or nil
  rules.completeAt=hide=='complete' and 1 or nil;mission.epilogue=hide=='epilogue' and {} or nil;rules.begun=hide~='not-begun'
  V.assert(Nav.Read(s)==nil,'waypoint absent without stale marker '..hide)
 end
 local groups={}
 local types={mg='mg3',sniper='sniper2',laser='laser1',missile='missile3'}
 for _,kind in ipairs({'mg','sniper','laser','missile'}) do groups[#groups+1]={kind=kind,name=kind,output=1,weapons={{type=types[kind],stats={}}}} end
 local weapons={groups=groups,current=1,energy=65,energyMax=100,Readiness=function() return .7 end}
 weapons.Group=function() return weapons.groups[weapons.current] end
 weapons.LockInfo=function() return {box=.12,phase='reload',reload=.45,count=2,tubes=6,progress=.5,energyOk=true} end
 session={pointer={captured=true},weapons=weapons,vehicle={speed=10,spec={motion={topSpeed=30}},body={translation=function() return Vector3.ZERO end}},yaw=0,world={time=0},camera={GetCamera=function() return {fov=48} end}}
 local proofScene=Scene();proofScene:CreateComponent('PhysicsWorld')
 local bodyNode=proofScene:CreateChild('ActualLogicalBody');local native=bodyNode:CreateComponent('RigidBody')
 native.mass=0;native.position=Vector3(-120,7,33)
 local body=require('physics.Body').Wrap(native);local logical=body.translation()
 V.assert(logical.x==120 and logical.y==7 and logical.z==33,'actual Body.Wrap.translation already returns reflected logical world coordinates')
 session.proofScene=proofScene;session.vehicle.body=body;session.aimPoint={123,11,33};session.aimRef={alive=true}
 weapons.groups[1].weapons[1].stats.range=4
 local stateView={session=session};State.Update(stateView,0)
 V.assert(stateView.fire and stateView.fire.sub=='超出 4 米 · 伤害衰减','actual body non-origin range stays logical in ReticleState.Update')
 view={hp=.68,structure=.8,clock=2,wordAt=0,fire={word='冷却',tone='busy',frac=.7,sub=''},hint='此旧长句不能显示',waypoint={yaw=0,dy=8,dist=160,label='目标',enemy=false}}
 UI.UnregisterGlobalComponent('vox-loading-page');root=Frame{width='100%',height='100%',pointerEvents='none'}
 UI.SetRoot(root);SubscribeToEvent('PostUpdate','HoldUnifiedHudRoot')
end)
V.atFrame(6,function() Capture('free');stage='story';session.story={} end)
V.atFrame(9,function()
 Capture('story');local a,b=rendered.free,rendered.story
 V.assert(#a==#b,'story and free HUD have identical visible text count')
 for i,t in ipairs(a) do local u=b[i]
  V.assert(u and t.text==u.text and t.x==u.x and t.y==u.y and t.font==u.font,'actual story/free HUD identical draw typography')
 end
 for _,t in ipairs(b) do V.assert(t.text~=view.hint,'obsolete center hint remains hidden') end
 stage='scope';session.scope=true;session.weapons.current=2
end)
V.atFrame(12,function()
 Capture('sniper-scope');local found={}
 local scopeIndex,frameIndex=0,0
 for i,t in ipairs(rendered.scope) do
  found[t.text]=true
  if t.text=='RNG 5 M' then scopeIndex=i elseif t.text=='EN' then frameIndex=i end
 end
 V.assert(scopeIndex>0 and frameIndex>scopeIndex,'actual source svg.scope paints before svg.frame at overlapping scope/frame labels')
 V.assert(found.HP and found.EN and found['5.0×'] and found['冷却'],'scope retains shared frame/fire state and actual source zoom')
 V.assert(found['RNG 5 M'],'actual sniper range uses real Body.Wrap logical translation at non-origin position')
 V.assert(scopeRecords.rects==0 and scopeRecords.lines==3 and #scopeRecords.dots==#fixture.scopeDots,'actual scope has no old mask/ring and source three-line/24-dot overlay')
 for _,dot in ipairs(scopeRecords.dots) do V.assert(math.abs(dot.r/scopeRecords.pixel-fixture.scopeDots[1].r)<1e-7,'actual sniper source ranging-dot CSS radius after UI scale conversion') end
 stage='missile';session.scope=false;session.weapons.current=4
end)
V.atFrame(15,function()
 Capture('missile');local forbidden=false
 for _,t in ipairs(rendered.missile) do if t.text:find('MSL',1,true) or t.text:find('充能',1,true) or t.text:find('齐射',1,true) then forbidden=true end end
 V.assert(not forbidden,'story missile HUD omits original CSS-hidden duplicate labels')
 stage='damage'
end)
V.atFrame(18,function()
 Capture('damage-font');local calls=rendered.damage;local found={}
 for _,t in ipairs(calls) do found[t.text]=true;V.assert(t.font=='vox-hud','damage numeric/Chinese caller uses shared Chakra/Industrial face') end
 V.assert(found['36'] and found['128'] and found['穿甲 75'] and found['抵抗 24'] and found['击碎 ×2'] and found['159'],'all six source damage categories rendered')
 root=nil;session.proofScene:Dispose();V.finish()
end)
