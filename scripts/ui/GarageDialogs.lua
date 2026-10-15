local Code=require 'storage.BlueprintCode'
local Host=require 'ui.DialogHost'
local M={}
M.Close=Host.Close
M.Confirm=Host.Confirm
function M.Save(s)
    if not s.editor and s.app.vehicleSwitch:IsBusy() then return end
    local ok,err,reason=s.app.bays:Save()
    if ok then Host.Notify(s,s.app.store:SaveMessage('已保存'));return end
    if reason~='full' then Host.Notify(s,err);return end
    return require('ui.BlueprintLibrary').Open(s,'save')
end
function M.Delete(s)
    if s.app.vehicleSwitch:IsBusy() then return end
    local slot=s.app.bays.active;if not slot then return end
    M.Confirm(s,'删除当前战车？','删除车位 '..slot..' 中的“'..s.app.blueprint.name..'”，此操作无法撤销。',function()
        s.Run(function() return s.app.bays:Delete(slot) end,function() s.message:Push('已删除战车','ok') end,s.app.bays:ReplacementAfterDelete(slot))
    end)
end
function M.Code(s,importing)
    if importing and s.editor and s.app.lobby=='salvage' then
        Host.Notify(s,'打捞行动的车在大厅「车库」里新建和切换','warn');return
    end
    local function Import(text,status)
        local ok,data=pcall(Code.Decode,text)
        if not ok then status:SetText('蓝图码无效');return end
        if s.editor then
            local function Replace()
                M.Close(s)
                s.app:WithVehicle(data,function() return s.app.bays:Import(data) end,function(loaded,err)
                    Host.Notify(s,loaded and '已导入为未入车位的草稿，原车位保留。' or err,loaded and 'ok' or 'bad')
                end)
            end
            if s.editor.bp:Size()>1 then
                Host.Confirm(s,'替换当前草稿？','未保存的改动将丢失，已有车位的存档保留。',Replace)
            else Replace() end
        else
            M.Close(s)
            s.Run(function(discard)
                local loaded,err,reason=s.app.bays:CreateVehicle(data,nil,discard)
                if loaded then s.SetTab('hangar') end
                return loaded,err,reason
            end,nil,data)
        end
    end
    return require('ui.SourceBlueprintDialog').Open(s,{importing=importing,name=s.app.blueprint.name,
        code=not importing and Code.Encode(s.app.blueprint:ToTable()) or '',onImport=Import})
end
function M.Help(s) return require('ui.SourceHelp').Open(s) end
function M.Settings(s)
    return require('ui.GraphicsPanel').Open(s)
end
return M
