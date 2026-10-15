local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Lifetime=require 'render.RenderTargetLifetime'
local owner={}
local root,modal,firstTexture
V.atFrame(10,function()
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    modal=Host.Open(owner,'资源寿命',nil,{width=420})
    modal:AddContent(UI.Label{text='Actual nested card and composite textures',height=80})
end)
V.atFrame(18,function()
    V.assert(modal.visual.card.ready and modal.visual.composite.ready,'both actual nested layers render before disposal')
    V.assert(modal.visual.card.images[modal.visual.composite.vg]~=nil,'card bridge actually lives inside composite context')
    firstTexture=modal.visual.card.texture
    modal.props.source.width=520
end)
V.atFrame(24,function()
    V.assert(modal.visual.card.texture~=firstTexture,'resizing replaces actual render texture')
    firstTexture=nil
    local visual=modal.visual;modal:Close(true)
    V.assert(visual.card.disposed and visual.composite.disposed,'real modal closes both dependent contexts')
    V.assert(not next(visual.card.images) and not next(visual.composite.images),'both consumers release all image bridges')
    modal=Host.Open(owner,'再次打开',nil,{width=420});modal:AddContent(UI.Label{text='Reopen after disposal',height=80})
end)
V.atFrame(32,function()
    V.assert(modal.visual.card.ready and modal.visual.composite.ready,'actual layers reopen after disposal')
    modal:Close(true);Lifetime.Flush()
end)
V.atFrame(38,function()
    Lifetime.Flush();V.assert(Lifetime.PendingCount()==0,'render surfaces release safely before texture disposal')
    UI.SetRoot(nil);root:Destroy();UI.Shutdown();V.finish()
end)
