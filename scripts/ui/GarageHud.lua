-- PC home composition: source NanoVG visuals, existing Garage state and operations.
local UI=require 'urhox-libs/UI'
local Theme=require 'ui.VoxTheme'
local Button=require 'ui.SourceButton'
local ActionButton=require 'ui.ActionButton'
local Layout=require 'ui.GarageLayout'
local Dialogs=require 'ui.GarageDialogs'
local Config=require 'Config'
local M={}
---@type table|false
local state=false
local function Clear(container)
    local old={table.unpack(container.children)};container:ClearChildren();for _,c in ipairs(old) do c:Destroy() end
end
function M.Dispose()
    if not state then return end
    require('ui.MusicBox').Close(state)
    require('ui.LiveryPage').Leave(state)
    require('ui.DialogHost').Dispose(state);state.CancelInput();state.previews:Dispose()
    require('ui.Workshop').Leave(state)
    if state.workshop then
        local saved={}
        for _,key in ipairs({'view','selected','group','sort','from'}) do saved[key]=state.workshop[key] end
        state.app.homeWorkshopState=saved
    end
    require('ui.StoryPage').Leave(state)
    require('ui.SalvagePage').Leave(state)
    if UI.GetRoot()==state.root then UI.SetRoot(nil) end
    if state.root.node then state.root:Destroy() end
    Theme.TrimThumbnails({});state=false
