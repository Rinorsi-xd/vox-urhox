-- Hold only the reactor color at the H5 breathing extrema; no production edits.
local factor=.6
local readyFrame
local function Configure()
    local p=assert(CRATER_PREVIEW);local camera=p.camera
    camera.node.position=Vector3(-100,-5,-20);camera.node:LookAt(Vector3(40,-2,10))
    camera.fov=2*math.atan(18/20/(graphics:GetWidth()/graphics:GetHeight()))*180/math.pi
    local update=p.environment.Update
    p.environment.Update=function(self,dt,node)
        self.time=10;update(self,0,node)
        for _,g in ipairs(self.glows) do if g.kind=='breath' then
            g.material:SetShaderParameter('tint',Variant(Vector4(g.color[1]*factor,g.color[2]*factor,g.color[3]*factor,1)))
        end end
    end
end
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'capture reactor '..name)
    V.assert(image:SavePNG('docs/migration/evidence/crater-native-breath-'..name..'.png'),'save reactor '..name);image:Dispose()
end
-- Scene loading is asynchronous; do not mistake a loading-screen PNG for a map.
for frame=1,350 do V.atFrame(frame,function()
    if not readyFrame and CRATER_PREVIEW then Configure();readyFrame=frame end
    if readyFrame and frame==readyFrame+30 then Shot('dim');factor=1 end
    if readyFrame and frame==readyFrame+60 then Shot('bright');V.finish() end
end) end
V.atFrame(355,function() V.assert(readyFrame~=nil,'crater scene loaded before capture deadline') end)
