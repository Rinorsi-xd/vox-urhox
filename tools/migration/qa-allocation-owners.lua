-- QA-only net Lua heap accounting. The external bounded ABA owns GC state.
local M={}
local MAX_FRAMES,MAX_DEPTH=64,128
local boundary='Net collectgarbage(count) KiB while external ABA phase B has automatic GC stopped. Inclusive parents overlap; selfKiB subtracts measured children. Wrapper/clock/engine/native-allocation overhead remains included; Lua bytes are not WASM/GPU bytes or GC CPU time. No observer correction is subtracted. No production optimization or device acceptance follows.'
function M.New(env)
    local gc,phase,frame=assert(env.gc),assert(env.phase),assert(env.frame)
    local self={bindings={},names={},frames={},stack={},depth=0,count=0,active=false,
        invalid=false,issues={},prepared=false,trialPrepared=false,boundary=boundary}
    -- Allocate observer storage before the stopped-collector window.
    for i=1,MAX_DEPTH do self.stack[i]={owner=self} end
    for i=1,MAX_FRAMES do self.frames[i]={rows={},number=0,used=false} end
    local function Invalid(message)
        self.invalid=true
        if #self.issues<8 then self.issues[#self.issues+1]=message end
    end
    local tokenMetatable={__close=function(token,err)
        local after=gc('count')
        if not token.open then return end
        token.open=false
        local row=token.row
        local inclusive=after-token.started
        row.calls=row.calls+1;row.inclusiveKiB=row.inclusiveKiB+inclusive
        row.selfKiB=row.selfKiB+inclusive-token.children
        if err~=nil then row.errors=row.errors+1 end
        if frame()~=token.frame then Invalid('engine frame changed inside allocation owner') end
        if gc('isrunning') or phase()~='B' then Invalid('collector/ABA phase changed inside allocation owner') end
        if self.stack[self.depth]~=token then Invalid('allocation owner nesting changed');return end
        self.depth=self.depth-1
        if self.depth>0 then
            local parent=self.stack[self.depth];parent.children=parent.children+inclusive
        else self.current.measuredKiB=self.current.measuredKiB+inclusive end
    end}
    for _,token in ipairs(self.stack) do setmetatable(token,tokenMetatable) end
    function self:Wrap(object,key,name)
        assert(not self.active and self.count==0,'Prepare allocation owners before B')
        assert(type(object)=='table' and type(object[key])=='function','Missing allocation owner '..name)
        for _,binding in ipairs(self.bindings) do
            assert(not (binding.object==object and binding.key==key),'Duplicate allocation method')
            assert(binding.name~=name,'Duplicate allocation name')
        end
        local id=#self.names+1;self.names[id]=name
        for _,slot in ipairs(self.frames) do slot.rows[id]={calls=0,inclusiveKiB=0,selfKiB=0,errors=0} end
        local original=object[key]
        local function Wrapped(...)
            if not self.active or phase()~='B' then return original(...) end
            if self.depth>=MAX_DEPTH then Invalid('allocation stack capacity');return original(...) end
            self.depth=self.depth+1
            local token=self.stack[self.depth]
            token.row=self.current.rows[id];token.children=0;token.frame=frame();token.open=true
            -- No table.pack/closure/token allocation around a measured call.
            local guard <close> = token
            token.started=gc('count')
            return original(...)
        end
        object[key]=Wrapped
        self.bindings[#self.bindings+1]={object=object,key=key,original=original,wrapped=Wrapped,name=name}
    end
    function self:PrepareCallbacks(callbacks,ui)
        assert(not self.prepared,'Allocation callbacks already prepared')
        local wanted={
            {callbacks,'HandleUpdate','main.Update'},
            {callbacks,'HandlePostUpdate','main.PostUpdate'},
            {callbacks,'HandleFramePresented','main.FramePresented'},
            {ui,'Update','ui.Update'},{ui,'Layout','ui.Layout'},
            {ui,'Render','ui.Render'},{ui,'UpdateInspector','ui.UpdateInspector'},
        }
        for _,item in ipairs(wanted) do
            assert(type(item[1])=='table' and type(item[1][item[2]])=='function','Missing allocation callback '..item[3])
        end
        for _,item in ipairs(wanted) do self:Wrap(item[1],item[2],item[3]) end
        self.prepared=true
    end
    function self:PrepareTrial(app,load)
        assert(self.prepared and not self.trialPrepared,'Prepare live trial once after callback preparation')
        local trial=assert(app and app.trial,'Live trial required')
        assert(not trial.disposed and trial.battle and #trial.world.units==8,'Eight-car battle required')
        load=load or require
        local wanted={
            {'combat.BattleController','BeforeStep','fixed.BeforeStep'},
            {'drive.TrackWorld','Step','fixed.WorldStep'},
            {'combat.BattleController','AfterStep','fixed.AfterStep'},
            {'app.TrialSession','Tick','trial.Tick'},
            {'app.TrialSession','ConsumeWorldEvents','trial.ConsumeWorldEvents'},
            {'combat.CarUnit','Step','unit.Step'},
            {'drive.Vehicle','Step','vehicle.Step'},
            {'drive.Vehicle','StepRotors','vehicle.StepRotors'},
            {'drive.Vehicle','PostStep','vehicle.PostStep'},
            {'combat.WeaponSystem','Step','weapons.Step'},
            {'combat.EnemyDriver','Step','ai.Step'},
            {'physics.Space','Step','physics.Step'},
            {'render.DriveView','Update','playerView.Update'},
            {'render.CombatView','Update','combatView.Update'},
            {'render.CombatView','Consume','combatView.Consume'},
            {'render.WeaponView','Update','weaponView.Update'},
            {'render.VehicleView','UpdateWeaponEffects','vehicleView.UpdateWeaponEffects'},
            {'render.CombatEffects','Update','effects.Update'},
            {'render.CombatEffects','Consume','effects.Consume'},
            {'audio.WeaponAudio','Update','weaponAudio.Update'},
            {'audio.DrivingAudio','Update','drivingAudio.Update'},
            {'audio.DrivingAudio','Observe','drivingAudio.Observe'},
            {'audio.CombatFeedbackAudio','Update','feedbackAudio.Update'},
            {'audio.CollisionAudio','BeforeStep','collisionAudio.BeforeStep'},
            {'audio.CollisionAudio','AfterStep','collisionAudio.AfterStep'},
        }
        -- Resolve and validate all boundaries before mutating modules.
        for _,item in ipairs(wanted) do
            item.object=load(item[1])
            assert(type(item.object[item[2]])=='function','Missing allocation owner '..item[3])
        end
        assert(type(trial.hud)=='table' and type(trial.hud.Update)=='function','Actual trial HUD required')
        for _,item in ipairs(wanted) do self:Wrap(item.object,item[2],item[3]) end
        self:Wrap(trial.hud,'Update','hud.Update')
        self.trialPrepared=true;self.trial=trial
    end
    function self:BeginFrame()
        if phase()~='B' then return false end
        if self.active or self.depth~=0 then Invalid('allocation frame already active');return false end
        if gc('isrunning') then Invalid('allocation frame requires externally stopped GC');return false end
        if self.count>=MAX_FRAMES then Invalid('allocation frame capacity');return false end
        assert(self.trialPrepared,'Allocation trial owners must be prepared before B')
        self.count=self.count+1
        local slot=self.frames[self.count]
        slot.used=true;slot.number=frame();slot.measuredKiB=0
        self.current=slot;self.active=true
        slot.startKiB=gc('count')
        return true
    end
    function self:EndFrame()
        if not self.active then return false end
        local after=gc('count')
        self.active=false
        local slot=self.current
        slot.endKiB=after;slot.netKiB=after-slot.startKiB
        slot.unscopedKiB=slot.netKiB-slot.measuredKiB
        if self.depth~=0 then Invalid('allocation frame ended inside owner') end
        if frame()~=slot.number then Invalid('allocation frame end mismatch') end
        if gc('isrunning') or phase()~='B' then Invalid('allocation frame collector/phase changed') end
        self.current=false
        return true
    end
    function self:Report()
        assert(not self.active and self.depth==0,'Stop allocation capture before reporting')
        local frames,totals={},{}
        for id,name in ipairs(self.names) do totals[id]={name=name,calls=0,inclusiveKiB=0,selfKiB=0,errors=0} end
        for i=1,self.count do
            local slot=self.frames[i];frames[i]=slot
            for id,row in ipairs(slot.rows) do
                local total=totals[id]
                for _,key in ipairs({'calls','inclusiveKiB','selfKiB','errors'}) do total[key]=total[key]+row[key] end
            end
        end
        return {invalid=self.invalid,issues=self.issues,frames=frames,names=self.names,totals=totals,
            bindingCount=#self.bindings,capacity=MAX_FRAMES,boundary=boundary,
            productionMonitorExpectedDisabled=true,observerUsesReusableTokens=true}
    end
    function self:RestoreWrappers()
        assert(not self.active and self.depth==0,'Finish allocation frame before restoring wrappers')
        for i=#self.bindings,1,-1 do
            local b=self.bindings[i]
            if b.object[b.key]==b.wrapped then b.object[b.key]=b.original end
        end
    end
    return self
end
return M
