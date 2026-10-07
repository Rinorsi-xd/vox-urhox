-- Recoverable derived images, keyed by the exact saved blueprint generation.
-- A missing/corrupt image never makes the authoritative blueprint unreadable.
local M={VERSION=1,width=320,height=200}
function M.Ref(store,slot,generation,context)
    return {store=store,slot=slot,generation=generation,context=context,
        path=store.prefix..'slot'..slot..'-preview-'..generation..'.jpg'}
end
function M.Current(ref)
    local data,generation=ref.store:LoadSlot(ref.slot)
    return data~=nil and generation==ref.generation
end
function M.Load(ref)
    if not ref or not fileSystem:FileExists(ref.path) then return nil end
    local file=File(ref.path,FILE_READ)
    if not file:IsOpen() or file.size>512*1024 then file:Dispose();return nil end
    file:Dispose()
    local image=Image:new();local ok=image:Load(ref.path)
    if not ok or image.width~=M.width or image.height~=M.height then image:Dispose();return nil end
    return image
end
function M.Save(ref,image)
    if not ref or not M.Current(ref) then return false end
    return image:SaveJPG(ref.path,82)
end
function M.Retire(store,slot,generation)
    -- Keep the matching previous blueprint generation for crash recovery.
    local path=M.Ref(store,slot,generation).path
    if fileSystem:FileExists(path) then fileSystem:Delete(path) end
end
return M
