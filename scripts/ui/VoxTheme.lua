-- Source CSS tokens and thumbnail ownership. Painting belongs to Source widgets.
local M={bg='#15171b',panel='#1b1d22',tile='#2a2e35',edge='#353a42',text='#f4f5f7',muted='#9aa0aa',brand='#ff6a13',energy='#2ea8ff'}
function M.Thumbnail(type) return type and ('UI/Parts/'..(type=='thruster' and 'thrusterUp2' or type)..'.png') or '' end
-- UI caches image handles globally. Trim only this feature's namespace, keeping
-- currently bound rows, detail and hotbar. Never evict another screen's images.
function M.TrimThumbnails(keep)
    local cache=require 'urhox-libs/UI/Core/ImageCache'
    for _,path in ipairs(cache.GetCachedPaths()) do if path:sub(1,9)=='UI/Parts/' and not keep[path] then cache.Release(path) end end
end
return M
