local UI=require 'urhox-libs/UI'
---@type integer|nil
local ready=nil
local requested=false
for frame=51,750 do V.atFrame(frame,function()
    local app=VOX_HANGAR.app
    if not requested and not app.loadingFlow.active then
        -- Geometry diagnostic only; bypass account/save/tutorial gates already
        -- covered by the actual Web purchase route, and keep the live renderer.
        requested=true;app.lobby='salvage'
        app.warehouse=app.warehouse or require('scene.Warehouse').New(app)
    end
    if requested and app.warehouse and not app.warehouse.ready then app.warehouse:Update() end
    if app.warehouse and app.warehouse.ready and not ready then ready=frame end
    if ready and frame==ready+30 then
        local camera=app.camera
        camera.flight=false;camera.autoSpin=false
        camera.target=Vector3(0,1.84119,.0198866);camera.dist=13.2012;camera.yaw=215.5234;camera.pitch=15.5155
        camera.cur={target=camera.target,dist=camera.dist,yaw=camera.yaw,pitch=camera.pitch};camera:Apply()
        local octree=app.scene:GetComponent('Octree');local rows={}
        for _,y in ipairs({.1,.2,.3,.5}) do
            local row={y=y,hits={}}
            for _,hit in ipairs(octree:Raycast(camera.camera:GetScreenRay(.5,y),RAY_TRIANGLE,100,DRAWABLE_GEOMETRY)) do
                local model=hit.drawable
                row.hits[#row.hits+1]={node=model.node.name,parent=model.node.parent.name,model=model.model and model.model.name,
                    distance=hit.distance,enabled=model.enabled,material=model.material and model.material.name,
                    pos={hit.position.x,hit.position.y,hit.position.z}}
                if #row.hits>=8 then break end
            end
            rows[#rows+1]=row
        end
        V.assert(#rows==4,'actual warehouse surface samples captured')
        print('WAREHOUSE_SURFACES '..cjson.encode(rows))
        local file=File('docs/migration/evidence/warehouse-surface-probe.json',FILE_WRITE);file:WriteString(cjson.encode(rows));file:Dispose()
    elseif ready and frame==ready+34 then
        local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/warehouse-surface-probe.png');image:Dispose();V.finish()
    end
end) end
V.atFrame(755,function() V.assert(ready~=nil,'actual warehouse became ready');V.finish() end)
