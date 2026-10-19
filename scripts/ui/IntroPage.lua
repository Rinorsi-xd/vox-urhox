local IntroImageWarmup=require("ui.IntroImageWarmup")
local IntroComic=require("ui.IntroComic")
local CommsPortrait=require("ui.CommsPortrait")
local SourceRichText=require("ui.SourceRichText")
local IntroTerminalFx=require("ui.IntroTerminalFx")
local Theme=require("urhox-libs/UI/Core/Theme")
local IntroTypography=require("ui.IntroTypography")
local IntroWipe=require("ui.IntroWipe")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Frame=require 'ui.IntroFrame'
local Paragraph=require 'ui.SourceParagraph'
local Paint=require 'ui.WorkshopPaint'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local ContractLayout=require 'ui.IntroContractLayout'
local Opacity=require 'ui.IntroOpacity'
local GateMotion=require 'ui.IntroGateMotion'
local GateFx=require 'ui.IntroGateFx'
local ContractMotion=require 'ui.IntroContractMotion'
local ContractText=require 'ui.IntroContractText'
local Impact=require 'intro.IntroImpact'
local nvgGlobalAlpha=Opacity.Set
local Page=UI.Widget:Extend('VoxOpeningPage')
local M={};local ice={214,240,255,255};local cyan={110,214,255,255};local white={242,250,255,255};local red={255,77,66,255}
local function Inside(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
function M.New(owner)
 local page=Page{position='absolute',left=0,top=0,width='100%',height='100%',pointerEvents='auto',focusable=false};page.owner=owner
 page.paragraph=Paragraph.New(28.08,47.736);page.paragraph.font='vox-title';page.terms=Paragraph.New(15.12,27.972);page.terms.font='vox-title'
 page.nameLabel=UI.Label{position='absolute',visible=false,text=owner.name,fontSize=28.08,
  fontFamily='vox-title',padding=12,borderRadius=0,backgroundColor={0,4,10,102},fontColor=white,borderColor={214,240,255,82},borderWidth=1,maxLines=1}
 page.inputClip=UI.Panel{position='absolute',left=0,top=0,width=0,height=0,overflow='hidden',pointerEvents='none'}
 page.inputClip:AddChild(page.nameLabel);page:AddChild(page.inputClip);page.termScroll=0;page.pointers={};page.buttons={}
 page.imageWarmup=IntroImageWarmup.New(owner.data.images,function()return page:PreparePortrait()end)
 return page
end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:GetAbsoluteLayoutForHitTest() return self:GetAbsoluteLayout() end
function Page:HitTest(x,y)
 if not self.owner.active then return false end
 if self.owner.playing and self.owner.sortie and self.owner.sortie.controlling then return Inside(self.skipRect,x,y) end
 return true
end
function Page:ShowContract(show)
 self.contractFieldRequested=show
 self.nameLabel:SetVisible(false)
end
function Page:OnPointerDown(e)
 if self.owner.finishing then return true end
 self.pointers[e.pointerId]=e.pointerType
 local I=self.owner
  for _,button in ipairs(self.buttons) do if Inside(button,e.x,e.y) and (not button.clip or Inside(button.clip,e.x,e.y)) then
  if button.id=='skip' then I:Skip() elseif button.id=='submit' then I:Submit()
  elseif button.id=='attachment' then self.attachment=not self.attachment;if self.attachment then I.audio:Sfx('blip',{vol=.4}) end
  elseif button.id=='close-attachment' then self.attachment=false
  elseif button.id=='close' then I:Finish()
  elseif button.id:sub(1,4)=='pick' then I:Choose(tonumber(button.id:sub(5))) end
  return true
 end end
 if I.shot=='contract' then
   if Inside(self.signatureRect,e.x,e.y) and (not self.signatureHitRect or Inside(self.signatureHitRect,e.x,e.y)) then
   local r=self.signatureRect
   self.signPointer=e.pointerId;self.lastPoint={e.x,e.y}
   -- A second pointer replaces the active stroke; stop its looped scribble first or it loops orphaned.
   if self.scribble then I.audio:StopSfx(self.scribble,.1,self.scribbleToken);self.scribble=nil end
   I.strokes[#I.strokes+1]={ {(e.x-r.x)/r.w,(e.y-r.y)/r.h} };self.scribble,self.scribbleToken=I.audio:Sfx('scribble',{vol=.4,loop=true})
   elseif Inside(self.termRect,e.x,e.y) and (not self.contractHitRect or Inside(self.contractHitRect,e.x,e.y)) then self.termPointer=e.pointerId;self.termLast=e.y end
 elseif I.playing then
  if I.host.CaptureSortie then I.host.CaptureSortie(I) end
 else
  I.holding=true;I:Advance()
 end
 return true
end
function Page:OnPointerMove(e)
 if self.owner.finishing then return true end
 self.mouseX=e.x;self.mouseY=e.y
 if self.signPointer==e.pointerId then
  local r=self.signatureRect;local p={math.max(r.x,math.min(r.x+r.w,e.x)),math.max(r.y,math.min(r.y+r.h,e.y))}
  local cssScale=UI.GetScale()/graphics:GetDPR()
  self.owner.ink=self.owner.ink+math.sqrt((p[1]-self.lastPoint[1])^2+(p[2]-self.lastPoint[2])^2)*cssScale
  local stroke=self.owner.strokes[#self.owner.strokes];stroke[#stroke+1]={(p[1]-r.x)/r.w,(p[2]-r.y)/r.h};self.lastPoint=p
 elseif self.termPointer==e.pointerId then self.termScroll=math.max(0,math.min(self.termMax or 0,self.termScroll+(self.termLast-e.y)/self.k));self.termLast=e.y end
 return true
end
function Page:OnPointerUp(e)
 self.pointers[e.pointerId]=nil;self.owner.holding=false
 if self.signPointer==e.pointerId then self.signPointer=nil;if self.scribble then self.owner.audio:StopSfx(self.scribble,.1,self.scribbleToken);self.scribble=nil end end
 if self.termPointer==e.pointerId then self.termPointer=nil end
 return true
end
function Page:OnPointerCancel(e) return self:OnPointerUp(e) end
function Page:UpdateSignatureBounds(r)
 local old=self.signatureRect
 if self.signPointer and old and (old.x~=r.x or old.y~=r.y or old.w~=r.w or old.h~=r.h) then
  self:OnPointerUp({pointerId=self.signPointer})
 end
 self.signatureRect=r
end
function Page:OnWheel(_,dy) if self.owner.shot=='contract' then self.termScroll=math.max(0,math.min(self.termMax or 0,self.termScroll-dy*36));return true end end
function Page:Close()
 for id,kind in pairs(self.pointers) do UI.CancelPointer(id,kind) end
 if self.scribble then self.scribble:StopImmediate() end
 if self.imageWarmup then self.imageWarmup:Dispose() end
 if self.portrait then
  local take=self.owner.host and self.owner.host.TakeTutorialPortrait
  if take and take(self.owner,self.portrait,Images.GetContext()) then self.portrait=nil
  else self.portrait:Dispose();self.portrait=nil end
 end
 IntroComic.Dispose(self)
 UI.ClearFocus();UI.PopOverlay(self);if UI.GetRoot()==self then UI.SetRoot(nil) end;self:Destroy()
end
local function Image(vg,I,name,x,y,w,h,alpha,cover)
 if not I.downloaded then return end
 local path=I.data.images[name];if not path then return end
 if cover then nvgSave(vg);nvgGlobalAlpha(vg,alpha or 1);Paint.Image(vg,path,{x=x,y=y,w=w,h=h},1,.5);nvgRestore(vg);return end
 local handle=Images.Get(path);if not handle or handle<=0 then return end
 local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
 local scale=math.min(w/iw,h/ih);local dw,dh=iw*scale,ih*scale
 local px,py=x+(w-dw)/2,y+h-dh
 nvgBeginPath(vg);nvgRect(vg,px,py,dw,dh);nvgFillPaint(vg,nvgImagePattern(vg,px,py,dw,dh,0,handle,alpha or 1));nvgFill(vg)
end
local function Panel(vg,x,y,w,h,u,kind,t,opacity)
 nvgSave(vg);nvgTranslate(vg,x,y)
 local stops=kind=='comms' and {{0,168},{.09,77},{.22,20},{.7,15},{1,102}} or kind=='dialog' and {{0,189},{.55,158},{1,87}}
 if stops then
  for i=1,#stops-1 do local a,b=stops[i],stops[i+1];nvgSave(vg)
   if kind=='comms' then nvgIntersectScissor(vg,0,a[1]*h,w,(b[1]-a[1])*h) else nvgIntersectScissor(vg,a[1]*w,0,(b[1]-a[1])*w,h) end
   Frame.Shape(vg,w,h,u,kind);nvgFillPaint(vg,nvgLinearGradient(vg,kind=='dialog' and a[1]*w or 0,kind=='comms' and a[1]*h or 0,kind=='dialog' and b[1]*w or 0,kind=='comms' and b[1]*h or 0,nvgRGBA(3,10,18,a[2]),nvgRGBA(3,10,18,b[2])));nvgFill(vg);nvgRestore(vg)
  end
 else Frame.Shape(vg,w,h,u,kind);nvgFillColor(vg,nvgRGBA(3,10,18,opacity or 180));nvgFill(vg) end
 nvgBeginPath(vg)
 for yy=0,h,4 do nvgMoveTo(vg,0,yy);nvgLineTo(vg,w,yy) end
 nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(214,240,255,6));nvgStroke(vg)
 Frame.Draw(vg,w,h,u,kind,t);nvgRestore(vg)
end
local function PanelShadow(vg,x,y,w,h,u)
 nvgSave(vg);nvgTranslate(vg,x+w/2,y+h/2);nvgScale(vg,1,(h+10*u)/(w+12*u))
 local r=(w+12*u)/2
 nvgBeginPath(vg);nvgCircle(vg,0,0,r)
 nvgFillPaint(vg,nvgRadialGradient(vg,0,0,r*.3,r,nvgRGBA(3,10,18,107),nvgRGBA(3,10,18,0)));nvgFill(vg);nvgRestore(vg)
end
local function SignatureBorder(vg,x,y,w,h,pixel)
 local dash=3*pixel;local color={214,240,255,82}
 for offset=0,w,dash*2 do local stop=math.min(w,offset+dash)
  D.Line(vg,x+offset,y,x+stop,y,color,pixel);D.Line(vg,x+offset,y+h,x+stop,y+h,color,pixel)
 end
 for offset=0,h,dash*2 do local stop=math.min(h,offset+dash)
  D.Line(vg,x,y+offset,x,y+stop,color,pixel);D.Line(vg,x+w,y+offset,x+w,y+stop,color,pixel)
 end
end
function Page:PreparePortrait()
 if self.portrait then return self.portrait end
 self.portrait=CommsPortrait.New('nono')
 local images=self.owner.data.images
 self.portrait.Texture=function(portrait,pose)
  if portrait.faces[pose] then return portrait.faces[pose] end
  local image=images['nono_'..pose];if not image then return nil end
  local texture=cache:GetResource('Texture2D',image);portrait.faces[pose]=texture;return texture
 end
 return self.portrait
end
local function Reveal(vg,x,y,w,h,age,dur)
 local k=math.max(0,math.min(1,age/(dur or .24)));local wide=math.min(1,k/.22);local tall=math.max(1/h,(k-.22)/.78)
 nvgIntersectScissor(vg,x+(1-wide)*w/2-40,y+(1-tall)*h/2-40,w*wide+80,h*tall+80)
 if k>.7 and k<.9 then nvgGlobalAlpha(vg,.5) end
end
function Page:Button(vg,id,label,x,y,w,h,u)
 local hover=Inside({x=x*self.k,y=y*self.k,w=w*self.k,h=h*self.k},self.mouseX or -1,self.mouseY or -1)
 if id:sub(1,4)=='pick' and self.owner.choice then hover=tonumber(id:sub(5))==self.owner.choice end
 local points={x+u,y,x+w,y,x+w-u,y+h,x,y+h};D.Path(vg,points)
 nvgFillColor(vg,D.Color(hover and {142,224,255,255} or {3,10,18,210}));nvgFill(vg)
 nvgStrokeColor(vg,nvgRGBA(214,240,255,102));nvgStrokeWidth(vg,1);nvgStroke(vg)
 D.Text(vg,label,x+2*u,y+1.2*u,2.7*u,hover and {3,20,31,255} or white,'vox-title')
 self.buttons[#self.buttons+1]={id=id,x=x*self.k,y=y*self.k,w=w*self.k,h=h*self.k}
end
function Page:SubmitButton(vg,x,y,w,h,u)
 local I=self.owner;local disabled=I.nameLoading or I.signed or I.pendingSignatureAt~=nil;local cut=1.4*u
 D.Path(vg,{x,y,x+w-cut,y,x+w,y+cut,x+w,y+h,x+cut,y+h,x,y+h-cut})
 nvgFillColor(vg,D.Color(disabled and {28,46,60,255} or {142,224,255,255}));nvgFill(vg)
 if not disabled then
  local center=x+w*(1.35-(I.time%3.2)/3.2*1.7);local spread=w*.375
  for side=0,1 do
   local a=center+(side-1)*spread;local b=a+spread
   local left=math.max(x,a);local right=math.min(x+w,b)
   if right>left then
    nvgSave(vg);nvgIntersectScissor(vg,left,y,right-left,h)
    D.Path(vg,{x,y,x+w-cut,y,x+w,y+cut,x+w,y+h,x+cut,y+h,x,y+h-cut})
    nvgFillPaint(vg,nvgLinearGradient(vg,a,y,b,y,nvgRGBA(240,251,255,side==0 and 0 or 255),nvgRGBA(240,251,255,side==0 and 255 or 0)))
    nvgFill(vg);nvgRestore(vg)
   end
  end
 end
 local label='我已阅读并自愿签署（前往机库）';local color=disabled and {93,122,140,255} or {3,20,31,255}
 local width=D.Width(vg,label,2.5*u,'vox-title');local start=x+(w-width-3.1*u)/2
 nvgBeginPath(vg);nvgMoveTo(vg,start,y+2.75*u);nvgLineTo(vg,start+.6*u,y+3.4*u);nvgLineTo(vg,start+1.9*u,y+1.9*u)
 nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,.35*u);nvgStroke(vg)
 D.Text(vg,label,start+3.1*u,y+1.6*u,2.5*u,color,'vox-title')
 if not disabled then self.buttons[#self.buttons+1]={id='submit',x=x*self.k,y=y*self.k,w=w*self.k,h=h*self.k} end
end
function Page:Snapshot()
 local field=self.nameLabel:GetAbsoluteLayout()
 return {buttons=self.buttons,signature=self.signatureRect,terms=self.termRect,field=field,contract=self.contractLayout,
  ink=self.owner.ink,name=self.owner.name,nameLoading=self.owner.nameLoading,choosing=self.owner.choosing or false,readTerms=self.readTerms or false,
  waitingAdvance=self.owner.waitingAdvance or false,
  choiceExit=self.choiceExit and {index=self.choiceExit.index,at=self.choiceExit.at,elapsed=self.owner.time-self.choiceExit.at} or nil,
  contractMotion=self.contractMotion,contractFieldVisible=self.contractFieldVisible or false,contractFocused=self.contractFocused or false,
  pendingSignature=self.owner.pendingSignatureAt~=nil}
end
local function DialogLayout(page,vg,I,width,u)
 local html=I.line and I.data.lines[I.line] or ''
 local plain=html:gsub('<[^>]+>','');local count=utf8.len(plain) or 0
 local shown=I.finishedTyping and count or math.min(count,math.floor((I.lineAge or 0)/math.max(.6,I.typing or 1)*count))
 local cached=page.dialogText
 if cached and cached.context==vg and cached.html==html and cached.shown==shown and cached.width==width and cached.unit==u then return cached.layout,count,shown end
 local chunks={};local offset=0;local cursor=1;local emphasized=false
 while cursor<=#html do
  local start,stop,tag=html:find('<([^>]+)>',cursor)
  local text=html:sub(cursor,start and start-1 or #html);local n=utf8.len(text) or 0;local take=math.max(0,math.min(n,shown-offset));local byte=utf8.offset(text,take+1)
  if take>0 then chunks[#chunks+1]={text=byte and text:sub(1,byte-1) or text,font='vox-title',size=2.6*u,spacing=.078*u,color=emphasized and red or white} end
  offset=offset+n;if not start then break end;emphasized=tag=='em';cursor=stop+1
 end
 local layout=SourceRichText.Layout(vg,{chunks},width,4.42*u,{font='vox-title',size=2.6*u})
 page.dialogText={context=vg,html=html,shown=shown,width=width,unit=u,layout=layout}
 return layout,count,shown
end
function Page:Comms(vg,w,h,u)
 local I=self.owner;local x=w*.96-48*u;local y=h-84*u;local cx=x+24*u
 local px=((self.mouseX or w*self.k*.5)/self.k/w*2-1);local py=((self.mouseY or h*self.k*.5)/self.k/h*2-1)
 x=x-px*1.2*u;y=y-py*.8*u
 local commsBox={x=x,y=y,w=48*u,h=84*u}
 local commsMotion=ContractMotion.Unfold(I.shot=='comms' and I.age or 1,.24,0,x,y,48*u,84*u,self.cssPixel)
 ContractMotion.Begin(vg,commsMotion,commsBox)
 Panel(vg,x,y,48*u,80*u,u,'comms',I.time,70)
 D.Rect(vg,x+2.2*u,y+1.3*u,.8*u,.8*u,cyan)
 D.Text(vg,'战术通讯 · 加密频道',x+3.8*u,y+1.3*u,1.15*u,ice,'vox-display',nil,.2875*u)
 D.Text(vg,'CH-07 · 坠舰陨坑',x+45.8*u,y+1.3*u,1.15*u,ice,'vox-display',NVG_ALIGN_RIGHT,.2875*u)
 IntroTerminalFx.Projection(vg,x,y,48*u,84*u,u,I.time)
 local face=I.face or 'smile';local path='nono_'..face
 if face=='talk' and I.lineAge and I.lineAge>I.voiceDuration then path='nono_smile' end
 self:PreparePortrait()
 self.portrait.width=56*u*self.k;self.portrait.height=77*u*self.k
 -- Shader effects use CSS pixels of the displayed canvas, not its small RT.
 for _,material in ipairs(self.portrait.materials) do material:SetShaderParameter('canvas_size',Variant(Vector2(56*u*self.k,77*u*self.k))) end
 self.portrait:Prepare(I.time,path,face=='talk' and I.line and I.lineAge<I.voiceDuration)
 self.portrait:Queue();self.portrait:Draw(vg,{x=x-6*u,y=y+3*u+math.sin(I.time*1.9)*.35*u,w=56*u,h=77*u})
 ContractMotion.Scan(vg,commsMotion,u,self.cssPixel);Opacity.Pop(vg)
 if I.shot~='comms' then return end
 local dx=w*.06;local dw=w*.96-51*u-dx
 self.paragraph.size=2.6*u;self.paragraph.lineHeight=4.42*u;self.paragraph.spacing=.078*u
 local textLayout,count,shown=DialogLayout(self,vg,I,dw-7.6*u,u)
 local dh=math.max(17*u,textLayout.height+6.6*u)
 local dy=h*.91-dh;self.dialogRect={x=dx*self.k,y=dy*self.k,w=dw*self.k,h=dh*self.k}
 local dialogBox={x=dx,y=dy,w=dw,h=dh}
 local dialogMotion=ContractMotion.Unfold(I.age,.2,.07,dx,dy,dw,dh,self.cssPixel)
 ContractMotion.Begin(vg,dialogMotion,dialogBox);Panel(vg,dx,dy,dw,dh,u,'dialog',I.time,183)
 local header='INCOMING · 诺诺';local labelSize=1.15*u;local roleSize=1.3*u
 local titleWidth=D.Width(vg,header,labelSize,'vox-display',labelSize*.3);local roleWidth=D.Width(vg,'战术领航员',roleSize,'vox-display',roleSize*.2)
 local headerWidth=2.4*u+titleWidth+1.2*u+roleWidth+1.2*u+4.7*u
 local hx,hy=dx+5.4*u,dy-1.15*u;D.Rect(vg,hx,hy,headerWidth,2.5*u,{3,10,18,204})
 D.Path(vg,{hx,hy,hx+headerWidth,hy,hx+headerWidth,hy+2.5*u,hx,hy+2.5*u});nvgStrokeColor(vg,nvgRGBA(214,240,255,97));nvgStrokeWidth(vg,1);nvgStroke(vg)
 D.Text(vg,header,hx+1.2*u,hy+.55*u,labelSize,ice,'vox-display',nil,labelSize*.3)
 D.Text(vg,'战术领航员',hx+1.2*u+titleWidth+1.2*u,hy+.45*u,roleSize,cyan,'vox-display',nil,roleSize*.2)
 for i=1,9 do local ph=(.15+.85*math.abs(math.sin(I.time*(11+i*2.3)+i*1.7)))*1.4*u;D.Rect(vg,hx+headerWidth-5.9*u+(i-1)*.55*u,hy+1.95*u-ph,.3*u,ph,cyan) end
 SourceRichText.Draw(vg,textLayout,dx+3.8*u,dy+3.6*u)
  if I.waitingAdvance then D.Text(vg,'▼',dx+dw-2.6*u,dy+dh-3.6*u+math.sin(I.time*7.85)*.25*u,2.2*u,cyan,'vox-title',NVG_ALIGN_RIGHT) end
 ContractMotion.Scan(vg,dialogMotion,u,self.cssPixel);Opacity.Pop(vg)
  if I.choosing and not I.choice then self.choiceExit=nil end
  if I.choice and not self.choiceExit then self.choiceExit={index=I.choice,at=I.choiceAt or I.time} end
  local exiting=self.choiceExit
  if I.choosing or exiting and I.time-exiting.at<.32 then
  for i,label in ipairs(I.data.choices) do
    local motion=exiting and ContractMotion.Choice(i,exiting.index,I.time-exiting.at,w) or {alpha=1,x=0,visible=true}
    if motion.visible then
   local bw=6.8*u+D.Width(vg,i,1.6*u,'vox-display')+1.4*u+D.Width(vg,label,2.7*u,'vox-title',.162*u)
   local bx,by=w*.07,h*.7-(18.4-(i-1)*6.6)*u;local bh=5.2*u;local skew=math.tan(math.rad(12))*bh/2
    bx=bx+motion.x
    local hover=Inside({x=bx*self.k,y=by*self.k,w=bw*self.k,h=bh*self.k},self.mouseX or -1,self.mouseY or -1) or exiting and exiting.index==i
   local progress=math.max(0,math.min(1,((I.chooseAge or 1)-(i-1)*.045)/.18))
    Opacity.Push(vg,motion.alpha);Reveal(vg,bx,by,bw,bh,progress,.999)
   local p={bx+skew,by,bx+bw+skew,by,bx+bw-skew,by+bh,bx-skew,by+bh}
   D.Path(vg,p);D.Gradient(vg,bx,by,bw,bh,hover and {232,248,255,255} or {3,10,18,199},hover and {142,224,255,255} or {3,10,18,128},true)
   D.Path(vg,p);nvgStrokeColor(vg,nvgRGBA(214,240,255,102));nvgStrokeWidth(vg,1);nvgStroke(vg)
   D.Line(vg,bx+skew,by,bx-skew,by+bh,cyan,.35*u)
   D.Line(vg,bx+bw+skew+.6*u,by+.6*u,bx+bw-skew+.6*u,by+bh+.6*u,{214,240,255,64},1);D.Line(vg,bx+bw-skew+.6*u,by+bh+.6*u,bx-skew+.6*u,by+bh+.6*u,{214,240,255,64},1)
   local numberWidth=D.Width(vg,i,1.6*u,'vox-display')
   D.Path(vg,{bx+3.4*u-.2*u,by+1.7*u-.12*u,bx+3.4*u+numberWidth+.2*u,by+1.7*u-.12*u,bx+3.4*u+numberWidth+.2*u,by+3.3*u+.12*u,bx+3.4*u-.2*u,by+3.3*u+.12*u});nvgStrokeColor(vg,nvgRGBA(214,240,255,85));nvgStrokeWidth(vg,1);nvgStroke(vg)
   D.Text(vg,i,bx+3.4*u,by+1.7*u,1.6*u,hover and {3,20,31,255} or cyan,'vox-display')
   D.Text(vg,label,bx+4.8*u+D.Width(vg,i,1.6*u,'vox-display'),by+1.2*u,2.7*u,hover and {3,20,31,255} or white,'vox-title',nil,.162*u)
    Opacity.Pop(vg)
    if not exiting then self.buttons[#self.buttons+1]={id='pick'..i,x=bx*self.k,y=by*self.k,w=bw*self.k,h=bh*self.k} end
    end
  end
 end
end
function Page:Contract(vg,w,h,u)
 local I=self.owner;local layout=ContractLayout.Plan(w,h);self.contractLayout=layout
 u=layout.unit
 local terminalMotion,padMotion=ContractMotion.Contract(I,layout,self.cssPixel)
 self.contractMotion={terminal=terminalMotion,pad=padMotion}
 local function HitClip(plan)
  return {x=plan.x*self.k,y=plan.y*self.k,w=plan.w*self.k,h=plan.h*self.k}
 end
 self.contractHitRect=terminalMotion.clipped and HitClip(terminalMotion) or nil
 local x,y,cw,ch=layout.terminal.x,layout.terminal.y,layout.terminal.w,layout.terminal.h;local pw=layout.pad.w
 ContractMotion.Begin(vg,terminalMotion,layout.terminal)
 PanelShadow(vg,x,y,cw,ch,u)
 Panel(vg,x,y,cw,ch,u,'terminal',I.time,180)
 Image(vg,I,'division-insignia',x+3*u,y+1.8*u,4.6*u,4.6*u)
 D.Text(vg,'特别安保部 · 战地人员登记终端',x+9.2*u,y+1.8*u,2.35*u,white,'vox-title')
 D.Text(vg,'FORM SS-07 · 优秀员工战地履约协议',x+9.2*u,y+4.9*u,1.15*u,ice,'vox-display')
 local kv=I.data.employeeFields;local by=y+8.8*u
 self.fieldParagraphs=self.fieldParagraphs or {}
 for i=1,#kv,2 do
  local paragraph=self.fieldParagraphs[i]
  if not paragraph then paragraph=Paragraph.New(1.65*u,2.97*u);paragraph.font='vox-title';self.fieldParagraphs[i]=paragraph end
  paragraph.size=1.65*u;paragraph.lineHeight=2.97*u
  D.Text(vg,kv[i],x+3*u,by,1.65*u,{214,240,255,158},'vox-title')
  self.fieldRuns=self.fieldRuns or {}
  local runs=self.fieldRuns[i]
  if not runs or runs.unit~=u or runs.text~=kv[i+1] then runs={unit=u,text=kv[i+1],content=ContractText.Field(kv[i+1],u)};self.fieldRuns[i]=runs end
  local measure=paragraph:Draw(vg,runs.content,x+14.1*u,by,cw-17.1*u,{238,248,255,255});by=by+math.max(2.97*u,measure.height)
 end
 local tx=x+3*u;local ty=by+1.4*u;local tw=cw-6*u;local th=math.max(10*u,y+ch-12*u-ty)
 D.Rect(vg,tx,ty,tw,th,{0,4,10,77});D.Line(vg,tx,ty,tx,ty+th,{214,240,255,115},1)
 self.termRect={x=tx*self.k,y=ty*self.k,w=tw*self.k,h=th*self.k};self.terms.size=1.4*u;self.terms.lineHeight=2.59*u
 if not self.termParagraphs then self.termParagraphs=ContractText.Terms(I.data) end
 local paragraphs=self.termParagraphs
 local heights={};local content=0
 for i,row in ipairs(paragraphs) do
  local style=ContractText.Style(row,u);row.style=style
  row.paragraph.size=style.size;row.paragraph.lineHeight=style.lineHeight
  if not row.egg or self.readTerms then local m=row.paragraph:Measure(vg,row.text,tw-3.2*u,style.color);heights[i]=m.height;content=content+style.before+m.height else heights[i]=0 end
 end
 self.termMax=math.max(0,content-th+3*u);self.termScroll=math.min(self.termScroll,self.termMax)
 nvgSave(vg);nvgIntersectScissor(vg,tx,ty,tw,th);local sy=ty+1.2*u-self.termScroll
 for i,row in ipairs(paragraphs) do if heights[i]>0 then
  sy=sy+row.style.before
  if row.separator then D.Line(vg,tx+1.6*u,sy-.6*u,tx+tw-1.6*u,sy-.6*u,{214,240,255,31},self.cssPixel or 1) end
  if sy+heights[i]>=ty and sy<=ty+th then
   local layout=row.paragraph:Draw(vg,row.text,tx+1.6*u,sy,tw-3.2*u,row.style.color)
   for _,line in ipairs(layout.lines) do
    local text='';for _,run in ipairs(line.runs) do text=text..run.text end
    local first,last=text:find('见附件七',1,true)
    if first then
     local lx=tx+1.6*u+D.Advance(vg,text:sub(1,first-1),row.style.size,'vox-title');local ly=sy+line.y
     if ly>=ty and ly+line.height<=ty+th then
      local lw=D.Advance(vg,text:sub(first,last),row.style.size,'vox-title');D.Line(vg,lx,ly+line.height-1,lx+lw,ly+line.height-1,cyan,1)
      self.buttons[#self.buttons+1]={id='attachment',x=lx*self.k,y=ly*self.k,w=lw*self.k,h=line.height*self.k,clip=self.contractHitRect}
     end
    end
   end
  end
  sy=sy+heights[i]
 end end
 if not self.readTerms and self.termScroll>=self.termMax-4 and self.termMax>0 then
  self.readTerms=true;I.audio:Sfx('confirm',{vol=.5});self.termScroll=math.huge
 end
 nvgRestore(vg)
 self:SubmitButton(vg,x+3*u,y+ch-9*u,cw-6*u,5.7*u,u)
 local submit=self.buttons[#self.buttons];if submit and submit.id=='submit' then submit.clip=self.contractHitRect end
 local foot=I.age>=90 and '* 记录已提交，欢迎咨询人事部。（人事部电话线路已停用。）' or I.age>=60 and '* 你在本页停留已超过 60 秒。该数据已记录。' or '* 跳过入职培训将被扣除本月绩效考核 0.5 分'
 D.Text(vg,foot,x+cw/2,y+ch-2.7*u,1.15*u,{214,240,255,140},'vox-title',NVG_ALIGN_CENTER)
 if self.attachment then
  Panel(vg,x+cw/2-13*u,ty-4,26*u,16*u,u,'pad',I.time,255)
  for i,line in ipairs({'附件七','状态    已遗失','遗失日期    归档当日','责任方    乙方'}) do D.Text(vg,line,x+cw/2-11*u,ty+(i-1)*3.1*u,1.4*u,i==4 and red or white,'vox-title') end
  table.insert(self.buttons,1,{id='close-attachment',x=(x+cw/2-13*u)*self.k,y=(ty-4)*self.k,w=26*u*self.k,h=16*u*self.k,clip=self.contractHitRect})
 end
 ContractMotion.Scan(vg,terminalMotion,u,self.cssPixel or 1);Opacity.Pop(vg)
 local sx,sy0,sh=layout.pad.x,layout.pad.y,layout.pad.h
 ContractMotion.Begin(vg,padMotion,layout.pad)
 PanelShadow(vg,sx,sy0,pw,sh,u)
 Panel(vg,sx,sy0,pw,sh,u,'pad',I.time,202)
 local marker='SIGN · 签署区 02';local mx,my=sx+3*u,sy0-1.15*u;local mh=2.25*u
 local mw=D.Width(vg,marker,1.15*u,'vox-tabular',.345*u)+2.4*u
 D.Rect(vg,mx,my,mw,mh,{3,10,18,217});D.Path(vg,{mx,my,mx+mw,my,mx+mw,my+mh,mx,my+mh})
 nvgStrokeColor(vg,nvgRGBA(214,240,255,97));nvgStrokeWidth(vg,self.cssPixel or 1);nvgStroke(vg)
 D.Text(vg,marker,mx+1.2*u,my+.55*u,1.15*u,ice,'vox-tabular',nil,.345*u)
 D.Rect(vg,sx+3*u,sy0+3.85*u,.6*u,.6*u,cyan)
 D.Text(vg,'机修师姓名 · TapTap 昵称',sx+4.5*u,sy0+3.4*u,1.5*u,white,'vox-title')
 -- Label 字号使用点数，局部换算源设计像素。
 local pointScale=Theme.FontSize(1)
 local field={left=(sx+3*u)*self.k,top=(sy0+6.1*u)*self.k,width=(pw-6*u)*self.k,height=5*u*self.k,fontSize=2.6*u*self.k/pointScale,
  padding=1.2*u*self.k,paddingLeft=1.6*u*self.k,paddingRight=1.6*u*self.k}
 local box={x=field.left,y=field.top,w=field.width,h=field.height}
 local clipped=padMotion.clipped and ContractMotion.Intersection(box,HitClip(padMotion)) or box
 local clipKey=table.concat({clipped.x,clipped.y,clipped.w,clipped.h},':')
 if self.inputClipKey~=clipKey then self.inputClipKey=clipKey;self.inputClip:SetStyle({left=clipped.x,top=clipped.y,width=clipped.w,height=clipped.h}) end
 field.left=field.left-clipped.x;field.top=field.top-clipped.y
 local key=table.concat({field.left,field.top,field.width,field.height,field.fontSize},':')
 if self.fieldKey~=key then self.fieldKey=key;self.nameLabel:SetStyle(field) end
 local fieldVisible=(self.contractFieldRequested or I.signed) and (I.shot=='contract' or I.shot=='stamp' or I.shot=='gate') and clipped.w>0 and clipped.h>0 and padMotion.alpha>0
 self.contractFieldVisible=fieldVisible or false
 local name=I.nameLoading and '正在获取 TapTap 昵称……' or I.name
 if self.displayedName~=name then self.displayedName=name;self.nameLabel:SetText(name) end
 self.nameLabel:SetVisible(fieldVisible or false);self.nameLabel:SetOpacity(Opacity.Exit(I)*padMotion.alpha)
 D.Rect(vg,sx+3*u,sy0+12.95*u,.6*u,.6*u,cyan)
 D.Text(vg,'本人签名',sx+4.5*u,sy0+12.5*u,1.5*u,white,'vox-title')
 local rx,ry,rw,rh=sx+3*u,sy0+15.1*u,pw-6*u,math.max(10*u,sh-23*u)
 D.Rect(vg,rx,ry,rw,rh,{0,4,10,100});self:UpdateSignatureBounds({x=rx*self.k,y=ry*self.k,w=rw*self.k,h=rh*self.k})
 SignatureBorder(vg,rx,ry,rw,rh,self.cssPixel or 1)
 self.signatureHitRect=padMotion.clipped and ContractMotion.Intersection(self.signatureRect,HitClip(padMotion)) or nil
 if #I.strokes==0 then D.Text(vg,'在此签名（随便画一笔就行，反正也没人看）',rx+1.4*u,ry+rh-2.1*u,1.2*u,{214,240,255,128},'vox-title') end
 nvgSave(vg);nvgIntersectScissor(vg,rx,ry,rw,rh)
 for _,stroke in ipairs(I.strokes) do if #stroke>1 then nvgBeginPath(vg);nvgMoveTo(vg,rx+stroke[1][1]*rw,ry+stroke[1][2]*rh);for i=2,#stroke do nvgLineTo(vg,rx+stroke[i][1]*rw,ry+stroke[i][2]*rh) end;nvgStrokeColor(vg,nvgRGBA(155,232,255,255));nvgStrokeWidth(vg,2.6);nvgStroke(vg) end end
 nvgRestore(vg)
 D.Text(vg,I.error or '',sx+3*u,sy0+sh-5.5*u,1.5*u,red,'vox-title')
 ContractMotion.Scan(vg,padMotion,u,self.cssPixel or 1);Opacity.Pop(vg)
end
function Page:Gate(vg,w,h,u)
 local I=self.owner;local t=I.age;local plan=GateMotion.Plan(t);local split=plan.split
 if not plan.visible then return end
 GateFx.Seam(vg,w,h,u,plan.seam)
 for _,side in ipairs({-1,1}) do
  local x=side==-1 and -w*.502*split or w*.498+w*.502*split
  nvgSave(vg);nvgIntersectScissor(vg,x,0,w*.502,h)
  D.Path(vg,{x,0,x+w*.502,0,x+w*.502,h,x,h});D.Gradient(vg,x,0,w*.502,h,{27,30,34,255},{42,46,51,255},true)
  local total=w*.502-9*u;local cols=side==-1 and {total/2.25,total*1.25/2.25} or {total*1.25/2.25,total/2.25}
  local rowBase=(h-12*u)/3.3;local heights={rowBase,rowBase*1.3,rowBase};local py=5*u
  for row=1,3 do local px=x+4*u
   for col=1,2 do local pw,ph=cols[col],heights[row];local cut=2.2*u
    D.Path(vg,{px+cut,py,px+pw,py,px+pw,py+ph-cut,px+pw-cut,py+ph,px,py+ph,px,py+cut})
    D.Gradient(vg,px,py,pw,ph,{52,57,64,255},{31,34,38,255})
    D.Line(vg,px+cut,py,px+pw,py,{255,255,255,23},1);D.Line(vg,px,py+ph-2,px+pw-cut,py+ph-2,{0,0,0,128},2)
    for _,cx in ipairs({px+1.6*u,px+pw-1.6*u}) do for _,cy in ipairs({py+1.6*u,py+ph-1.6*u}) do
     nvgBeginPath(vg);nvgCircle(vg,cx,cy,.28*u);nvgFillColor(vg,D.Color({154,161,169,255}));nvgFill(vg)
    end end
    if row==2 and col==1 then for yy=py+3*u,py+ph-3*u,1.7*u do D.Rect(vg,px+2*u,yy,pw-4*u,.3*u,{0,0,0,89}) end end
    px=px+pw+u
   end
   py=py+heights[row]+u
  end
  -- Magnify normal cached glyph geometry; a 450px glyph overflows the atlas.
  nvgSave(vg);nvgTranslate(vg,x+w*.25,h*.32);nvgScale(vg,10,10)
  D.Text(vg,side==-1 and '0' or '7',0,0,4*u,{100,117,128,96},'vox-title',NVG_ALIGN_CENTER);nvgRestore(vg)
  for yy=18*u,84*u,4*u do D.Rect(vg,x+(side==-1 and w*.5-2*u or u),yy,u,2*u,{214,240,255,130}) end
  for yy=20*u,80*u,60*u do D.Rect(vg,x+(side==-1 and w*.5-8*u or 6*u),yy,2*u,6*u,t>1.89 and cyan or {255,186,60,255}) end
  local by=h*.76;local bh=4.6*u
  D.Rect(vg,x,by,w*.502,bh,{22,23,26,255})
  nvgSave(vg);nvgIntersectScissor(vg,x,by,w*.502,bh)
  for stripe=-8*u,w*.502+8*u,3.2*u do D.Path(vg,{x+stripe,by,x+stripe+1.6*u,by,x+stripe+bh+1.6*u,by+bh,x+stripe+bh,by+bh});nvgFillColor(vg,D.Color({110,214,255,235}));nvgFill(vg) end
  nvgRestore(vg)
  D.Rect(vg,x+6*u,by+u,35*u,2.6*u,{21,23,26,255});D.Text(vg,'重型闸门 · HEAVY GATE · 第 7 机库',x+7.4*u,by+1.4*u,1.3*u,white,'vox-title')
  if plan.half then GateFx.Lock(vg,I,side==-1 and x+w*.502 or x,h/2,u,plan,Image,true) end
  nvgRestore(vg)
 end
 if not plan.half then GateFx.Lock(vg,I,w/2,h/2,u,plan,Image,false) end
 GateFx.Steam(self,vg,w,h,t)
 if t>.81 and plan.idAlpha>0 then
  Opacity.Push(vg,plan.idAlpha)
  local x=w/2-25*u;local y=8*u;Reveal(vg,x,y,50*u,25*u,t-.81,.22);Panel(vg,x,y,50*u,25*u,u,'terminal',I.time,230)
  local status=plan.ok and cyan or {255,176,46,255};local name=I.name~='' and I.name or '新人'
  D.Rect(vg,x+2.4*u,y+2*u,.8*u,.8*u,status)
  D.Text(vg,'身份核验 · ACCESS CONTROL',x+4*u,y+2*u,1.25*u,cyan,'vox-tabular',nil,.25*u)
  D.Text(vg,'第 7 机库 · 机修师通道',x+47.6*u,y+2*u,1.25*u,cyan,'vox-tabular',NVG_ALIGN_RIGHT,.25*u)
  for i,row in ipairs({{'机修师','NAME',name},{'工号','ID','SS-07-0413'},{'工位','BAY','第 7 机库 · 1 号车台'}}) do
   local ry=y+(5.65+(i-1)*4.4)*u
   D.Path(vg,{x+2.4*u,ry,x+47.6*u,ry,x+47.6*u,ry+3.8*u,x+2.4*u,ry+3.8*u})
   D.Gradient(vg,x+2.4*u,ry,45.2*u,3.8*u,{110,214,255,26},{110,214,255,0},true)
   D.Line(vg,x+2.4*u,ry,x+47.6*u,ry,{110,214,255,71},1)
   D.Text(vg,'>',x+3.4*u,ry+1.1*u,1.6*u,cyan,'vox-tabular')
   D.Text(vg,row[1],x+5.4*u,ry+.65*u,1.45*u,{215,222,228,255},'vox-title')
   D.Text(vg,row[2],x+5.4*u,ry+2.2*u,.85*u,{110,214,255,179},'vox-tabular',nil,.1275*u)
   local valueSize=math.min(2*u,2*u*26*u/math.max(26*u,D.Width(vg,row[3],2*u,'vox-title',.12*u)))
   D.Text(vg,row[3],x+46.2*u,ry+.9*u,valueSize,white,'vox-title',NVG_ALIGN_RIGHT,.12*u)
  end
  D.Rect(vg,x+2.4*u,y+20.05*u,45.2*u,.5*u,{255,255,255,26})
  D.Rect(vg,x+2.4*u,y+20.05*u,45.2*u*math.min(1,(t-.81)/1.1),.5*u,status)
  D.Text(vg,plan.ok and '核验通过 · 欢迎入职，机修师 '..name or '正在核验身份……',x+2.4*u,y+21.55*u,1.6*u,status,'vox-title',nil,.128*u)
  Opacity.Pop(vg)
 end
end
function Page:Render(vg)
 local I=self.owner;if not I.active or I.capturePending then return end
 D.Begin(vg);local vw,vh=UI.GetViewportSize();local k=math.min(vw/1920,vh/1080);self.k=k
 self.cssPixel=1/(k*UI.GetScale()/graphics:GetDPR())
 local w,h=vw/k,vh/k;local u=h/100;self.buttons={};local alpha=Opacity.Exit(I)
 self.nameLabel:SetOpacity(alpha);Opacity.Push(vg,alpha);nvgScale(vg,k,k)
 local impactX,impactY=Impact.Shake(I,u);nvgTranslate(vg,impactX,impactY)
 local id=I.shot
 if id~='contract' and id~='stamp' and (id~='gate' or not I.contractExitAt or I.time-I.contractExitAt>=.3) then self.nameLabel:SetVisible(false) end
 if I.stage=='boot' or I.failed then
  if not I.failed then
   local _,err=self.imageWarmup:Step(vg,I.downloaded)
   if err then I.failed=true;I.error=err end
  end
  local warm=I.host.state and I.host.state.warmup
  if warm and not warm.disposed then
   IntroTypography.Warm(vg)
   local visual=I.host.state.sortieUi;if visual then visual:Warm(vg,w,h) end
  end
  D.Rect(vg,0,0,w,h,{3,10,18,255});Image(vg,I,'company-emblem',w/2-45,h*.29,90,90)
  D.Text(vg,'星际前途有限公司 · 员工终端',w/2,h*.45,3.2*u,white,'vox-title',NVG_ALIGN_CENTER)
  D.Text(vg,'INTERSTELLAR PROSPECTS LTD. · SPECIAL SECURITY DIV.',w/2,h*.51,1.5*u,cyan,'vox-title',NVG_ALIGN_CENTER)
  if I.ready then D.Text(vg,'▶ 点击任意处接入',w/2,h*.64,2.6*u,white,'vox-title',NVG_ALIGN_CENTER) end
  D.Text(vg,I.failed and I.error or I.ready and '入职资料同步完成 · 建议佩戴耳机' or '正在同步入职资料……建议佩戴耳机 · 全程可随时「跳过广告」',w/2,h*.9,1.4*u,I.failed and red or cyan,'vox-title',NVG_ALIGN_CENTER)
  if warm and not warm.disposed then
   local progress=math.max(0,math.min(1,((warm.index or 1)-1+(warm.batch and math.min(1,warm.batch.next/math.max(1,#warm.batch.items)) or 1))/#warm.phases))
   D.Rect(vg,w/2-26*u,h*.76,52*u,.4*u,{26,51,74,255});D.Rect(vg,w/2-26*u,h*.76,52*u*progress,.4*u,cyan)
   D.Text(vg,'实时画面准备 · '..math.floor(progress*100)..'%',w/2,h*.79,1.4*u,cyan,'vox-title',NVG_ALIGN_CENTER)
  end
  if I.failed then self:Button(vg,'close','返回机库',w/2-10*u,h*.74,20*u,5*u,u) end
 elseif id=='comms' or id=='contract' or id=='stamp' or id=='gate' then
  u=ContractLayout.Unit(w,h)
  local exit=id=='gate' and I.contractExitAt and math.max(0,I.time-I.contractExitAt) or 0
  local comms=id~='gate' or I.contractExitAt and exit<.4
  if comms then
   Opacity.Push(vg,id=='gate' and GateMotion.Out(exit,.4) or 1)
   D.Rect(vg,0,0,w,h,{1,7,14,42});IntroTerminalFx.Backdrop(vg,w,h,u,I.time,id=='contract' or id=='stamp' or id=='gate' and I.contractExitAt~=nil)
   Opacity.Pop(vg)
   Opacity.Push(vg,id=='gate' and GateMotion.Out(exit,.3) or 1);self:Comms(vg,w,h,u);Opacity.Pop(vg)
  end
  if id=='contract' or id=='stamp' or id=='gate' and I.contractExitAt and exit<.3 then
   Opacity.Push(vg,id=='gate' and GateMotion.Out(exit,.3) or 1);self:Contract(vg,w,h,u);Opacity.Pop(vg)
  end
  if id=='stamp' or id=='gate' and I.contractExitAt and exit<.5 then
   local stamp=GateMotion.Stamp(id=='stamp' and I.age or 1)
   Opacity.Push(vg,stamp.alpha*(id=='gate' and GateMotion.Out(exit,.5) or 1));nvgTranslate(vg,w*.5,h*.5);nvgRotate(vg,-14*math.pi/180);nvgScale(vg,stamp.scale,stamp.scale)
   Image(vg,I,'company-stamp',-18*u,-18*u,36*u,36*u);Opacity.Pop(vg)
  end
  if id=='gate' then self:Gate(vg,w,h,h/100) end
 else DeferredModules['ui.IntroPromo'].Draw(self,vg,w,h,u) end
 if I.stage=='ad' then
  local size=1.45*u;local spacing=.06*size;local title='跳过广告';local detail='（扣除 0.5 天绩效）';local small=size*5/6
  local tw=D.Width(vg,title,size,'vox-title',spacing);local dw=D.Width(vg,detail,small,'vox-title',spacing)
  local sw=3.2*u+tw+small*.5+dw+2;local sh=size*1.2+1.8*u+2;local x=w*.974-sw;local y=h*.024
  local hover=Inside({x=x*k,y=y*k,w=sw*k,h=sh*k},self.mouseX or -1,self.mouseY or -1)
  D.Rect(vg,x,y,sw,sh,hover and {0,0,0,153} or {0,0,0,89})
  D.Path(vg,{x,y,x+sw,y,x+sw,y+sh,x,y+sh});nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,255,255,56));nvgStroke(vg)
  D.Text(vg,title,x+1.6*u+1,y+.9*u+1,size,hover and white or {255,255,255,158},'vox-title',nil,spacing)
  D.Text(vg,detail,x+1.6*u+1+tw+small*.5,y+.9*u+1+size-small,small,{255,138,106,255},'vox-title',nil,spacing)
  self.skipRect={x=(x+impactX)*k,y=(y+impactY)*k,w=sw*k,h=sh*k};local r=self.skipRect;self.buttons[#self.buttons+1]={id='skip',x=r.x,y=r.y,w=r.w,h=r.h}
 end
 Impact.Flash(vg,I,w,h)
 IntroWipe.Draw(vg,I,w,h,u)
 Opacity.Pop(vg)
end
M.Image=Image
return M
