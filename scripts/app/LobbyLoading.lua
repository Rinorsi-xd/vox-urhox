-- Hall -> salvage uses the source's own preparation page, not the car lift.
local ResourceGate=require("app.ResourceGate")
local Dependencies=require("parts.Dependencies")
local Warehouse=require("scene.Warehouse")
local ResourceData=require("core.ResourceData")
local VoxTheme=require("ui.VoxTheme")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local M={};M.__index=M
local steps={{'save','读取仓库与车库存档'},{'build','搭建打捞仓库'},{'icons','渲染物资图标'},
    {'light','烘焙仓库光照'},{'shaders','编译着色器'},{'thumbs','拍摄战车照片'}}
local tips={
    '车被打爆时，车上的零件和货全部丢失——带入价值越高，赌得越大。',
    '改车优先用仓库里的零件；仓库里没有的，零件库里会灰掉，点一下就能买。',
    '后勤处按标价的六成收购，货物带回来就能换成信用点。',
    '仓库里没装在车上的零件才能卖；拆掉一辆车，零件全部回到仓库。',
    '稀有度越高的物资点，箱子越多，也越危险。',
    '撤离点各有条件：有的随时开放，有的要交能量电池，有的只容得下窄车。',
}
function M.New(app) return setmetatable({app=app,active=false,gate=ResourceGate.New()},M) end
function M:Begin(done)
    local app=self.app;local flow=app.loadingFlow
    if self.active or app.stopped or flow.active or app.mode~='hangar' or app.build or app.loader.state=='loading' then return false end
    if app.vehicleSwitch and app.vehicleSwitch:Finish()==false then return false end
    self.active=true;self.done=done;self.index=1;self.started=false;self.switched=false;self.thumbnail=nil
    flow:Open({id='salvage-lobby',name='07 号打捞仓库',loadingArt='UI/Salvage/depot.jpg',loadingBrand='打捞行动',
        loadingKicker='星际前途 · 第 7 边境星区',loadingSub='地下打捞站 · 你的仓库、车库和后勤处都在这里',
        loadingColor={122,216,255,255},loadingIcon='hook',loadingTips=tips,loadingSteps=steps},function() self:Cancel() end)
    self.generation=flow.generation;self.frame=flow.pageFrames
    return true
end
function M:Next()
    local flow=self.app.loadingFlow;local step=flow.steps[self.index]
    step.state='done';step.note=string.format('%.1fs',step.elapsed)
    self.index=self.index+1;self.started=false;self.frame=flow.pageFrames
    if self.index>#steps then
        self.active=false;self.switched=false
        local done=self.done;self.done=nil;if done then done() end
        flow:Finish();return
    end
    flow.current=self.index;flow.progress=(self.index-1)/#steps;flow.steps[self.index].state='run'
end
function M:Work()
    local app=self.app;local flow=app.loadingFlow;local step=steps[self.index][1]
    if step=='save' then
        if not self.started then
            self.started=true;self.downloaded=false;self.failure=nil
            local generation=self.generation
            local data=DeferredModules['app.SalvageLobby'].VehicleData(app,'salvage')
            self.gate:Start(Dependencies.FromBlueprint(data),function(ok,message)
                if not self.active or self.generation~=generation then return end;self.downloaded=ok;self.failure=not ok and message or nil
            end)
        end
        if self.failure then error(self.failure,0) end
        if not self.downloaded then
            flow.steps[self.index].note=self.gate.completed..' / '..self.gate.total;return
        end
        local ok,err=DeferredModules['app.SalvageLobby'].Switch(app,'salvage');assert(ok,err)
        self.switched=true;self:Next()
    elseif step=='build' then
        app.warehouse=app.warehouse or Warehouse.New(app,{deferActivation=true})
        local warehouse=app.warehouse
        if warehouse.failure then error(warehouse.failure,0) end
        warehouse:Update();flow.steps[self.index].note=tostring(warehouse.cursor-1)..' 批'
        if warehouse.built or warehouse.ready then self:Next() end
    elseif step=='icons' then
        if not self.started then
            self.started=true;self.icons={};self.iconIndex=1;self.downloaded=false;self.failure=nil
            local generation=self.generation
            local data=ResourceData.Read('UI/Outgame.json')
            for id,item in pairs(data.items) do if item.part and app.salvageLobby:Owned(id)>0 then
                self.icons[#self.icons+1]=VoxTheme.Thumbnail(item.part)
            end end
            self.gate:Start(self.icons,function(ok,message)
                if not self.active or self.generation~=generation then return end;self.downloaded=ok;self.failure=not ok and message or nil
            end)
        end
        if self.failure then error(self.failure,0) end
        if not self.downloaded then return end
        local started=Time:GetSystemTime()
        for _=1,8 do
            local path=self.icons[self.iconIndex]
            if not path then self.icons=nil;self:Next();break end
            assert(cache:GetResource('Texture2D',path),'物资图标不可用：'..path);self.iconIndex=self.iconIndex+1
            if Time:GetSystemTime()-started>=2 then break end
        end
    elseif step=='light' then
        if not app.warehouse.ready then app.warehouse:Activate() end
        self:Next()
    elseif step=='shaders' then
        if not self.started then
            self.started=true;flow.keepSceneVisible=true;app.graphicsSettings:SetSceneVisible(true)
            app.camera:Step(1);flow:PrepareScene()
        end
        if not flow.renderWarmup then self:Next() end
    elseif step=='thumbs' then
        if not self.started then
            self.started=true;self.thumbnailReady=false
            local generation=self.generation
            local data=app.bays:Slots()[app.bays.active] or app.blueprint:ToTable()
            self.thumbnail=app.previews:Request(data,function(image,message)
                if image then image:Dispose() end
                if not self.active or self.generation~=generation then return end
                self.thumbnailReady=true;self.thumbnailError=message
            end)
        end
        if self.thumbnailReady then
            if self.thumbnailError then print('[LobbyLoading] Optional thumbnail: '..tostring(self.thumbnailError)) end
            self.thumbnail=nil;self:Next()
        end
    end
end
function M:Update(dt)
    if not self.active then return end
    local flow=self.app.loadingFlow
    if not flow.active or flow.generation~=self.generation then self:Cancel();return end
    if flow.failed or not flow:CanStartLoad() then return end
    local step=flow.steps[self.index];step.elapsed=step.elapsed+math.max(0,dt)
    if step.elapsed>15 then step.note='仍在加载…' end
    -- Every checklist row is presented before its work, including cached paths.
    if flow.pageFrames-self.frame<2 then return end
    local ok,err=xpcall(self.Work,debug.traceback,self)
    if not ok then flow:Fail(err) end
end
function M:Cancel()
    self.active=false;self.done=nil;self.gate:Cancel()
    if self.thumbnail then self.app.previews:Cancel(self.thumbnail);self.thumbnail=nil end
    local flow=self.app.loadingFlow
    if flow and flow.renderWarmup then flow.renderWarmup:Restore();flow.renderWarmup=nil end
    if self.switched then
        local app=self.app
        if app.warehouse then app.warehouse:Dispose();app.warehouse=nil end
        if not app.stopped then
            local ok,err=DeferredModules['app.SalvageLobby'].Switch(app,'arena')
            if not ok then app.toasts:Push(err,'bad') end
            DeferredModules['ui.GarageHud'].Refresh();app:HomeView('hangar')
        end
        self.switched=false
    end
end
function M:Dispose() self:Cancel() end
return M
