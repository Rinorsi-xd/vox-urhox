-- Diagnostic wall timings, not thread CPU or GPU timestamps. No gameplay changes.
local M={};M.__index=M
local LIMIT=80
-- 日志限流：手机低帧时几乎每帧都算慢帧，完整明细（约 28 KB/条）几十秒就写满 5 MB 反馈日志。
-- 尖峰帧（≥SPIKE_MS）每 SPIKE_GAP 毫秒最多一条，普通慢帧每 SLOW_GAP 毫秒最多一条；被跳过的计数写进每秒样本。
local SPIKE_MS=150
local SPIKE_GAP=250
local SLOW_GAP=2000
local DETAIL_STAGES=24
local scopeMetatable={__close=function(token,err)
    if err then
        local m=token.monitor;m.errors=m.errors or {}
        if #m.errors<16 then m.errors[#m.errors+1]=token.name..': '..tostring(err):sub(1,1200) end
    end
    token.monitor:End(token)
end}
local function Now() return Time:GetSystemTime() end
local function Delta(a,b) return (a-b)%4294967296 end
local function Percentile(values,p)
    if #values==0 then return 0 end
    return values[math.max(1,math.ceil(#values*p))]
end
function M.New(options)
    local self=setmetatable({},M);self:init(options or {});return self
end
function M:init(options)
    self.clock=options.clock or Now;self.threshold=options.threshold or LIMIT
    self.enabled=options.enabled~=false;self.frame=0;self.recording=false;self.closed=false
    self.session=options.session or (os.date('%Y%m%d-%H%M%S')..'-'..tostring(self.clock()))
    self.stages={};self.stageOrder={};self.stacks=setmetatable({},{__mode='k'});self.tokenOrder=0
    self.wrapped=setmetatable({},{__mode='k'});self.restores=setmetatable({},{__mode='k'})
    self.ring={};self.window={};self.sampleDrops=0;self.slowFrames=0;self.discardedAsyncSpans=0
    self.windowStages={};self.steadyStages={};self.steadyFrames=0;self.suppressedSlow=0;self.suppressedSpikes=0
    self.lastSlowEmit=nil;self.lastSpikeEmit=nil
    self.startedAt=self.clock();self.lastSample=self.startedAt;self.lastFlush=self.startedAt
    self.maxMs=0;self.p95Ms=0;self.lastEvent='';self.stepsTotal=0
    self.sink=options.sink;self.noFile=options.noFile==true;self.segment=0;self.fileBytes=0
    self.logPath='performance/'..self.session;self.fileError='';self.lastSnapshot={enabled=self.enabled};self.phases={}
    if self.enabled then
        self:Emit({type='session',thresholdMs=self.threshold,clock='Time.GetSystemTime wall milliseconds',
            schema=1,boundary='inclusive stages nest; selfMs excludes instrumented children; residual is not GPU time'})
    end
end
function M:OpenFile()
    if self.noFile or self.fileError~='' or self.file then return end
    self.segment=self.segment+1
    if self.segment>16 then self.fileError='128 MiB session file limit reached; console logging continues';return end
    local ok,err=pcall(function()
        fileSystem:CreateDir('performance')
        local file=File(self.logPath..'-'..self.segment..'.jsonl',FILE_WRITE)
        if not file:IsOpen() then file:Dispose();error('Cannot open performance log') end
        self.file=file;self.fileBytes=0
    end)
    if not ok then self.fileError=tostring(err) end
end
function M:Emit(record)
    record.session=self.session;record.atMs=record.atMs or Delta(self.clock(),self.startedAt)
    if self.sink then self.sink(record);return end
    local ok,line=pcall(cjson.encode,record)
    if not ok then self.fileError='JSON encode: '..tostring(line);return end
    print('VOX_PERF '..line)
    self:OpenFile()
    if self.file then
        local saved,err=pcall(function() if self.file:WriteLine(line)==false then error('Performance log write returned false') end end)
        if not saved then self.fileError=tostring(err);self.file:Dispose();self.file=nil;return end
        self.fileBytes=self.fileBytes+#line+1
        if self.fileBytes>=8*1024*1024 then self.file:Flush();self.file:Dispose();self.file=nil end
    end
end
function M:Begin(name)
    if not self.enabled or not self.recording then return nil end
    local thread=coroutine.running()
    local stack=self.stacks[thread]
    if not stack then stack={depth=0,tokens={}};self.stacks[thread]=stack end
    stack.depth=stack.depth+1
    local token=stack.tokens[stack.depth]
    -- Closed scopes can reuse their slot; yielded scopes still own their token.
    if not token or token.active then token=setmetatable({monitor=self},scopeMetatable);stack.tokens[stack.depth]=token end
    self.tokenOrder=self.tokenOrder+1
    token.frame=self.frame;token.start=self.clock();token.children=0;token.name=name;token.stack=stack
    token.order=self.tokenOrder;token.active=true;token.externalParent=nil
    if stack.depth==1 then
        -- A synchronous coroutine.resume is inside its resumer's measured work.
        -- Suspended coroutines are excluded so their waiting time is never a parent.
        for other,candidateStack in pairs(self.stacks) do
            if other~=thread and coroutine.status(other)=='normal' then
                local parent=candidateStack.tokens[candidateStack.depth]
                if parent and parent.frame==self.frame and parent.active and
                    (not token.externalParent or parent.order>token.externalParent.order) then token.externalParent=parent end
            end
        end
    end
    return token
end
function M:End(token)
    if not token then return end
    if token.frame~=self.frame or not self.recording then
        token.active=false;self.discardedAsyncSpans=self.discardedAsyncSpans+1;return
    end
    local elapsed=Delta(self.clock(),token.start)
    local stack=token.stack
    if stack.tokens[stack.depth]~=token then return end
    stack.depth=stack.depth-1
    token.active=false
    local parent=stack.depth>0 and stack.tokens[stack.depth] or token.externalParent
    if parent and not parent.active then self.discardedAsyncSpans=self.discardedAsyncSpans+1;return end
    if parent then parent.children=parent.children+elapsed else self.scriptMs=self.scriptMs+elapsed end
    local stat=self.stages[token.name]
    if not stat then stat={name=token.name,ms=0,selfMs=0,calls=0,maxMs=0};self.stages[token.name]=stat;self.stageOrder[#self.stageOrder+1]=stat end
    stat.ms=stat.ms+elapsed;stat.selfMs=stat.selfMs+math.max(0,elapsed-token.children)
    stat.calls=stat.calls+1;stat.maxMs=math.max(stat.maxMs,elapsed)
    if elapsed>self.threshold then
        if #self.longSpans<128 then
            self.longSpans[#self.longSpans+1]={name=token.name,ms=elapsed,selfMs=math.max(0,elapsed-token.children)}
        else self.longSpanDrops=self.longSpanDrops+1 end
    end
end
function M:Wrap(object,key,label)
    if not self.enabled or type(object)~='table' or type(object[key])~='function' then return end
    local known=self.wrapped[object]
    if not known then known={};self.wrapped[object]=known end
    if known[key]==object[key] then return end
    local original=object[key];local own=rawget(object,key)
    local monitor=self
    local function measured(...)
        if not monitor.enabled or not monitor.recording then return original(...) end
        local token <close> = monitor:Begin(label)
        return original(...)
    end
    object[key]=measured;known[key]=measured
    -- Ephemeron values may capture their key indirectly (HUD closures do).
    -- A strong array of wrappers would retain every retired battle session.
    local entries=self.restores[object]
    if not entries then entries={};self.restores[object]=entries end
    entries[#entries+1]={key=key,own=own,wrapper=measured}
end
function M:StageRows()
    local rows={}
    for _,stat in ipairs(self.stageOrder) do
        if stat.calls>0 then rows[#rows+1]={name=stat.name,ms=stat.ms,selfMs=stat.selfMs,calls=stat.calls,maxMs=stat.maxMs} end
    end
    table.sort(rows,function(a,b) return a.selfMs>b.selfMs end)
    return rows
end
function M:AggregateRows(agg)
    local rows={}
    for id,a in pairs(agg) do
        local stat=self.stageOrder[id]
        if stat then rows[#rows+1]={name=stat.name,ms=a[1],selfMs=a[2],calls=a[3],maxMs=a[4]} end
    end
    table.sort(rows,function(x,y) return x.selfMs>y.selfMs end)
    for i=#rows,41,-1 do rows[i]=nil end
    return rows
end
function M:StageNames()
    local names={}
    for id,stat in ipairs(self.stageOrder) do names[id]=stat.name end
    return names
end
function M:Recent()
    local rows={}
    for i=math.max(1,#self.ring-14),#self.ring do rows[#rows+1]=self.ring[i] end
    return rows
end
local function Accumulate(agg,id,stat)
    local a=agg[id];if not a then a={0,0,0,0};agg[id]=a end
    a[1]=a[1]+stat.ms;a[2]=a[2]+stat.selfMs;a[3]=a[3]+stat.calls;if stat.maxMs>a[4] then a[4]=stat.maxMs end
end
-- 场景更新 = PostUpdate 开始 - Update 结束；3D 渲染 = 视图画完 - PostUpdate 结束；UI+提交 = 帧结束 - 视图画完
-- （UI+提交里含引擎帧率上限的等待；帧时间高于上限时才代表真实开销）
local function PhaseSplit(phases,wall)
    local u,post,postEnd,rendered=phases.update,phases.post,phases.postEnd,phases.rendered
    if not (u and post and postEnd and rendered) then return nil end
    return math.max(0,post-u),math.max(0,rendered-postEnd),math.max(0,wall-rendered)
end
function M:Finalize(now,incomplete)
    local p=self.pending
    if not p then return end
    self.pending=nil
    p.frameMs=incomplete and p.wallMs or Delta(now,p.started)
    p.intervalIncomplete=incomplete or nil;p.started=nil
    p.unattributedMs=math.max(0,p.wallMs-p.scriptMs)
    p.outsideEndFrameMs=math.max(0,p.frameMs-p.wallMs)
    p.sceneMs,p.renderMs,p.presentMs=PhaseSplit(p.phases or {},p.wallMs)
    self.maxMs=math.max(self.maxMs,p.frameMs)
    local rows=nil ---@type table|nil
    local top=nil ---@type table|nil
    -- 每秒样本只带聚合后的阶段耗时（全部帧 + 去掉尖峰帧的“平时”），不再逐帧带阶段数组
    local steady=p.frameMs<SPIKE_MS
    if steady then self.steadyFrames=self.steadyFrames+1 end
    for id,stat in ipairs(self.stageOrder) do
        if stat.calls>0 then
            if not top or stat.selfMs>top.selfMs then top=stat end
            Accumulate(self.windowStages,id,stat)
            if steady then Accumulate(self.steadyStages,id,stat) end
        end
    end
    local compact={frame=p.frame,frameMs=p.frameMs,wallMs=p.wallMs,scriptMs=p.scriptMs,steps=p.steps,
        sceneMs=p.sceneMs,renderMs=p.renderMs,presentMs=p.presentMs,
        topStage=top and top.name or '',topMs=top and top.selfMs or 0,luaKiB=p.context.luaKiB,
        context={mode=p.context.mode,map=p.context.map,story=p.context.story,storyStep=p.context.storyStep,
            matchState=p.context.matchState,loading=p.context.loading,loadingPhase=p.context.loadingPhase}}
    if p.frameMs>self.threshold or p.wallMs>self.threshold then
        self.slowFrames=self.slowFrames+1;self.lastEvent='frame '..p.frame..' / '..string.format('%.1f ms',p.frameMs)
        local spike=p.frameMs>=SPIKE_MS
        local last=spike and self.lastSpikeEmit or self.lastSlowEmit
        if last==nil or Delta(now,last)>=(spike and SPIKE_GAP or SLOW_GAP) then
            if spike then self.lastSpikeEmit=now else self.lastSlowEmit=now end
            rows=self:StageRows()
            local detail={};for i=1,math.min(DETAIL_STAGES,#rows) do detail[i]=rows[i] end
            local spans={};for i=1,math.min(16,#p.longSpans) do spans[i]=p.longSpans[i] end
            p.type='slow_frame';p.spike=spike or nil;p.stages=detail;p.longSpans=spans;p.recent=self:Recent();p.discardedAsyncSpans=self.discardedAsyncSpans
            self:Emit(p)
        elseif spike then self.suppressedSpikes=self.suppressedSpikes+1
        else self.suppressedSlow=self.suppressedSlow+1 end
    elseif p.errors and #p.errors>0 then
        rows=self:StageRows()
        p.type='error_frame';p.stages=rows;self:Emit(p)
    end
    self.ring[#self.ring+1]=compact;if #self.ring>120 then table.remove(self.ring,1) end
    if #self.window<1024 then self.window[#self.window+1]=compact else self.sampleDrops=self.sampleDrops+1 end
    self.lastSnapshot={enabled=true,fps=p.frameMs>0 and 1000/p.frameMs or 0,frameMs=p.frameMs,
        p95Ms=self.p95Ms,maxMs=self.maxMs,slowFrames=self.slowFrames,steps=p.steps,cpuMs=p.scriptMs,
        topStage=compact.topStage,topMs=compact.topMs,luaKiB=p.context.luaKiB or 0,units=p.context.units or 0,
        projectiles=p.context.projectiles or 0,effects=p.context.effects or 0,lastEvent=self.lastEvent,
        logPath=self.logPath,fileError=self.fileError,thresholdMs=self.threshold}
    if Delta(now,self.lastSample)>=1000 then
        local values,total={},0
        for _,row in ipairs(self.window) do values[#values+1]=row.frameMs;total=total+row.frameMs end
        table.sort(values);self.p95Ms=Percentile(values,.95);self.lastSnapshot.p95Ms=self.p95Ms
        self:Emit({type='sample',frame=p.frame,frameMs=p.frameMs,wallMs=p.wallMs,scriptMs=p.scriptMs,
            context=p.context,frameSamples=self.window,sampleDrops=self.sampleDrops,
            -- 本秒内各阶段合计（ms/selfMs/calls 为总和，maxMs 为单次最大）；steady 只算 <SPIKE_MS 的帧
            stages=self:AggregateRows(self.windowStages),steadyStages=self:AggregateRows(self.steadyStages),steadyFrames=self.steadyFrames,
            frameStats={count=#values,meanMs=#values>0 and total/#values or 0,p50Ms=Percentile(values,.5),
                p95Ms=self.p95Ms,p99Ms=Percentile(values,.99),maxMs=values[#values] or 0},
            slowFrames=self.slowFrames,suppressedSlow=self.suppressedSlow,suppressedSpikes=self.suppressedSpikes,
            monitorMs=self.monitorMs or 0})
        self.window={};self.sampleDrops=0;self.lastSample=now
        self.windowStages={};self.steadyStages={};self.steadyFrames=0;self.suppressedSlow=0;self.suppressedSpikes=0
    end
    if self.file and Delta(now,self.lastFlush)>=1000 then self.file:Flush();self.lastFlush=now end
end
-- 引擎阶段打点（距本帧 Update 开始的毫秒）：update=Lua Update 结束，post=PostUpdate 开始，
-- postEnd=PostUpdate 结束，rendered=所有 3D 视图画完。用来把 Lua 以外的时间拆成场景更新 / 3D 渲染 / UI+提交
function M:Phase(name)
    if not self.enabled or not self.recording then return end
    self.phases[name]=Delta(self.clock(),self.frameStarted)
end
function M:BeginFrame(dt)
    if not self.enabled or self.closed then return end
    local now=self.clock();self:Finalize(now,false)
    self.monitorMs=Delta(self.clock(),now)
    self.frame=self.frame+1;self.frameStarted=now;self.eventDtMs=dt*1000;self.scriptMs=0;self.recording=true
    self.longSpans={};self.longSpanDrops=0;self.phases={}
    for _,stat in ipairs(self.stageOrder) do stat.ms=0;stat.selfMs=0;stat.calls=0;stat.maxMs=0 end
    for _,stack in pairs(self.stacks) do stack.depth=0 end
end
function M:EndFrame(context)
    if not self.enabled or not self.recording then return end
    self.recording=false
    local now=self.clock();local total=context.stepsTotal or 0
    local steps=self.lastTrial==context.trialId and math.max(0,total-self.stepsTotal) or 0
    self.lastTrial=context.trialId;self.stepsTotal=total
    self.pending={frame=self.frame,started=self.frameStarted,atMs=Delta(self.frameStarted,self.startedAt),
        wallMs=Delta(now,self.frameStarted),scriptMs=self.scriptMs,eventDtMs=self.eventDtMs,steps=steps,context=context,
        monitorMs=self.monitorMs,errors=self.errors,longSpans=self.longSpans,longSpanDrops=self.longSpanDrops,phases=self.phases}
    self.errors=nil
end
function M:Marker(label,context)
    if not self.enabled then return end
    self.lastEvent=label
    self:Emit({type='marker',frame=self.frame,label=label,context=context})
    if self.file then self.file:Flush() end
end
function M:Snapshot() return self.lastSnapshot end
function M:Dispose()
    if self.closed then return end
    if not self.enabled then self.closed=true;return end
    self.recording=false;self:Finalize(self.clock(),true)
    if #self.window>0 then self:Emit({type='sample_tail',frameSamples=self.window,sampleDrops=self.sampleDrops,stages=self:AggregateRows(self.windowStages)}) end
    self:Emit({type='session_end',frame=self.frame,slowFrames=self.slowFrames,fileError=self.fileError})
    self.enabled=false;self.closed=true
    for object,entries in pairs(self.restores) do
        for _,entry in ipairs(entries) do
            if rawget(object,entry.key)==entry.wrapper then object[entry.key]=entry.own end
        end
    end
    self.restores={}
    if self.file then self.file:Flush();self.file:Dispose();self.file=nil end
end
return M
