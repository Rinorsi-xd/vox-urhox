local RecordNumbers=require("storage.RecordNumbers")

local M={}
M.defaults={sens=1,size=1,assist=true,autoFire=false,plane='point',build='tap',fullscreen=true}
M.options={sens={.6,1,1.5,2.2},size={.85,1,1.15},plane={'point','keys'},build={'tap','aim'}}
-- 局内触屏按钮自定义布局：{[控件 id]={x=中心横向占比,y=中心纵向占比,s=缩放}}，占比相对安全区。
-- 不放进 defaults：老存档没有这个字段，按 defaults 校验会把整份触屏设置判成无效。
M.layoutControls={'stick','primary','scope','up','aux','weapon','interact','rudder-l','rudder-r','board','toggle'}
M.layoutScale={min=.6,max=1.6}
local layoutKnown={};for _,id in ipairs(M.layoutControls) do layoutKnown[id]=true end
function M.ValidLayout(layout)
    if layout==nil then return true end
    if type(layout)~='table' then return false end
    for id,c in pairs(layout) do
        if not layoutKnown[id] or type(c)~='table' then return false end
        for _,field in ipairs({'x','y','s'}) do if type(c[field])~='number' or c[field]~=c[field] then return false end end
        if c.x<0 or c.x>1 or c.y<0 or c.y>1 or c.s<M.layoutScale.min-1e-6 or c.s>M.layoutScale.max+1e-6 then return false end
    end
    return true
end
function M.CopyLayout(layout)
    local copy={};for id,c in pairs(layout or {}) do copy[id]={x=c.x,y=c.y,s=c.s} end;return copy
end
function M.Valid(p)
    if type(p)~='table' then return false end
    if not M.ValidLayout(p.layout) then return false end
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
        prefs.layout=M.CopyLayout(stored and stored.layout)
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
