-- Frozen intro.css / introSortie.js composition; actual shared drive reticle.
local MechReticle=require("ui.MechReticle")
local UI=require("urhox-libs/UI")
local DriveOverlay=require("ui.DriveOverlay")
local ReticleState=require("ui.ReticleState")
local ReticleGauges=require("ui.ReticleGauges")
local ReticleWeapons=require("ui.ReticleWeapons")
local IntroSortieKill=require("ui.IntroSortieKill")
local IntroTypography=require("ui.IntroTypography")

local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local Coord=require 'core.Coord'
local Fx=require 'ui.IntroSortieFx'
local M={};M.__index=M
local white={237,246,255,255};local cyan={122,216,255,255};local red={255,59,48,255}
local function Box(vg,x,y,w,h,c)
 D.Path(vg,{x+1.3*h/10,y,x+w,y,x+w-1.3*h/10,y+h,x,y+h});nvgFillColor(vg,D.Color(c));nvgFill(vg)
end
local function Circle(vg,x,y,r,c)
 nvgBeginPath(vg);nvgCircle(vg,x,y,r);nvgFillColor(vg,D.Color(c));nvgFill(vg)
end
local function Tokens(s)
 if s.pending then return {{text='完成！'}} end
 if s.step==1 then return s.elapsed>=4 and {{text='按住键盘上的 ',color=cyan},{text='W',key=true},{text=' · 车就会往前开'}} or {{text='按住 '},{text='W',key=true},{text=' 冲过去 · 车会朝'},{text='准星',color=cyan},{text='的方向开'}} end
 if s.step==2 then return s.elapsed>=6 and {{text='把准星对准红色'},{text='「打它！」',color={255,107,94,255}},{text='· '},{text='按住',color=cyan},{text=' '},{text='左键',key=true}} or {{text='左键',key=true},{text=' 开火 · 打掉冲在最前面那辆！'}} end
 if s.step==3 then return {{text='暴走战车群盯上你了',color={255,107,94,255}},{text=' · 撑住！援军到达还有 '},{text=tostring(math.ceil(s.left or 10)),color={255,211,106,255},number=true},{text=' 秒'}} end
 return {{text='援军已到达！'},{text='友军火控：锁定目标中……',color={255,107,94,255}}}
end
M.Tokens=Tokens
function M.New(session)
 local reticle=MechReticle{pointerEvents='none'};reticle.session=session
 reticle.GetAbsoluteLayout=function()return {x=0,y=0,w=reticle.width or 1920,h=reticle.height or 1080}end
 local root=UI.Panel{width='100%',height='100%',pointerEvents='none'}
 local overlay=DriveOverlay.New(session,root,reticle)
 overlay.layer.GetAbsoluteLayout=reticle.GetAbsoluteLayout
 session.openingOverlay=overlay
 return setmetatable({session=session,reticle=reticle,root=root,overlay=overlay},M)
end
function M:Update(dt)
 self.reticle.hit=math.max(0,(self.reticle.hit or 0)-dt)
 if self.session.combat.player.alive then ReticleState.Update(self.reticle,dt) end
 self.overlay:Update(dt);self.reticle.aimState=self.overlay.aimState
end
function M:Warm(vg,w,h)
 D.HudFont(vg);local layout=ReticleState.Layout(w,h)
 ReticleGauges.Render(vg,self.reticle,layout)
 ReticleGauges.Compass(vg,self.reticle,layout)
 ReticleWeapons.Render(vg,self.reticle,layout)
 self.reticle:Center(vg,layout)
end
function M:Project(point,dy,w,h)
 local camera=self.session.camera:GetCamera();local p=Coord.Vec(point[1],point[2]+dy,point[3]);local depth=camera.node:WorldToLocal(p).z
 if depth<=camera.nearClip or depth>=camera.farClip then return end
 local uv=camera:WorldToScreenPoint(p);if uv.x<-.05 or uv.x>1.05 or uv.y<-.05 or uv.y>1.05 then return end
 return uv.x*w,uv.y*h
