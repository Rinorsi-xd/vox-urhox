-- QA-only recorder. Replay accepted quads; never reevaluate effects or RNG.
local M={};M.__index=M
local function Copy(value)
    if type(value)~='table' then return value end
    local result={};for key,item in pairs(value)do result[key]=Copy(item)end;return result
end
function M.New(batch,tagAtPosition)
    local self=setmetatable({batch=batch,frame={entries={}},activeTag=false},M)
    self.begin=batch.Begin;self.quad=batch.Quad;self.finish=batch.Finish
    local disc=batch.Disc
    batch.Begin=function(object,camera,time)
        self.frame={camera=Copy(camera),time=time,entries={}}
        return self.begin(object,camera,time)
    end
    batch.Disc=function(object,position,...)
        local previous=self.activeTag;self.activeTag=tagAtPosition(position)or false
        local result=table.pack(pcall(disc,object,position,...));self.activeTag=previous
        if not result[1]then error(result[2],0)end
        return table.unpack(result,2,result.n)
    end
    batch.Quad=function(object,points,uvs,color,alpha,params)
        local before=object.count
        local result=table.pack(self.quad(object,points,uvs,color,alpha,params))
        if object.count>before then
            local entries=self.frame.entries
            entries[#entries+1]={points=Copy(points),uvs=Copy(uvs),color=Copy(color),alpha=alpha,
                params=Copy(params),tag=Copy(self.activeTag)}
        end
        return table.unpack(result,1,result.n)
    end
    return self
end
function M:Snapshot()
    assert(self.frame.camera and self.frame.time,'At least one actual batch Begin required')
    assert(#self.frame.entries==self.batch.count,'All accepted batch quads captured')
    return Copy(self.frame)
end
function M:Replay(frame,omit)
    self.begin(self.batch,frame.camera,frame.time)
    local removed=0
    for _,entry in ipairs(frame.entries)do
        if omit and omit(entry)then removed=removed+1
        else self.quad(self.batch,entry.points,entry.uvs,entry.color,entry.alpha,entry.params)end
    end
    self.finish(self.batch)
    assert(self.batch.count==#frame.entries-removed,'Replay must preserve all unmasked accepted quads')
    return {original=#frame.entries,removed=removed,retained=self.batch.count,enabled=self.batch.mesh.enabled}
end
return M