end
function M.IsBlocked() return state and (state.dialog~=nil or state.newOpen or state.musicBox~=nil) or false end
function M.SetMode(text) if state then state.message:SetText(text or '') end end
function M.GetState() return state end
function M.Refresh() if state then state.revision=-1 end end
local function Build(app)
    require('controls.TouchMode').Apply('home');local w,h=UI.GetViewportSize()
    local s={app=app,revision=-1,tab=app.homeTab or 'hangar',buttons={},cards={},width=w,height=h,pointers={}}
    if app.homeWorkshopState then
        s.workshop={elapsed=0}
        for _,key in ipairs({'view','selected','group','sort','from'}) do s.workshop[key]=app.homeWorkshopState[key] end
        if s.workshop.view~='feature' then s.workshop.entrance={kind=s.workshop.view,elapsed=.9} end
    end
    state=s
    s.Track=function(widget)
        local down,up,cancel=widget.OnPointerDown,widget.OnPointerUp,widget.OnPointerCancel
        widget.OnPointerDown=function(self,e) s.pointers[e.pointerId]=e.pointerType;return down(self,e) end
        widget.OnPointerUp=function(self,e) s.pointers[e.pointerId]=nil;return up(self,e) end
        widget.OnPointerCancel=function(self,e) s.pointers[e.pointerId]=nil;return cancel(self,e) end
        return widget
    end
    s.CancelInput=function()
        for id,kind in pairs(s.pointers) do UI.CancelPointer(id,kind) end;s.pointers={}
        if s.bayScroll then s.bayScroll.state.isDragging=false;s.bayScroll.state.velocityX=0 end
    end
    local function AddButton(parent,id,text,icon,kind,fn,props)
        local p={text=text,icon=icon,sourceKind=kind,onClick=fn,borderRadius=0,fontSize=17}
        for k,v in pairs(props or {}) do p[k]=v end
        local b=s.Track(Button(p));parent:AddChild(b);if id then s.buttons[id]=b end;return b
    end
    s.SetNew=function(open) s.newOpen=open;s.menu:SetOpen(open);s.scrim:SetVisible(open) end
    s.SetTab=function(tab,options)
        app.vehicleGate:Cancel()
        if app.vehicleSwitch then app.vehicleSwitch:CancelDownload() end
        if s.tab=='livery' and tab~='livery' then require('ui.LiveryPage').Leave(s) end
        if s.tab=='story' and tab~='story' then require('ui.StoryPage').Leave(s) end
        if (s.tab=='workshop' or s.tab=='salvage') and tab~=s.tab then require('ui.Workshop').Leave(s) end
        if s.tab=='salvage' and tab~='salvage' then require('ui.SalvagePage').Leave(s) end
        s.SetNew(false);s.tab=tab;app.homeTab=tab;s.revision=-1
        if app.gallery then app:ToggleGallery() end
        app:HomeView(tab)
        if not (options and options.quiet) then require('audio.UiSound').Play('whoosh') end
        Layout.Apply(s,s.width,s.height,s.safe)
    end
    s.Run=function(fn,onSuccess,data)
        local function Begin(discard)
            if state~=s then return false end
            return app.vehicleSwitch:Begin(function()
                if state~=s then return false,'界面已切换' end
                return fn(discard)
            end,function(ok,err,reason)
                if state~=s then return end
                s.revision=-1
                if not ok and reason=='discard' then
                    Dialogs.Confirm(s,'放弃未保存的草稿？',err..'。换车后无法恢复当前草稿。',function() Begin(true) end)
                else
                    s.message:SetText(ok and '' or err)
                    if ok and onSuccess then onSuccess() end
                end
            end,data and require('parts.Dependencies').FromBlueprint(data) or nil)
        end
        return Begin(false) -- Accepted request, not a synchronous storage result.
    end
    s.SetLobby=function(mode)
        s.Run(function() return require('app.SalvageLobby').Switch(app,mode) end,function()
            s.bayRevision=nil;s.SetTab(mode=='salvage' and 'salvage' or 'hangar')
        end,require('app.SalvageLobby').VehicleData(app,mode))
    end
    s.CreateVehicle=function(id)
        s.SetNew(false)
        if app.lobby=='salvage' and id~='empty' then return require('ui.SalvageBuy').Car(s,id) end
        s.Run(function(discard) return app.bays:CreateVehicle(id,nil,discard) end,function()
            if app.lobby=='salvage' then
                require('ui.SalvagePage').Tab(s,'garage');s.SetTab('salvage',{quiet=true})
            else s.SetTab('hangar',{quiet=true});if id=='empty' then app:EnterBuild() end end
        end,require('construction.Prefab').Create(require('construction.Blueprint').New(),id):ToTable())
    end
    s.root=UI.Panel{width='100%',height='100%',pointerEvents='box-none'}
    s.root.actionButtonKeys=function() return s.tab=='hangar' and not s.dialog and not s.musicBox end
    local chrome=require('ui.HomeChrome'){position='absolute',width='100%',height='100%',pointerEvents='none'};chrome.owner=s;s.root:AddChild(chrome)
    s.nav=UI.Panel{position='absolute',pointerEvents='box-none'};s.root:AddChild(s.nav)
    for _,tab in ipairs({{'hangar','机库'},{'livery','涂装'},{'workshop','创意工坊'},{'shop','商店'}}) do AddButton(s.nav,tab[1],tab[2],tab[1],'tab',function() s.SetTab(tab[1]) end) end
    AddButton(s.nav,'intro','开场动画','play','intro',function() app:StartOpening() end)
    AddButton(s.nav,'help','','help','icon',function() Dialogs.Help(s) end)
    AddButton(s.nav,'settings','','gear','icon',function() require('ui.PauseMenu').Open(s) end)
    local Info=UI.ScrollView
    s.info=Info{position='absolute',overflow='hidden',scrollX=false,scrollY=true,bounces=false};s.stats=s.info;s.root:AddChild(s.info)
    s.loadout=UI.ScrollView{position='absolute',overflow='hidden',scrollX=false,scrollY=true,bounces=false};s.root:AddChild(s.loadout)
    s.navHeight=64
    s.page=require('ui.HomePages').Create(s);s.root:InsertChild(s.page,1)
    s.cta=UI.Panel{position='absolute',pointerEvents='box-none'}
    AddButton(s.cta,'edit','改装','wrench','cta-left',function() app:EnterBuild() end,{subtitle='进编辑页搭车',key='E'})
    AddButton(s.cta,'trial','试车','wheel','cta-right',function() app:EnterTrial() end,{subtitle='直接开去试车场',key='T'})
    AddButton(s.cta,'battle','出战','battle','cta-main',function() if s.tab=='battle' then app:EnterTrial(app.selectedMap) else s.SetTab('battle') end end,{key='F'})
    s.actions=UI.Panel{position='absolute',flexDirection='row',gap=6,padding=8,backgroundColor='#112337',borderWidth=1,borderColor='#6286a5'}
    AddButton(s.actions,'copy','复制','copy','action',function() s.Run(function(d) return app.bays:Copy(d) end) end,{width=80,height=38})
    AddButton(s.actions,'export','分享','share','action',function() Dialogs.Code(s,false) end,{width=80,height=38})
    AddButton(s.actions,'delete','删除','trash','action',function() Dialogs.Delete(s) end,{width=82,height=38})
    s.root:AddChild(s.actions)
    AddButton(s.root,'manage','车辆管理','gear','manage',function() s.manageOpen=not s.manageOpen;Layout.Visibility(s) end)
    s.bayStrip=UI.Panel{flexDirection='row',gap=10,height=138}
    s.bayScroll=UI.ScrollView{position='absolute',scrollX=true,scrollY=false,showScrollbar=false,children={s.bayStrip}}
    s.root:AddChild(s.bayScroll);s.previews=require('ui.BayPreviews').New(s.bayScroll,app.previews)
    local function Scroll(direction) local x=s.bayScroll:GetScroll();s.bayScroll:SetScroll(x+direction*s.bayScroll:GetLayout().w*.8,0) end
    s.leftArrow=AddButton(s.root,nil,'','back','arrow',function() Scroll(-1) end)
    s.rightArrow=AddButton(s.root,nil,'','back','arrow',function() Scroll(1) end,{rightArrow=true})
    AddButton(s.root,'new','新战车','plus','new',function() s.SetNew(not s.newOpen) end)
    s.root:AddChild(s.cta)
    s.musicConsole=require('ui.MusicBoxVisual').Console{text='音乐盒',icon='music',position='absolute',padding=0,onClick=function() require('ui.MusicBox').Open(s) end}
    s.musicConsole.player=app.music;s.root:AddChild(s.musicConsole);s.buttons.music=s.musicConsole
    s.modeStrip=UI.Panel{position='absolute',pointerEvents='box-none'}
    AddButton(s.modeStrip,'arena','竞技对战','battle','mode',function() end,{selected=true,subtitle='3v3 / 4v4 匹配'})
    AddButton(s.modeStrip,'salvage','打捞行动','hook','mode',function() s.SetLobby('salvage') end,{subtitle='搜打撤 · 独立仓库',salvage=true})
    s.root:AddChild(s.modeStrip)
    s.message=app.toasts
    if app.homeMessage then s.message:Push(app.homeMessage,'bad');app.homeMessage=nil end
    s.scrim=UI.Panel{position='absolute',width='100%',height='100%',visible=false,onPointerDown=function() s.SetNew(false) end};s.root:AddChild(s.scrim)
    s.menu=require('ui.HomeNewMenu').Create(s);s.root:AddChild(s.menu)
    Layout.Apply(s,w,h,UI.GetSafeAreaInsets());UI.SetRoot(s.root,true)