end
function M:Draw(vg,I,w,h,u)
 local s=I.sortie;if not s then return end
 if I.capturePending then return end
 self.reticle.width=w;self.reticle.height=h
 self.overlay.layer:Render(vg)
 if s.controlling and s.step<5 then self.reticle:Render(vg) end
 if s.killAt then IntroSortieKill.Draw(vg,w,h,u,I.time-s.killAt,s.mine) end
 if not s.controlling and s.step<5 then
  local bw,bh=52*u,8.5*u;local x,y=(w-bw)/2,h*.46-bh/2
  D.Rect(vg,x,y,bw,bh,{8,15,28,209});D.Rect(vg,x,y,bw,1,{122,216,255,128})
  nvgSave(vg);nvgGlobalAlpha(vg,.65+.35*math.sin(I.time*math.pi/1.1)^2)
  D.Text(vg,'点击画面 · 接管战车',w/2,y+1.6*u,2.8*u,white,'vox-title',NVG_ALIGN_CENTER);nvgRestore(vg)
  D.Text(vg,'鼠标转视角 · 按 Esc 松开鼠标',w/2,y+5.2*u,1.5*u,{159,196,228,255},'vox-body',NVG_ALIGN_CENTER)
 end
 if s.step==2 and not s.pending and self.session.combat.easy.alive then
  local x,y=self:Project(self.session.combat.easy:Position(),2.6,w,h)
  if x then
   local bob=(1-math.cos(I.time*math.pi/.6))*.4*u;local size=1.9*u;local bw=D.Width(vg,'打它！',size,'vox-title')+2.66*u
   Box(vg,x-bw/2,y-4.6*u,bw,2.66*u,{216,23,12,255});D.Text(vg,'打它！',x,y-4.15*u,size,white,'vox-title',NVG_ALIGN_CENTER)
   D.Path(vg,{x-1.1*u,y-1.5*u+bob,x+1.1*u,y-1.5*u+bob,x,y+bob});nvgFillColor(vg,D.Color(red));nvgFill(vg)
  end
 end
 if s.step==4 then
  local x,y=self:Project(self.session.combat.player:Position(),1.2,w,h)
  if x then
   local progress=math.min(1,s.elapsed/1.8);local radius=8*u*(2.4-progress*1.5);local angle=I.time*math.pi*2/1.2
   nvgSave(vg);nvgGlobalAlpha(vg,.4+progress*.6)
   Fx.LockRing(vg,x,y,radius,angle,u)
   local text=progress>.72 and '识别失败 · 照打' or 'LOCK';local bw=D.Width(vg,text,1.6*u,'vox-title')+1.92*u
   D.Rect(vg,x-bw/2,y+radius*1.16,bw,2.24*u,progress>.72 and white or {216,23,12,255})
   D.Text(vg,text,x,y+radius*1.16+.32*u,1.6*u,progress>.72 and red or white,'vox-title',NVG_ALIGN_CENTER);nvgRestore(vg)
  end
 end
 if s.step<=0 or s.step>=5 then return end
 local runs=Tokens(s);local size=2.6*u;local widths={};local content=0
 for i,run in ipairs(runs) do local fs=run.key and size*.85 or run.number and size*1.25 or size;local font=(run.key or run.number) and 'vox-tabular' or 'vox-title';local width=D.Width(vg,run.text,fs,font)+(run.key and size*1.3 or 0);widths[i]={width=width,size=fs,font=font};content=content+width end
 local bw=1.2*u+4.4*u+1.6*u+content+2.8*u;local scale=math.min(1,(w-4*u)/bw);local bh=6.8*u
 local enter=1-(1-math.min(1,s.elapsed/.26))^3;local x=(w-bw*scale)/2;local y=h*.83-bh*scale+(1-enter)*3*u
 nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,scale,scale);nvgGlobalAlpha(vg,s.pending and .8 or enter)
 local pulse=Fx.Nudge(s);Fx.TipGlow(vg,bw,bh,u,pulse)
 Box(vg,.5*u,.5*u,bw,bh,{3,14,24,255});D.Path(vg,{0,0,bw,0,bw-1.2*u,bh,-1.2*u,bh});D.Gradient(vg,0,0,bw,bh,{23,48,76,255},{8,15,28,255})
 D.Line(vg,0,0,bw,0,{122,216,255,math.floor(153+77*pulse)},.3*u);local cx=1.2*u;D.Rect(vg,cx,1.2*u,4.4*u,4.4*u,s.pending and {47,191,113,255} or {40,121,235,255})
 if s.pending then D.Line(vg,cx+u,3.4*u,cx+1.9*u,4.1*u,white,.3*u);D.Line(vg,cx+1.9*u,4.1*u,cx+3.4*u,2.3*u,white,.3*u)
 else D.Text(vg,string.format('%02d',s.step),cx+2.2*u,2.3*u,2.2*u,white,'vox-tabular',NVG_ALIGN_CENTER) end
 cx=cx+6*u
 for i,run in ipairs(runs) do local a=widths[i]
  if run.key then D.Rect(vg,cx,1.72*u,a.width,3.25*u,{3,14,24,255});D.Rect(vg,cx,1.48*u,a.width,3.25*u,cyan);D.Text(vg,run.text,cx+a.width/2,2.1*u,a.size,{3,20,31,255},a.font,NVG_ALIGN_CENTER)
  else D.Text(vg,run.text,cx,2*u,a.size,run.color or white,a.font) end
  cx=cx+a.width
 end
 nvgRestore(vg)
