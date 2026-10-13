-- Compare the live UI against independent DOM measurements from the frozen H5.
local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local Dialogs=require 'ui.GarageDialogs'
local f=assert(io.open('docs/migration/evidence/home-parity-source.json','r'))
local source=cjson.decode(f:read('*a'));f:close()
local app,s,store,menuUpdate
local w,h=1920,1080
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function Click(widget)
    local r=widget:GetAbsoluteLayoutForHitTest()
    local data={x=(r.x+r.w/2)*UI.GetScale(),y=(r.y+r.h/2)*UI.GetScale(),pointerType='mouse',pointerId=95,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',data));UI.HandlePointerEvent(E.new('PointerUp',data))
end
local function Bound()
    s=Hud.GetState();s.root:SetStyle({width=w,height=h})
    renderer:GetViewport(0):SetRect(IntRect(0,0,math.min(w,graphics:GetWidth()),math.min(h,graphics:GetHeight())))
end
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'native screenshot available')
    local crop=image:GetSubimage(IntRect(0,0,math.min(w,graphics:GetWidth()),math.min(h,graphics:GetHeight())))
    V.assert(crop:SavePNG('docs/migration/evidence/pc-source-'..name..'.png'),'saved '..name)
    crop:Dispose();image:Dispose()
end
local function Bounds(widget,expected,name)
    local r=widget:GetAbsoluteLayoutForHitTest();local e=expected.rect
    -- Native UI snaps fractional boxes to the nearest physical pixel.
    V.assert(math.abs(r.x-e[1])<=.51 and math.abs(r.y-e[2])<=.51 and math.abs(r.w-e[3])<=.51 and math.abs(r.h-e[4])<=.51,name..' matches frozen H5 DOM')
end
local function HomeBounds(case)
    local nodes=case.home.nodes
    for name,widget in pairs({nav=s.nav,info=s.info,loadout=s.loadout,cta=s.cta,edit=s.buttons.edit,battle=s.buttons.battle,trial=s.buttons.trial,mode=s.modeStrip,strip=s.bayScroll,card=s.cards[1],new=s.buttons.new,music=s.musicConsole}) do
        Bounds(widget,nodes[name],case.name..' '..name)
    end
