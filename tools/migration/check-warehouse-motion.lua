local data=require('core.ResourceData').Read('Warehouse/Manifest.json')
local f=assert(io.open('tools/migration/source-warehouse-motion.json'));local source=cjson.decode(f:read('*a'));f:close()
local stage='boot';local saved=nil ---@type table|nil
local savedModels={}
local function Check(warehouse)
    local motion=warehouse.motion;local count=0;for _ in pairs(motion.nodes) do count=count+1 end
    V.assert(count==7,'all authored moving joints retained')
    local triangles,moving=0,0
    for i,d in ipairs(data.models) do
        triangles=triangles+d.triangles
        local n=warehouse.batches[i];savedModels[i]=n:GetComponent('StaticModel').model
        V.assert(n.parent==(d.motion and motion.nodes[d.motion] or warehouse.root),'batch has its original nearest moving joint '..i)
        if d.motion then moving=moving+1 end
    end
    V.assert(triangles==5844 and moving==20,'original triangles retained once; articulated meshes and trader anchor separated')
    for _,sample in ipairs(source.samples) do
        motion:Update(sample.time);local actual=motion:Snapshot()
        for id,expected in pairs(sample.nodes) do
            for _,key in ipairs({'position','quaternion','scale'}) do for i,value in ipairs(expected[key]) do
                V.assert(math.abs(actual.nodes[id][key][i]-value)<.00002,'source joint '..sample.time..' '..id..' '..key..i)
            end end
            for _,p in ipairs({{0,0,0},{.25,.4,-.6}}) do
                local world=motion.nodes[id]:LocalToWorld(Vector3(-p[1],p[2],p[3]));local m=expected.matrix
                local want={m[1]*p[1]+m[5]*p[2]+m[9]*p[3]+m[13],m[2]*p[1]+m[6]*p[2]+m[10]*p[3]+m[14],m[3]*p[1]+m[7]*p[2]+m[11]*p[3]+m[15]}
                V.assert((world-Vector3(-want[1],want[2],want[3])):Length()<.00005,'source world transform '..sample.time..' '..id)
            end
        end
    end
    for i,n in ipairs(warehouse.batches) do V.assert(savedModels[i]==n:GetComponent('StaticModel').model,'animation never rebuilds geometry '..i) end
    motion:Update(0);saved=motion
end
local function Poll()
    local app=VOX_HANGAR and VOX_HANGAR.app
    if not app then return end
    if stage=='boot' then
        V.assert(app.bays:Save(1),'save before switching lobby');require('ui.GarageHud').GetState().SetLobby('salvage');stage='loading'
    elseif stage=='loading' and app.warehouse and app.warehouse.ready then
        Check(app.warehouse);require('ui.GarageHud').GetState().SetLobby('arena');stage='dispose'
    elseif stage=='dispose' and not app.warehouse then
        V.assert(saved.disposed and not next(saved.nodes),'leaving warehouse disposes animation joints')
        local time,updates=saved.time,saved.updates
        saved:Update(99);V.assert(saved.time==time and saved.updates==updates,'disposed animation rejects stale update')
        savedModels={};stage='done';V.finish()
    end
end
for frame=45,240 do V.atFrame(frame,Poll) end
V.atFrame(245,function() V.assert(stage=='done','warehouse lifecycle completes '..stage);V.finish() end)
