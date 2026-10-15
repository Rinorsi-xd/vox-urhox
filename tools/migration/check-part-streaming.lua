local Gate=require 'app.ResourceGate'
local Controller=require 'app.HomeVehicleSwitch'
local Ghost=require 'render.BuildGhost'
local BP=require 'construction.Blueprint'
local Editor=require 'construction.BuildEditor'
local function Backend()
    local b={localFiles={},requests={},cancelled={}}
    function b:Exists(path) return self.localFiles[path]==true end
    function b:DownloadResources(paths,done)
        self.requests[#self.requests+1]={paths=paths,done=done};return #self.requests
    end
    function b:CancelDownloadGroup(id) self.cancelled[id]=true end
    function b:Complete(id,ok)
        local request=self.requests[id]
        if ok then for _,path in ipairs(request.paths) do self.localFiles[path]=true end end
        request.done(ok,ok and 0 or 1)
    end
    return b
end
V.atFrame(55,function()
    local dependencies=require('parts.Dependencies')
    local warmed={};for _,path in ipairs(dependencies.For({{type='rotorStep',rot=22}})) do warmed[path]=true end
    for _,type in ipairs({'rotor','rotorSpin','rotorStep'}) do
        local ready=true;for _,path in ipairs(dependencies.For({{type=type,rot=22}})) do if not warmed[path] then ready=false end end
        V.assert(ready,type..' mode substitution and undo have warmed model dependencies')
    end
    local app=VOX_HANGAR.app;local controller=Controller.New(app,app.car.root)
    local backend=Backend();controller.gate=Gate.New(backend)
    local calls,results=0,{}
    local function Action() calls=calls+1;return true end
    local function Done(ok) results[#results+1]=ok end
    local y=app.car.root.position.y
    V.assert(controller:Begin(Action,Done,{'cold-model.bin'}),'cold vehicle operation is accepted')
    controller:Update(2)
    V.assert(controller:IsBusy() and not controller.pending.ready and calls==0 and app.car.root.position.y==y,'pending download preserves visible car and never runs storage action')
    V.assert(controller:Finish()==false and calls==0,'navigation cannot force an undownloaded blueprint commit')
    V.assert(not controller:Begin(Action,Done,{}),'concurrent vehicle action is rejected')
    V.assert(controller:CancelDownload() and backend.cancelled[1],'cancel retires only owned vehicle download')
    backend:Complete(1,true);controller:Update(1)
    V.assert(not controller:IsBusy() and calls==0 and #results==0,'cancelled completion cannot mutate vehicle or callback')
    controller:Begin(Action,Done,{'failed-model.bin'});backend:Complete(2,false)
    V.assert(not controller:IsBusy() and calls==0 and #results==1 and results[1]==false,'download failure leaves old vehicle and reports once')
    controller:Begin(Action,Done,{'failed-model.bin'});backend:Complete(3,true)
    V.assert(controller.pending.ready and controller.lift.anim~=nil and calls==0,'retry starts lift only after readiness')
    controller:Update(.2)
    V.assert(calls==1 and #results==2 and results[2] and not controller:IsBusy(),'ready operation commits once at source lift boundary')
    controller:Finish();controller:Begin(Action,Done,{'disposed-model.bin'});controller:Dispose();backend:Complete(4,true)
    V.assert(calls==1 and #results==2,'disposed home controller ignores late download')

    local editor=Editor.New(BP.New());editor:SelectType('mg5')
    local ghost=Ghost.New(app.scene);local ghostBackend=Backend();ghost.gate=Gate.New(ghostBackend)
    V.assert(not ghost:Warm(editor) and ghost.gate.state=='loading','cold ghost requests selected type without decoding model')
    ghost:Refresh(editor,false)
    V.assert(#ghost.pool==0 and #ghostBackend.requests==1,'pending ghost stays empty and does not restart every refresh')
    local first=ghostBackend.requests[1]
    editor:SelectType('laser5');ghost:Warm(editor)
    V.assert(ghostBackend.cancelled[1] and #ghostBackend.requests==2,'switching selected type retires old ghost download')
    first.done(true,0)
    V.assert(not ghost.ready and ghost.gate.state=='loading','late previous type cannot mark new ghost ready')
    ghostBackend:Complete(2,false)
    ghost:Refresh(editor,false);V.assert(#ghostBackend.requests==2,'failed ghost does not retry on every frame')
    ghost:Warm(editor,true);V.assert(#ghostBackend.requests==3,'explicit placement retries failed ghost resources')
    ghostBackend:Complete(3,true)
    V.assert(ghost.ready and editor.dirty,'ready ghost invalidates layout for next frame')
    ghost:Dispose()

    local original=app.vehicleGate;local b=Backend();app.vehicleGate=Gate.New(b)
    local ran=0
    local data=require('construction.Prefab').BuildRaceCar(BP.New()):ToTable()
    app:WithVehicle(data,function() ran=ran+1;return true end)
    V.assert(ran==0 and #b.requests==1,'blueprint import preserves old state during download')
    V.assert(not app:WithVehicle(data,function() ran=ran+1 end),'concurrent draft replacement is rejected')
    app.vehicleGate:Cancel();b:Complete(1,true)
    V.assert(ran==0,'cancelled draft replacement has no delayed mutation')
    app:WithVehicle(data,function() ran=ran+1;return true end)
    V.assert(ran==1,'already downloaded draft commits synchronously')
    app.vehicleGate=original
    local Hud=require 'ui.GarageHud';local home=Hud.GetState()
    home.workshop={view='detail',selected='hawk',group='wheel',sort='tier',from='feature'}
    V.assert(app:EnterBuild(),'enter builder after workshop selection')
    app:ExitBuild();local restored=Hud.GetState().workshop
    V.assert(restored and restored.view=='browse' and restored.selected=='hawk' and restored.group=='wheel' and restored.sort=='tier' and restored.from=='feature',
        'rebuilding home preserves source workshop selection and filters without preview owner')
    V.finish()
end)
