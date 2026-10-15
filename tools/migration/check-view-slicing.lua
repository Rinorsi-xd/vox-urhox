local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local DriveView=require 'render.DriveView'
local job=nil ---@type thread|nil
local function Run()
    local scene=Scene();scene:CreateComponent('Octree')
    local bp=Prefab.Create(BP.New(),'feather')
    local vehicle=Vehicle.New(Space.New(scene),Spec.Build(bp))
    local sync=DriveView.New(scene:CreateChild('Synchronous'),bp,vehicle)
    local retained=nil;local count,last=0,0;local monotonic=true
    local sliced=DriveView.New(scene:CreateChild('Sliced'),bp,vehicle,function(p)
        monotonic=monotonic and p>=last and p<=1;last=p;count=count+1
        V.assert(retained~=nil,'assembly owner exists before slice '..count)
        if count%8==0 then coroutine.yield() end
    end,function(view) retained=view end)
    V.assert(sliced==retained and count>#bp:List() and last==1 and monotonic,'actual sliced flight view completes with monotonic preparation progress')
    local same=true
    for _,part in ipairs(bp:List()) do
        local a,b=sync.view.visuals[part.id],sliced.view.visuals[part.id]
        same=same and a.node.position==b.node.position and a.node.rotation==b.node.rotation and #a.models==#b.models
        for i,model in ipairs(a.models) do same=same and model.model==b.models[i].model and model.instanceColor==b.models[i].instanceColor end
    end
    V.assert(same,'yielding preserves every actual part transform, model and color')
    V.assert(#sync.wings==#sliced.wings and #sync.wheels==#sliced.wheels and #sync.tracks==#sliced.tracks,'yielding preserves actuator and flight bindings')
    local a,b=sync.view:GetWorldBounds(),sliced.view:GetWorldBounds()
    V.assert(a.min==b.min and a.max==b.max,'sliced and synchronous rendered bounds match')
    local cancelledParent=scene:CreateChild('Cancelled');local cancelled=nil
    local pending=coroutine.create(function()
        DriveView.New(cancelledParent,bp,vehicle,function() coroutine.yield() end,function(view) cancelled=view end)
    end)
    local ok,err=coroutine.resume(pending);if not ok then error(err) end
    V.assert(cancelled~=nil and coroutine.status(pending)=='suspended','real assembly can be cancelled after its first part')
    cancelled:Dispose();coroutine.close(pending)
    V.assert(cancelledParent:GetNumChildren()==0,'cancelled assembly disposes its vehicle and equipment nodes')
    sync:Dispose();sliced:Dispose();vehicle:Dispose();scene:Dispose();V.finish()
end
V.atFrame(50,function() job=coroutine.create(Run) end)
for frame=51,100 do V.atFrame(frame,function()
    if job and coroutine.status(job)~='dead' then local ok,err=coroutine.resume(job);if not ok then error(err) end end
end) end
