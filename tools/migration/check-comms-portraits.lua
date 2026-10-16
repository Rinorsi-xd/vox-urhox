package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function equal(actual,expected,label)
    checks=checks+1
    assert(type(actual)==type(expected),label..' type')
    if type(actual)=='number' then assert(math.abs(actual-expected)<1e-8,label..': '..actual..' ~= '..expected)
    else assert(actual==expected,label) end
end
local Layout=require 'ui.CommsPortraitLayout'
for _,case in ipairs(SOURCE.cases) do
    local image=IMAGES[case.name]
    local sx,sy,ox,oy=Layout.Fit(case.size[1],case.size[2],image.width,image.height)
    equal(sx,case.scale[1],case.name..' fit x');equal(sy,case.scale[2],case.name..' fit y')
    equal(ox,case.offset[1],case.name..' offset x');equal(oy,case.offset[2],case.name..' offset y')
end
for who,rect in pairs(RECTS) do for key,value in pairs(rect) do equal(Layout.Rect(who)[key],value,who..' CSS '..key) end end
for _,case in ipairs(CONTAIN) do
    local image=IMAGES[case.name];local rect=Layout.Contain(Layout.Rect(case.who),image.width,image.height,case.who=='boss')
    for key,value in pairs(case.rect) do equal(rect[key],value,case.name..' contain '..key) end
end
for _,case in ipairs(EMBLEMS) do
    local x,y,scale=Layout.Emblem(case.height)
    equal(x,case.x,'yun SVG x');equal(y,case.y,'yun SVG y');equal(scale,case.scale,'yun SVG scale')
end
local function none() end
local web=false
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return web end}
local Portrait=require 'ui.CommsPortrait'
local function ExpectedPath(name)
    if name=='chairman_cut' then return 'Story/Boss/chairman_cut.png' end
    return (name:match('^nono_') and 'Intro/Images/' or 'UI/Faces/')..name..'.png'
end
for name in pairs(IMAGES)do
    if name~='chairman_cut' then
        local who,face=name:match('^([^_]+)_(.+)$')
        equal(Portrait.Path(who,face),ExpectedPath(name),name..' actual short-face resource path')
        equal(Portrait.Path(who,name),ExpectedPath(name),name..' actual prefixed-face resource path')
    end
end
local patterns,paths={},{}
local transforms=0
local draw=setmetatable({Color=function(c)return c end,Width=function()return 0 end},{__index=function()return none end})
package.loaded['ui.SourceDraw']=draw;package.loaded['ui.CommsFrame']={Shape=none,Draw=none}
package.loaded['ui.SourceParagraph']={New=function()return {Measure=function()return {height=20} end,Draw=none} end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function(path)paths[#paths+1]=path;return 1 end,
    GetSize=function(path)local name=path:match('([^/]+)%.png$');local image=IMAGES[name];assert(image,'unknown image '..path);return image.width,image.height end}
package.loaded['ui.CommsPortrait']={Path=Portrait.Path,New=function()return {Prepare=function()return false end,Queue=none,Dispose=none} end}
for _,name in ipairs({'nvgSave','nvgRestore','nvgBeginPath','nvgRect','nvgFillPaint','nvgFillColor','nvgFill','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgCircle','nvgScale','nvgGlobalAlpha','nvgIntersectScissor','nvgFontBlur'})do _G[name]=none end
nvgTranslate=function(_,x,y)transforms=transforms+1;if x~=166 and (x~=0 or y~=0)then patterns.translate={x,y}end end
nvgRGBA=function(...)return {...}end;nvgRadialGradient=none;nvgLinearGradient=none
nvgImagePatternTinted=none;nvgCreateImage=function()return 1 end
nvgImagePattern=function(_,x,y,w,h)patterns[#patterns+1]={x=x,y=y,w=w,h=h};return {}end
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2;NVG_ALIGN_RIGHT=4
local Card=require 'ui.CommsCard'
for _,case in ipairs(CONTAIN) do
    patterns={};paths={};transforms=0
    Card.Draw(1,{who=case.who,face=case.name,text='source subtitle',age=1,typing=.5,finishedTyping=true,enteredAt=0},0,0,646,196,1,1)
    equal(#patterns,1,case.name..' image draw count')
    local image=patterns[1]
    for key,value in pairs(case.rect)do equal(image[key],value,case.name..' actual Card '..key)end
    equal(paths[#paths],ExpectedPath(case.name),case.name..' actual path')
    equal(transforms,2,case.name..' fallback does not add RT flip')
end
for _,case in ipairs(EMBLEMS)do
    patterns={};paths={}
    Card.Draw(1,{who='yun',text='source subtitle',age=0,typing=1,enteredAt=0},0,0,646,case.height,1,0,case.height)
    equal(patterns.translate[1],case.x,'actual yun x');equal(patterns.translate[2],case.y,'actual yun y')
    equal(#paths,0,'yun has emblem rather than face')
end
package.loaded['audio.AudioLevels']={}
package.loaded['audio.StoryCommsCues']={Dependencies=function()return {'test-cue'}end}
package.loaded['story.MissionData']={voices={}}
local dependencies=require('audio.StoryComms').Dependencies();local found={}
for _,path in ipairs(dependencies)do found[path]=true end
for name in pairs(IMAGES)do
    equal(found[ExpectedPath(name)],true,name..' dependency')
    if name:match('^nono_') then equal(found['UI/Faces/'..name..'.png'],nil,name..' obsolete dependency absent') end
end
package.loaded['ui.CommsPortrait']=Portrait
nvgCreateVideo=function(_,texture)return texture end
nvgImagePatternTinted=function(_,x,y,w,h,_,image)return {image=image}end
nvgImagePattern=function(_,x,y,w,h,_,image)return {image=image}end
NVG_ONE=1;NVG_ZERO=0
nvgGlobalCompositeBlendFuncSeparate=none
for _,mode in ipairs({false,true})do
    web=mode
    for _,rect in ipairs({{x=-70,y=-2,w=330,h=410},{x=-3,y=-16,w=156,h=195},
        {x=128,y=71,w=532,h=731},{x=18,y=-14,w=460,h=632}})do
        local matrix={sx=1,sy=1,tx=0,ty=0};local stack={};local samples={}
        nvgSave=function()stack[#stack+1]={sx=matrix.sx,sy=matrix.sy,tx=matrix.tx,ty=matrix.ty}end
        nvgRestore=function()matrix=table.remove(stack)end
        nvgTranslate=function(_,x,y)matrix.tx=matrix.tx+x*matrix.sx;matrix.ty=matrix.ty+y*matrix.sy end
        nvgScale=function(_,x,y)matrix.sx=matrix.sx*x;matrix.sy=matrix.sy*y end
        nvgFillPaint=function(_,paint)
            samples[#samples+1]={image=paint.image,top=matrix.ty+rect.y*matrix.sy,
                bottom=matrix.ty+(rect.y+rect.h)*matrix.sy,left=matrix.tx+rect.x*matrix.sx}
        end
        local portrait=setmetatable({ready=true,images={},textures={101,102}},Portrait)
        portrait:Draw(1,rect)
        equal(#samples,2,'RT coverage and RGB both draw')
        for i,sample in ipairs(samples)do
            equal(sample.image,100+i,'RT copy identity')
            equal(sample.left,rect.x,'RT x retained')
            equal(sample.top,mode and rect.y+rect.h or rect.y,'RT upper edge')
            equal(sample.bottom,mode and rect.y or rect.y+rect.h,'RT lower edge')
        end
        equal(#stack,0,'RT transform restored')
        equal(matrix.sy,1,'RT does not leak vertical transform')
    end
end
return checks
