local RecordNumbers=require("storage.RecordNumbers")

local M={}
M.defaults={sens=1,size=1,assist=true,autoFire=false,plane='point',build='tap',fullscreen=true}
M.options={sens={.6,1,1.5,2.2},size={.85,1,1.15},plane={'point','keys'},build={'tap','aim'}}
function M.Valid(p)
    if type(p)~='table' then return false end
    for key,default in pairs(M.defaults) do
        local value=p[key]
        if type(value)~=type(default) then return false end
        if type(value)=='number' and not RecordNumbers.NonNegative(value) then return false end
        local choices=M.options[key]
        if choices then local found=false;for _,choice in ipairs(choices) do if value==choice then found=true end end;if not found then return false end end
    end
    return true
end
function M.Get(app)
    if not app.touchPrefs then
        local stored=app.store:Read('touch-settings',M.Valid);local prefs={}
        for key,value in pairs(M.defaults) do prefs[key]=stored and stored[key] or value;if stored and stored[key]==false then prefs[key]=false end end
        app.touchPrefs=prefs
        app.SaveTouchPrefs=function(owner,p)
            if not M.Valid(p) then return false,'触屏设置无效' end
            local ok,err=owner.store:Write('touch-settings',p,M.Valid)
            if not ok then owner.toasts:Push(err,'bad') end
            return ok,err
        end
    end
    return app.touchPrefs
end
return M
