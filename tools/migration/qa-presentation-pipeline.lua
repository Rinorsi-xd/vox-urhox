-- Appended only to the explicit presentation variant, inside the base scope.
local presentationHudBinding=nil
local function PreparePresentationHud(hud)
    if presentationHudBinding and presentationHudBinding.owner==hud then return end
    assert(#stack==0 or stack[#stack].name=='envelope.AppUpdate' or stack[#stack].name=='main.Update','Bind HUD before Trial timing')
    if presentationHudBinding then
        local old=presentationHudBinding
        assert(old.owner[old.key]==old.wrapped,'HUD timing owner replaced externally')
        old.owner[old.key]=old.original
        for i,binding in ipairs(bindings) do if binding==old then table.remove(bindings,i);break end end
        presentationHudBinding=nil
    end
    if hud then
        assert(type(hud.Update)=='function','Missing live HUD.Update')
        Wrap(hud,'Update','presentation.HudUpdate')
        presentationHudBinding=bindings[#bindings]
    end
end
function M.PreparePresentation()
    assert(M.prepared and not M.enabled and identity.presentationPipeline==true and identity.fixedSteps==true)
    local app=require 'app.HangarApp'
    local trial=require 'app.TrialSession'
    local combatView=require 'render.CombatView'
    local effects=require 'render.CombatEffects'
    local wanted={
        {app,'Update','envelope.AppUpdate'},
        {trial,'Update','envelope.TrialUpdate'},
        {trial,'Tick','envelope.TrialTick'},
        {combatView,'Update','presentation.CombatView'},
        {effects,'Update','presentation.Effects'},
    }
    for _,item in ipairs(wanted) do assert(type(item[1][item[2]])=='function','Missing presentation boundary '..item[3]) end
    for _,item in ipairs(wanted) do Wrap(item[1],item[2],item[3]) end
    local measuredApp=app.Update
    app.Update=function(self,...)
        if not self.trial then PreparePresentationHud(nil) end
        return measuredApp(self,...)
    end
    local measuredTrial=trial.Update
    trial.Update=function(self,...)
        PreparePresentationHud(self.hud)
        return measuredTrial(self,...)
    end
end
