-- Large rectangular CSS shadows, sampled from a shared Gaussian kernel.
-- Each widget owns its context handles and releases them before context death.
local M={};M.__index=M
function M.New() return setmetatable({images={}},M) end
function M:Draw(vg,x,y,w,h,blur,color)
    local radius=blur*1.5
    assert(w>=radius*2 and h>=radius*2,'Nine-slice shadow requires non-overlapping blur edges')
    local handle=self.images[vg]
    if not handle then
        handle=nvgCreateImage(vg,'UI/SourceBoxShadow.png',0)
        assert(handle and handle>0,'Source box-shadow kernel unavailable');self.images[vg]=handle
    end
    local xs,ys={x-radius,x+radius,x+w-radius,x+w+radius},{y-radius,y+radius,y+h-radius,y+h+radius}
    local uv={0,96,97,193}
    nvgSave(vg);nvgShapeAntiAlias(vg,0)
    for row=1,3 do for col=1,3 do
        local dx,dy=xs[col],ys[row];local dw,dh=xs[col+1]-dx,ys[row+1]-dy
        if dw>0 and dh>0 then
            local sx,sy=dw/(uv[col+1]-uv[col]),dh/(uv[row+1]-uv[row])
            nvgBeginPath(vg);nvgRect(vg,dx,dy,dw,dh)
            nvgFillPaint(vg,nvgImagePatternTinted(vg,dx-uv[col]*sx,dy-uv[row]*sy,193*sx,193*sy,0,handle,color));nvgFill(vg)
        end
    end end
    nvgRestore(vg)
end
function M:Dispose()
    for vg,handle in pairs(self.images) do nvgDeleteImage(vg,handle) end;self.images={}
end
return M
