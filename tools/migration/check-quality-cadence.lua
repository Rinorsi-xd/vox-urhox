local checks=0
for _,case in ipairs({
    {web=true,desktop=false,touch=false,args={},fps=60},
    {web=true,desktop=false,touch=true,args={},fps=30},
    {web=false,desktop=true,touch=false,args={},fps=60},
    {web=false,desktop=false,touch=true,args={},fps=30},
    {web=true,desktop=false,touch=false,args={'-quality=mobile'},fps=30},
    {web=true,desktop=false,touch=true,args={'-quality=desktop'},fps=60},
}) do
    local platform={IsWebPlatform=function() return case.web end,IsDesktopPlatform=function() return case.desktop end}
    local env=setmetatable({GetArguments=function() return case.args end,require=function(name)
        if name=='urhox-libs.Platform.PlatformUtils' then return platform end
        if name=='controls.TouchMode' then return {Enabled=function() return case.touch end} end
        error(name)
    end},{__index=_G})
    local quality=assert(loadfile('scripts/render/Quality.lua','t',env))()
    assert(quality.FrameLimit()==case.fps,'device frame cadence')
    assert(quality.current.name==((case.desktop or case.args[1]=='-quality=desktop') and 'desktop' or 'mobile'))
    checks=checks+1
end
return {result='PASS',checks=checks}
