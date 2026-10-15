-- Camera clearance, using authored triangles without duplicate physics meshes.
-- target ---- ray ---- [camera] .35m | solid wall
-- Keep the look direction, shorten only at opaque architecture; ignore vehicle,
-- transparent FX and moving machinery. Room planes also cover mesh seams.
local M={};M.__index=M
function M.New(scene,sceneRoot,roomLimit)
    local root=sceneRoot or assert(scene:GetChild('OrbitalHangar'))
    local solids={}
    for _,model in ipairs(root:GetComponents('StaticModel',true)) do
        local node=model.node;local moving=sceneRoot~=nil and node.parent~=root;local parent=node
        while parent and parent~=root do
            if parent.name:match('^Crane') or parent.name:match('^Drone') or parent.name:match('^DisplayPart') then moving=true;break end
            parent=parent.parent
        end
        local shader=model.material and model.material:GetSurfaceShader()
        if not moving and shader and (shader.name:match('/Surface%.shader$') or shader.name:match('/Deck%.shader$')) then solids[model]=true end
    end
    return setmetatable({root=root,octree=scene:GetComponent('Octree'),solids=solids,limit=roomLimit or require('scene.HangarConfig').layout.cameraLimit},M)
end
function M:Resolve(target,position)
    if not self.root.enabled then return position end
    local b=self.limit;local margin=.35
    local origin=Vector3(math.max(-b.x+margin,math.min(b.x-margin,target.x)),
        math.max(b.y0+margin,math.min(b.y1-margin,target.y)),math.max(b.z0+margin,math.min(b.z1-margin,target.z)))
    local delta=position-origin;local length=delta.length
    if length<.001 then return origin end
    local dir=delta/length;local distance=length
    for _,axis in ipairs({'x','y','z'}) do
        local low=axis=='x' and -b.x or axis=='y' and b.y0 or b.z0
        local high=axis=='x' and b.x or axis=='y' and b.y1 or b.z1
        if math.abs(dir[axis])>.00001 then
            local edge=dir[axis]>0 and high-margin or low+margin
            distance=math.min(distance,math.max(0,(edge-origin[axis])/dir[axis]))
        end
    end
    -- Stationary menu cameras reuse the last query; spinning previews query as they move.
    if self.lastOrigin and (origin-self.lastOrigin).length<.0001 and (position-self.lastPosition).length<.0001 then return self.lastResult end
    for _,hit in ipairs(self.octree:Raycast(Ray(origin,dir),RAY_TRIANGLE,distance+margin,DRAWABLE_GEOMETRY)) do
        if self.solids[hit.drawable] and hit.distance>margin then distance=math.min(distance,math.max(.05,hit.distance-margin)) end
    end
    local result=origin+dir*distance
    self.lastOrigin=origin;self.lastPosition=position;self.lastResult=result
    return result
end
return M
