local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local Stations=require 'controls.HomeStations'
local app
local originalSize,originalW,originalH,originalScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function Bounds()
    local s=Hud.GetState();s.root:SetStyle({width=1920,height=1080});renderer:GetViewport(0):SetRect(IntRect(0,0,1920,1080))
end
local function Near(a,b) return math.abs(a-b)<.0001 end
local function Replay()
    local f=assert(io.open('tools/migration/source-home-camera.json'));local data=cjson.decode(f:read('*a'));f:close()
    for _,case in ipairs(data.cases) do
        local cam=require('controls.OrbitCamera').New(app.scene);cam.roomLimit=data.limit
        for i,s in ipairs(case.frames) do
            if s.action=='tab' then cam:FlyTo(Stations.Get(case.stats,s.tab,cam.maxDist),.65) end
            local fake={mouseMoveX=s.dx or 0,mouseMoveY=s.dy or 0,mouseMoveWheel=s.wheel or 0,
                GetKeyDown=function() return s.shift==true end,
                GetMouseButtonDown=function(_,b) return (s.action=='rotate' or s.action=='shiftPan') and b==MOUSEB_RIGHT or s.action=='pan' and b==MOUSEB_MIDDLE or s.action=='left' and b==MOUSEB_LEFT end}
            local original=input;input=fake;local ok,err=pcall(cam.Update,cam,s.dt,false,true);input=original;if not ok then error(err) end
            local p,t=cam.node.position,cam.cur.target
            V.assert(Near(p.x,-s.pos[1]) and Near(p.y,s.pos[2]) and Near(p.z,s.pos[3]),case.name..' source orbit position frame '..i)
            V.assert(Near(t.x,-s.target[1]) and Near(t.y,s.target[2]) and Near(t.z,s.target[3]) and Near(cam.cur.dist,s.dist)
                and Near(cam.cur.yaw,s.yaw) and Near(cam.cur.pitch,s.pitch),case.name..' source camera interpolation frame '..i)
            V.assert(cam.autoSpin==s.spin and (cam.flight~=false)==s.flight,case.name..' source camera interruption frame '..i)
            local forward=cam.node.rotation*Vector3.FORWARD
            V.assert(Near(forward.x,-s.forward[1]) and Near(forward.y,s.forward[2]) and Near(forward.z,s.forward[3]),case.name..' clamped source camera direction frame '..i)
        end
        cam.node:Remove()
    end
end
local function FinishFlight()
    if app.camera.flight then app.camera:Step(.65) end
    app.camera.autoSpin=false
end
local function Shot(name)
    local img=Image:new();local ok=graphics:TakeScreenShot(img);local crop=img:GetSubimage(IntRect(0,0,1920,1080))
    V.assert(ok and crop:SavePNG('docs/migration/evidence/pc-camera-'..name..'.png'),'actual PC camera '..name);crop:Dispose();img:Dispose()
end
V.atFrame(60,function()
    app=VOX_HANGAR.app;Replay();FinishFlight()
    _G.VOX_DEBUG={time=10}
    UI.SetScale(1);UI.GetViewportSize=function() return 1920,1080 end;UI.GetWidth=function() return 1920 end;UI.GetHeight=function() return 1080 end
    Hud.Update(0);Bounds()
    V.assert(app.camera.dist>17,'initial actual PC homepage uses vehicle-sized framing')
    Hud.GetState().SetTab('battle');V.assert(app.camera.flight~=false,'real battle tab starts source transition');FinishFlight()
end)
V.atFrame(70,function() Shot('battle');Hud.GetState().SetTab('workshop');FinishFlight() end)
V.atFrame(80,function() Shot('workshop');local p=app.camera.cur.target;V.assert(Near(p.x,-22) and Near(p.z,-2),'workshop source display-wall target');Hud.GetState().SetTab('shop');FinishFlight() end)
V.atFrame(90,function() Shot('shop');local p=app.camera.cur.target;V.assert(Near(p.x,-22) and Near(p.z,8),'shop has distinct source target');Hud.GetState().SetTab('hangar');FinishFlight() end)
V.atFrame(100,function()
    Shot('hangar');Hud.GetState().SetTab('battle');app:EnterBuild();V.assert(not app.camera.flight,'entering edit cancels homepage flight')
    app:ExitBuild();V.assert(app.camera.flight~=false,'return from edit restores source home transition');FinishFlight();Bounds()
    V.assert(app.homeTab=='hangar' and Hud.GetState().tab=='hangar','return from battle edit restores hangar UI and camera together')
end)
V.atFrame(110,function()
    Shot('return')
    local bp=require('build.Prefab').BuildTank(require('build.Blueprint').New())
    app:HomeView('shop');local yaw=app.camera.yaw
    V.assert(app:LoadBlueprint(bp:ToTable()),'vehicle replacement accepts source tank')
    local expected=Stations.Get(app.blueprint:Stats(),'hangar',app.camera.maxDist)
    V.assert(not app.camera.flight and Near(app.camera.dist,expected.dist) and (app.camera.target-Vector3(table.unpack(expected.target))).length<.0001 and app.camera.yaw==yaw,'vehicle replacement refocuses size without inventing new viewing angle')
    UI.GetViewportSize=originalSize;UI.GetWidth=originalW;UI.GetHeight=originalH;UI.SetScale(originalScale)
    _G.VOX_DEBUG=nil;V.finish()
end)
