-- Offline native render verification of the authored scene; no editor control.
local Crater=require("scene.Crater")
local GraphicsSettings=require("render.GraphicsSettings")
local RenderTargetLifetime=require("render.RenderTargetLifetime")
local WindowViewports=require("render.WindowViewports")

local loader=require('app.SceneLoader').New()
local environment,scene,camera,settings
function Start()
    renderer.hdrRendering=true;renderer.shadowMapSize=2048;engine.maxFps=60;engine.maxInactiveFps=60
    loader:Load('Scenes/Crater.xml',function(s)
        local candidate=Crater.New(s)
        local n=s:GetChild('Camera');n.position=Vector3(-350,220,-380);n:LookAt(Vector3(0,5,0))
        local c=n:GetComponent('Camera');c.fov=48;c.farClip=2600
        local graphicsSettings=GraphicsSettings.New({ownsScene=true,isValidation=true})
        local ok,err=pcall(graphicsSettings.Apply,graphicsSettings,s)
        if not ok then graphicsSettings:Dispose();candidate:Dispose();error(err) end
        scene=s;environment=candidate;camera=c;settings=graphicsSettings
        settings:Show(scene,camera);_G.CRATER_PREVIEW={scene=scene,environment=environment,camera=camera,settings=settings}
    end,function(err) error(err) end)
    SubscribeToEvent('Update','HandleUpdate')
end
function HandleUpdate(_,data) local dt=data:GetFloat('TimeStep');RenderTargetLifetime.Update();loader:Update(dt);if settings then settings:Update(dt) end;if environment then environment:Update(dt,camera.node) end;if settings then settings:PostUpdate() end end
function Stop() loader:Cancel();WindowViewports.Stop();if settings then settings:Dispose() end;if environment then environment:Dispose() end;if scene then scene:Dispose() end;RenderTargetLifetime.Flush() end
