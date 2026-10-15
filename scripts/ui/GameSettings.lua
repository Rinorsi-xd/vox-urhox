-- One settings entry for live modes and the editor, using the source pause card.
local M={}
function M.Open(owner)
    if owner.Pause then owner:Pause() end
    return require('ui.PauseMenu').Open(owner,{inGame=owner.combat~=nil,unified=true})
end
function M.Attach(session,root,top)
    local Button=require 'ui.SourceButton'
    local props={position='absolute',text='设置',icon='gear',top=12,width=62,height=36,
        onClick=function() M.Open(session) end}
    local button=nil ---@type Widget|nil
    if session.battle then
        props.right=134;props.sourceKind='flat';props.height=34;button=Button(props)
    elseif session.endless then
        props.right=156;props.height=44;button=require('ui.EndlessWidgets').Button(props)
    else
        props.right=12;props.top=top+103;props.kind='exit';props.course=true
        button=require('ui.DriveChrome')(props);button.session=session
    end
    root:AddChild(button);return button
end
return M
