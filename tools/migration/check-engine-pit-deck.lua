local work=nil ---@type thread|nil
local scene=nil ---@type Scene|nil
local function Near(a,b) return math.abs(a-b)<.0001 end
V.atFrame(43,function()
    work=coroutine.create(function()
        scene=Scene:new();local resource=cache:GetFile('Scenes/EnginePit.xml');local loaded=scene:LoadXML(resource);resource:Dispose()
        V.assert(loaded,'actual EnginePit scene loads source fallen resource')
        local world=require('drive.EnginePitWorld').New(scene,true)
        local batches=0;require('drive.CraterPhysics').Build(world,function()batches=batches+1;if batches%64==0 then coroutine.yield()end end)
        local deck=world.deck
        V.assert(#deck.physics.deck==3 and #deck.physics.fallen==18,'source three intact and eighteen fallen real Bullet colliders retained')
        local function Visible(root) local n=0;for _,m in ipairs(root:GetComponents('StaticModel',true)) do if m.enabledEffective then n=n+1 end end;return n end
        local visible=Visible(deck.intact)
        V.assert(visible==3 and Visible(deck.fallen)==0,'source intact geometry visible and fallen geometry fully hidden')
        local file=File('tools/migration/source-engine-pit-deck-fixtures.json',FILE_READ);local fixtures=cjson.decode(file:ReadString());file:Dispose()
        for i,f in ipairs(fixtures.containsCases) do V.assert(deck:Contains(f.x,f.z,f.margin)==f.expected,'actual frozen deck.contains strict edge '..i) end
        local center=deck.center;local ray=world:CastRay({center[1],10,center[3]},{0,-1,0},30,nil)
        V.assert(ray and Near(ray.point[2],deck.top),'intact source center ray hits real support at two metres')
        local box=scene:CreateChild('SleepingDeckVehicle');box.position=require('core.Coord').Vec(center[1],deck.top+.5,center[3]);box:CreateComponent('CollisionShape'):SetBox(Vector3.ONE)
        local body=box:CreateComponent('RigidBody');body.mass=10;body.friction=.8
        for i=1,360 do world.space:Step(1/60);if i%6==0 then coroutine.yield() end end
        V.assert(not body.active,'real dynamic body sleeps on intact support before collapse')
        deck:Collapse()
        V.assert(deck.collapsed and body.active and Near(deck.dustT,.9),'source collapse wakes sleeping dynamic body and starts point-nine-second dust')
        V.assert(Visible(deck.intact)==0 and Visible(deck.fallen)==3,'collapse swaps actual source child StaticModels')
        for i,b in ipairs(deck.physics.deck) do V.assert(not b.enabled,'collapse disables actual intact collider '..i) end
        for i,b in ipairs(deck.physics.fallen) do V.assert(b.enabled,'collapse enables actual fallen collider '..i) end
        ray=world:CastRay({center[1],10,center[3]},{0,-1,0},30,{native=body})
        V.assert(ray and ray.point[2]<deck.top-2,'collapsed center ray reaches source pit instead of invisible support')
        for i=1,60 do world.space:Step(1/60);if i%6==0 then coroutine.yield() end end
        V.assert(box.position.y<deck.top-1,'actual dynamic body falls through removed deck support')
        deck:Collapse();V.assert(Near(deck.dustT,.9),'source repeated collapse is idempotent')
        local seed=fixtures.randomSeedAtFirstUpdate;local function Random()seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end
        local dust=require('render.EnginePitDust').New(scene,deck,Random);deck.dust=dust
        for _,f in ipairs(fixtures.smokeCases) do deck:Update(1/30);dust:Step(1/30)
            V.assert(dust.origins[1].rate==f.rate and #dust.parts==f.count,'original buildSmoke rate and bounded pool frame '..f.frame)
            for i=#dust.parts,1,-1 do local p=dust.parts[i];local j=(#dust.parts-i)*4;local k=p.age/p.life
                V.assert(Near(p.x,f.puff[j+1]) and Near(p.y,f.puff[j+2]) and Near(p.z,f.puff[j+3]) and Near(p.r*(1+k*3.2),f.puff[j+4]),'source smoke physical position and radius frame '..f.frame..'/'..i)
                V.assert(Near(math.min(1,p.age/1.5)*(1-k)^1.4*(.35+.4*p.dark),f.look[j+1]) and Near(p.seed,f.look[j+2]) and Near(.85+.6*(1-p.dark)*k,f.look[j+3]) and Near(p.rot+p.age*.08,f.look[j+4]),'source smoke alpha seed brightness rotation frame '..f.frame..'/'..i)
            end
            if f.frame%6==0 then coroutine.yield() end
        end
        world:Reset();V.assert(not deck.collapsed and deck.dustT==0 and dust.origins[1].rate==0,'world reset restores source deck and stops new dust emission')
        V.assert(Visible(deck.intact)==visible and Visible(deck.fallen)==0,'reset restores original geometry masks')
        ray=world:CastRay({center[1],10,center[3]},{0,-1,0},30,nil);V.assert(ray and Near(ray.point[2],deck.top),'reset restores real source support collision')
        local camera=scene:GetChild('Camera'):GetComponent('Camera');camera.node.position=require('core.Coord').Vec(center[1]+70,45,center[3]-65);camera.node:LookAt(require('core.Coord').Vec(center[1],0,center[3]),Vector3.UP)
        require('urhox-libs/UI').GetRoot():SetVisible(false)
        renderer:SetViewport(0,Viewport:new(scene,camera));deck:Collapse();deck:Update(1/30);dust:Update(1/30,3,camera.node)
        V.assert(dust.batch.enabled and #dust.parts>0,'original source dust compiles and submits a real billboard batch')
        coroutine.yield();coroutine.yield();local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/engine-pit-deck-native.png');image:Dispose()
        world:Dispose();scene:Dispose();V.finish()
    end)
end)
for frame=44,700 do V.atFrame(frame,function()if work and coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);if not ok then error(err) end end end) end
