-- Bounded helper wall timings; no collector changes or per-call result tables.
local M={}
function M.New(clock)
    local self={enabled=false,rows={},bindings={},tokens={},depth=0,invalid=false}
    local guardMetatable={__close=function(token,err)
        local elapsed=(clock()-token.started)&0xffffffff
        local row=token.row
        row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+elapsed-token.children
        row.maxMs=math.max(row.maxMs,elapsed);if err then row.errors=row.errors+1 end
        if self.tokens[self.depth]~=token then self.invalid=true;return end
        self.depth=self.depth-1
        if self.depth>0 then local parent=self.tokens[self.depth];parent.children=parent.children+elapsed end
    end}
    for i=1,128 do self.tokens[i]=setmetatable({},guardMetatable)end
    function self:Wrap(object,key,name)
        assert(not self.enabled,'Bind helper timings before capture')
        local row={name=name,calls=0,ms=0,selfMs=0,maxMs=0,errors=0};self.rows[#self.rows+1]=row
        local original=assert(object[key])
        local function Wrapped(...)
            if not self.enabled then return original(...)end
            if self.depth>=#self.tokens then self.invalid=true;return original(...)end
            self.depth=self.depth+1;local token=self.tokens[self.depth]
            token.row=row;token.children=0
            local guard <close> = token
            token.started=clock()
            return original(...)
        end
        object[key]=Wrapped
        self.bindings[#self.bindings+1]={object=object,key=key,original=original,wrapped=Wrapped}
    end
    function self:Report()
        assert(not self.enabled and self.depth==0,'Finish helper timing before report')
        return {rows=self.rows,invalid=self.invalid,
            boundary='Integer Time.GetSystemTime wall milliseconds including observer/native binding/GC/preemption. Inclusive scopes overlap; sum selfMs only. Normal automatic GC is running. Not exact thread CPU, Web gain or device FPS.'}
    end
    function self:Restore()
        assert(not self.enabled and self.depth==0,'Finish timing before restoring wrappers')
        for i=#self.bindings,1,-1 do local b=self.bindings[i]
            if b.object[b.key]==b.wrapped then b.object[b.key]=b.original end
        end
    end
    return self
end
return M
