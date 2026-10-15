-- Target flashes and world-space health bars follow source TrackView. One health
-- batch and one shared face material; instance data keeps hit feedback independent.
local Batch=require "render.EffectBatch"
local M={};M.__index=M
function M.New(root,targets)
    local self=setmetatable({},M);self.batch=Batch.New(root,"Health",#targets*2)
    self.face=targets[1].models[1].material:Clone()
    assert(self.face:SetSurfaceShader("Shaders/BLGL/Track/Target.shader"))
    for _,t in ipairs(targets) do t.models[1].material=self.face end
    return self
end
local function Rectangle(batch,pos,w,h,color,alpha,right,up)
    local pts={}
    for _,corner in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}}) do
        pts[#pts+1]={pos[1]+right[1]*corner[1]*w/2+up[1]*corner[2]*h/2,
            pos[2]+right[2]*corner[1]*w/2+up[2]*corner[2]*h/2,
            pos[3]+right[3]*corner[1]*w/2+up[3]*corner[2]*h/2}
    end
    batch:Quad(pts,{{0,0},{1,0},{0,1},{1,1}},color,alpha)
end
function M:Update(targets,time,camera,dt)
    local p=camera.worldPosition;local r=camera.worldRotation*Vector3.RIGHT;local u=camera.worldRotation*Vector3.UP
    local right,up={-r.x,r.y,r.z},{-u.x,u.y,u.z};self.batch:Begin({-p.x,p.y,p.z},time)
    for _,t in ipairs(targets) do
        t.fall=t.fall+((t.alive and 0 or 1)-t.fall)*math.min(1,(dt or 0)*(t.alive and 6 or 9))
        t.board.rotation=Quaternion(t.fall*86.4,Vector3.FORWARD)
        t.models[1].instanceCustomData=Vector4(math.max(0,1-(time-t.hitAt)/.15),0,0,0)
        local k=math.max(0,t.hp/t.definition.hp)
        if t.alive and k<.999 then
            local c=t.node.position;local center={-c.x,c.y+3.15,c.z}
            Rectangle(self.batch,center,1.9,.2,{.0052,.0056,.007},.8,right,up)
            for i=1,3 do center[i]=center[i]-right[i]*.9*(1-k) end
            local forward=camera.worldRotation*Vector3.FORWARD
            center[1]=center[1]+forward.x*.01;center[2]=center[2]-forward.y*.01;center[3]=center[3]-forward.z*.01
            local hue=k*1.8;local rgb=hue<1 and {.875,.125+.75*hue,.125} or {.875-.75*(hue-1),.875,.125}
            -- Source HSL colors are sRGB; convert to the linear geometry color ABI.
            for i=1,3 do rgb[i]=((rgb[i]+.055)/1.055)^2.4 end
            Rectangle(self.batch,center,1.8*math.max(.001,k),.12,rgb,1,right,up)
        end
    end
    self.batch:Finish()
end
function M:Dispose()
    self.batch:Dispose()
    -- Target StaticModels still own this material until TrackWorld removes its
    -- root. Drop our reference; never invalidate a material still bound to nodes.
    self.face=nil
end
return M
