local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
package.loaded['ui.VoxTheme']={}
package.loaded['controls.TouchMode']={Apply=function() end}
package.loaded['ui.DriveControls']={Create=function() return {} end}
package.loaded['urhox-libs/UI']={GetViewportSize=function() return 1600,900 end,Panel=function() return {AddChild=function() end} end}
local buttons={}
package.loaded['ui.DriveChrome']=function(props)
    if props.kind=='exit' and not props.course then error('COURSES_CAPTURED') end
    if props.course then buttons[props.text]=props end
    return {}
end
local Hud=assert(load(HUD_CODE,'@scripts/ui/DriveHud.lua'))()
local trial=assert(io.open('scripts/app/TrialSession.lua','r')):read('*a')
local first=assert(trial:find('function M:GoTo(name)',1,true));local last=assert(trial:find('\nfunction M:Flip()',first,true))
local Session=assert(load('local M={}\n'..trial:sub(first,last-1)..'\nreturn M','@actual-GoTo'))()
for i,case in ipairs(fixtures.cases) do
    local trace={};local session=setmetatable({disposed=not case.active,vehicle={legMode=true},map={id='trial'},weapons={},world={layout={teleports=case.available and {{name='节足山坡'},{name='节足抓墙'}} or {}}},app={toasts={}}}, {__index=Session})
    function session:Reset() trace[#trace+1]={'spawn',self.world.layout.teleports[self.teleport].name} end
    function session:Resume() trace[#trace+1]={'resume'} end
    function session.app.toasts:Push(...) trace[#trace+1]={'toast',...} end
    buttons={};local ok,err=pcall(Hud.Create,session)
    Check(not ok and tostring(err):find('COURSES_CAPTURED',1,true)~=nil,'case '..i..' actual HUD creates course buttons before adapter boundary')
    Check(buttons['练习：山坡'] and buttons['练习：抓墙 / 跳跃'],'case '..i..' both real course callbacks captured')
    if case.name=='missing' then
        -- The source accepts arbitrary names; the two actual buttons only expose valid course names.
        Check(not Session.GoTo(session,case.name),'case '..i..' actual GoTo rejects missing target')
    else
        buttons[case.name=='节足山坡' and '练习：山坡' or '练习：抓墙 / 跳跃'].onClick()
    end
    Check(Same(trace,case.trace),'case '..i..' source valid/invalid/disposed teleport, info6000 and resume order')
end
return checks
