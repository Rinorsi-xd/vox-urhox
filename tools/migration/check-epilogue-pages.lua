package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(a,b,message) Check(math.abs(a-b)<.0002,message) end
local noop=function()end
local wall,w,h=0,1600,900
Time={GetSystemTime=function() return wall end}
local Widget={}
function Widget:Extend()
    local class={};class.__index=class
    return setmetatable(class,{__call=function(cls,props) return setmetatable(props,cls) end})
end
local UI={Widget=Widget,GetViewportSize=function() return w,h end}
package.loaded['urhox-libs/UI']=UI
local stack,state,draws,videos={}, {alpha=1,x=0,y=0},{},{}
local deletedVideos,deletedImages=0,0
function nvgSave() stack[#stack+1]={alpha=state.alpha,x=state.x,y=state.y} end
function nvgRestore() state=table.remove(stack) end
function nvgTranslate(_,x,y) state.x=state.x+x;state.y=state.y+y end
function nvgGlobalAlpha(_,alpha) state.alpha=alpha end
function nvgCreateImage() return 1 end
function nvgCreateVideo(_,texture) videos[101]=texture;return 101 end
function nvgDeleteVideo(_,handle) Check(videos[handle]~=nil,'owned video bridge deleted once');videos[handle]=nil;deletedVideos=deletedVideos+1 end
function nvgDeleteImage() deletedImages=deletedImages+1 end
function nvgImagePattern(_,_,_,_,_,_,handle)
    if videos[handle] then draws[#draws+1]={path='video',alpha=state.alpha,x=state.x,y=state.y} end
end
for _,name in ipairs({'nvgRotate','nvgScale','nvgBeginPath','nvgRect','nvgFillPaint','nvgFill','nvgImagePatternTinted','nvgRGBA','nvgFillColor','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgIntersectScissor'}) do _G[name]=noop end
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2;NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2
KEY_ESCAPE=1;KEY_RETURN=2;KEY_SPACE=3
package.loaded['ui.SourceDraw']={Text=noop,Rect=noop,Path=noop,Color=noop,Line=noop,Width=function() return 10 end}
package.loaded['ui.WorkshopPaint']={Image=function(_,path) draws[#draws+1]={path=path,alpha=state.alpha,x=state.x,y=state.y} end}
local released={}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function()return 1 end,GetSize=function()return 10,10 end,GetContext=function()return 1 end,Release=function(p)released[p]=true end}
package.loaded['ui.CommsCard']={}
package.loaded['ui.IntroTypography']={Begin=noop,Dependencies=function()return{}end}
local cues={}
package.loaded['audio.StoryRadio']={Dependencies=function()return{}end,New=function()return{Play=function(_,id)cues[#cues+1]=id end,Update=noop,Dispose=noop}end}
package.loaded['audio.StoryComms']={New=function()return{card=nil,queue={},time=0,Update=noop,Dispose=noop,Hide=noop,SkipLine=noop}end}
local function Panel(bg,shot) return {bg=bg,shot=shot,rect={0,0,100,100}} end
local resource={data={scenes={{page=true,panel=Panel('a')},{panel=Panel('b')},{page=true,panel=Panel('c',{'capture'})}}},
    images={a={path='a'},b={path='b'},c={path='c'}}}
package.loaded['core.ResourceData']={Read=function()return resource end}
package.loaded['ui.EpilogueMotion']=assert(load(MOTION_SOURCE))()
local Motion=package.loaded['ui.EpilogueMotion']
local Epilogue=assert(load(EPILOGUE_SOURCE))()
local root={AddChild=function(self,page)self.page=page;page.parent=self;page.Destroy=function(p)p.destroyed=true end end,
    RemoveChild=function(self,page) Check(self.page==page,'only owned page removed');page.parent=nil end}
local ep=Epilogue.Attach({},root,noop,{capture={width=32,height=32}})
local function Advance(ms) wall=ms;ep.rules:Next();ep:Update(0,true) end
Advance(0);Advance(100);Advance(200)
local layers=ep.motion and ep.motion.pages or {{panels=ep.panels}}
Check(#layers==2 and #layers[1].panels==2 and #ep.panels==1,'new page retains old two panels and current public alias')
Check(#cues==3,'original panel pickup events unchanged')
ep.rules.time=1
for _,case in ipairs(EPILOGUE_EXPECTED) do
    wall=case.at;ep:Update(0,true);draws={};ep.page:Render(1)
    Check(#stack==0,'actual render balances drawing state')
    Check(#ep.motion.pages==(case.retiredRemoved and 1 or 2),'original 500ms old page removal')
    Check(#draws==(case.alpha>0 and 3 or 1),'actual draw retains old page through its fade')
    local alpha,x,y=Motion.Alpha(ep.motion.current,wall/1000),Motion.Offset(ep.motion.current,h,wall/1000)
    Near(alpha,1,'new page independent opacity');Near(x,case.x,'source new-page horizontal shake');Near(y,case.y,'source new-page vertical shake')
    for _,draw in ipairs(draws) do
        if draw.path~='video' then Near(draw.alpha,case.alpha,'source old-page CSS ease opacity in actual renderer');Near(draw.x,case.oldX,'retired page keeps active source horizontal shake');Near(draw.y,case.oldY,'retired page keeps active source vertical shake')
        else Near(draw.x,case.x,'actual page transform reaches new panel draw');Near(draw.y,case.y,'actual vertical page transform reaches draw') end
    end
end
local alive=ep.motion.current
ep:Dispose();ep:Dispose()
Check(not ep.active and #ep.motion.pages==0 and ep.motion.current==nil and #alive.panels==0,'dispose releases current and retired layers idempotently')
Check(deletedVideos==1 and deletedImages==1 and next(ep.page.captures)==nil and next(ep.shots)==nil,'dispose releases bridge, dots and texture references once')
Check(released.a and released.b and released.c,'all original image releases retained')
wall=10000;ep:Update(100,true);Check(#ep.motion.pages==0,'late update cannot revive disposed page')
return checks
