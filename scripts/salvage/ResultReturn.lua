-- Retain settlement data across disposal of the live battle and hall loading.
local M={};M.__index=M
local function Copy(value)
    if type(value)~='table' then return value end
    local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out
end
function M.Queue(run,delay)
    local app=run.session.app
    if app.pendingSalvageResult and app.pendingSalvageResult.runId==run.runId then return app.pendingSalvageResult end
    local payload=setmetatable({runId=run.runId,result=Copy(run.result),originalParts=Copy(run.original.parts),
        lobby=app.salvageLobby,committed=run.committed,saveError=run.saveError,delay=delay or 0},M)
    app.pendingSalvageResult=payload;return payload
end
function M:Commit()
    if self.committed then return true end
    local ok,err=self.lobby:CommitRun(self.runId,self.result,self.originalParts)
    self.committed=ok;self.saveError=not ok and tostring(err) or nil;return ok
end
function M.RecordRelease(app,trial)
    local pending=app.pendingSalvageResult
    if pending and app.trial==trial then
        pending.release={disposed=trial.disposed==true,scene=trial.scene==nil,world=trial.world==nil,
            combat=trial.combat==nil,effects=trial.effects==nil,view=trial.view==nil,hud=trial.hud==nil}
    end
end
function M.Update(app,owner,dt,show)
    local pending=app.pendingSalvageResult
    if not pending or pending.shown or app.mode~='hangar' or app.trial or not app.scene or
        app.loader.state=='loading' or app.loadingFlow.active or not owner or owner.dialog then return end
    pending.delay=math.max(0,pending.delay-math.max(0,dt or 0))
    if pending.delay>0 then return end
    pending.shown=true
    show(owner,pending,function()
        if app.pendingSalvageResult==pending then app.pendingSalvageResult=nil end
    end)
end
return M
