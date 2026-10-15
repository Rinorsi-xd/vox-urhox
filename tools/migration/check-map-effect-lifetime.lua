local work=nil ---@type thread|nil
V.atFrame(43,function()
    work=coroutine.create(function()
        for _,namespace in ipairs({'EnginePit','Crater'}) do
            local scene=Scene:new();local file=assert(cache:GetFile('Scenes/'..namespace..'.xml'))
            local loaded=scene:LoadXML(file);file:Dispose();V.assert(loaded,'actual authored map loads for lifecycle '..namespace)
            local layout=require('drive.CraterLayout').Begin(namespace)
            require('drive.CraterLayout').Fill(layout,function()coroutine.yield()end)
            local environment=require('scene.'..namespace).New(scene,layout)
            local effects=environment.effects;local air=effects.air
            local camera=scene:GetChild('LifetimeCamera') or scene:CreateChild('LifetimeCamera')
            camera.position=Vector3(0,18,-35)
            environment:Update(1/60,camera)
            V.assert(effects.smoke.batch.numGeometries>0 and effects.dust.batch.numGeometries>0,'actual smoke and dust remain submitted before disposal '..namespace)
            V.assert(air.g.numGeometries>0 and #effects.devils==4,'original wind motes and four dust devils preserved '..namespace)
            environment:Dispose();environment:Dispose()
            V.assert(environment.disposed and environment.effects==nil and environment.skyMaterial==nil,'environment releases owned sky and effect references idempotently '..namespace)
            V.assert(effects.disposed and effects.root==nil and effects.smoke==nil and effects.dust==nil,'smoke and dust native owners released '..namespace)
            V.assert(air.disposed and air.g==nil and air.streak==nil and air.material==nil and air.streakMaterial==nil and air.ground==nil,'wind geometry materials and CPU mask references released '..namespace)
            V.assert(scene:GetChild('CraterAtmosphere')==nil,'real effect root detached by native Dispose '..namespace)
            if namespace=='EnginePit' then
                local deck=require('scene.EnginePitDeck').Get(scene,layout);deck:Dispose();deck:Dispose()
                V.assert(deck.disposed and deck.scene==nil and deck.intact==nil and deck.fallen==nil,'deck weak registry and scene references cleared idempotently')
            end
            scene:Dispose();scene=nil;layout=nil;environment=nil;effects=nil;air=nil
            collectgarbage('collect');cache:ReleaseAllResources(false);coroutine.yield()
        end
        V.finish()
    end)
end)
for frame=44,400 do V.atFrame(frame,function()
    if work and coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);if not ok then error(err) end end
end) end
