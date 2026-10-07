-- shared/ui/ui.js openImport/openExport, shared by home and build owners.
-- Callers own storage policy; this module only owns the source PC dialog.
local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Button=require 'ui.SourceButton'
local M={}
function M.Open(owner,options)
    local importing=options.importing
    local modal=Host.Open(owner,importing and '导入蓝图码' or '导出蓝图码',nil,
        {width=780,subtitle=not importing and options.name or nil})
    local hint=importing and '粘贴以 FKZC1: 开头的蓝图码。当前车辆会被替换，需要的话先保存到蓝图库。'
        or '把这段文字发给朋友，对方点「导入蓝图码」粘贴即可得到同一辆车。'
    local segments=importing and {{text='粘贴以 '},{text='FKZC1:',font='vox-inline-code'},
        {text=' 开头的蓝图码。当前车辆会被替换，需要的话先保存到蓝图库。'}} or nil
    local status=require('ui.SourceHint'){text=hint,segments=segments,width='100%',height=29.25,marginTop=12.5,marginBottom=12.5,flexShrink=0}
    local field=require('ui.SourceCodeField'){value=options.code or '',placeholder='FKZC1:...',maxLength=4*1024*1024,
        width='100%',height=130,flexShrink=0,readOnly=not importing}
    modal:AddContent(status);modal:AddContent(field);modal.field=field;modal.status=status
    local function Submit()
        if importing then options.onImport(field:GetValue(),status)
        else
            ui.useSystemClipboard=true;ui:SetClipboardText(field:GetValue())
            local copied=ui:GetClipboardText()==field:GetValue()
            if not copied then UI.SetFocus(field);field:SelectAll() end
            Host.Notify(owner,copied and '蓝图码已复制' or '请在输入框中全选复制')
        end
    end
    modal.actions={confirm=Button{text=importing and '导入' or '复制',sourceKind='primary',width=72,height=40,onClick=Submit},
        cancel=Button{text=importing and '取消' or '关闭',sourceKind='dialog',width=72,height=40,onClick=function() Host.Close(owner) end}}
    local actions=UI.Panel{flexDirection='row',justifyContent='flex-end',gap=8,marginTop=23,children={modal.actions.confirm,modal.actions.cancel}}
    modal:AddContent(actions)
    -- Preserve CSS fractional line boxes. The same render offsets are consumed
    -- by Widget hit testing and input, including while the modal is moving.
    local function Place(widget,x,y,w,h)
        widget.renderOffsetX_=x;widget.renderOffsetY_=y;widget.renderWidth_=w;widget.renderHeight_=h
    end
    modal.props.source.contentHeight=function() return status.props.height+25+130+23+40 end
    modal.props.source.layoutContent=function(x,y,w)
        Place(status,x,y+12.5,w,status.props.height)
        local fieldY=y+25+status.props.height
        Place(field,x,fieldY,w,130);Place(actions,x,fieldY+153,w,40)
    end
    UI.SetFocus(field);if not importing then field:SelectAll();field.state.cursorPos=0 end
    return modal
end
return M
