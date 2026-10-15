-- The real BuildSession edits a separate blueprint over the paused battle scene.
-- The host adapter preserves garage editor/history/store ownership throughout.
local BP=require('construction.Blueprint')
local Inv=require('endless.Inventory')
local Config=require('Config')
local UI=require('urhox-libs/UI')
local Coord=require('core.Coord')
local M={};M.__index=M
function M.New(controller) return setmetatable({controller=controller},M) end
function M:Enter()
    local c=self.controller;local s=c.session;local u=c.player;local p=u.vehicle.body.translation();self.anchor={pos={p.x,p.y,p.z},yaw=u.vehicle:Yaw()}
    self.originalRoot=UI.GetRoot();self.originalViewport=renderer:GetViewport(0);UI.SetRoot(nil)
    self.root=s.scene:CreateChild('EndlessEditing');self.root.position=Coord.Vec(table.unpack(self.anchor.pos));self.root.rotation=Quaternion(-math.deg(self.anchor.yaw),Vector3.UP)
    local host={scene=s.scene,toasts=s.app.toasts,tier=5,blueprint=BP.New():Load(c.run.blueprint),buildCameraState={},buildXray=false,
        tutorial={Replay=function() s.app.toasts:Push('完成改装后按 Enter 返回本局战斗','info') end},vehicleGate=require('app.ResourceGate').New()}
    self.host=host;host.camera=require('controls.OrbitCamera').New(s.scene);host.camera.maxDist=260;host.camera.camera.farClip=s.camera:GetCamera().farClip
    host.touchPrefs=require('controls.TouchPreferences').Get(s.app)
    host.SaveTouchPrefs=function(_,prefs) return s.app:SaveTouchPrefs(prefs) end
    local offset=Coord.Vec(p.x+15,p.y+12,p.z-18);host.camera.node.position=offset;host.camera.node:LookAt(self.root.position)
    host.buildCameraState={pos={-offset.x,offset.y,offset.z},forward=require('core.Math3').Normalize({self.anchor.pos[1]+offset.x,-12,18})}
    host.car=require('render.VehicleView').New(self.root,'EndlessEditCar');host.car:Rebuild(host.blueprint)
    host.store={LoadBuildSettings=function() return nil end,SaveBuildSettings=function() return true end,Flush=function() return true end,Queue=function() end}
    host.bays={active=1,Changed=function() end,Rename=function(_,name) host.blueprint.name=name;return true end,Save=function() return false,'本局改装期间不可写入机库车位' end}
    host.ExitBuild=function() return self:Depart() end
    host.EnterTrial=function() s.app.toasts:Push('本局改装期间不可用','warn');return false end
    host.LoadBlueprint=host.EnterTrial;host.WithVehicle=host.EnterTrial;host.NewBlueprint=host.EnterTrial
    host.editor=require('construction.BuildEditor').New(host.blueprint,function(ops) host.car:ApplyEdits(ops,host.blueprint) end)
    host.inventory=require('construction.Inventory').New({hotbar={'cube','slope','heavy','truss',false,false,false,false,false,false},active=1})
    local index=5;for _,def in ipairs(require('parts.Defs').LIST) do if (c.run.inventory[def.id] or 0)>0 and index<=10 then host.inventory.hotbar[index]=def.id;index=index+1 end end
    local list=host.inventory.List;host.inventory.List=function(model)
        local result={};for _,def in ipairs(list(model)) do if not Inv.Limited(def.id) or (c.run.inventory[def.id] or 0)>0 then result[#result+1]=def end end;return result
    end
    local history=host.editor.history;local commit=history.Commit
    history.Commit=function(h,ops,derive)
        local counts=Inv.Count(host.blueprint)
        for _,op in ipairs(ops) do if (op.op=='add' or op.op=='remove') and Inv.Limited(op.data.type) then counts[op.data.type]=(counts[op.data.type] or 0)+(op.op=='add' and 1 or -1) end end
        for id,count in pairs(counts) do if count>(c.run.inventory[id] or 0) then s.app.toasts:Push(require('parts.Defs').PARTS[id].name..' 超过本局仓库数量','warn');return false end end
        return commit(h,ops,derive)
    end
    self.sourceTier=Config.TIERS[5];Config.TIERS[5]=Inv.Limits(c.run.tier)
    self.build=require('app.BuildSession').New(host)
    self.build.ghost.root.position=self.root.position;self.build.ghost.root.rotation=self.root.rotation
    self.build.inspection.view.node.position=self.root.position;self.build.inspection.view.node.rotation=self.root.rotation
    local build=self.build
    build.OpenLibrary=function() build:Notify('本局改装期间不可用','warn');return false end
    build.LoadSlot=build.OpenLibrary
    build.OpenPause=function() build:Notify('完成改装后按 Enter 返回本局战斗','info') end
    build.Trace=function(b,x,y)
        local w,h=UI.GetViewportSize();if b.buildCamera.mode=='fp' then x,y=w*.5,h*.5 end
        local ray=host.camera.camera:GetScreenRay(x/math.max(1,w),y/math.max(1,h));local origin=self.root:WorldToLocal(ray.origin);local direction=self.root.worldRotation:Inverse()*ray.direction
        b.editor.forward={-direction.x,0,direction.z};b.editor:Trace({-origin.x,origin.y,origin.z},{-direction.x,direction.y,direction.z})
    end
    build.BoxSelect=function(b,rect)
        local w,h=UI.GetViewportSize();b.editor:BoxSelect(rect,function(cell)
            local world=self.root:LocalToWorld(Coord.Vec(cell[1]*Config.CELL,(cell[2]+.5)*Config.CELL,cell[3]*Config.CELL));local projected=host.camera.camera:WorldToScreenPoint(world)
            local f=host.camera.node.worldRotation*Vector3.FORWARD;return projected.x*w,projected.y*h,(world-host.camera.node.worldPosition):DotProduct(f)>0
        end)
    end
    build.buildCamera.flight.limit={x=3000,y0=-100,y1=500,z0=-3000,z1=3000}
    build.buildCamera.Focus=function(camera)
        local st=host.blueprint:Stats();local b=st.bb;local localCenter=Coord.Vec((b.minX+b.maxX)*.5*Config.CELL,((b.minY+b.maxY)*.5+.5)*Config.CELL,(b.minZ+b.maxZ)*.5*Config.CELL)
        camera:FocusAt(self.root:LocalToWorld(localCenter),math.max(8,math.sqrt(st.dims.L^2+st.dims.W^2+st.dims.H^2)*Config.CELL*1.5))
    end
    build.buildCamera:Focus()
    self:ConfigureHud()
    require('render.NodeVisibility').Set(s.view.view.root,false)
    local post=s.app.graphicsSettings.post
    if post and post.scene==s.scene then
        -- Keep one source viewport and its depth targets while changing cameras.
        self.post=post;self.battleCamera=post.camera
        post.camera=host.camera.camera;post.source:SetCamera(host.camera.camera)
    else require('render.WindowViewports').Set(0,Viewport:new(s.scene,host.camera.camera)) end
    build:Refresh()
end
function M:ConfigureHud()
    local build=self.build
    for _,key in ipairs({'trial','save','help'}) do if build.hud.buttons[key] then build.hud.buttons[key]:SetDisabled(true) end end
    for _,button in ipairs(build.hud.stats.pane.tiers) do button:SetDisabled(true) end
    self.bar=require('ui.EndlessEditBar').Attach(self,build.hud.root);self.hudRoot=build.hud.root
end
function M:StockCards()
    self.remaining=Inv.Remaining(self.controller.run.inventory,self.host.blueprint)
    local panel=self.build.inventoryPanel;if not panel then return end
    for _,row in pairs(panel.list.pool_.inUse) do for _,cell in ipairs(row.cells) do
        if not cell.root.endlessStock then
            local card=cell.root;local render=card.Render;card.endlessStock=true
            card.Render=function(widget,vg)
                render(widget,vg);local id=widget.props.partType;if not id or not Inv.Limited(id) then return end
                local count=self.remaining[id] or 0;local r=widget:GetAbsoluteLayout();local draw=require('ui.SourceDraw')
                draw.Rect(vg,r.x,r.y,56,22,count>0 and {17,38,57,238} or {86,36,36,238})
                draw.Text(vg,'剩余 '..count,r.x+5,r.y+4,12,{238,247,255,255},'vox-title')
            end
        end
    end end
end
function M:Validation() return Inv.Validate(self.host.blueprint,self.controller.run.tier,self.controller.run.inventory) end
function M:Depart()
    local result=self:Validation();if not result.ok then self.build:Notify(table.concat(result.errors,'；'),'bad');return result end
    return self.controller:ResumeEdit(self.host.blueprint:ToTable())
end
function M:Reset()
    self.host.blueprint:Load(self.controller.run.blueprint);self.host.car:Rebuild(self.host.blueprint);self.host.editor.history.undoStack={};self.host.editor.history.redoStack={};self.host.editor.selection={};self.host.editor.dirty=true
end
function M:HandleKey(key) if key==KEY_RETURN and not self.build.dialog and not self.build.inventoryPanel and not self.shop then self:Depart();return true end;return true end
function M:Update(dt)
    if input:GetKeyPress(KEY_RETURN) and not self.build.dialog and not self.build.inventoryPanel and not self.shop then self:Depart();return end
    if self.shop then
        self.build.controls:Cancel();self.build.buildCamera:Release()
        if input:GetKeyPress(KEY_ESCAPE) then self.shop:Close() end
        return
    end
    self.build:Update(dt)
    if self.build.hud.root~=self.hudRoot then self:ConfigureHud() end
    self.stockClock=(self.stockClock or 0)+dt;if self.stockClock>=.1 then self.stockClock=0;self:StockCards() end
    if self.bar then self.bar.Update() end
end
function M:Leave()
    if self.left then return end;self.left=true
    if self.shop then self.shop:Close();self.shop=nil end
    if self.build then self.build:Dispose() end
    Config.TIERS[5]=self.sourceTier
    if self.post then self.post.camera=self.battleCamera;self.post.source:SetCamera(self.battleCamera) end
    self.host.car:Dispose();self.host.camera.node:Dispose();self.root:Dispose()
    local s=self.controller.session;require('render.NodeVisibility').Set(s.view.view.root,s.combat.player.alive)
    if self.originalRoot and self.originalRoot.node then UI.SetRoot(self.originalRoot) end
    require('render.WindowViewports').Set(0,self.originalViewport)
    require('controls.TouchMode').Apply('drive')
    self.controller=nil;self.host=nil;self.build=nil;self.root=nil;self.bar=nil;self.hudRoot=nil
    self.post=nil;self.battleCamera=nil;self.originalRoot=nil;self.originalViewport=nil;self.sourceTier=nil
end
return M
