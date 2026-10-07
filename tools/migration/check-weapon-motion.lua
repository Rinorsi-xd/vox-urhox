local Motion=require 'render.WeaponMotion'
local Presentation=require 'render.WeaponPresentation'
local VehicleView=require 'render.VehicleView'
local WeaponView=require 'render.WeaponView'
local Rot=require 'core.Rotations'
local Data=require 'core.ResourceData'
local profiles=Data.Read('Parts/WeaponMotion.json')
local function Near(a,b) return type(a)=='number' and math.abs(a-b)<2e-5*math.max(1,math.abs(b)) end
local function MatrixNear(node,m)
    local n=node.transform
    local actual={n.m00,-n.m10,-n.m20,0,-n.m01,n.m11,n.m21,0,-n.m02,n.m12,n.m22,0,-n.m03,n.m13,n.m23,1}
    for i,v in ipairs(actual) do if not Near(v,m[i]) then return false end end;return true
end
V.atFrame(55,function()
    local f=assert(io.open('tools/migration/source-weapon-motion.json'));local fixture=cjson.decode(f:read('*a'));f:close()
    local view=VehicleView.New(VOX_HANGAR.scene,'WeaponMotionVerification')
    for _,case in ipairs(fixture.cases) do
        local part={id=1,type=case.type,pos={7,3,-9},rot=Rot.IDENTITY,color=0xffcc22}
        local vis=view:AddPart(part);vis.weaponMotion=Motion.New(case.type,vis.data,profiles[case.type],function()return .5 end)
        local motion=vis.weaponMotion
        local baseCount=0
        for _,model in ipairs(vis.models) do
            if model.node==vis.node then local origin=model.instanceCustomData;baseCount=baseCount+1
                V.assert(origin.x==0 and origin.y==0 and origin.z==0 and origin.w==1,case.type..' base flow excludes vehicle placement')
            end
        end
        V.assert(baseCount>0,case.type..' authored base geometry exists')
        for i,s in ipairs(case.steps) do
            motion:SetState(s.state,s.time,{offline=s.offline});motion:Update(s.time,s.dt);Presentation.Apply(vis)
            local ok=Near(motion.recoil,s.recoil) and Near(motion.kick,s.kick) and Near(motion.load,s.load) and Near(motion.power,s.power) and Near(motion.flowPhase,s.flowPhase)
            local label='state'
            for j,p in ipairs(vis.rig.parts) do if not MatrixNear(p.node,s.matrices[j]) then ok=false;label=p.definition.name..'/'..j;break end end
            if vis.rig.spin and not MatrixNear(vis.rig.spin,s.spin) then ok=false;label='spin' end
            for slot,material in pairs(vis.weaponMaterials) do
                local expected=s.mats[slot];local color=material:GetShaderParameter('emission_color'):GetColor()
                local intensity=material:GetShaderParameter('emission_strength'):GetFloat()
                if not Near(intensity,expected.intensity) or not Near(color.r,expected.color[1]) or not Near(color.g,expected.color[2]) or not Near(color.b,expected.color[3]) then ok=false;label='material/'..slot end
                local flow=motion.flow;local e=expected.flow
                if not (Near(flow.phase,e.uTime) and Near(flow.freq,e.uFreq) and Near(flow.amp,e.uAmp) and Near(flow.power,e.uPower) and Near(flow.sweep,e.uSweep) and Near(flow.sweepI,e.uSweepI)) then ok=false;label='flow' end
            end
            if #motion.emits~=#s.emits then ok=false;label='event count' end
            for j,e in ipairs(s.emits) do
                local actual=motion.emits[j];if not actual or actual.kind~=e.kind then ok=false;label='event kind'
                else for k,v in ipairs(e.p) do if not Near(actual.p[k],v) then ok=false;label='event point' end end end
            end
            V.assert(ok,case.type..' source motion/material step '..i..' '..label)
        end
        local old=vis.weaponMotion;view:RemovePart(1)
        V.assert(vis.weaponMotion==nil and vis.weaponMaterials==nil and view.visuals[1]==nil,case.type..' removes owned animation/materials')
    end
    view:Dispose();V.finish()
end)
