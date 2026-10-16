local UI=require 'urhox-libs/UI'
local M={}
function M.Create(session,root)
    local prefs=require('controls.TouchPreferences').Get(session.app)
    local controls=session.controls;local layer=false
    local function Ready()
        if session.dialog or not session:HasFocus() then return false end
        if not session.pointer.captured then return session:Resume() end
        return true
    end
    local playfield=UI.Panel{position='absolute',width='100%',height='100%'};root:AddChild(playfield)
    local options={{'menu','继续'},{'settings','设置'},{'exit','退出 / 返回'},{'flip','翻正（R）'},
        {'aux-boost','辅助键：下降 / 冲刺'},{'aux-cut','辅助键：停止升力'},{'rotor','步进转轴'}}
    if session.battle then options[#options+1]={'board','战绩'} end
    if session.practice or not session.combat then options[#options+1]={'teleport','传送到下一个区域'};options[#options+1]={'spawn','回出生点'} end
    if session.endless then for _,item in ipairs({{'repair','维修补给'},{'wave','下一波'},{'refit','战场改装'}}) do options[#options+1]=item end end
    local adapter={}
    adapter={mode='drive',app=session.app,prefs=prefs,sensitivity=prefs.sens,Ready=Ready,
        Move=function(x,y) controls.touchSteer=-x;controls.touchThrottle=y end,
        Look=function(dx,dy) controls:Look(dx,dy) end,
        Zoom=function(delta) session:ZoomPixels(delta) end,
        Dash=function(on)
            local dash=on and session.vehicle.mechControl~=nil
            controls.held.boost=dash or layer and layer.gestures:Held('aux') and layer.aux=='boost' or false
            if layer then layer.stick.dash=dash end
        end,
        Hold=function(action,on)
            if action=='aux' then action=layer.aux end
            if action=='interact' then
                if on and layer.contextRole~='interact' then return false end
                if not on and not controls.held.interact then return false end
                if on and session.salvage then session.salvage.tapE=true end
            end
            local keys={up={'brake','jump','climb'},down={'descend'},boost={'descend','boost'},cut={'cutLift'},['rudder-l']={'strafeLeft'},['rudder-r']={'strafeRight'},interact={'interact'},primary={'fire'}}
            local fields=keys[action];if not fields then return false end
            for _,key in ipairs(fields) do controls.held[key]=on end
            return true
        end,
        Action=function(action)
            if action:sub(1,4)=='aux-' then layer.aux=action:sub(5)
            elseif action=='exit' then
                if session.battle then require('combat.MatchActions').ConfirmLeave(session.battle) else session.wantsReturn=true end
            elseif action=='scope' then session.scope=not session.scope
            elseif action=='settings' then require('ui.GameSettings').Open(session)
            elseif action=='weapon' then session.weapons:Select(session.weapons.current%math.max(1,#session.weapons.groups)+1)
            elseif action=='flip' then session:Flip()
            elseif action=='interact' then
                if layer.contextRole=='flip' then session:Flip()
                elseif layer.contextRole=='swap' and session.salvage then session.salvage.tapF=true end
            elseif action=='rotor' then controls.rotorStep=true
            elseif action=='teleport' then session:NextArea()
            elseif action=='spawn' then session:ResetAll()
            elseif action=='repair' then session.endless:HandleKey(KEY_V)
            elseif action=='wave' then session.endless:NextWave()
            elseif action=='refit' then session.endless:EnterEdit()
            elseif action=='board' then session.touchScoreboard=not session.touchScoreboard end
            if action=='plane-mode' then controls.planePoint=not controls.planePoint end
        end,
        Reset=function() controls:Clear();session.scope=false;session.firing=false;session.pointer:Suppress() end,
        Menu=function(open) if open then session:Pause() else session:Resume() end end,
        Labels=function(l)
            if session.combat and not session.combat.player.alive then
                l.flipSince=nil;l.contextRole=nil
                for _,button in pairs(l.buttons) do button:SetVisible(false) end
                return
            end
            local v=session.vehicle;local wings=#(v.spec.wings or {})>0
            controls.planePoint=wings and prefs.plane=='point';adapter.sensitivity=prefs.sens
            local keys=wings and not controls.planePoint;local point=wings and controls.planePoint
            local lifts=false;for _,t in ipairs(v.spec.thrusters or {}) do if t.dir[2]>.7 then lifts=true;break end end
            l.Relayout(keys,prefs.size)
            l.buttons.up.props.icon=keys and 'pitch-up' or v.legMode and 'jump' or (v.hoverMode or lifts) and 'up' or 'brake'
            l.buttons.up:SetVisible(not l.menu and not l.blocked and not point)
            l.buttons.aux.props.icon=keys and 'pitch-down' or v.mechControl and l.aux=='boost' and 'boost' or 'down'
            l.buttons.aux:SetVisible(not l.menu and not l.blocked and not point and (keys or v.hoverMode or lifts or v.mechControl or l.aux~='boost'))
            for _,id in ipairs({'rudder-l','rudder-r'}) do l.buttons[id]:SetVisible(not l.menu and not l.blocked and keys) end
            l.buttons.scope.props.selected=session.scope
            local time=session.world.time or 0;local q=v.body.rotation();local inverted=1-2*(q.x*q.x+q.z*q.z)<.35
            if not inverted then l.flipSince=nil elseif not l.flipSince then l.flipSince=time end
            local story=session.story;local rules=story and story.rules;local step=rules and rules:StepSpec()
            local storyPrompt=story and story.player.alive and not rules.finished and not rules.completeAt and rules.inside and step and
                (step.kind=='install' and not rules.blocked or step.kind=='capture' and rules.cap and rules.cap.phase=='scrub')
            local salvage=session.salvage;local prompt=salvage and salvage.touchPrompt or storyPrompt
            l.contextRole=salvage and salvage.touchSwap and 'swap' or prompt and 'interact' or l.flipSince and time-l.flipSince>1 and not session.resetChan and 'flip' or nil
            l.buttons.interact:SetVisible(not l.menu and not l.blocked and l.contextRole~=nil)
            l.buttons.interact.props.icon=l.contextRole=='swap' and 'erase' or l.contextRole=='flip' and 'flip' or 'interact'
            l.buttons.interact.props.text=({swap='换货',flip='翻正',interact='交互'})[l.contextRole] or ''
            local groups=session.weapons.groups;local nextGroup=#groups>1 and groups[session.weapons.current%#groups+1]
            local last=nextGroup and nextGroup.weapons[#nextGroup.weapons];local kind=last and last.type
            l.buttons.weapon.props.iconPath=kind and ('UI/WeaponIcons/'..(kind=='fuyuanDrill' and 'tianyuanDrill' or kind)..'.png') or nil
            l.buttons.weapon:SetVisible(not l.menu and not l.blocked and nextGroup~=false and nextGroup~=nil)
            l.buttons.board:SetVisible(not l.menu and not l.blocked and session.battle~=nil)
            if l.readiness then local group=session.weapons:Group();l.readiness.value=group and math.max(0,math.min(1,session.weapons:Readiness(group))) or 1 end
        end}
    layer=require('ui.SourceTouchOverlay').Create(root,playfield,adapter,{'scope','interact','up','primary','aux','weapon','rudder-l','rudder-r','board'},options)
    layer.buttons.fire=layer.buttons.primary;layer.buttons.brake=layer.buttons.up;layer.buttons.descend=layer.buttons.aux
    layer.Update(false);return layer
end
return M
