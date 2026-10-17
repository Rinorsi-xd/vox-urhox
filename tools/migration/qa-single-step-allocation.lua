-- Isolated diagnosis only: one fixed step, bounded stopped-GC heap accounting.
local M={}
function M.New(env)
    local gc=assert(env.gc);local clock=assert(env.clock)
    local limit=env.limitKiB or 16384;local deadline=env.deadlineMs or 250
    local capacity=env.capacity or 8;local depthLimit=128
    assert(limit>0 and limit<=16384 and capacity>=1 and capacity<=32)
    local self={bindings={},names={},ids={},frames={},stack={},depth=0,count=0,active=false,
        restored=true,aborted=false,error=false,limitKiB=limit,deadlineMs=deadline,modeUntouched=true}
    for i=1,depthLimit do self.stack[i]={} end
    for i=1,capacity do self.frames[i]={rows={}} end
    local function Restore()
        if not self.active then return end
        if self.originalRunning then gc('restart')else gc('stop')end
        self.restored=gc('isrunning')==self.originalRunning
        self.active=false
        assert(self.restored,'Single-step collector running state restore failed')
    end
    local function CheckBudget(after)
        if self.aborted then return end
        local elapsed=(clock()-self.startedMs)&0xffffffff
        local reason=after-self.startedKiB>limit and 'single-step growth limit' or elapsed>deadline and 'single-step deadline' or false
        if reason then self.aborted=true;self.error=reason;Restore();error(reason)end
    end
    local tokenMeta={__close=function(token,err)
        local after=gc('count')
        if not token.open then return end;token.open=false
        local inclusive=after-token.before;local row=token.row
        row.calls=row.calls+1;row.inclusiveKiB=row.inclusiveKiB+inclusive
        row.selfKiB=row.selfKiB+inclusive-token.children;row.maxKiB=math.max(row.maxKiB,inclusive)
        if err~=nil then row.errors=row.errors+1 end
        assert(self.stack[self.depth]==token,'Single-step allocation stack changed')
        self.depth=self.depth-1
        if self.depth>0 then self.stack[self.depth].children=self.stack[self.depth].children+inclusive
        else self.current.measuredKiB=self.current.measuredKiB+inclusive end
        if err==nil and not self.aborted then
            assert(not gc('isrunning'),'Collector unexpectedly restarted inside a sample')
            CheckBudget(after)
        end
    end}
    for _,token in ipairs(self.stack)do setmetatable(token,tokenMeta)end
    function self:Wrap(object,key,name)
        assert(not self.active and self.count==0,'Bind before first stopped-GC step')
        assert(type(object)=='table' and type(object[key])=='function','Missing allocation boundary '..name)
        for _,binding in ipairs(self.bindings)do assert(binding.object~=object or binding.key~=key,'Duplicate method')end
        local id=self.ids[name]
        if not id then
            id=#self.names+1;self.names[id]=name;self.ids[name]=id
            for _,slot in ipairs(self.frames)do slot.rows[id]={calls=0,inclusiveKiB=0,selfKiB=0,maxKiB=0,errors=0}end
        end
        local original=object[key]
        local function Wrapped(...)
            if not self.active then return original(...)end
            assert(self.depth<depthLimit,'Single-step allocation nesting capacity')
            self.depth=self.depth+1;local token=self.stack[self.depth]
            token.row=self.current.rows[id];token.children=0;token.open=true
            local guard <close> = token
            token.before=gc('count')
            return original(...)
        end
        object[key]=Wrapped
        self.bindings[#self.bindings+1]={object=object,key=key,original=original,wrapped=Wrapped,name=name}
    end
    function self:Capture(step,fn,...)
        assert(not self.active and self.depth==0 and not self.aborted,'Cannot nest/reuse aborted sample')
        assert(self.count<capacity,'Single-step allocation sample capacity')
        self.originalRunning=gc('isrunning');assert(self.originalRunning,'Begin each step with automatic GC running')
        self.count=self.count+1;local slot=self.frames[self.count]
        slot.step=step;slot.measuredKiB=0;slot.modeUntouched=true;self.current=slot
        self.startedMs=clock();self.startedKiB=gc('count');slot.startKiB=self.startedKiB
        self.restored=false;self.active=true;gc('stop')
        local ok,err=xpcall(fn,function(value)return value end,...)
        local after=gc('count');slot.endKiB=after;slot.netKiB=after-slot.startKiB
        slot.unscopedKiB=slot.netKiB-slot.measuredKiB;slot.wallMsDiagnosticOnly=(clock()-self.startedMs)&0xffffffff
        if ok then ok,err=pcall(CheckBudget,after)end
        Restore();assert(self.depth==0,'Single-step allocation scopes must unwind')
        slot.restored=self.restored;slot.complete=ok;slot.error=not ok and tostring(err)or false
        self.current=false
        if not ok then self.aborted=true;self.error=err;error(err)end
        return slot
    end
    function self:Restore()
        Restore()
        for i=#self.bindings,1,-1 do local b=self.bindings[i]
            if b.object[b.key]==b.wrapped then b.object[b.key]=b.original end
        end
    end
    function self:Report()
        assert(not self.active and self.depth==0,'Report after restored single step')
        local frames,totals={},{}
        for i,name in ipairs(self.names)do totals[i]={name=name,calls=0,inclusiveKiB=0,selfKiB=0,maxKiB=0,errors=0}end
        for i=1,self.count do local slot=self.frames[i];frames[i]=slot
            for id,row in ipairs(slot.rows)do local total=totals[id]
                total.calls=total.calls+row.calls;total.inclusiveKiB=total.inclusiveKiB+row.inclusiveKiB
                total.selfKiB=total.selfKiB+row.selfKiB;total.maxKiB=math.max(total.maxKiB,row.maxKiB);total.errors=total.errors+row.errors
            end
        end
        return {frames=frames,totals=totals,names=self.names,bindingCount=#self.bindings,aborted=self.aborted,
            restored=self.restored,modeUntouched=self.modeUntouched,limitKiB=limit,deadlineMs=deadline,
            allocationValidity=not self.aborted and self.restored and 'COMPLETE_SAMPLES_ONLY' or 'INVALID_ABORTED_CAPTURE',
            timingValidity='INVALID_FOR_PERFORMANCE',
            boundary='One synchronous fixed step per stopped-GC interval. Net Lua heap accounting includes native binding/observer costs; parent inclusive overlaps children. Stop/restart does not alter collector mode. Budget/deadline checked at every instrumented method exit and step exit; a single uninstrumented native call is not preempted. No CPU/FPS or device performance conclusion.'}
    end
    return self
end
return M
