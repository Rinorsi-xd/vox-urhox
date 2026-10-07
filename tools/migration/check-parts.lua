local Defs=require "parts.Defs"
local BP=require "build.Blueprint"
local Prefab=require "build.Prefab"
local Rot=require "core.Rotations"
local Assets=require "parts.PartAssets"
local Rig=require "render.PartRig"
local View=require "render.VehicleView"
local file=assert(io.open("tools/migration/source-parts-fixtures.json","r"))
local fixture=cjson.decode(file:read("*a"));file:close()
---@type VehicleView|nil
local view=nil
V.atFrame(55,function()
    V.assert(#Defs.LIST==fixture.parts,"catalog count equals source")
    for i,m in ipairs(Defs.DATA.rotations) do for k,v in ipairs(m) do
        V.assert(Rot.ROTATIONS[i-1].m[k]==v,"rotation ABI "..i..":"..k)
    end end
    for key,build in pairs({buildRaceCar=Prefab.BuildRaceCar,buildTank=Prefab.BuildTank}) do
        local bp=build(BP.New());local stats=bp:Stats();local expected=fixture.prefabs[key]
        V.assert(bp:Size()==expected.parts and stats.mass==expected.mass and stats.budget==expected.budget,key.." exact count/mass/budget")
        V.assert(bp:Connectivity().floatingCount==expected.floating,key.." connectivity equals source")
        local restored=BP.New():Load(bp:ToTable())
        V.assert(restored:Size()==bp:Size(),key.." lossless save/load")
    end
    local bp=BP.New();local identity=Rot.IDENTITY
    V.assert(not bp:Check("cube",{0,0,0},identity).ok,"floor does not accept disconnected parts")
    V.assert(bp:Check("core",{0,4,0},identity).ok,"first core may anchor blueprint")
    local a=bp:Add{type="half",pos={0,4,0},rot=identity}
    local inverted=Rot.RotIndex({0,-1,0},{0,0,1})
    V.assert(bp:Check("half",{0,4,0},inverted,nil,nil,false).ok,"complementary half blocks share a cell")
    local b=bp:Add{type="half",pos={0,4,0},rot=inverted}
    V.assert(not bp:Check("cube",{0,4,0},identity,nil,nil,false).ok,"full block cannot overlap shared cell")
    bp:Remove(a.id)
    V.assert(bp:PartAt(0,4,0)==b,"removing one occupant preserves other lookup")
    b.shellColor=0x224466
    local restored=BP.New():Load(bp:ToTable())
    V.assert(restored:List()[1].shellColor==b.shellColor,"second paint channel round trip")
    for _,case in ipairs(fixture.legs) do
        local g=Assets.Get(case.type).segments.info
        local actual=require("parts.LegIK").Solve(g,case.target)
        for _,key in ipairs({"yaw","first","second","blade","error"}) do
            V.assert(math.abs(actual[key]-case.expected[key])<1e-7,case.type.." IK "..key)
        end
    end
    view=View.New(VOX_HANGAR.scene,"PartResourceQA")
end)
for index,def in ipairs(Defs.LIST) do
    V.atFrame(55+index,function()
        view:Clear()
        local part={id=index,type=def.id,pos={0,0,0},rot=Rot.IDENTITY,color=def.color}
        local vis=view:AddPart(part)
        V.assert(#vis.models>0,def.id.." native geometry")
        for _,sm in ipairs(vis.models) do
            V.assert(sm.model~=nil and sm.model.numGeometries>0,def.id.." model loaded")
            for i=0,sm.numGeometries-1 do V.assert(sm:GetMaterial(i)~=nil,def.id.." material slot "..i) end
        end
        if def.wheel then
            local mount=vis.node.position
            Rig.SetWheel(vis,{0,0,1},0.2,0.3,1.2)
            V.assert((vis.node.position-mount):Length()<1e-8,def.id.." wheel motion preserves mount")
            Rig.SetWheel(vis,{0,0,1},0,0,0)
            V.assert(vis.rig.steer.position:Length()<1e-6,def.id.." steering pivot returns to rest")
        elseif def.track then
            local first=vis.rig.pads[1].node.position
            Rig.SetTrack(vis,0.5)
            V.assert((vis.rig.pads[1].node.position-first):Length()>0.1,def.id.." belt moves on path")
            Rig.SetTrack(vis,vis.data.segments.path.total)
            V.assert((vis.rig.pads[1].node.position-first):Length()<1e-6,def.id.." belt closes without drift")
        elseif def.weapon then
            Rig.SetWeapon(vis,0.3,0.1,0.8)
            V.assert(vis.head~=nil,def.id.." articulates separately from base")
            Rig.SetWeapon(vis,0,0,0)
        elseif def.leg then
            local g=vis.data.segments.info;local target=g.origins.toe
            Rig.SetLegTarget(vis,target)
            local toe=vis.rig.joints.blade:LocalToWorld(Vector3(-(target[1]-g.origins.blade[1]),target[2]-g.origins.blade[2],target[3]-g.origins.blade[3]))
            local expected=vis.node:LocalToWorld(Vector3(-target[1],target[2],target[3]))
            V.assert((toe-expected):Length()<0.001,def.id.." rig toe matches IK rest target")
        end
    end)
end
V.atFrame(60+#Defs.LIST,function()
    view:Dispose();view=nil
    local app=VOX_HANGAR.app
    V.assert(app.scene:GetChild("PartResourceQA")==nil,"part QA nodes released")
    app:ToggleGallery();app.gallery:Update()
    V.assert(#app.gallery.pending<12,"catalog page progresses incrementally")
    app.gallery:Page(10);app.gallery:Update()
    local count=0;for _ in pairs(app.gallery.view.visuals) do count=count+1 end
    V.assert(count<=12,"catalog holds a bounded page")
    app:ToggleGallery()
    V.assert(app.gallery==nil and app.scene:GetChild("Gallery")==nil,"closing catalog releases instances")
    V.assert(app.scene:GetChild("Car")~=nil,"catalog release preserves player car")
end)
