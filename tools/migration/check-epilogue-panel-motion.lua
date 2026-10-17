package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(v,msg)checks=checks+1;assert(v,msg)end
local function Near(a,b,msg)Check(math.abs(a-b)<.0003,msg..': '..tostring(a)..' / '..tostring(b))end
local noop=function()end
local wall=0;Time={GetSystemTime=function()return wall end}
local Widget={};function Widget:Extend()local c={};c.__index=c;return setmetatable(c,{__call=function(cls,p)return setmetatable(p,cls)end})end
package.loaded['urhox-libs/UI']={Widget=Widget,GetViewportSize=function()return 1600,900 end}
local state={alpha=1,m={1,0,0,1,0,0}};local stack={};local draws={}
local function Multiply(a,b)
 return {a[1]*b[1]+a[3]*b[2],a[2]*b[1]+a[4]*b[2],a[1]*b[3]+a[3]*b[4],a[2]*b[3]+a[4]*b[4],a[1]*b[5]+a[3]*b[6]+a[5],a[2]*b[5]+a[4]*b[6]+a[6]}
end
function nvgSave()stack[#stack+1]={alpha=state.alpha,m={table.unpack(state.m)}}end
function nvgRestore()state=table.remove(stack)end
function nvgTranslate(_,x,y)state.m=Multiply(state.m,{1,0,0,1,x,y})end
function nvgRotate(_,r)local c,s=math.cos(r),math.sin(r);state.m=Multiply(state.m,{c,s,-s,c,0,0})end
function nvgScale(_,x,y)state.m=Multiply(state.m,{x,0,0,y,0,0})end
function nvgGlobalAlpha(_,a)state.alpha=a end
function nvgCreateImage()return 1 end
function nvgImagePattern(_,x,y,w,h,_,image)if image==21 then draws[#draws+1]={kind='portrait',x=x,y=y,w=w,h=h,m={table.unpack(state.m)},alpha=state.alpha}end end
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgFillPaint','nvgFill','nvgImagePatternTinted','nvgRGBA','nvgFillColor','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgIntersectScissor','nvgDeleteImage'})do _G[name]=noop end
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2;NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2
local function Record(kind)draws[#draws+1]={kind=kind,m={table.unpack(state.m)},alpha=state.alpha}end
package.loaded['ui.SourceDraw']={Text=function(_,text)if text=='POW'then Record('impact')end end,Rect=noop,Path=noop,Color=noop,Line=noop,Width=function()return 10 end}
package.loaded['ui.WorkshopPaint']={Image=function()Record('panel')end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function()return 21 end,GetSize=function()return 200,400 end,GetContext=function()return 1 end,Release=noop}
package.loaded['ui.CommsCard']={};package.loaded['ui.IntroTypography']={Begin=noop,Dependencies=function()return{}end}
package.loaded['audio.StoryRadio']={Dependencies=function()return{}end,New=function()return{Play=noop,Update=noop,Dispose=noop}end}
package.loaded['audio.StoryComms']={New=function()return{card=nil,queue={},time=0,Update=noop,Dispose=noop,Hide=noop,SkipLine=noop}end}
local resource={data={scenes={}},images={ep_photo_bg={path='background'},huhu={path='portrait'}}}
package.loaded['core.ResourceData']={Read=function()return resource end}
package.loaded['ui.EpilogueMotion']=assert(load(MOTION_SOURCE))()
local Motion=package.loaded['ui.EpilogueMotion'];local Epilogue=assert(load(EPILOGUE_SOURCE))()
for _,case in ipairs(EXPECTED)do
 local eased,rotation,opacity=Motion.Panel(case.age);Near(eased,case.panel.eased,'source panel easing');Near(rotation,case.panel.rotation,'source panel angle');Near(opacity,case.panel.opacity,'source clamped panel opacity')
 local scale,angle,alpha=Motion.Impact(case.age,case.delay,-11);Near(scale,case.impact.scale,'source impact scale');Near(angle,case.impact.rotation,'source impact angle');Near(alpha,case.impact.opacity,'source impact opacity')
 for _,zoom in ipairs({false,true})do
  local p={bg='ep_photo_bg',rect={5,10,60,75},fromParts={-30,12,'vw'},sfx={'POW','red','right:12%;bottom:10%',-11},deal=case.delay>1,chr={src='huhu',left=10,width=60,top=15,bottom=20}}
  if zoom then p.chr.zoom={-10,-20,130}end
  local root={AddChild=function(self,page)self.page=page;page.parent=self;page.Destroy=noop end,RemoveChild=noop}
  local ep=Epilogue.Attach({},root,noop);ep.rules.current={kind='panel'};ep.rules.time=case.age;ep.rules.age=case.age
  ep.motion:Add({panel=p,at=0},true,0);ep.motion.current.shakeStarts={};draws={};ep.page:Render(1)
  Check(#stack==0,'render state balanced')
  local panel,portrait,impact=nil,nil,nil
  for _,draw in ipairs(draws)do if draw.kind=='panel'then panel=draw elseif draw.kind=='portrait'then portrait=draw elseif draw.kind=='impact'then impact=draw end end
  local x=80+(1-case.panel.eased)*-480;local y=90+(1-case.panel.eased)*192
  local c,s=math.cos(case.panel.rotation*math.pi/180),math.sin(case.panel.rotation*math.pi/180)
  local matrix={c,s,-s,c,x+480-c*480+s*337.5,y+337.5-s*480-c*337.5}
  for i=1,6 do Near(panel.m[i],matrix[i],'actual centered panel transform '..i)end
  local outer=math.min(1,case.age/.8)
  Near(panel.alpha,outer*case.panel.opacity,'actual panel opacity')
  local height=zoom and 675 or .65*675
  local offset=height*.02*(1-case.character)
  Near(portrait.y,zoom and (-.2*675+offset) or (.15*675+offset),'actual portrait float / container height')
  if case.age>case.delay then Check(impact~=nil,'impact rendered after source delay');Near(impact.alpha,outer*case.panel.opacity*case.impact.opacity,'actual impact opacity')
   local a=case.impact.rotation*math.pi/180;local combined=Multiply(matrix,{math.cos(a)*scale,math.sin(a)*scale,-math.sin(a)*scale,math.cos(a)*scale,960*.88,675*.9})
   for i=1,6 do Near(impact.m[i],combined[i],'actual impact transform '..i)end
  else Check(impact==nil,'source backwards-fill impact invisible before delay')end
 end
end
return checks
