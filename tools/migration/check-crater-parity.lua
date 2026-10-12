-- Fixed review cameras from the source terrain-sample.js. Source X is mirrored.
local views={
    {name='fort',eye={70,28,-200},at={0,8,-272},lens=26},
    {name='ship',eye={-150,45,-190},at={0,0,0},lens=24},
    {name='interior',eye={100,-5,-20},at={-40,-2,10},lens=20},
}
local label='current'
for _,arg in ipairs(GetArguments()) do label=arg:match('^%-parity%-label=([%w-]+)$') or label end
local configured=false
local function Pose(v)
    local p=assert(CRATER_PREVIEW,'crater preview not loaded')
    if not configured then
        dofile('tools/migration/check-crater-authoring.lua').Check(p)
        local settings=p.settings
        settings:Apply(p.scene);configured=true
        local zone=p.scene:GetComponent('Zone',true)
        V.assert(settings.post and not zone:GetAttribute('Bloom Enable'):GetBool(),'native tonemap disabled before H5 HDR post chain')
        V.assert(settings.post.graph.passCount==29 and not settings.tonemap,'H5 bloom, mist, grade and lens own the final image')
        V.assert(p.scene:SaveXML('.tmp/CraterParityBound.xml'),'serialize production native settings')
        local lamps=p.environment.effects.root:GetChildrenWithComponent('Light',false)
        V.assert(#lamps==6,'all source interior and fortress lamps exist')
        local first=lamps[1]:GetComponent('Light')
        V.assert(first:GetBrightness()==1400 and first:GetRange()==90,'source lamp photometry survives native binding')
    end
    local aspect=graphics:GetWidth()/graphics:GetHeight()
    p.camera.node.position=Vector3(-v.eye[1],v.eye[2],v.eye[3])
    p.camera.node:LookAt(Vector3(-v.at[1],v.at[2],v.at[3]))
    p.camera.fov=2*math.atan(18/v.lens/aspect)*180/math.pi
    p.environment.time=10
    print('[CraterParity] '..v.name..' '..graphics:GetWidth()..'x'..graphics:GetHeight()..' fov='..p.camera.fov)
end
for i,v in ipairs(views) do
    local frame=120+(i-1)*40
    V.atFrame(frame,function() Pose(v) end)
    V.atFrame(frame+30,function()
        local image=Image:new()
        V.assert(graphics:TakeScreenShot(image),'render formal '..v.name)
        V.assert(image:SavePNG('docs/migration/evidence/crater-native-'..label..'-'..v.name..'.png'),'save formal '..v.name)
        image:Dispose()
    end)
end
V.atFrame(235,function()
    V.assert(configured,'production graphics applied')
    local graph=CRATER_PREVIEW.settings.post.graph
    local f=File('docs/migration/evidence/crater-post-allocation.json',FILE_WRITE)
    f:WriteString(cjson.encode({width=graph.width,height=graph.height,passes=graph.passCount,color_bytes=graph.colorBytes,
        limits='Owned FP16 color targets only; excludes engine depth, shadow and other scratch allocations; not a GPU timing measurement'}));f:Dispose()
    V.finish()
end)