end
function M:Dispose()
 if self.session.openingOverlay==self.overlay then self.session.openingOverlay=nil end
 self.root:Destroy();self.reticle:Destroy()
end
function M.Stamp(vg,w,h,u,s)
 if not s.stamped then return end
 local typography=IntroTypography;typography.Begin(vg)
 local progress=math.min(1,math.max(0,s.elapsed-.9)/.26);local scale=2.4-1.4*progress
 local reason=(s.reason or '')..' · 维修费将从你的工资中扣除'
 local width=math.max(58*u,D.Width(vg,reason,2.2*u,'vox-title')+6.8*u);local height=22.6*u
 nvgSave(vg);nvgTranslate(vg,w/2,h*.44);nvgRotate(vg,(-14+6*progress)*math.pi/180);nvgScale(vg,scale,scale);nvgGlobalAlpha(vg,progress)
 D.Rect(vg,-width/2,-height/2,width,height,{20,4,3,89});nvgBeginPath(vg);nvgRect(vg,-width/2,-height/2,width,height);nvgStrokeWidth(vg,.7*u);nvgStrokeColor(vg,D.Color(red));nvgStroke(vg)
 nvgSave(vg);nvgTranslate(vg,0,-height/2+1.4*u);local size=12*u;local glyph=size/48;nvgScale(vg,glyph,glyph);D.Text(vg,'已损毁',0,0,48,red,typography.face,NVG_ALIGN_CENTER);nvgRestore(vg)
 D.Text(vg,reason,0,height/2-6.4*u,2.2*u,{255,217,212,255},'vox-title',NVG_ALIGN_CENTER)
 D.Text(vg,'（新员工第一次出勤，基本都是这个结局。）',0,height/2-3.4*u,1.6*u,{255,217,212,255},'vox-body',NVG_ALIGN_CENTER);nvgRestore(vg)
