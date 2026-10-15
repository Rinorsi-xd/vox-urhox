local M={}
function M.Release()
    local refs=require('core.ResourceData').Read('Salvage/Resources.json')
    for _,kind in ipairs({'Material','Model','Texture2D'}) do
        for _,path in ipairs(refs) do
            if path:sub(1,8)=='Salvage/' then
                local ext=path:match('%.(%w+)$')
                if kind=='Material' and ext=='xml' or kind=='Model' and ext=='bin' and path~='Salvage/Height.bin' or kind=='Texture2D' and ext=='png' then
                    cache:ReleaseResource(kind,path)
                end
            end
        end
    end
    require('render.SalvageCinematics').Release()
end
return M
