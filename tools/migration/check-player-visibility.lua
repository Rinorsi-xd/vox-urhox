local Sync=require 'combat.PlayerViewSync'
local Feedback=require 'controls.CameraFeedback'
V.atFrame(47,function()
    local scene=Scene();local root=scene:CreateChild('Player')
    local child=root:CreateChild('VisiblePart');local model=child:CreateComponent('StaticModel')
    model.model=cache:GetResource('Model','Models/Box.mdl')
    local hidden=root:CreateChild('OriginalHiddenPart');hidden.enabled=false
    local hiddenModel=hidden:CreateComponent('StaticModel');hiddenModel.model=model.model
    local view={root=root,Rebuild=function()end}
    local driveView={view=view,Bind=function()end}
    local player={alive=false,bp={},vehicle={},weapons={}}
    local session={view=driveView};local controller={session=session,player=player,world={viewEvents={{type='unitKilled',unit=player}}}}
    Sync.Update(controller)
    V.assert(not model.enabledEffective and not hiddenModel.enabledEffective,'real killed player hides all child model components')
    player.alive=true;controller.world.viewEvents={{type='unitSpawn',unit=player}}
    Sync.Update(controller)
    V.assert(model.enabledEffective and not hiddenModel.enabledEffective,'real respawn restores visible child and preserves original hidden child')
    V.assert(session.vehicle==player.vehicle and session.weapons==player.weapons,'respawn presentation binds the current physical vehicle and weapon system')
    local visibility=require 'render.NodeVisibility'
    visibility.Set(root,false,true);child.enabled=true
    visibility.Set(root,false,true)
    V.assert(not model.enabledEffective,'scoped animated parts remain hidden after their pose updates')
    visibility.Set(root,true,true)
    V.assert(model.enabledEffective and not hiddenModel.enabledEffective,'scope release restores the original child visibility mask')
    visibility.Set(root,false,true);child:Dispose();hidden:Dispose()
    local replacement=root:CreateChild('RebuiltPart');local rebuilt=replacement:CreateComponent('StaticModel');rebuilt.model=cache:GetResource('Model','Models/Box.mdl')
    visibility.Set(root,true,true)
    V.assert(rebuilt.enabledEffective,'restoration after a real rebuild ignores disposed child nodes')
    local state={};local feedback=Feedback.New(state)
    for _=1,200 do feedback:Queue({type='shot',kind='sniper',kick=.65,shake=1},false) end
    feedback:Discard()
    V.assert(feedback.count==0 and next(feedback.events)==nil and next(feedback.remote)==nil,'spectator transition releases pending feedback event references')
    feedback:Flush({0,0,0})
    V.assert(state.trauma==0,'discarded dead-player events never apply on the next live camera')
    scene:Dispose();V.finish()
end)
