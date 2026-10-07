-- PC playfield only. Captured look/fire come from DrivePointer, never UI drags.
local UI=require 'urhox-libs/UI'
local M={}
function M.Create(session,root)
    if session.touch then return require('ui.TouchDriveControls').Create(session,root) end
    local playfield=UI.Panel{position='absolute',width='100%',height='100%',onPointerDown=function(e)
        if not e:IsTouch() and e:IsPrimaryButton() and not session.pointer.captured then session:Resume() end
    end}
    root:AddChild(playfield)
    return {playfield=playfield,Clear=function() session.controls:Clear();session.pointer:Suppress() end}
end
return M
