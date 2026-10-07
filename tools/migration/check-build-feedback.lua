local UI=require 'urhox-libs/UI'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local app,s,hover,hitX,hitY,oldRoot,keptToast
local w,h=1920,1080
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function At(x,y,kind,button)
    UI.HandlePointerEvent(E.new(kind,{x=x,y=y,pointerId=91,pointerType='mouse',button=button or MOUSEB_LEFT}))
end
local function Bound()
    s.hud.root:SetStyle({width=w,height=h});renderer:GetViewport(0):SetRect(IntRect(0,0,w,h));hover=s.hud.hover
end
local function Words(widget)
    local result={};for _,line in ipairs(widget.info and widget.info.paragraphs or {}) do for _,run in ipairs(line) do result[#result+1]=run.text or '' end end
    return table.concat(result)
end
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'captured native feedback frame')
    local crop=image:GetSubimage(IntRect(0,0,w,h));V.assert(crop:SavePNG('docs/migration/evidence/pc-feedback-'..name..'.png'),'saved '..name);crop:Dispose();image:Dispose()
end
V.atFrame(55,function()
    app=VOX_HANGAR.app
    UI.SetScale(1);UI.GetViewportSize=function() return w,h end;UI.GetWidth=function() return w end;UI.GetHeight=function() return h end
    app:EnterBuild();s=app.build;Bound()
    -- Injected UI mouse events do not move the OS cursor. Prevent real desktop
    -- focus/mouse polling from overwriting the injected pointer between frames.
    s.controls.Update=function() end
end)
V.atFrame(72,function()
    -- A real camera ray and native mouse event, not a hand-authored hover label.
    for y=360,800,20 do for x=600,1300,20 do
        if not hitX then s:Trace(x,y);if s.editor.hit and s.editor.preview and s.editor.preview.res.ok then hitX,hitY=x,y end end
    end end
    V.assert(hitX~=nil,'raycast found an actual attachable vehicle surface')
    At(hitX,hitY,'PointerMove');s:Refresh()
    V.assert(hover.info and Words(hover):find('放置',1,true) and Words(hover):find('耐久',1,true),'native pointer hover includes placement and actual target properties')
end)
V.atFrame(82,function()
    Shot('hover');local layout=hover.textLayout;local r=hover.bounds
    V.assert(r and r.x==hitX+18 and r.y==hitY+18 and r.w<=340,'orbit tooltip matches source 18px offset and 340px border-box limit')
    hover:Sync();V.assert(hover.textLayout==layout,'unchanged picking reuses measured text layout')
    At(hitX,hitY,'PointerDown',MOUSEB_RIGHT);s:Refresh()
    V.assert(hover.info==nil,'right mouse camera ownership hides hover')
    At(hitX+20,hitY,'PointerMove',MOUSEB_RIGHT);At(hitX+20,hitY,'PointerUp',MOUSEB_RIGHT)
    At(150,30,'PointerMove');s:Refresh();V.assert(hover.info==nil,'moving over toolbar releases world hover')
    s.hud.SetColor(true);hover:Sync();V.assert(hover.info==nil,'color popover blocks hover');s.hud.SetColor(false)
    s:OpenPause();hover:Sync();V.assert(hover.info==nil,'pause modal blocks hover');s.dialog:Close()
    s:OpenInventory();hover:Sync();V.assert(hover.info==nil,'inventory blocks hover');s.inventoryPanel:Close()
    -- Command-model fixtures exercise disconnected, mirrored, paste and empty slots.
    local bp=require('build.Blueprint').New()
    bp:Add({id=1,type='core',pos={0,4,0},rot=0,color=0xff6a13})
    bp:Add({id=2,type='cube',pos={4,4,0},rot=0,color=0x336699})
    local mirrored=require('build.Placement').Mirror('cube',{4,4,0},0)
    bp:Add({id=3,type='cube',pos=mirrored.pos,rot=mirrored.rot,color=0x336699})
    local ed=require('build.BuildEditor').New(bp)
    local fixture={editor=ed,controls={inside=true,x=700,y=500},buildCamera={mode='orbit',captured=false},hud={colorOpen=false},inspection={Get=function() return bp:Diagnose(require('Config').TIERS[3]) end}}
    local actual=hover.session;hover.session=fixture
    local hit={partId=2,cell={4,4,0},place={4,5,0},normal={0,1,0}}
    ed:SetTool('paint');ed:Preview(hit);hover:Sync()
    V.assert(Words(hover):find('涂装',1,true) and Words(hover):find('含镜像',1,true),'paint tooltip identifies actual mirrored targets')
    V.assert(Words(hover):find('未连接核心',1,true),'disconnected warning comes from blueprint connectivity')
    ed:SetTool('erase');ed:Preview(hit);hover:Sync();V.assert(hover.info.bad and Words(hover):find('删除',1,true),'erase uses original danger feedback')
    ed:SelectType('core');ed:Preview(hit);hover:Sync();V.assert(hover.info.bad and Words(hover):find('无法放置',1,true),'actual rejected placement exposes command reason')
    ed:SelectType('cube');ed.emptySlot=true;ed:Preview(hit);hover:Sync();V.assert(not Words(hover):find('放置',1,true) and Words(hover):find('耐久',1,true),'empty hotbar keeps target info without invented placement')
    ed.emptySlot=false;ed.selection={[2]=true};ed:Copy();ed:StartPaste();ed:Preview(hit);hover:Sync()
    V.assert(Words(hover):find('粘贴 1 个零件',1,true) and not Words(hover):find('耐久',1,true),'valid actual clipboard preview displays count and omits target footer')
    ed:Preview({partId=2,cell={4,4,0},place={4,4,0},normal={0,1,0}});hover:Sync()
    V.assert(hover.info.bad and Words(hover):find('无法粘贴',1,true),'overlapping paste exposes first actual failure')
    fixture.buildCamera.mode='fp';hover:Sync();V.assert(hover.info==nil,'uncaptured first-person view has no target tooltip')
    fixture.buildCamera.captured=true;hover:Sync();V.assert(hover.info.center,'captured first-person hover is centered')
    hover.session=actual;s.controls:Cancel();s:Refresh()
    local q=require('ui.SourceToasts').New()
    q:Push('一');q:Push('二');q:Push('三');q:Push('四')
    V.assert(#q.items==3 and q.items[1].text=='二','toast queue evicts oldest after three')
    q:Update(2.19);V.assert(#q.items==3 and q.items[1].age<q.items[1].hold,'toast stays before source 2200ms deadline')
    q:Update(.02);V.assert(#q.items==3 and q.items[1].age>q.items[1].hold,'toast begins exit after deadline')
    q:Update(.4);V.assert(#q.items==0,'expired toast entries and layouts are released')
    q:Push('重复');q:Push('重复');V.assert(#q.items==2,'repeated notification events remain distinct')
    q:SetText('');V.assert(#q.items==2,'clearing last message does not cancel earlier event notifications')
    app.toasts.items={};s:Notify('已保存到车位 1','ok');s:Notify('无法放置：此处已有零件','bad');s:Notify('零件没有连接核心','warn')
end)
V.atFrame(94,function()
    Shot('toasts');V.assert(#app.toasts.items==3 and app.toasts.items[1].layoutWidth==682,'live app toast renders source 720px maximum and is capped at three')
    s:OpenPause();s:Notify('通知显示在暂停面板上方','info')
end)
V.atFrame(108,function()
    Shot('modal');s.dialog:Close()
    app.toasts.items={};keptToast=app.toasts:Push('PC 窗口缩放时保留提示','ok',5000);keptToast.age=.5
    oldRoot=s.hud.root;w,h=1440,900
end)
V.atFrame(122,function()
    Bound();V.assert(not oldRoot.node and app.toasts.items[1]==keptToast and keptToast.age>=.5,'PC resize keeps live notification age and releases old widgets')
    s.editor:SetTool('erase');At(760,550,'PointerMove');s:Refresh()
end)
V.atFrame(134,function()
    Shot('1440');local toast=app.toasts
    app:ExitBuild();V.assert(require('ui.GarageHud').GetState().message==toast,'home and build share the same source notification lifetime')
    V.assert(#toast.items>0,'returning home does not discard active notification')
    UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale)
    toast:Dispose();toast:Push('已销毁');V.assert(toast.disposed and #toast.items==0,'disposal unregisters notifications and rejects late events')
    V.finish()
end)
