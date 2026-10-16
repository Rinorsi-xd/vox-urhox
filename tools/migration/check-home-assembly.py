"""Actual home controller, lift, Garage transaction and Rebuild under CPU adapters."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SETUP = r'''
wall=0;modules={};checks={};events={};TRIANGLE_LIST=0;cjson={null={}}
function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
function Cost(ms)wall=wall+ms end
function Event(name)events[#events+1]=name end
Time={GetSystemTime=function()return wall end}
require=function(name)return assert(modules[name],name)end
function LoadModule(text,name)local value=assert(load(text,name))();modules[name]=value;return value end
function Vector3(x,y,z)return {x=x,y=y,z=z}end
modules.Config={CELL=.5};modules['parts.Defs']={};modules['parts.PartAssets']={};modules['render.PartRig']={};modules['render.JoinedSurface']={};modules['core.Coord']={}
modules['construction.Prefab']={};modules['storage.BlueprintCode']={Validate=function(v)return v end}
local BP={};BP.__index=BP
function BP.New()return setmetatable({},BP)end
function BP:Load(data)self.name=data.name;self.count=data.count;return self end
function BP:ToTable()return {name=self.name,count=self.count}end
function BP:Size()return self.count end
function BP:Stats()return {count=self.count,dims={H=self.count}}end
function BP:List()local out={};for i=1,self.count do out[i]={id=i}end;return out end
modules['construction.Blueprint']=BP
modules['app.ResourceGate']={New=function()return {Start=function(self,paths,done)self.done=done;if not delayDownload then done(true)end end,Cancel=function(self)self.done=nil end}end}
function Make(Controller)
 wall=0;events={};delayDownload=false
 local bp=BP.New():Load({name='old',count=3});local root={position=Vector3(0,1,0)}
 local app={blueprint=bp,mode='hangar',loader={state='ready'},hangar={Welcome=function()Event('welcome')end},DisplayHeight=function()return 1 end}
 local view=setmetatable({root=root},View)
 function view:Clear()Event('clear');self.parts={};self.joined={Update=function()Event('joined');Cost(1)end};self.livery={Set=function()Event('livery-set')end,Update=function()Event('livery');Cost(1)end}end
 function view:AddPart(p)Cost(1);self.parts[#self.parts+1]=p.id;Event('part'..p.id)end
 app.car=view;local control=Controller.New(app,root);app.vehicleSwitch=control
 local store={slots={[1]={name='old',count=3},[2]={name='new',count=18}},active=1}
 function store:LoadSlot(i)return self.slots[i]end
 function store:SaveGarageState(i)Event('metadata');if self.fail then self.fail=false;return false,'injected metadata failure'end;self.active=i;return true end
 function store:Queue(value)self.draft=value:ToTable();Event('queue')end
 function store:Flush()Event('flush');return true end
 local garage=Garage.New(bp,store,function(data)
  bp:Load(data);local checkpoint=control.AssemblyCheckpoint and control:AssemblyCheckpoint()or nil
  view:Rebuild(bp,checkpoint);root.position=Vector3(0,1,0);control:Replaced();return true
 end,false)
 garage.active=1;garage.unsaved=false
 return app,control,garage,store
end
function Count(name)local n=0;for _,e in ipairs(events)do if e==name then n=n+1 end end;return n end
'''

CHECKS = r'''
local app,control,garage,store=Make(Controller);local done=0
Check(control:AssemblyCheckpoint()==nil,'Direct editor replacement receives no coroutine checkpoint')
control:Begin(function()return garage:Open(2)end,function(ok)Check(ok,'Successful done result');done=done+1 end)
control:Update(.1);Check(garage.active==1 and Count('clear')==0,'Original car and selected bay persist through 100 ms sink')
control:Update(.1)
Check(control:IsBusy() and control:IsAssembling() and garage.active==1,'Assembly yields with transaction pending and old active bay')
Check(#app.car.parts==3 and Count('metadata')==0 and Count('welcome')==0,'First slice does not save or welcome partial car')
Check(app.car.root.position.y<=-control:Depth(),'Candidate height is hidden below platform before yielding')
Check(control:Finish()==false and control:IsBusy(),'Navigation cannot synchronously drain unfinished assembly')
Check(not control:Begin(function()error('second action')end),'Concurrent transaction remains rejected while yielding')
local frames=0
while control:IsBusy()do control:Update(.016);frames=frames+1;assert(frames<40)
 if control:IsBusy()then Check(not control.lift.anim and app.car.root.position.y<0,'No rise during suspended transaction '..frames)end
end
Check(garage.active==2 and #app.car.parts==18 and done==1,'Complete assembly commits selected bay and callback exactly once')
Check(Count('metadata')==1 and Count('flush')==1 and Count('welcome')==1,'Save and welcome occur once after all parts')
Check(control.maxAssemblyMs<=3 and control.assemblyFrames>=6,'Deterministic 20 ms fixture is split into bounded CPU slices')
Check(control.lift.anim and control.lift.anim.duration==.45,'Original 450 ms rise starts after transaction success')
control:Update(.45);Check(app.car.root.position.y==1,'Rise ends at original rest height')
Check(control:Finish()==true,'Navigation proceeds after completed assembly')
local successfulFrames,successfulMax=control.assemblyFrames,control.maxAssemblyMs
store.fail=true;done=0
control:Begin(function()return garage:Open(1)end,function(ok,err)Check(not ok and err=='injected metadata failure','Failed save result retained');done=done+1 end)
for i=1,40 do control:Update(.2);if not control:IsBusy()then break end end
Check(garage.active==2 and app.blueprint.name=='new' and #app.car.parts==18,'Actual Garage rollback finishes original car across slices')
Check(done==1 and not control:IsBusy() and control.lift.anim~=nil,'Rollback raises restored car only after final callback')
local retiredApp,retired=Make(Controller);local called=0
retired:Begin(function()
 local checkpoint=retired:AssemblyCheckpoint();for i=1,20 do Cost(1);checkpoint(i/20)end;called=called+1;return true
end,function()called=called+100 end)
retired:Update(.2);Check(retired:IsAssembling(),'Cancellation fixture has actual suspended coroutine')
local suspended=retired.job;retired:Dispose();retired:Update(1)
Check(called==0 and retired.job==nil and retired.pending==nil and retired.app==nil and coroutine.status(suspended)=='dead','Dispose closes job without delayed action or callback')
local externalApp,external,externalGarage=Make(Controller);local superseded=0
external:Begin(function()return externalGarage:Open(2)end,function()superseded=superseded+1 end);external:Update(.2)
local previousJob=external.job;externalApp.blueprint:Load({name='external',count=1});external:Replaced();external:Update(.5)
Check(coroutine.status(previousJob)=='dead' and not external:IsBusy() and not external:IsAssembling() and superseded==0,'External replacement cancels suspended transaction without later callback')
local _,broken=Make(Controller);local failed=0
broken:Begin(function()error('injected action failure')end,function(ok)Check(not ok,'Thrown action reports failure');failed=failed+1 end)
broken:Update(.2);Check(failed==1 and not broken:IsBusy() and broken.lift.anim~=nil,'Thrown action clears ownership and recovers lift')
local _,download=Make(Controller);delayDownload=true;download:Begin(function()return true end)
Check(download:Finish()==false and download:CancelDownload(),'Unready download is cancellable and blocks navigation')
return {checks=checks,frames=successfulFrames,maxSliceMs=successfulMax}
'''


def run(controller_source, assertions=True):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(SETUP)
    for name in ['scene.CarLift', 'construction.Garage', 'render.VehicleView']:
        value = lua.globals().LoadModule((ROOT / 'scripts' / (name.replace('.', '/') + '.lua')).read_text(encoding='utf-8'), name)
        if name.endswith('Garage'):
            lua.globals().Garage = value
        if name.endswith('VehicleView'):
            lua.globals().View = value
    lua.globals().Controller = lua.globals().LoadModule(controller_source, 'app.HomeVehicleSwitch')
    if not assertions:
        return dict(lua.execute("local app,c,g,s=Make(Controller);c:Begin(function()return g:Open(2)end);c:Update(.2);return {elapsed=wall,selected=g.active,pending=c:IsBusy(),parts=#app.car.parts}").items())
    result = lua.execute(CHECKS)
    return {'checks': list(result.checks.values()), 'frames': result.frames, 'maxSliceMs': result.maxSliceMs}


def main():
    path = ROOT / 'scripts/app/HomeVehicleSwitch.lua'
    source = path.read_text(encoding='utf-8')
    result = run(source)
    host = (ROOT / 'scripts/app/HangarApp.lua').read_text(encoding='utf-8')
    assert 'self.car:Rebuild(self.blueprint,self.vehicleSwitch and self.vehicleSwitch:AssemblyCheckpoint())' in host
    begin = host.index('if self.vehicleSwitch then self.vehicleSwitch:Update(dt) end')
    end = host.index('local focus=UI.GetFocus()', begin)
    assert 'self.vehicleSwitch:IsAssembling()' in host[begin:end] and 'dt);return' in host[begin:end]
    result['checks'].extend(['Actual HangarApp LoadBlueprint passes guarded assembly checkpoint',
                             'Actual HangarApp returns before partial-car idle and HUD work while assembling'])
    old = subprocess.run(['git', 'show', '48ef15f2:scripts/app/HomeVehicleSwitch.lua'], cwd=ROOT,
                         capture_output=True, text=True, encoding='utf-8', check=True).stdout
    previous = run(old, False)
    assert previous == {'elapsed': 20, 'selected': 2, 'pending': False, 'parts': 18}, previous
    negatives = []
    for label, before, after in [
        ('no-yield', 'if Time:GetSystemTime()-self.sliceStart>=3 then coroutine.yield() end', ''),
        ('early-rise', 'if self.job and coroutine.running()==self.job then return end', ''),
        ('navigation-drains', 'if self.pending or self.job then return false end', ''),
        ('unclosed-cancel', 'if job and coroutine.running()~=job then coroutine.close(job) end', ''),
    ]:
        assert before in source
        try:
            run(source.replace(before, after))
        except Exception as error:
            negatives.append({'name': label, 'error': str(error).splitlines()[0]})
        else:
            raise AssertionError('Negative passed: ' + label)
    inputs = [path, ROOT / 'scripts/scene/CarLift.lua', ROOT / 'scripts/render/VehicleView.lua', ROOT / 'scripts/app/HangarApp.lua',
              ROOT / 'scripts/construction/Garage.lua', Path(__file__)]
    report = {'result': 'PASS', **result, 'oldMain': previous, 'negativeControls': negatives,
              'inputs': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
              'boundary': 'Actual HomeVehicleSwitch, CarLift, Garage and VehicleView.Rebuild with deterministic per-part CPU/native/store adapters. No GPU timing, disk/cloud latency or visual/performance acceptance. Host AssemblyCheckpoint/IsAssembling hooks require integrated audit.'}
    output = ROOT / 'docs/migration/evidence/home-assembly-offline.json'
    output.write_text(json.dumps(report, indent=2, sort_keys=True)+'\n', encoding='utf-8')
    print(json.dumps({'result': 'PASS', 'checks': len(result['checks']), 'negativeControls': len(negatives), 'oldSingleFrameMs': previous['elapsed'], 'newMaxSliceMs': result['maxSliceMs'], 'output': str(output)}))


if __name__ == '__main__':
    main()
