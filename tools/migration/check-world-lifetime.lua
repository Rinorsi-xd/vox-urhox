local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local View=require 'render.DriveView'
local Space=require 'physics.Space'
local Trial=require 'app.TrialSession'
V.atFrame(2,function()
    local scene=Scene();scene:CreateComponent('Octree')
    local world=require('drive.CraterWorld').New(scene,true)
    local space=world.space
    local bp=Prefab.BuildRaceCar(BP.New())
    local vehicle=Vehicle.New(space,Spec.Build(bp))
    local body=vehicle.body
    local view=View.New(scene,bp,vehicle)
    V.assert(body.isValid() and body.native~=nil and #scene:GetChildren(true)>2,'actual Bullet body and original rendered vehicle exist')
    vehicle:Step({throttle=1,steer=0},1/60);space:Step(1/60);view:SavePose();view:Update(1,1/60)
    V.assert(body.linvel().y<0,'actual Bullet simulation runs before teardown')
    local unit=require('combat.CarUnit').New(world,bp:ToTable(),{name='Death HUD',combat=true,externalControl=true,externalView=true,autoRespawn=false,spawn={pos={0,4,0},yaw=0}})
    local retired=unit.vehicle;unit:Dispose()
    local vitals={session={combat={player=unit},vehicle=retired,weapons=unit.weapons},fire={word='old'},lock={locked=true}}
    require('ui.ReticleState').Update(vitals,1/60)
    V.assert(vitals.hp==0 and not vitals.fire and not vitals.lock and not retired.body.isValid(),'real destroyed player HUD updates health without touching retired native body')
    view:Dispose();view:Dispose();vehicle:Dispose();vehicle:Dispose()
    V.assert(not body.isValid() and body.native==nil,'externally held body wrapper releases its native body')
    V.assert(vehicle.native==nil and vehicle.space==nil and view.vehicle==nil,'held vehicle and view release native world ownership')
    local native=scene:CreateChild('HeldStatic'):CreateComponent('RigidBody')
    local held=space:Register(native,{type='fixture'})
    world:Dispose();world:Dispose();space:Dispose()
    V.assert(not held.isValid() and held.native==nil and next(space.bodies)==nil,'world disposal invalidates remaining registered native wrappers exactly once')
    V.assert(space.scene==nil and space.world==nil and world.scene==nil and world.space==nil and world.layout==nil and world.visualGround==nil,'held world releases scene physics layout and heightfield')
    scene:Dispose()
    local borrowed=Scene();local physics=borrowed:CreateComponent('PhysicsWorld');local standalone=Space.New(borrowed)
    standalone:Dispose();standalone:Dispose()
    V.assert(borrowed:GetComponent('PhysicsWorld')==physics,'space never disposes borrowed PhysicsWorld component')
    borrowed:Dispose()
    local order={};local function Mark(name)order[#order+1]=name end
    local session=setmetatable({disposed=false},Trial)
    local fakeView={alive=true,Dispose=function(self)self.alive=false;Mark('view')end}
    session.view=fakeView
    session.endless={edit={Leave=function()V.assert(fakeView.alive,'editor leaves while battle view is still alive');Mark('edit')end}}
    session.combat={Dispose=function()Mark('combat')end}
    session.world={Dispose=function()Mark('world')end}
    session.hud={Dispose=function()Mark('hud')end}
    session:Dispose();session:Dispose()
    V.assert(table.concat(order,',')=='edit,hud,view,combat,world','session closes editor then HUD view combat and world once')
    V.assert(session.world==nil and session.view==nil and session.combat==nil and session.endless==nil,'held disposed session releases mode and scene ownership')
    V.finish()
end)
