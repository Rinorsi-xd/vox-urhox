local Button=require 'ui.SourceButton'
local Host=require 'ui.DialogHost'
local M={}
function M.Open(owner)
    local build=owner.editor~=nil
    local modal=Host.Open(owner,'暂停',nil,{width=480,gap=6});local buttons={}
    local function Add(id,label,icon,subtitle,action,disabled)
        local b=Button{text=label,icon=icon,subtitle=subtitle,sourceKind='pause',onClick=action,width='100%',height=66,flexShrink=0,disabled=disabled};modal:AddContent(b);buttons[id]=b
    end
    Add('resume','继续','play','回到'..(build and '编辑' or '机库'),function() Host.Close(owner) end)
    if build then
        Add('save','保存','save','存进车位（Ctrl+S）',function() Host.Close(owner);owner:SaveSlot() end)
        Add('home','回机库','hangar','有车位的车自动保存',function() Host.Close(owner);owner.app:ExitBuild() end)
    end
    Add('help','操作说明','help','建造、视角、试车的全部按键（H）',function() require('ui.GarageDialogs').Help(owner) end)
    Add('graphics','画面设置','gear','画质、泛光、曝光、环境光遮蔽',function() require('ui.GarageDialogs').Settings(owner) end)
    Add('keys','键位设置','sliders','开发中',function() end,true)
    modal.actions=buttons;return modal
end
return M
