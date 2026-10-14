local UI=require 'urhox-libs/UI'
local M={}
function M.Create(session,root)
    local controls=session.controls;local layer=false
    local function Ready()
        if session.dialog or not session:HasFocus() then return false end
        if not session.pointer.captured then return session:Resume() end
        return true
    end
    local playfield=UI.Panel{position='absolute',width='100%',height='100%'};root:AddChild(playfield)
    local options={{'menu','继续'},{'exit','返回'},{'weapon','切换武器'},{'flip','翻正'},
        {'scope','瞄准开关'},{'aux-interact','辅助：交互'},{'aux-boost','辅助：加速 / 降'},
        {'aux-cut','辅助：停止升力'},{'aux-strafe-left','辅助：左平移'},{'aux-strafe-right','辅助：右平移'},{'rotor','步进转轴'}}
    if session.battle then options[#options+1]={'board','战绩'} end
    local adapter={mode='drive',Ready=Ready,
        Move=function(x,y) controls.touchSteer=-x;controls.touchThrottle=y end,
        Look=function(dx,dy) controls:Look(dx,dy) end,
        Zoom=function(delta) session:ZoomPixels(delta) end,
        Hold=function(action,on)
            if action=='aux' then action=layer.aux end
            local keys={up={'brake','jump','climb'},down={'descend'},boost={'descend'},cut={'cutLift'},['strafe-left']={'strafeLeft'},['strafe-right']={'strafeRight'},interact={'interact'},primary={'fire'}}
            local fields=keys[action];if not fields then return false end
            for _,key in ipairs(fields) do controls.held[key]=on end
            return true
        end,
        Action=function(action)
            if action:sub(1,4)=='aux-' then layer.aux=action:sub(5)
            elseif action=='exit' then session.wantsReturn=true
            elseif action=='scope' then session.scope=not session.scope
            elseif action=='weapon' then session.weapons:Select(session.weapons.current%math.max(1,#session.weapons.groups)+1)
            elseif action=='flip' then session:Flip()
            elseif action=='rotor' then controls.rotorStep=true
            elseif action=='board' then session.touchScoreboard=not session.touchScoreboard end
        end,
        Reset=function() controls:Clear();session.scope=false;session.firing=false;session.pointer:Suppress() end,
        Menu=function(open) if open then session:Pause() else session:Resume() end end,
        Labels=function(l)
            l.buttons.primary.props.text='开火';l.buttons.up.props.text=session.vehicle.legMode and '跳 / 升' or '刹 / 升'
            if l.buttons.scope then l.buttons.scope.props.text='开镜';l.buttons.scope.props.selected=session.scope end
            if l.buttons.interact then l.buttons.interact.props.text='交互' end
            local aux={boost=session.vehicle.mechControl and '加速' or '下降',cut='停止升力',interact='交互',['strafe-left']='左平移',['strafe-right']='右平移'}
            l.buttons.aux.props.text=aux[l.aux];l.buttons.weapon.props.text='武器'
        end}
    layer=require('ui.SourceTouchOverlay').Create(root,playfield,adapter,{'scope','interact','up','primary','aux','weapon'},options)
    layer.buttons.fire=layer.buttons.primary;layer.buttons.brake=layer.buttons.up;layer.buttons.descend=layer.buttons.aux
    layer.Update(false);return layer
end
return M
