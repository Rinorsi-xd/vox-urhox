package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks,events={},{}
local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
local function none()end
local UI={GetViewportSize=function()return 1920,1080 end}
UI.Widget={Extend=function()
 local Page={};Page.__index=Page
 return setmetatable(Page,{__call=function(_,props)return setmetatable(props,Page)end})
end}
package.loaded['urhox-libs/UI']=UI
package.loaded['ui.LoadingFx']={New=function()return {Draw=none}end}
package.loaded['ui.MatchLobby']={Draw=function()events[#events+1]='opaque'end}
package.loaded['ui.SourceButtonMotion']={Ease=function(x)return x end}
package.loaded['ui.WorkshopPaint']={Image=none,Radial=none}
package.loaded['ui.SourceDraw']={Begin=none,Text=none,Gradient=none,Path=none,Panel=none,Icon=none,
 Color=function(color)return color end,white={255,255,255,255},orange={255,154,60,255},ink={},muted={},
 Rect=function(_,x,y,w,h,color)if x==0 and y==0 and w==1920 and h==1080 and color[4]==255 then events[#events+1]='opaque'end end}
for _,name in ipairs({'nvgSave','nvgRestore','nvgScale','nvgScissor','nvgBeginPath','nvgRect','nvgFillPaint','nvgFillColor','nvgRadialGradient','nvgRGBA','nvgFill','nvgTranslate','nvgRotate','nvgGlobalAlpha','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgArc'})do _G[name]=none end
if LOADING_PAGE_SOURCE then package.preload['ui.LoadingPage']=function()return assert(load(LOADING_PAGE_SOURCE,'@candidate-LoadingPage.lua'))()end end
local LoadingPage=require 'ui.LoadingPage'
local flow={active=true,pageVisible=true,phase='loading',elapsed=1,time=0,progress=.2,steps={{id='scene',label='scene',note=''}},current=1,
 map={boot=true,name='map'},PageRendered=function()events[#events+1]='page'end,
 commsWarmup={Draw=function(_,vg)check(vg==17,'warmup uses stable page UI context');events[#events+1]='warm'end}}
local page=LoadingPage.New(flow);page.fx={Draw=none}
for _,boot in ipairs({true,false})do
 flow.map.boot=boot
 for _,phase in ipairs({'loading','ready'})do
  events={};flow.phase=phase;page:Render(17)
  check(events[1]=='warm' and events[2]=='opaque' and events[#events]=='page','portrait submits before actual opaque '..(boot and 'boot' or 'map')..' page during '..phase)
 end
 for _,phase in ipairs({'cover','reveal','boot-exit','exit-cover','exit-reveal'})do
  events={};flow.phase=phase;page:Render(17)
  check(not table.concat(events,','):find('warm'),'portrait never leaks into partial/fading cover during '..phase)
 end
end
flow.phase='loading'
for _,key in ipairs({'pageVisible','active'})do
 flow[key]=false;events={};page:Render(17);check(not table.concat(events,','):find('warm'),key..' guard stops hidden portrait draw');flow[key]=true
end
flow.failed=true;events={};page:Render(17);check(not table.concat(events,','):find('warm'),'failed loading never queues additional portrait work')
return {count=#checks,checks=checks}
