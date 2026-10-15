-- Reproduce the obstructed city-road shot with the actual map and camera.
local stage='boot';local app=nil ---@type HangarApp|nil
local shotTime=4.7;local frames=0
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;app.bays:Save(1)
        require('ui.GarageHud').GetState().SetLobby('salvage');stage='warehouse'
    elseif stage=='warehouse' and app.warehouse and app.warehouse.ready then
        V.assert(app:EnterTrial('salvage'),'enter actual map');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then
        local s=app.trial;local run=s.salvage
        for _,spawn in ipairs(s.world.layout.salvage.spawns) do
            if spawn.name=='城西公路' then run.spawn=spawn;run.player.spawnAt=spawn;break end
        end
        V.assert(run.spawn.name=='城西公路','same obstructed source spawn')
        s.Update=function() end;run.cine:Drop();stage='camera'
    elseif stage=='camera' then
        local s=app.trial;local cine=s.salvage.cine
        cine.current.t=shotTime;cine:StepShot(cine.current);cine:HoldCar();cine:Camera()
        frames=frames+1
        if frames==20 then
            local p=cine.cameraResolved;local r=cine.shot
            local delta=Vector3(-r.pos.x,r.pos.y,r.pos.z)-p
            print('[SalvageCamera] original='..tostring(r.pos)..' resolved='..tostring(p)..' delta='..delta:Length())
            V.assert(delta:Length()>1,'reproduced obstruction changes camera position')
            local image=Image();V.assert(graphics:TakeScreenShot(image),'capture exact obstructed shot')
            V.assert(image:SavePNG('docs/migration/evidence/salvage-cine-city-camera.png'),'save shot evidence')
            image:Dispose();stage='done';V.finish()
        end
    end
end
for frame=45,800 do V.atFrame(frame,Poll) end
V.atFrame(805,function() V.assert(stage=='done','camera reproduction completed '..stage);V.finish() end)
