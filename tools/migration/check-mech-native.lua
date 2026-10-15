local Math=require('core.Math3')
local IK=require('parts.MechIK')
local Rot=require('core.Rotations')
local BP=require('construction.Blueprint')
local Spec=require('drive.VehicleSpec')
local Space=require('physics.Space')
local Vehicle=require('drive.Vehicle')
local measurements={}
local function Part(type,x,y,z,rot,id)
    return {id=id,type=type,pos={x,y,z},rot=rot,color=0xffffff,_cells=BP.PartCells(type,{x,y,z},rot)}
end
local function Blueprint(type,count)
    local rot
    for i=0,23 do local up=Rot.ApplyRot(i,{0,1,0});local forward=Rot.ApplyRot(i,{0,0,1});if up[2]<-.99 and forward[3]>.99 then rot=i;break end end
    assert(rot,'source mech mounting rotation')
    local parts={};local function Add(type,x,y,z,r) parts[#parts+1]=Part(type,x,y,z,r or 0,#parts+1) end
    for x=-4,4 do for z=-2,2 do Add(x==0 and z==0 and 'core' or 'cube',x,1,z) end end
    for _,x in ipairs({-4,4}) do for _,z in ipairs(count==4 and {-2,2} or {0}) do Add(type,x,0,z,rot) end end
    return Spec.BuildParts(parts,0)
end
local function Native(type,count,run)
    local info=IK.Data(type)
    V.assert(info.bounds and info.bounds.min and info.bounds.max,type..' source rig bounds available')
    local scene=Scene();local space=Space.New(scene);local floor=scene:CreateChild('MechFloor')
    floor:CreateComponent('CollisionShape'):SetStaticPlane();space:Register(floor:CreateComponent('RigidBody'),{type='ground'})
    local spec=Blueprint(type,count);local v=Vehicle.New(space,spec);v:Place({0,0,0},0)
    local function Step(seconds,command,each)
        for i=1,math.floor(seconds*60+.5) do v:Step(command or {},1/60);space:Step(1/60);if each then each(i) end end
    end
    run(v,Step,space,floor)
    v:Dispose();scene:Dispose()
end
for index,case in ipairs({{'mech3',2},{'mech4',2},{'mech5',2},{'mech5',4}}) do
    V.atFrame(50+index*5,function()
        local type,count=case[1],case[2];local name=type..'/'..count
        Native(type,count,function(v,Step,space,floor)
            Step(5);local start=Math.Array(v.body.translation())
            V.assert(v.telemetry.legAvailable==count and v.telemetry.legContacts==count,name..' all actual feet support idle chassis')
            Step(2);local idle=Math.Length(Math.Sub(Math.Array(v.body.translation()),start))
            V.assert(idle<.08,name..' released input remains stationary')
            local p=Math.Array(v.body.translation());local swings,maxSlide,prev=0,0,{}
            Step(3,{throttle=1},function()
                for _,s in ipairs(v.mechControl.list) do
                    if s.swing then swings=swings+1 end
                    if s.grounded and prev[s.leg.partId] then maxSlide=math.max(maxSlide,Math.Length(Math.Sub(s.foot,prev[s.leg.partId]))) end
                    prev[s.leg.partId]=s.grounded and s.foot or nil
                end
            end)
            local forward=v.body.translation().z-p[3]
            V.assert(forward>8 and swings>20,name..' actual forward walking has cyclic foot placement')
            V.assert(maxSlide<.001,name..' planted feet stay world locked')
            Step(3);V.assert(math.abs(v.speed)<.15,name..' throttle release stops actual chassis')
            p=Math.Array(v.body.translation());Step(1.5,{strafe=1});local strafe=v.body.translation().x-p[1]
            V.assert(strafe>1,name..' actual chassis strafes')
            Step(1,{steer=1});V.assert(v.body.angvel().y>.25,name..' steering rotates actual chassis')
            Step(4);local before=v.body.translation().y;local jumped,jet=false,false;local maxY=before
            Step(1.5,{jump=true},function() jumped=jumped or v.telemetry.legJumped;jet=jet or (v.telemetry.mechJetLift or 0)>0;maxY=math.max(maxY,v.body.translation().y) end)
            V.assert(jumped and maxY-before>1,name..' actual jump lifts chassis')
            if v.mechControl.jetMax>0 then V.assert(jet and v.mechControl.jetFuel<v.mechControl.jetMax,name..' held jump supplies aerial jets and consumes fuel') end
            Step(7);V.assert(v.telemetry.legAvailable==count and v.telemetry.legContacts==count,name..' actual landing replants feet')
            local fuel=v.mechControl.boostFuel;local boosting=false
            Step(.8,{throttle=1,boost=true},function() boosting=boosting or v.telemetry.mechBoost end)
            if v.mechControl.boostMax>0 then V.assert(boosting and v.mechControl.boostFuel<fuel,name..' actual boost consumes independent fuel') end
            local saved=v:GetState();local snapshot=v.mechControl:Snapshot();v:Place({0,0,0},0);v:SetState(saved)
            V.assert(math.abs(v.mechControl.jetFuel-snapshot.jetFuel)<1e-9 and math.abs(v.mechControl.boostFuel-snapshot.boostFuel)<1e-9,name..' damage rebuild restore preserves both fuel pools')
            V.assert(#v.mechHitboxes.items==count*4,name..' four animated massless hit sensors per foot')
            measurements[name]={idle=idle,forward=forward,strafe=strafe,maxSlide=maxSlide,swings=swings,jumpRise=maxY-before,jet=jet,boosting=boosting,telemetry=v.telemetry}
        end)
    end)
end
V.atFrame(80,function()
    Native('mech3',2,function(v,Step,space,floor)
        floor:GetComponent('CollisionShape'):SetBox(Vector3(20,.2,20),Vector3(0,-.1,0))
        Step(5);Step(3,{throttle=1});local before=v.body.translation().y
        Step(1,{throttle=1});V.assert(v.telemetry.legAvailable==0 and v.body.translation().y<before-1,'finite terrain edge removes mech support and permits falling')
    end)
    local f=assert(io.open('docs/migration/evidence/mech-native-measurements.json','w'));f:write(cjson.encode(measurements));f:close()
    print('[MechNative] '..cjson.encode(measurements));V.finish()
end)