end
V.atFrame(50,function()
    V.assert(source.baseline.commit=='90862445074e7e146da900037979ad97899ecf6c','fixture identifies the frozen current H5 commit')
    app=VOX_HANGAR.app;app.camera.autoSpin=false
    app.hangar.scanTime=100;app.hangar.greet=0
    store=require('storage.BlueprintStore').New('vox-pc-source-test');app.store=store;app.bays.store=store;app.bays.active=false
    for i=1,20 do store:DeleteSlot(i) end
    app.bays.revision=app.bays.revision+1
    UI.SetScale(1);UI.GetViewportSize=function() return w,h end;UI.GetWidth=function() return w end;UI.GetHeight=function() return h end
    Hud.Update(0);Bound()
end)
V.atFrame(75,function()
    local D=require 'ui.SourceDraw';local vg=UI.GetNVGContext();D.Begin(vg);nvgSave(vg)
    local metrics={baseline=source.baseline,display={}}
    for _,row in ipairs(source.display) do
        local actual=D.Width(vg,row.text,row.size,row.font,row.spacing)
        V.assert(math.abs(actual-row.width)<.016,'current DOM display advance '..row.font..' '..row.size..'px tracking '..row.spacing..' '..row.text)
        metrics.display[#metrics.display+1]={text=row.text,size=row.size,spacing=row.spacing,browser=row.width,native=actual}
    end
    local Typography=require 'ui.SourceTextLayout'
    V.assert(Typography.Get('从零建造')==Typography.Get('从零建造'),'display runs reuse cached layout')
    V.assert(Typography.Get('a'..utf8.char(0x301))==nil,'combining glyphs preserve native shaping')
    for digit=0,9 do V.assert(math.abs(D.Width(vg,tostring(digit),24,'vox-tabular')-D.Width(vg,'0',24,'vox-tabular'))<.01,'source tabular digit '..digit) end
    local file=assert(io.open('docs/migration/evidence/pc-font-metrics.json','w'));file:write(cjson.encode(metrics));file:close();nvgRestore(vg)
    Shot('home-1920');HomeBounds(source.cases[1]);Bounds(s.buttons.save,source.cases[1].home.nodes.save,'source save button')
    V.assert(#s.cards==1 and #s.previews.items==0,'draft placeholder does not instantiate empty bays')
    V.assert(not s.buttons.details and not s.buttons.rename,'no additional homepage commands')
    Click(s.buttons.new);V.assert(s.newOpen and Hud.IsBlocked(),'new popover gates scene camera')
    menuUpdate=s.menu.Update;s.menu.Update=function() end;s.menu:SetOpen(true);menuUpdate(s.menu,0)
end)
V.atFrame(77,function()
    Shot('new-menu-entry-0');menuUpdate(s.menu,.05)
    V.assert(s.menu.entry.value>0 and s.menu.entry.value<1 and s.menu.props.translateY>0,'source popover animates after 50ms')
end)
V.atFrame(79,function() Shot('new-menu-entry-50');menuUpdate(s.menu,.18) end)
V.atFrame(83,function()
    Shot('new-menu');s.menu.Update=menuUpdate
    local nodes=source.cases[1].menu.nodes
    Bounds(s.menu,nodes.menu,'current new menu');Bounds(s.menu.children[1],nodes.menuHeader,'menu header')
    for i,key in ipairs({'menuEmpty','menuImport','menuWorkshop'}) do Bounds(s.menu.children[i+1],nodes[key],key) end
    V.assert(not s.menu.entry and s.menu.props.translateY==0,'source popover entry settles')
    V.assert(not s.menu.layer.texture and s.menu.layer.bytes==0,'settled menu releases entry textures')
    V.assert(s.menu.children[2].props.text=='创建新车' and s.menu.children[3].props.text=='导入蓝图' and s.menu.children[4].props.text=='创意工坊','menu contains current H5 commands')
    Click(s.menu.children[3]);V.assert(not s.newOpen and s.dialog~=nil,'real import pointer opens dialog')
    Dialogs.Close(s);Click(s.buttons.save);V.assert(app.bays.active==1,'draft save writes an actual bay')
end)
V.atFrame(104,function()
    Shot('saved-car');V.assert(#s.cards==1 and s.previews.items[1].ready,'saved bay renders the actual vehicle')
    Click(s.buttons.manage);Click(s.buttons.export);V.assert(s.dialog~=nil,'manage share opens export dialog');Dialogs.Close(s)
    Click(s.buttons.battle);V.assert(s.tab=='battle' and not app.trial,'battle opens original mode page')
end)
V.atFrame(117,function()
    Shot('battle-1920');V.assert(not s.info:IsVisible() and not s.bayScroll:IsVisible() and not s.cta:IsVisible(),'mode page hides all original home bands')
    Click(s.buttons.workshop)
end)
V.atFrame(130,function()
    Shot('workshop-1920');V.assert(s.workshop and s.workshop.view=='feature','workshop opens current feature page')
    Click(s.buttons.shop)
end)
V.atFrame(141,function()
    Shot('shop-1920');Click(s.buttons.hangar);app.camera.autoSpin=false;w,h=1920,1200
end)
V.atFrame(157,function()
    Bound();V.assert(Hud.GetState()==s,'resizing retains UI owner');HomeBounds(source.cases[2])
    Click(s.buttons.new);s.menu:Update(.23)
end)
V.atFrame(160,function()
    Bounds(s.menu,source.cases[2].menu.nodes.menu,'16:10 menu bottom/right anchors');s.SetNew(false)
end)
V.atFrame(166,function()
    Click(s.buttons.settings);V.assert(s.dialog~=nil,'settings stays interactive');Dialogs.Close(s)
    local root=s.root;Click(s.buttons.edit);V.assert(app.build~=nil and not root.node,'edit releases homepage and uses same app')
    app:ExitBuild();Bound()
end)
V.atFrame(196,function()
    V.assert(app.bays.active==1 and s.root.node~=nil,'return retains saved vehicle and creates live homepage')
    Hud.Dispose();UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale)
    store.pending=nil
    for i=1,20 do store:DeleteSlot(i) end
    for _,key in ipairs({'draft','garage-state'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local path=store.prefix..key..suffix;if fileSystem:FileExists(path) then fileSystem:Delete(path) end end end
    V.finish()
end)
