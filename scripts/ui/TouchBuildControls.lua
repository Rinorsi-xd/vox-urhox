local UI=require 'urhox-libs/UI'
local M={}
function M.Create(session,root,playfield)
    local camera=session.camera;local controls=session.controls;local e=session.editor
    local layer=false
    local options={{'menu','继续'},{'exit','返回'},{'inventory','零件库'},{'save','保存'},{'rotate','旋转'},{'tilt','翻转'},
        {'tool-build','放置'},{'tool-erase','删除'},{'tool-paint','上色'},{'tool-select','选择'},{'tool-stretch','拉伸'},
        {'undo','撤销'},{'redo','重做'},{'copy','复制'},{'paste','粘贴'},{'mirror','镜像'},{'focus','聚焦车辆'},{'cancel','取消操作'},{'test','试车'}}
    local extras={{'slot-prev','上一件'},{'slot-next','下一件'},{'material','换材质'},{'form','连块 / 拆开'},{'color','换颜色'},
        {'channel','装饰色'},{'all','全选'},{'delete','删除选区'},{'lift-up','高度 +'},{'lift-down','高度 −'},
        {'forward','选区前移'},{'backward','选区后移'},{'left','选区左移'},{'right','选区右移'}}
    local function Cycle(direction)
        for i=1,10 do local slot=(session.inventory.active-1+direction*i)%10+1
            if session.inventory.hotbar[slot] then session:SelectHotbar(slot);break end
        end
    end
    local adapter={mode='edit',Ready=function()
            if session.dialog or session.inventoryPanel or session.hud.colorOpen or not input.focus or input.minimized then return false end
            if not session.buildCamera.captured then session.buildCamera:Capture() end
            return true
        end,
        Move=function(x,y) session.buildCamera.touchRight=x;session.buildCamera.touchForward=y end,
        Look=function(dx,dy)
            if session.buildCamera.mode=='fp' then local f=session.buildCamera;f.dx=f.dx+dx;f.dy=f.dy+dy;return end
            camera.flight=false;camera.autoSpin=false
            camera.yaw=camera.yaw+math.deg(dx*.005)
            camera.pitch=math.max(90-math.deg(1.62),math.min(90-math.deg(.12),camera.pitch+math.deg(dy*.004)))
        end,
        Zoom=function(delta) if session.buildCamera.mode~='orbit' then return end;camera.flight=false;camera.autoSpin=false;camera.dist=math.max(camera.minDist,math.min(camera.maxDist,camera.dist*1.0012^delta)) end,
        Pan=function(dx,dy)
            if session.buildCamera.mode~='orbit' then return end
            camera.flight=false;camera.autoSpin=false;local rot=camera.node.rotation;local scale=camera.dist*.0014
            local target=camera.target-rot*Vector3.RIGHT*(dx*scale)+rot*Vector3.UP*(dy*scale)
            camera.target=Vector3(target.x,math.max(0,math.min(camera.panMaxY,target.y)),target.z)
        end,
        Hold=function(action,on,cancelled)
            if action=='up' or action=='down' then session.buildCamera.held[action]=on;return true end
            if action=='primary' then controls:TouchPrimary(on,cancelled);return true end
            return false
        end,
        Action=function(action)
            controls:Cancel();UI.ClearFocus()
            if action=='exit' then session.app:ExitBuild();return
            elseif action=='test' then session.app:EnterTrial();return
            elseif action=='inventory' then session:OpenInventory()
            elseif action=='save' then session:SaveSlot()
            elseif action=='rotate' then e:Rotate(1)
            elseif action=='tilt' then e:Tilt(1)
            elseif action:sub(1,5)=='tool-' then
                local tool=action:sub(6);session.selecting=tool=='select';e:SetTool(tool=='select' and 'build' or tool)
            elseif action=='undo' then e:Undo()
            elseif action=='redo' then e:Redo()
            elseif action=='copy' then e:Copy()
            elseif action=='paste' then e:StartPaste()
            elseif action=='mirror' then e.mirror=not e.mirror
            elseif action=='focus' then session.buildCamera:Focus()
            elseif action=='cancel' then session:Escape()
            elseif action=='slot-prev' or action=='slot-next' then Cycle(action=='slot-prev' and -1 or 1)
            elseif action=='material' then if session.inventory:CycleBlock() then session:ApplyHotbar();session:SaveSettings() end
            elseif action=='form' then session:ToggleForm()
            elseif action=='color' then session:CyclePaintColor(1)
            elseif action=='channel' then session.selecting=false;if e.tool=='paint' then e.paintChannel=e.paintChannel=='shell' and 'accent' or 'shell' else e:SetTool('paint') end
            elseif action=='all' then e:SelectAll()
            elseif action=='delete' then if next(e.selection) then e:DeleteSelection() else e:Remove() end
            elseif action=='lift-up' or action=='lift-down' then
                local direction=action=='lift-up' and 1 or -1
                if e.stretch then require('construction.BuildStretch').Adjust(e,direction)
                elseif next(e.selection) then session:MoveSelection(0,0,direction) else e:Lift(direction) end
            elseif action=='forward' then session:MoveSelection(1,0,0)
            elseif action=='backward' then session:MoveSelection(-1,0,0)
            elseif action=='left' then session:MoveSelection(0,-1,0)
            elseif action=='right' then session:MoveSelection(0,1,0) end
            session:Refresh()
        end,
        Reset=function() controls:Cancel();local f=session.buildCamera;f.held={};f.dx=0;f.dy=0;f.touchForward=0;f.touchRight=0;if f.flight then f.flight:Stop() end end,
        Menu=function(open) if open then session.buildCamera:Release() else session.buildCamera:Capture() end end,
        Labels=function(l)
            l.buttons.up.props.text='上升';l.buttons.primary.props.text=session.selecting and '选择' or ({build='放置',erase='删除',paint='上色',stretch='拉伸'})[e.tool] or '放置'
            l.buttons.down.props.text='下降'
            if l.buttons['slot-prev'] then l.buttons['slot-prev'].props.text='上一件' end
            if l.buttons['slot-next'] then l.buttons['slot-next'].props.text='下一件' end
        end}
    layer=require('ui.SourceTouchOverlay').Create(root,playfield,adapter,{'up','primary','down','slot-prev','slot-next'},options,extras)
    layer.Update(false);return layer
end
return M