end
function M.Brief(vg,w,h,u,time)
 local width=math.min(74*u,w*.88);local height=30.4*u;local x=w*.06;local y=h*.5-height/2
 local progress=math.min(1,math.max(0,time-2.2)/.32);local ease=1-(1-progress)^3
 nvgSave(vg);nvgGlobalAlpha(vg,ease);nvgTranslate(vg,-w*.06*(1-ease),0)
 local c=2.6*u
 D.Path(vg,{x,y,x+width-c,y,x+width,y+c,x+width,y+height,x+c,y+height,x,y+height-c});D.Gradient(vg,x,y,width,height,{23,48,76,240},{8,15,28,240})
 D.Line(vg,x,y,x+width-c,y,cyan,.35*u)
 local tx=x+3*u
 Circle(vg,tx+.55*u,y+3.25*u,.55*u,red);D.Text(vg,'紧急插播 · 实机演示',tx+2.1*u,y+2.4*u,1.7*u,{255,138,128,255},'vox-title')
 D.Text(vg,'公司矿车遇袭！这一次——',tx,y+5.7*u,3.4*u,white,'vox-title');D.Text(vg,'由你亲自驾驶。',tx,y+10.12*u,3.4*u,cyan,'vox-title')
 D.Rect(vg,tx,y+15.5*u,4.8*u,2.4*u,cyan);D.Text(vg,'任务',tx+2.4*u,y+15.9*u,1.6*u,{3,20,31,255},'vox-title',NVG_ALIGN_CENTER)
 D.Text(vg,'保护矿车，坚持到援军到达',tx+6*u,y+15.7*u,2*u,white,'vox-title')
 local cursor=tx
 for _,run in ipairs({{'W','前进'},{'鼠标','瞄准 · 车朝准星开'},{'左键','开火'}}) do
  local kw=D.Width(vg,run[1],1.62*u,'vox-tabular')+1.78*u
  D.Rect(vg,cursor,y+19.6*u,kw,2.6*u,cyan);D.Text(vg,run[1],cursor+kw/2,y+20.09*u,1.62*u,{3,20,31,255},'vox-tabular',NVG_ALIGN_CENTER)
  D.Text(vg,run[2],cursor+kw+.8*u,y+20*u,1.8*u,{201,220,239,255},'vox-title');cursor=cursor+kw+.8*u+D.Width(vg,run[2],1.8*u,'vox-title')+2.4*u
 end
 D.Rect(vg,tx,y+24.5*u,width-6*u,3.5*u,{40,121,235,255});D.Text(vg,'▶ 点击画面 · 接管战车',x+width/2,y+25.05*u,2.4*u,white,'vox-title',NVG_ALIGN_CENTER)
 nvgRestore(vg)
end
function M.Chrome(vg,w,h,u,time,step)
 local x,y=w*.026,h*.15;local liveW=32*u;local textW=D.Width(vg,'未经美化（美术预算已花在上一段）',1.3*u,'vox-body')
 Box(vg,x,y,liveW+textW,3.4*u,{8,15,28,255});D.Line(vg,x+u,y,x+liveW+textW,y,{122,216,255,115},1)
 if math.floor(time*2)%2==0 then Circle(vg,x+1.7*u,y+1.7*u,.6*u,red) end
 D.Text(vg,'实机画面 · LIVE',x+3.3*u,y+.7*u,2*u,white,'vox-title');D.Text(vg,'未经美化（美术预算已花在上一段）',x+23*u,y+1.05*u,1.3*u,{159,196,228,255},'vox-body')
 local task=step==5 and '战车已损毁' or step==4 and '援军已到达' or step==3 and '撑住！援军马上到' or '保护公司矿车 · 坚持到援军到达'
 local width=D.Width(vg,task,1.75*u,'vox-title')+8*u;Box(vg,x,h*.196,width,3.2*u,{8,15,28,184})
 D.Rect(vg,x+u,h*.196+.62*u,4.4*u,1.96*u,cyan);D.Text(vg,'任务',x+3.2*u,h*.196+.89*u,1.4*u,{3,20,31,255},'vox-title',NVG_ALIGN_CENTER)
 D.Text(vg,task,x+6.4*u,h*.196+.65*u,1.75*u,white,'vox-title')
end
return M
