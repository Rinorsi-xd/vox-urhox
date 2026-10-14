-- PC source HUD composition; custom VG draws, UI owns pointer routing/lifetime.
local UI=require 'urhox-libs/UI'
local Chrome=require 'ui.DriveChrome'
local Theme=require 'ui.VoxTheme'
local M={}
function M.Create(session)
    require('controls.TouchMode').Apply('drive')
    local width,height=UI.GetViewportSize();local weapons=session.weapons
    local root=UI.Panel{width='100%',height='100%',pointerEvents='box-none'}
    local controls=require('ui.DriveControls').Create(session,root)
    local state={root=root,playfield=controls.playfield,touchControls=session.touch and controls or nil,buttons={},cards={},width=width,height=height,refresh=0,readoutUpdates=0,disposed=false}
    local function Add(kind,props)
        props=props or {};props.kind=kind;props.position='absolute';props.pointerEvents=props.onClick and 'auto' or 'none'
        local widget=Chrome(props);widget.session=session;root:AddChild(widget);return widget
    end
    state.title=Add('title',{left=12,top=12,width=400,height=37})
    state.timer=Add('timer',{top=12,left='50%',width=1,height=1});state.timer.title=state.title
    local top=12
    if session.vehicle.legMode and session.map.id=='trial' then
        for _,item in ipairs({{'hill','练习：山坡','节足山坡',102},{'wall','练习：抓墙 / 跳跃','节足抓墙',151}}) do
            state.buttons[item[1]]=Add('exit',{text=item[2],course=true,right=12,top=top,width=item[4],height=36,onClick=function() session:GoTo(item[3]) end});top=top+44
        end
    end
    state.buttons['return']=Add('exit',{right=12,top=top,width=103.03125,height=36,onClick=function() session.wantsReturn=true end})
    state.stats=Add('stats',{right=12,top=top+44,width=206,height=51})
    state.meter=require('ui.DriveMeter'){position='absolute',left=12,bottom=50,width=400,height=110,pointerEvents='none'};state.meter.session=session;root:AddChild(state.meter)
    state.detailPanel=require('ui.DriveDetails'){position='absolute',left=12,top=72,width=280,height=260,pointerEvents='none',visible=session.details};state.detailPanel.session=session;root:AddChild(state.detailPanel)
    state.vitals=require('ui.MechReticle'){position='absolute',left=0,top=0,width='100%',height='100%',pointerEvents='none'};state.vitals.session=session;root:AddChild(state.vitals)
    state.overlay=require('ui.DriveOverlay').New(session,root,state.vitals)
    state.missile=require('ui.MissileHud'){position='absolute',width='100%',height='100%',pointerEvents='none'}
    state.missile.session=session;state.missile.overlay=state.overlay;root:AddChild(state.missile)
    local total=math.max(1,#weapons.groups)*50-4
    for i=1,math.max(1,#weapons.groups) do
        local index=i
        local card=Add('weapon',{right=12,bottom=58+total-i*50+4,width=214,height=46,onClick=session.touch and function() weapons:Select(index) end or nil})
        card.group=weapons.groups[i];card.index=i;state.cards[#state.cards+1]={widget=card}
    end
    state.keys=Add('keys',{left=0,bottom=14,width='100%',height=33})
    state.pause=Add('pause',{width='100%',height='100%'})
    if session.battle then
        for _,widget in ipairs({state.title,state.timer,state.stats,state.keys,state.buttons['return']}) do widget:SetVisible(false) end
        state.match=require('ui.MatchHud').Attach(session,root)
        state.mvp=require('ui.MvpShow'){position='absolute',width='100%',height='100%',pointerEvents='auto',visible=false};state.mvp.session=session;root:AddChild(state.mvp)
    elseif session.story then
        for _,widget in ipairs({state.timer,state.stats,state.keys}) do widget:SetVisible(false) end
        state.story=require('ui.MissionHud').Attach(session,root)
    elseif session.salvage then
        for _,widget in ipairs({state.title,state.timer,state.stats,state.keys}) do widget:SetVisible(false) end
        for _,card in ipairs(state.cards) do card.widget:SetStyle({bottom=220+(#state.cards-card.widget.index)*50}) end
        state.salvage=require('ui.SalvageRunHud').Attach(session,root)
        state.cinema=require('ui.SalvageCinematics'){position='absolute',left=0,top=0,width='100%',height='100%',pointerEvents='auto'}
        state.cinema.session=session;root:AddChild(state.cinema)
    end
    if session.touch then
        state.stats:SetVisible(false);state.keys:SetVisible(false);state.timer:SetVisible(false);state.meter:SetVisible(false)
        root:RemoveChild(controls.root);root:AddChild(controls.root)
    end
    -- The frozen reticle owns weapon slots and speed; retain real touch buttons.
    for _,card in ipairs(state.cards) do card.widget:SetVisible(false) end
    local modes={};for _,child in ipairs(root.children) do modes[child]=child.props.pointerEvents or 'auto' end
    state.Clear=controls.Clear
    function state.Update(s,dt)
        if state.disposed then return end;dt=dt or 0
        weapons=s.weapons
        local active=s.pointer.captured and not s.dialog
        if state.captured~=active and not s.touch then
            state.captured=active
            root:SetStyle({pointerEvents=active and 'none' or 'box-none'})
            for child,mode in pairs(modes) do child:SetStyle({pointerEvents=active and 'none' or mode}) end
        end
        local alive=not s.combat or s.combat.player.alive;local over=s.battle and s.battle.rules.state=='over' or s.story and s.story.rules.finished or s.salvage and s.salvage.result~=nil
        local cinematic=s.salvage and s.salvage.cine.blocking
        local hideHud=cinematic or s.salvage and s.salvage.cine.barsOn
        local mvp=s.battle and s.battle.mvpShow and not s.battle.mvpShow.done
        hideHud=hideHud or mvp
        if state.mvp then state.mvp:SetVisible(mvp==true);state.missile:SetVisible(not mvp);state.overlay.layer:SetVisible(not mvp) end
        local choosing=s.story and s.story.rules.choice~=nil
        state.pause:SetVisible(not active and not s.touch and not over and not choosing and not hideHud);state.vitals:SetVisible(active and alive and not hideHud);state.detailPanel:SetVisible(s.details and alive and not hideHud)
        if s.salvage then state.buttons['return']:SetVisible(not hideHud and not over);state.missile:SetVisible(not hideHud and not over) end
        if state.touchControls then
            state.touchControls.Update(over or choosing or cinematic or s.dialog~=nil or not s:HasFocus())
        end
        state.meter:SetVisible(false)
        if not state.touchControls then state.playfield:SetVisible(not over and not cinematic) end
        if state.match then state.match.Update(dt) end
        if state.story then state.story.Update(dt) end
        if state.salvage then state.salvage.Update(dt) end
        state.vitals.hit=math.max(0,(state.vitals.hit or 0)-dt)
        state.overlay:Update(dt);state.vitals.aimState=state.overlay.aimState
        require('ui.ReticleState').Update(state.vitals,dt)
        for i,card in ipairs(state.cards) do card.widget.group=weapons.groups[i];card.widget.readiness=weapons.groups[i] and math.max(0,math.min(1,weapons:Readiness(weapons.groups[i]))) or 0 end
        local group=weapons:Group()
        state.vitals.hint=group and group.weapons[1].stats.drill and weapons.drill:Hint() or group and group.kind=='missile' and '' or s.firing and group and weapons.blocked>=#group.weapons and '目标在射界外' or s.firing and state.overlay.aimState=='blocked' and '炮口被挡住' or ''
        state.refresh=state.refresh-dt
        if state.refresh<=0 or dt==0 then
            state.refresh=.1;state.readoutUpdates=state.readoutUpdates+1;if alive then state.meter:Refresh() end
            if s.details and alive then state.detailPanel:Refresh() end
        end
    end
    function state.Dispose()
        if state.disposed then return end;state.disposed=true
        if controls.Dispose then controls.Dispose() else controls.Clear() end;Theme.TrimThumbnails({})
        if UI.GetRoot()==root then UI.SetRoot(nil) end
        if root.node then root:Destroy() end
    end
    UI.SetRoot(root,true);state.Update(session,0);return state
end
return M
