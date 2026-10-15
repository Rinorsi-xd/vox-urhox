-- QA-only: no shader, model, texture, light or normal-preview modifications.
local Settings=require 'render.GraphicsSettings'
local show,post,visible=Settings.Show,Settings.PostUpdate,Settings.SetSceneVisible
local function Guard(self)
    local zero=graphics:GetWidth()<=0 or graphics:GetHeight()<=0
    if zero then
        if not self.qaZeroViews then self.qaZeroViews={} end
        for i=0,renderer.numViewports-1 do
            local viewport=renderer:GetViewport(i)
            if viewport then self.qaZeroViews[i]=viewport;renderer:SetViewport(i,nil) end
        end
    elseif self.qaZeroViews then
        for i,viewport in pairs(self.qaZeroViews) do
            if not renderer:GetViewport(i) then renderer:SetViewport(i,viewport) end
        end
        self.qaZeroViews=nil
    end
end
function Settings:Show(scene,camera)
    self.qaZeroViews=nil
    show(self,scene,camera);Guard(self)
end
function Settings:SetSceneVisible(value)
    visible(self,value);Guard(self)
end
function Settings:PostUpdate()
    Guard(self)
    if not self.qaZeroViews then post(self) end
end
function HandleG0RenderScreenMode()
    local app=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app
    if app then Guard(app.graphicsSettings) end
end
SubscribeToEvent('ScreenMode','HandleG0RenderScreenMode')

if G0_WARM_EXPERIMENT then
    local Flow=require 'app.LoadingFlow'
    local finish,rendered,close=Flow.Finish,Flow.Rendered,Flow.Close
    local Trial=require 'app.TrialSession'
    local postUpdate=Trial.PostUpdate
    function Trial:PostUpdate(dt)
        postUpdate(self,dt)
        local warm=self.app.loadingFlow and self.app.loadingFlow.qaWarm
        if warm and warm.introView then
            -- First full-intro shot in the frozen H5/MatchIntro. Other shots are not covered.
            local camera=self.camera:GetCamera();local node=camera.node
            node.position=require('core.Coord').Vec(300,170,-260)
            node:LookAt(Vector3.ZERO);camera.fov=50
        end
    end
    local function Restore(flow)
        if not flow.qaWarm then return end
        local warm=flow.qaWarm
        for _,item in ipairs(warm.items) do item.drawable.viewMask=item.mask end
        if warm.camera then
            warm.camera.node.position=warm.position;warm.camera.node.rotation=warm.rotation;warm.camera.fov=warm.fov
        end
        print('[G0RenderExperiment] restored='..#warm.items..' batches='..warm.batches..' introView='..tostring(warm.introView))
        flow.qaWarm=nil
    end
    local function Batch(flow)
        local warm=flow.qaWarm
        for _,item in ipairs(warm.items) do item.drawable.viewMask=0 end
        local last=math.min(#warm.items,warm.next+7)
        for i=warm.next,last do local item=warm.items[i];item.drawable.viewMask=item.mask end
        warm.next=last+1;warm.batches=warm.batches+1
    end
    function Flow:Finish()
        finish(self)
        if not self.active or not self.app.scene then return end
        local scene=self.app.scene
        local items={}
        -- Resolve concrete types rather than relying on abstract Component lookup.
        local seen={}
        for _,kind in ipairs({'StaticModel','StaticModelGroup','AnimatedModel','CustomGeometry','BillboardSet','Terrain','Skybox'}) do
            for _,drawable in ipairs(scene:GetComponents(kind,true)) do
                if drawable.viewMask~=0 and not seen[drawable] then items[#items+1]={drawable=drawable,mask=drawable.viewMask};seen[drawable]=true end
            end
        end
        self.qaWarm={items=items,next=1,batches=0}
        if G0_WARM_INTRO_EXPERIMENT and self.match and self.app.trial.battle then
            local camera=self.app.trial.camera:GetCamera();local warm=self.qaWarm
            warm.camera=camera;warm.position=camera.node.position;warm.rotation=camera.node.rotation;warm.fov=camera.fov
            warm.introPending=true
        end
        print('[G0RenderExperiment] begin drawables='..#items)
        Batch(self)
    end
    function Flow:Rendered()
        if self.qaWarm then
            if self.qaWarm.next>#self.qaWarm.items then
                if self.qaWarm.introPending then
                    local warm=self.qaWarm;warm.introPending=false;warm.introView=true;warm.next=1
                    print('[G0RenderExperiment] first-intro-camera batches begin');Batch(self)
                else Restore(self) end
            else Batch(self) end
            return
        end
        rendered(self)
    end
    function Flow:Close()
        Restore(self);close(self)
    end
end
