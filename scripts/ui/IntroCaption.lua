-- Source intro.css .cap: blue P5 slanted narration box with the「旁白」relief tag.
-- Enter/leave follow intro.js say(): 280ms clip reveal in, 200ms ease-in out.
local Relief=require("ui.SourceRelief")

local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local M={}
local text={237,246,255,255};local brand={122,216,255,255};local deep={40,121,235,255}
local LABEL='旁白 · 星际前途宣传部'
-- Source say( id, { ad } )：广告段旁白斜得更少；决定之后那句是 .cap.big
local AD={idyll=true,['m-build']=true,['m-drive']=true,['m-missile']=true,['m-salvage']=true,recruit=true,peacekeeper=true,master=true}
local function Bezier(x1,y1,x2,y2,t)
 local function At(a,b,s) return 3*a*s*(1-s)^2+3*b*s*s*(1-s)+s^3 end
 local lo,hi=0,1
 for _=1,18 do local mid=(lo+hi)/2;if At(x1,x2,mid)<t then lo=mid else hi=mid end end
 return At(y1,y2,(lo+hi)/2)
end
local function Runs(content)
 local runs={};local at=1
 while at<=#content do
  local a,b,inner=content:find('<b>(.-)</b>',at)
  if not a then runs[#runs+1]={text=content:sub(at):gsub('<[^>]+>',''),color=text};break end
  if a>at then runs[#runs+1]={text=content:sub(at,a-1):gsub('<[^>]+>',''),color=text} end
  runs[#runs+1]={text=inner,color=brand};at=b+1
 end
 return runs
end
local function Box(vg,state,w,h,u,alpha,dx,reveal)
 local fs=(state.big and 3.2 or 2.2)*w/100;local spacing=fs*.05;local font='vox-title'
 local runs=Runs(state.text);local content=0
 for _,run in ipairs(runs) do run.width=D.Width(vg,run.text,fs,font,spacing);content=content+run.width end
 local bw,bh=content+2.8*fs,(1.3+.5+.55)*fs
 -- white-space: nowrap；窄屏整块缩小而不是折行
 local scale=math.min(1,w*.94/(bw+.35*w/100))
 local cx,cy=w/2+dx,h-13*u-bh*scale/2
 local rotate=state.ad and -1 or -1.6;local skew=state.ad and -6 or -10
 nvgSave(vg);nvgGlobalAlpha(vg,alpha)
 if reveal<1 then
  local left=cx-bw*scale/2;nvgScissor(vg,left-.2*bw*scale,0,bw*scale*1.4*reveal,h)
 end
 nvgTranslate(vg,cx,cy);nvgScale(vg,scale,scale);nvgRotate(vg,math.rad(rotate))
 nvgSave(vg);nvgSkewX(vg,math.rad(skew))
 local x,y=-bw/2,-bh/2;local shadow=.35*w/100
 D.Rect(vg,x+shadow,y+shadow,bw,bh,deep)
 nvgBeginPath(vg);nvgRect(vg,x,y,bw,bh)
 nvgFillPaint(vg,nvgLinearGradient(vg,0,y,0,y+bh*.78,nvgRGBA(23,48,76,255),nvgRGBA(8,15,28,255)));nvgFill(vg)
 D.Rect(vg,x,y,bw,.3*u,{122,216,255,153});D.Rect(vg,x,y+bh-.15*u,bw,.15*u,{122,216,255,46})
 -- ::before 标签：字号 .5em，left/top 按标签自身 em 算；skewX(10deg) 叠在框的斜切里
 local ls=fs*.5;local lw=D.Width(vg,LABEL,ls,font,ls*.14)+1.4*ls;local lh=ls*1.5
 local lx,ly=x+1.2*ls,y-1.1*ls
 nvgSave(vg);nvgTranslate(vg,lx+lw/2,ly+lh/2);nvgSkewX(vg,math.rad(10))
 Relief.Draw(vg,-lw/2,-lh/2,lw,lh,true,true,{-lw/2,-lh/2,lw/2,-lh/2,lw/2,lh/2,-lw/2,lh/2})
 D.Text(vg,LABEL,-lw/2+.7*ls,-lh/2+.25*ls,ls,{255,255,255,255},font,nil,ls*.14)
 nvgRestore(vg)
 nvgRestore(vg)
 -- 文字反向斜切回正，只保留整框的旋转
 local tx,ty=-content/2,y+.5*fs
 for _,run in ipairs(runs) do D.Text(vg,run.text,tx,ty,fs,run.color,font,nil,spacing,false,1.3*fs);tx=tx+run.width end
 nvgRestore(vg)
end
function M.Draw(page,vg,I,w,h,u)
 local now=I.time or 0;local current=page.captionState
 local caption=I.caption or ''
 if caption~='' and (not current or current.text~=caption) then
  if current then page.captionLeaving={text=current.text,ad=current.ad,big=current.big,at=now} end
  current={text=caption,ad=AD[I.shot]==true,big=I.shot=='decided',at=now};page.captionState=current
 elseif caption=='' and current then
  page.captionLeaving={text=current.text,ad=current.ad,big=current.big,at=now};page.captionState=nil;current=nil
 end
 local leaving=page.captionLeaving
 if leaving then
  local k=math.min(1,(now-leaving.at)/.2)
  if k>=1 then page.captionLeaving=nil
  else local e=Bezier(.42,0,1,1,k);Box(vg,leaving,w,h,u,1-e,4*w/100*e,1) end
 end
 if current then
  local k=math.min(1,math.max(0,now-current.at)/.28);local e=Bezier(.16,1,.3,1,k)
  Box(vg,current,w,h,u,e,-5*w/100*(1-e),e)
 end
end
function M.Reset(page) page.captionState=nil;page.captionLeaving=nil end
return M
