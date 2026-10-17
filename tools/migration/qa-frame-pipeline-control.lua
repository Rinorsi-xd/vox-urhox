-- Last suffix, evaluated before Start subscribes any global callbacks. The
-- engine may retain this exact function reference; no later replacement needed.
do
    local pipeline=assert(VOX_QA_FRAME_PIPELINE)
    assert(pipeline.Snapshot().prepared and not pipeline.enabled)
    local state={updateChecks=0,framePresentedChecks=0,detected=0,changes=0,pending=false}
    pipeline.control=state
    local measuredUpdate=HandleUpdate
    function HandleUpdate(...)
        state.updateChecks=state.updateChecks+1;state.lastUpdateFrame=GetTime().frameNumber
        if input:GetKeyPress(KEY_F9) then state.pending=true;state.detected=state.detected+1 end
        return measuredUpdate(...)
    end
    local measured=HandleFramePresented
    function HandleFramePresented(...)
        local result=table.pack(measured(...))
        -- The measured handler and its scope have returned before toggling or
        -- serializing. F8 projections remain explicit and are measured QA work.
        state.framePresentedChecks=state.framePresentedChecks+1;state.lastPresentedFrame=GetTime().frameNumber
        if state.pending then
            state.pending=false;state.changes=state.changes+1
            local enabled=not pipeline.enabled
            pipeline.Enable(enabled)
            if not enabled then pipeline.Emit() end
            print('VOX_FRAME_PIPELINE_CONTROL '..cjson.encode(pipeline.Snapshot()))
        end
        return table.unpack(result,1,result.n)
    end
end
