local scene=Scene();scene:CreateComponent('Octree')
local n=scene:CreateChild('Camera');n.position=Vector3(0,13,-35);n:LookAt(Vector3(0,4,0));local camera=n:CreateComponent('Camera');camera.farClip=500
local fx=nil ---@type table|nil
local showing=false;local shown=0;local finished=false
V.atFrame(10,function()
    local seed=20261014;fx=require('render.SalvageExplosion').New(scene,function() seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end)
    V.assert(#fx.pools.fire==240 and #fx.pools.core==40 and #fx.pools.smoke==200 and #fx.pools.embers==600,'actual source fixed particle pool counts')
    V.assert(#fx.rings==4 and #fx.lights==2 and #fx.materials==13,'source bounded rings lights shared texture materials')
    local initial=#fx.root:GetChildren();fx:Explode({-5,1,0},3,false);fx:Explode({6,1,0},4,true)
    V.assert(#fx.root:GetChildren()==initial and fx.rules.shake==1.6,'normal elite blasts reuse preallocated nodes')
end)
local function Poll()
    if finished or not fx or not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
    if not showing then
        showing=true
        if VOX_HANGAR.app.tutorial then VOX_HANGAR.app.tutorial:Dispose();VOX_HANGAR.app.tutorial=nil end
    end
    require('urhox-libs/UI').SetRoot(require('urhox-libs/UI').Panel{width='100%',height='100%',pointerEvents='none'})
    renderer:SetViewport(0,Viewport:new(scene,camera));shown=shown+1;fx:Update(1/60,n,{0,1,0})
    if shown==28 or shown==90 or shown==180 then
        local count=0;for _,kind in ipairs({'fire','core','smoke','embers'}) do for _,q in ipairs(fx.pools[kind]) do if q.node.enabled then count=count+1 end end end
        V.assert(count>0,'visible source pooled geometry phase '..shown)
        local image=Image:new();V.assert(graphics:TakeScreenShot(image),'actual source explosion screenshot '..shown)
        V.assert(image:SavePNG('docs/migration/evidence/salvage-explosion-'..shown..'-native.png'),'saved explosion phase '..shown);image:Dispose()
    end
    if shown==185 then
        for _,fov in ipairs({30,60,90}) do
            camera.fov=fov
            local size=.55/math.abs(camera.projection.m11)
            local center=n.worldPosition+n.worldRotation*Vector3(0,0,20)
            local half=n.worldRotation*Vector3(0,size*.5,0)
            local a,b=camera:WorldToScreenPoint(center-half),camera:WorldToScreenPoint(center+half)
            V.assert(math.abs(math.abs(a.y-b.y)-.55/40)<.00001,'actual projection retains original THREE Points pixel size at FOV '..fov)
        end
        local count=#fx.root:GetChildren();fx:Explode({0,1,0},3,false);fx:Update(1/60,n,{0,1,0})
        V.assert(count==#fx.root:GetChildren(),'repeated blast fixed pools remain bounded')
        V.assert(fx.pools.fire[1].model.useInstanceCustomData and fx.pools.fire[1].model.useInstanceColor,'GPU source puff time size color parameters enabled')
        local marker=require('render.SalvageFx').New(scene)
        local player={alive=true,Position=function() return {0,1,0} end,spec={bounds={min={-1,-1,-1},max={1,1,1}}},vehicle={mass=10,native={},speed=0}}
        local enemy={alive=false,name='source enemy',elite=true,Position=function() return {0,1,0} end,spec={bounds={radius=8}}}
        local rules={time=10,kills=0,cargo={},Heat=function() end,AddExtra=function(self,o) self.added=o end,Step=function() end,Drain=function() return {} end}
        local run=setmetatable({begun=true,landed=true,rules=rules,player=player,entries={{unit=player},{unit=enemy,kind='rat'}},explosion=fx,fx=marker,view={Update=function() end},
            session={pointer={captured=false},controls={held={}}},director={Remove=function(self,e) table.remove(self.run.entries,2) end,Step=function() end},feed={},weigh=0},require('salvage.Run'));run.director.run=run
        local before=#fx.rules.fires;run:AfterStep(1/60)
        V.assert(#fx.rules.fires==before+1 and fx.rules.fires[#fx.rules.fires].S==7.5 and rules.kills==1 and rules.added.kind=='kill','actual Run.AfterStep uses original capped enemy radius and elite blast then creates searchable wreck')
        player.alive=false;rules.Drain=function() return {{type='failed',reason='destroyed'}} end
        local death=0;run.cine={Death=function() death=death+1 end};run.audio={Event=function() end};before=#fx.rules.fires;run:Events()
        V.assert(death==1 and #fx.rules.fires==before+1 and fx.rules.fires[#fx.rules.fires].S==5.25,'actual Run failed event starts original elite player blast and death cinematic')
        marker:Dispose()
        fx:Dispose();scene:Dispose();finished=true;V.finish()
    end
end
for frame=20,680 do V.atFrame(frame,Poll) end
V.atFrame(685,function() V.assert(finished,'all explosion phases rendered after loader exit');V.finish() end)