end
function M.Create(app)
    M.Dispose()
    local ok,err=xpcall(Build,debug.traceback,app)
    if ok then return end
    -- Build 一开始就发布 state（页面模块建控件时要读它）。中途失败时不能留下半成品：
    -- 否则 SetMode / Update 每帧访问还没建的控件，一个初始化错误会变成上百条连锁报错。
    pcall(M.Dispose);state=false
    error(err,0)
end
local function Rebuild(s)
    -- Decal edits dirty the blueprint each pointer move; hidden home cards can
    -- wait until SetTab invalidates the page again on returning to the hangar.
    if s.tab=='livery' and s.page.session then s.revision=s.app.bays.revision;s.tier=s.app.tier;return end
    local app=s.app;local slots=app.bays:Slots();local used=0
    for _,d in ipairs(slots) do if d then used=used+1 end end;s.usedCount=used
    s.buttons.copy:SetDisabled(used==20);s.buttons.new:SetDisabled(used==20);s.buttons.delete:SetDisabled(not app.bays.active)
    Clear(s.info);Clear(s.loadout);require('ui.HomeStats').Fill(s.info,app,s)
    for _,id in ipairs({'hangar','livery','workshop','shop'}) do s.buttons[id].props.selected=s.tab==id end
    s.buttons.battle:SetText(s.tab=='battle' and '开始战斗' or '出战');s.buttons.battle.props.key=s.tab=='battle' and 'Enter' or 'F'
    local mode=require('core.ResourceData').Read('UI/Outgame.json').modes[s.modeChoice or 'elimination']
    s.buttons.battle.props.subtitle=mode and (mode.name..' · '..mode.size..'v'..mode.size) or '单人 · 不计战绩'
    if not (s.tab=='livery' and s.page.session) then
        s.root:RemoveChild(s.page);s.page:Destroy();s.page=require('ui.HomePages').Create(s);s.root:InsertChild(s.page,1)
    end
    if s.bayRevision~=app.bays.revision then
        s.previews:Clear();Clear(s.bayStrip);s.cards={}
        local function Card(slot,data)
            local draft=not slot;local active=slot==app.bays.active
            local card=s.Track(UI.Panel{width=s.cardWidth,height=s.cardHeight,flexShrink=0,overflow='hidden',backgroundColor='#122638',onClick=function() if slot and slot~=app.bays.active then s.Run(function(d) return app.bays:Open(slot,d) end,nil,data) end end})
            if not draft then local picture=s.previews:Add(data);picture:SetStyle({position='absolute',left=0,top=0,width=s.cardWidth,height=s.cardHeight});card:AddChild(picture) end
            local overlay=require('ui.HomeBay'){position='absolute',width='100%',height='100%',pointerEvents='none'}
            local budget=0;local defs=require('parts.Defs').PARTS;for _,p in ipairs(data.parts) do budget=budget+(defs[p[1]] and defs[p[1]].budget or 0) end
            overlay.data={draft=draft,slot=slot,active=active,name=data.name,budget=budget,parts=#data.parts};overlay.card=card;card:AddChild(overlay)
            if draft then
                local save=s.Track(Button{text='保存到车位',icon='save',sourceKind='save',position='absolute',right=18,top=8,width=110.5,height=28,onClick=function() Dialogs.Save(s) end})
                card:AddChild(save);s.buttons.save=save
            end
            s.bayStrip:AddChild(card);s.cards[#s.cards+1]=card
        end
        if not app.bays.active then Card(false,app.blueprint:ToTable()) end
        for i,data in ipairs(slots) do if data then Card(i,data) end end
        s.bayRevision=app.bays.revision
    end
    Layout.Apply(s,s.width,s.height,s.safe);s.revision=app.bays.revision;s.tier=app.tier
end
function M.Update(dt)
    if not state then return end;require('controls.TouchMode').Update('home');local s=state;local w,h=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
    require('ui.DialogHost').Update(s,dt)
    if w~=s.width or h~=s.height then s.CancelInput();Layout.Apply(s,w,h,safe);s.app:HomeView(s.tab);s.revision=-1 end
    if s.revision~=s.app.bays.revision or s.tier~=s.app.tier then Rebuild(s) end
    s.previews:Update(dt)
    if s.salvagePreviews then s.salvagePreviews:Update(dt) end
    if s.tab=='workshop' or s.tab=='salvage' and s.salvage and s.salvage.tab=='workshop' then require('ui.Workshop').Update(s,dt) end
    if s.tab=='story' then require('ui.StoryPage').Update(s,dt) end
    if s.tab=='livery' then require('ui.LiveryPage').Update(s,dt) end
    if s.workshopPreview then s.workshopPreview:Update(dt) end
    if s.dialogTick then s.dialogTick(dt) end
    if s.musicBox then require('ui.MusicBox').Update(s,dt);return end
    if not input.focus or input.minimized then s.CancelInput();return end
    local focus=UI.GetFocus();local typing=focus and focus.OnTextInput~=nil
    -- A button may change tabs or focus in its native key callback this frame.
    if ActionButton.KeyConsumed(KEY_RETURN) or ActionButton.KeyConsumed(KEY_KP_ENTER) or ActionButton.KeyConsumed(KEY_SPACE)
        or ActionButton.HasKeyboardFocus(focus) and (input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_KP_ENTER) or input:GetKeyPress(KEY_SPACE)) then return end
    if s.dialog then if input:GetKeyPress(KEY_ESCAPE) then Dialogs.Close(s) end
    elseif not typing and s.tab=='story' then require('ui.StoryPage').Key(s)
    elseif not typing and s.tab=='livery' and s.livery.controls:Key() then
    elseif not typing and s.tab=='salvage' then require('ui.SalvagePage').Key(s)
    elseif not typing and s.tab=='workshop' and require('ui.Workshop').Key(s) then
        -- Workshop consumes its source keys before global garage shortcuts.
    elseif not typing then
        if input:GetKeyPress(KEY_ESCAPE) then if s.newOpen then s.SetNew(false) elseif s.tab~='hangar' then s.SetTab('hangar') else require('ui.PauseMenu').Open(s) end
        elseif input:GetKeyPress(KEY_F) then s.SetTab('battle')
        elseif input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_KP_ENTER) then if s.tab=='battle' then require('ui.HomeBattle').Start(s) else s.app:EnterBuild() end
        elseif input:GetKeyPress(KEY_H) or input:GetKeyPress(KEY_F1) then Dialogs.Help(s) end
    end
end
return M
