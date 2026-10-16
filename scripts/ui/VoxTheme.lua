-- Source CSS tokens and thumbnail ownership. Painting belongs to Source widgets.
local ImageCache=require("urhox-libs/UI/Core/ImageCache")

local M={bg='#080f1c',panel='#12263b',tile='#213b55',edge='#3d5872',text='#edf6ff',muted='#91acc8',brand='#7ad8ff',energy='#2879eb'}
function M.Thumbnail(type) return type and ('UI/Parts/'..(type=='thruster' and 'thrusterUp2' or type)..'.png') or '' end
-- UI caches image handles globally. Trim only this feature's namespace, keeping
-- currently bound rows, detail and hotbar. Never evict another screen's images.
function M.TrimThumbnails(keep)
    local cache=ImageCache
    for _,path in ipairs(cache.GetCachedPaths()) do if path:sub(1,9)=='UI/Parts/' and not keep[path] then cache.Release(path) end end
end
return M
