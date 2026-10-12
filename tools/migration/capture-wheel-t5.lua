-- Same T5 and orthographic views as the original H5 part-size ruler.
-- Uses the running app's VehicleView, rig and materials; temporary validation only.
local evidence='docs/migration/evidence/'
---@type Scene|nil
local reviewScene=nil
local views={}
local cameras={}
V.atFrame(50,function()
    local app=assert(VOX_HANGAR).app
    local UI=require 'urhox-libs/UI'
    UI.SetRoot(UI.Panel{width=0,height=0})
    local R=require 'core.Rotations'
    app.car:Clear()
    app.car.root.position=Vector3.ZERO
    local part={id=1,type='drive5',pos={0,0,0},rot=R.IDENTITY,color=0xffc21a}
    local visual=app.car:AddPart(part)
    reviewScene=app.scene
    app.car:SetVisible(true)
    -- Keep the real hangar lighting/materials, hide room meshes in this
    -- inspection camera so depth-disabled holograms cannot cover the tire.
    for _,kind in ipairs({'StaticModel','CustomGeometry','BillboardSet','Skybox'}) do
        for _,drawable in ipairs(reviewScene:GetComponents(kind,true)) do drawable:SetViewMask(1) end
    end
    for _,model in ipairs(visual.models) do model:SetViewMask(2) end
    local f=assert(io.open('tools/migration/source-wheel-size.json'))
    local data=cjson.decode(f:read('*a'));f:close()
    local expected
    for _,case in ipairs(data.cases) do
        if case.part.type=='drive5' and case.part.rot==R.IDENTITY then expected=case;break end
    end
    assert(expected)
    local a,b=expected.whole.min,expected.whole.max
    local center=Vector3(-(a[1]+b[1])/2,(a[2]+b[2])/2,(a[3]+b[3])/2)
    local function CameraView(name,offset,up,rect)
        local node=reviewScene:CreateChild(name)
        node.position=center+offset;node:LookAt(center,up)
        local c=node:CreateComponent('Camera');c.orthographic=true
        c:SetViewMask(2)
        cameras[#cameras+1]=c
        c.orthoSize=6*460/640;c.autoAspectRatio=false;c.aspectRatio=640/460
        -- Ruler view: exclude intervening hangar walls/ceiling, retain the
        -- entire wheel (radius < 2.3 m around a target 30 m away).
        c.nearClip=26;c.farClip=34
        local vp=Viewport:new(reviewScene,c);vp:SetRect(rect);return vp
    end
    views[1]=CameraView('Tread',Vector3(-30,0,0),Vector3.UP,IntRect(0,0,640,460))
    views[2]=CameraView('Hub',Vector3(0,30,0),Vector3(-1,0,0),IntRect(0,0,640,460))
    renderer:SetNumViewports(1)
    renderer:SetViewport(0,views[1])
    V.assert(#visual.models>0,'T5 uses actual app car assembly and production materials')
end)
local function Shot(name)
    local image=Image:new()
    V.assert(graphics:TakeScreenShot(image),'capture T5 tread and hub')
    local crop=image:GetSubimage(IntRect(0,0,640,460))
    V.assert(crop:SavePNG(evidence..'wheel-t5-native-'..name..'.png'),'save T5 '..name)
    crop:Dispose();image:Dispose()
end
V.atFrame(60,function() Shot('tread');renderer:SetViewport(0,views[2]) end)
V.atFrame(70,function() Shot('hub');V.finish() end)
