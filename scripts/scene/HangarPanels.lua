-- Four authored surfaces get fixed-resolution, on-demand NanoVG canvases.
-- Independent offscreen contexts never touch the UI frame or viewport.
local RenderTargetLifetime=require("render.RenderTargetLifetime")

local Projection=require 'render.HangarBlueprintPanel'
local Stats=require 'render.HangarStatsPanel'
local Signs=require 'render.HangarBaySigns'
local Canvas=require 'render.HangarCanvas'
local PARTS=require('parts.Defs').PARTS
local M={};M.__index=M
function M.New(hangar,provider,scale)
    local self=setmetatable({},M)
    local ok,err=pcall(self.init,self,hangar,provider,scale)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(hangar,provider,scale)
    self.scale=scale or 1
    self.provider=provider;self.entries={};self.disposed=false;self.computations=0;self.renders=0
    local specs={{'stats',1024,640,'uMap',Stats.Draw},{'blueprint',1024,640,'uMap',Projection.Draw},
        {'mark',2048,1126,'albedo_map',Signs.Mark},{'bay',2048,1024,'albedo_map',Signs.Bay}}
    for _,s in ipairs(specs) do
        local material=s[4]=='uMap' and hangar:Material('Holo_'..s[1]) or hangar.planeMats[s[1]]
        local entry={id=s[1],width=s[2],height=s[3],sampler=s[4],draw=s[5],material=material,
            fallback=material:GetSurfaceTexture(s[4]),dirty=true,renders=0}
        self.entries[s[1]]=entry
        local tex=Texture2D:new();tex:SetNumLevels(1)
        tex:SetSRGB(false)
        entry.texture=tex
        assert(tex:SetSize(math.ceil(s[2]*self.scale),math.ceil(s[3]*self.scale),Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Hangar canvas allocation failed')
        tex:SetFilterMode(FILTER_BILINEAR);tex:SetAddressMode(COORD_U,ADDRESS_CLAMP);tex:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        local vg=assert(nvgCreate(1));entry.vg=vg;nvgSetRenderTarget(vg,tex);nvgSetColorSpace(vg,NVG_COLOR_GAMMA)
        Canvas.Init(vg)
        SubscribeToEvent(vg,'NanoVGRender',function() self:Render(entry) end)
    end
    self:Update()
    print('[HangarPanels] Four source canvases attached')
end
function M:Update()
    if self.disposed then return end
    local bp,tier,slot,revision,diagnostic=self.provider()
    if not bp then return end
    if self.bp==bp and self.revision==revision and self.name==bp.name and self.tier==tier and self.slot==slot then return end
    local old=self.info
    local diag=diagnostic or bp:Diagnose(tier)
    -- Every panel field derives from the parts. Livery edits bump the revision
    -- but return the same cached diagnostics object: nothing to redraw.
    if old and diag==old.diag and self.bp==bp and self.name==bp.name and self.tier==tier and self.slot==slot then
        self.revision=revision;return
    end
    local parts=bp:List();local hp=0;for _,p in ipairs(parts) do hp=hp+PARTS[p.type].hp end
    local info={name=bp.name,tier=tier,slot=slot,no=slot and string.format('%02d',slot) or '--',
        diag=diag,hp=hp,projection=Projection.Build(parts)}
    self.bp=bp;self.revision=revision;self.name=bp.name;self.tier=tier;self.slot=slot
    self.info=info;self.computations=self.computations+1
    self.entries.stats.dirty=true;self.entries.blueprint.dirty=true
    if not old or old.name~=info.name or old.tier~=tier or old.slot~=slot then self.entries.mark.dirty=true end
    if not old or old.slot~=slot then self.entries.bay.dirty=true end
end
function M:Render(entry)
    if self.disposed or not entry.dirty or not self.info then return end
    local vg=entry.vg
    -- Mode A: the original Canvas dimensions are the design and texture size;
    -- pixel ratio 1 belongs to this fixed texture, independent of screen DPR.
    nvgBeginFrame(vg,entry.width*self.scale,entry.height*self.scale,1)
    nvgScale(vg,self.scale,self.scale)
    nvgSave(vg);nvgGlobalCompositeOperation(vg,NVG_COPY)
    Canvas.Rect(vg,0,0,entry.width,entry.height,{0,0,0,0});nvgRestore(vg)
    entry.draw(vg,self.info);nvgEndFrame(vg)
    entry.material:SetSurfaceTexture('canvas_map',entry.texture)
    entry.material:SetShaderParameter('canvas_enabled',Variant(1.0))
    entry.dirty=false;entry.renders=entry.renders+1;entry.info=self.info;self.renders=self.renders+1
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    for _,e in pairs(self.entries) do
        if e.vg then UnsubscribeFromEvent(e.vg,'NanoVGRender');nvgDelete(e.vg);e.vg=nil end
        e.material:SetSurfaceTexture(e.sampler,e.fallback)
        e.material:SetSurfaceTexture('canvas_map',e.fallback)
        e.material:SetShaderParameter('canvas_enabled',Variant(0.0))
        if e.texture then RenderTargetLifetime.Retire(e.texture);e.texture=nil end
        e.info=nil
    end
    self.bp=nil;self.info=nil;self.provider=nil
end
return M
