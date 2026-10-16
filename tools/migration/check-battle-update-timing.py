"""Exercise actual opt-in QA timing with Lua/CDP adapters; never start a browser."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

PROBE = ROOT / 'tools/migration/probe-outgame-web.lua'
RUNNER = ROOT / 'tools/migration/check-story-natural-web.cjs'

SETUP = r'''
wall=0;checks={};messages={};pressed=nil;fixtureCalls={}
KEY_F8='F8';KEY_F13='F13';KEY_F14='F14';KEY_F15='F15'
Time={GetSystemTime=function()return wall end}
print=function(text)messages[#messages+1]=text end
input={GetKeyPress=function(_,key)return key~=nil and pressed==key end}
package={loaded={}}
local hostile=setmetatable({}, {
 __pairs=function()error('Timing observer traversed parts')end,
 __len=function()error('Timing observer measured parts')end,
 __index=function()error('Timing observer indexed parts')end})
local function Hit(name,delay,body)
 return function(self,token,...)
  fixtureCalls[name]=(fixtureCalls[name] or 0)+1;wall=wall+delay
  if body then body(self,token,...)end
  return token,nil,'third',false
 end
end
local function Object(name,methods,rawOwned)
 local prototype={};local object={parts=hostile,bp={parts=hostile},fixtureName=name}
 for method,spec in pairs(methods)do
  local fn=Hit(name..'.'..method,spec[1],spec[2])
  if rawOwned then object[method]=fn else prototype[method]=fn end
 end
 prototype.__index=prototype;setmetatable(object,prototype)
 object.fixtureOriginal={};for method in pairs(methods)do object.fixtureOriginal[method]=object[method]end
 return object
end
function MakeVehicle(name,rawOwned)
 local control=Object(name..'.control',{Step={1}},rawOwned)
 local vehicle=Object(name,{Step={2,function(self,dt)self.mechControl:Step(dt)end}},rawOwned)
 vehicle.mechControl=control;return vehicle
end
local function Unit(name,rawOwned)
 local unit=Object(name,{Flush={1},Step={1,function(self,dt)self.vehicle:Step(dt)end}},rawOwned)
 unit.vehicle=MakeVehicle(name..'.vehicle',rawOwned);unit.alive=true;return unit
end
local function VehicleView(name,rawOwned)
 return Object(name,{Update={1},UpdateIdle={1},UpdateWeaponEffects={1}},rawOwned)
end
function MakeTrial(name)
 local player,bossUnit,ally=Unit(name..'.player'),Unit(name..'.boss',true),Unit(name..'.ally')
 local units={player,bossUnit,ally}
 for i=4,12 do units[i]=Unit(name..'.unit'..i,i%2==0)end
 local space=Object(name..'.space',{Step={2}})
 local world=Object(name..'.world',{Step={2,function(self,dt)
  for _,unit in ipairs(self.units)do unit:Flush();unit:Step(dt)end
  self.space:Step(dt)
 end}});world.units=units;world.space=space
 local bossView=Object(name..'.bossView',{Update={1}})
 local boss=Object(name..'.bossController',{
  BeforeStep={1},StepAllies={1},Projectiles={1},
  Update={1,function(self,dt)self:Projectiles(dt);self.view:Update(dt)end}},true)
 boss.unit=bossUnit;boss.allies={{unit=ally}};boss.view=bossView
 local story=Object(name..'.story',{
  BeforeStep={1,function(self,dt)self.boss:BeforeStep(dt);self.boss:StepAllies(dt)end},
  AfterStep={1},Update={1,function(self,dt)self.boss:Update(dt);self.view:Update(dt)end}})
 story.player=player;story.boss=boss;story.level={id='fixture'};story.rules={}
 story.view=Object(name..'.missionView',{Update={1}});story.entries={}
 for i,unit in ipairs(units)do story.entries[i]={unit=unit}end
 local drive=Object(name..'.playerDrive',{Update={1,function(self,dt)self.view:Update(dt)end}})
 drive.view=VehicleView(name..'.playerView')
 local combatView=Object(name..'.combatView',{Update={1,function(self,dt)
  for _,entry in pairs(self.units)do entry:Update(dt);entry.view:Update(dt)
   entry.view:UpdateIdle(dt);entry.view:UpdateWeaponEffects(dt)
  end
 end}})
 combatView.units={}
 for i,unit in ipairs(units)do
  local entry=Object(name..'.driveView'..i,{Update={1}},i%2==0)
  entry.view=VehicleView(name..'.vehicleView'..i,i%2==0);combatView.units[unit]=entry
 end
 local trial=Object(name,{
  Tick={1,function(self,dt)
   self.story:BeforeStep(dt);self.world:Step(dt);self.story:AfterStep(dt);self.story:Update(dt)
  end},
  RenderViews={1,function(self,dt)
   self.view:Update(dt);self.view.view:UpdateIdle(dt);self.view.view:UpdateWeaponEffects(dt)
   self.combatView:Update(dt)
  end},PostUpdate={1}})
 trial.world=world;trial.story=story;trial.combat=story;trial.vehicle=player.vehicle
 trial.view=drive;trial.combatView=combatView;trial.map={id='fixture'}
 trial.pointer={captured=true,pending=false};return trial
end
function MakeApp(name)
 local app={trial=MakeTrial(name),loadingFlow={active=false,phase='live'}}
 function app:Update(dt)self.trial:Tick(dt);self.trial:RenderViews(dt)end
 return app
end
actual=MakeApp('initial');VOX_HANGAR={app=actual}
function HandleUpdate(_,event)actual:Update(event:GetFloat('TimeStep'))end
EVENT={GetFloat=function()return .016 end}
function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
function Frame(key)pressed=key;HandleUpdate('Update',EVENT);pressed=nil end
'''

CHECKS = r'''
local originalTrial=actual.trial
local originalTick=originalTrial.Tick
local originalBossUpdate=originalTrial.story.boss.Update
Check(BATTLE.state().enabled==false,'Detailed battle timing defaults off')
for i=1,3 do Frame()end
Check(originalTrial.Tick==originalTick,'Default frames do not install trial wrappers')
Check(originalTrial.story.boss.Update==originalBossUpdate,'Default frames do not install nested wrappers')
Frame('F15')
Check(BATTLE.state().enabled==true,'Real HandleUpdate F15 enables detailed timing')
Check(originalTrial.Tick~=originalTick,'F15 wraps actual trial before dispatch')
Check(originalTrial.story.boss.Update~=originalBossUpdate,'F15 wraps actual nested boss')
Check(TIMING['battle.Trial.Tick'].calls==1,'F15 binding captures its very first original dispatch')
local firstWrapper=originalTrial.Tick
for i=1,4 do Frame()end
Check(originalTrial.Tick==firstWrapper,'Repeated frames preserve a single wrapper')
for _,label in ipairs({'battle.Trial.Tick','battle.Trial.RenderViews','battle.World.Step','battle.Space.Step',
 'battle.Mission.BeforeStep','battle.Mission.AfterStep','battle.Mission.Update','battle.Boss.BeforeStep',
 'battle.Boss.StepAllies','battle.Boss.Projectiles','battle.Boss.Update','battle.BossView.Update',
 'battle.Player.Flush','battle.Player.Vehicle.Step','battle.Player.MechControl.Step',
 'battle.BossUnit.Flush','battle.BossUnit.Vehicle.Step','battle.BossUnit.MechControl.Step',
 'battle.Ally1.Flush','battle.Ally1.Vehicle.Step','battle.Ally1.MechControl.Step',
 'battle.PlayerView.DriveView.Update','battle.PlayerView.VehicleView.Update',
 'battle.PlayerView.VehicleView.UpdateIdle','battle.PlayerView.VehicleView.UpdateWeaponEffects',
 'battle.CombatView.Update'})do
 Check(TIMING[label] and TIMING[label].calls==5,'Actual nested method counted once each frame: '..label)
end
for _,method in ipairs({'DriveView.Update','VehicleView.Update','VehicleView.UpdateIdle','VehicleView.UpdateWeaponEffects'})do
 Check(TIMING['battle.CombatVehicle.'..method].calls==60,'Actual combat vehicle aggregation includes twelve views: '..method)
end
Check(TIMING['battle.Trial.Tick'].maxMs==74 and TIMING['battle.World.Step'].maxMs==64,'Nested inclusive CPU durations retain controlled call costs')
Check(BATTLE.state().sampledUnits==5 and BATTLE.state().unitLimit==5,'Unit samples stay bounded at five despite twelve world units')
local wrappedUnits=0
for _,unit in ipairs(originalTrial.world.units)do if unit.Flush~=unit.fixtureOriginal.Flush then wrappedUnits=wrappedUnits+1 end end
Check(wrappedUnits==5 and originalTrial.world.units[6].Flush==originalTrial.world.units[6].fixtureOriginal.Flush,'Unit wrappers do not spill outside the selected sample')
originalTrial:PostUpdate(.016);Check(TIMING['battle.Trial.PostUpdate'].calls==1,'Actual optional PostUpdate binding is counted')
local firstEpoch=BATTLE.state().epoch
local firstSnapshot={epoch=firstEpoch,sampledUnits=BATTLE.state().sampledUnits,boundMethods=BATTLE.state().boundMethods,
 tickCalls=TIMING['battle.Trial.Tick'].calls,tickMaxMs=TIMING['battle.Trial.Tick'].maxMs,
 worldMaxMs=TIMING['battle.World.Step'].maxMs,combatViewCalls=TIMING['battle.CombatVehicle.VehicleView.UpdateIdle'].calls}
local a,b,c,d=originalTrial:Tick('token')
Check(a=='token' and b==nil and c=='third' and d==false,'Nested wrappers retain self arguments and four returns')
local slow=BATTLE.timed('fixture.quiet',function(token)wall=wall+130;return token,nil,'third',false end,true)
local beforeMessages=#messages
a,b,c,d=slow('quiet-token')
Check(a=='quiet-token' and b==nil and c=='third' and d==false,'Quiet timing retains nil and false return slots')
Check(#messages==beforeMessages,'Quiet slow call does not print')
Check(TIMING['fixture.quiet'].calls==1 and TIMING['fixture.quiet'].slowCalls==1 and TIMING['fixture.quiet'].maxMs==130,'Quiet mode retains slow-call statistics')
local legacy=BATTLE.timed('fixture.legacy',function()wall=wall+130 end)
legacy();Check(#messages==beforeMessages+1 and messages[#messages]:find('fixture.legacy',1,true)~=nil,'Default TimedCall preserves legacy slow-call log')
local external=function(self,token)wall=wall+131;return token,nil,'replacement',false end
originalTrial.Tick=external;BATTLE.ensure(actual)
Check(originalTrial.Tick~=external,'Explicit method replacement is rebound')
beforeMessages=#messages
a,b,c,d=originalTrial:Tick('replacement-token')
Check(a=='replacement-token' and b==nil and c=='replacement' and d==false,'Rebound method retains all return slots')
Check(#messages==beforeMessages and TIMING['battle.Trial.Tick'].slowCalls==1,'Actually bound slow method remains quiet and records its duration')
local oldVehicle=originalTrial.vehicle
local newVehicle=MakeVehicle('new-player-vehicle',true)
originalTrial.vehicle=newVehicle;originalTrial.story.player.vehicle=newVehicle
BATTLE.ensure(actual)
Check(newVehicle.Step~=newVehicle.fixtureOriginal.Step,'Replacement player vehicle is instrumented')
Check(oldVehicle.Step==oldVehicle.fixtureOriginal.Step,'Detached player vehicle wrapper is restored')
local replacementTrial=MakeTrial('replacement-trial')
actual.trial=replacementTrial;BATTLE.ensure(actual)
Check(originalTrial.Tick==external,'Detached trial restores latest external implementation')
Check(rawget(originalTrial.story,'BeforeStep')==nil,'Detached inherited method removes instance shadow')
Check(originalTrial.story.boss.Update==originalBossUpdate,'Detached raw-owned method restores original')
Check(rawget(newVehicle,'Step')==newVehicle.fixtureOriginal.Step,'Detached raw-owned vehicle restores original')
Check(replacementTrial.Tick~=replacementTrial.fixtureOriginal.Tick,'Replacement trial is instrumented')
local oldApp=actual;actual=MakeApp('replacement-app');VOX_HANGAR={app=actual};Frame()
Check(rawget(replacementTrial,'Tick')==nil,'Replacement app unbinds previous trial')
Check(actual.trial.Tick~=actual.trial.fixtureOriginal.Tick,'Replacement app binds its actual trial')
local externalBoss=function()return 'external',nil,'third',false end
actual.trial.story.boss.Update=externalBoss
Frame('F15')
Check(BATTLE.state().enabled==false,'Second actual F15 disables detailed timing')
Check(rawget(actual.trial,'Tick')==nil,'Disable restores inherited trial method without instance shadow')
Check(actual.trial.story.boss.Update==externalBoss,'Disable preserves an externally replaced raw method')
local disabledTick=actual.trial.Tick;Frame();Check(actual.trial.Tick==disabledTick,'Disabled subsequent frame stays unwrapped')
BATTLE.set(true);BATTLE.ensure(actual)
Check(actual.trial.Tick~=disabledTick,'Explicit re-enable binds cleanly')
Check(BATTLE.state().epoch==firstEpoch+1 and TIMING['battle.Trial.Tick'].calls==0,'New enabled epoch resets detailed counters')
local leavingTrial=actual.trial
actual.stopped=true;BATTLE.ensure(actual)
Check(not BATTLE.state().active and BATTLE.state().boundMethods==0 and rawget(leavingTrial,'Tick')==nil,'Stopped app unbinds its actual trial')
actual.stopped=false;BATTLE.ensure(actual)
Check(BATTLE.state().active and rawget(leavingTrial,'Tick')~=nil,'Restarted live owner rebinds methods')
leavingTrial.disposed=true;BATTLE.ensure(actual)
Check(not BATTLE.state().active and BATTLE.state().boundMethods==0 and rawget(leavingTrial,'Tick')==nil,'Disposed trial restores all instrumented methods')
leavingTrial.disposed=false;BATTLE.ensure(actual)
actual.trial=nil;BATTLE.ensure(actual)
Check(BATTLE.state().enabled==true,'Leaving trial retains opt-in switch for later session')
Check(not BATTLE.state().active and BATTLE.state().boundMethods==0 and rawget(leavingTrial,'Tick')==nil,'Leaving trial restores wrappers and reports no active methods')
BATTLE.set(false);Check(BATTLE.state().enabled==false,'Explicit teardown disables switch')
Check(next(package.loaded)==nil,'Observer does not eagerly require or alter module cache')
return {checks=checks,initialTickCalls=fixtureCalls['initial.Tick'],timing=TIMING,snapshot=firstSnapshot}
'''

RUNNER_CHECKS = r'''
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const file=path.resolve(process.argv[1]),source=fs.readFileSync(0,'utf8'),actualRequire=createRequire(file);
const begin=source.indexOf('await configureBattleTiming(battleTimingCheck,async key=>{');
const endMarker='},wait,value=>{Object.assign(report.battleTiming,value);persist();});';
assert(begin>=0);const end=source.indexOf(endMarker,begin);assert(end>=0);
const configureCall=source.slice(begin,end+endMarker.length);
let checks=[];
const check=(ok,label)=>{assert(ok,label);checks.push(label);};
function load(env){
 const module={exports:{}};let browserAttempts=0;
 const adaptedRequire=name=>name.includes('/node_modules/playwright')?
  {chromium:{launch:()=>{browserAttempts++;throw Error('Browser must never launch in CPU fixture');}}}:actualRequire(name);
 const context=vm.createContext({require:adaptedRequire,module,exports:module.exports,__filename:file,__dirname:path.dirname(file),
  process:{env:{VOX_STORY_LEVEL:'1',...env}},console,Buffer,setTimeout,clearTimeout,structuredClone});
 vm.runInContext(source,context,{filename:file});check(browserAttempts===0,'Full actual runner import does not launch browser');
 return {context,api:module.exports};
}
async function run(env,mode='success'){
 const {context,api}=load(env),events=[],records=[];let observed=0,persisted=0;
 const state={performance:{battleTiming:{enabled:mode!=='false-ack',epoch:3,active:true,boundMethods:26}}};
 context.objectInput={send:async(method,event)=>{
  if(mode==='dispatch-failure')throw Error('actual dispatch adapter failure');events.push({method,...event});
 }};
 context.sleep=async ms=>assert.equal(ms,40);
 context.report={battleTiming:{samples:[]}};context.persist=()=>{persisted++;records.push(structuredClone(context.report.battleTiming));};
 context.wait=async(predicate,label,timeout)=>{
  observed++;assert.equal(timeout,20000);assert.equal(label,'explicit F15 CPU timing acknowledgement');
  assert.equal(predicate({}),false);assert.equal(predicate({performance:{battleTiming:{enabled:false}}}),false);
  if(mode==='observe-failure')throw Error('actual observation adapter failure');
  if(mode==='success')assert.equal(predicate(state),true);
  return state;
 };
 let error;
 try{await vm.runInContext('(async()=>{'+configureCall+'})()',context);}catch(value){error=String(value);}
 return {events,records,observed,persisted,error,state,context,api};
}
(async()=>{
 for(const value of [undefined,'','0','true','false','01']){
  const result=await run(value===undefined?{}:{VOX_STORY_BATTLE_TIMING:value});
  check(!result.error&&result.events.length===0&&result.observed===0,'Default/non-1 env never dispatches or waits: '+String(value));
  check(result.records.length===1&&result.records[0].result==='NOT_REQUESTED'&&result.records[0].keyRequests===0,'Disabled run records explicit NOT_REQUESTED: '+String(value));
 }
 const enabled=await run({VOX_STORY_BATTLE_TIMING:'1'});
 check(!enabled.error&&enabled.observed===1,'Explicit 1 environment waits for actual enabled observation');
 check(enabled.events.length===2&&enabled.events.every(e=>e.method==='Input.dispatchKeyEvent'&&e.key==='F15'&&e.code==='F15'&&e.windowsVirtualKeyCode===126&&e.nativeVirtualKeyCode===126),'Actual runner dispatches F15 using Chrome key 126');
 check(enabled.events[0].type==='rawKeyDown'&&enabled.events[1].type==='keyUp','Actual runner releases F15 after its explicit keydown');
 check(enabled.records.map(s=>s.result).join(',')==='REQUESTED,OBSERVED'&&enabled.records[1].keyRequests===1,'Requested and actual observed results persist separately');
 enabled.state.performance.battleTiming.boundMethods=999;
 check(enabled.context.report.battleTiming.observed.boundMethods===26,'Observed acknowledgement is frozen against later state mutations');
 for(const mode of ['false-ack','observe-failure','dispatch-failure']){
  const result=await run({VOX_STORY_BATTLE_TIMING:'1'},mode);
  check(!!result.error&&result.records.every(r=>r.result!=='OBSERVED'),'Missing actual acknowledgement cannot pass: '+mode);
 }
 const direct=load({}).api.configureBattleTiming,records=[];
 await direct(false,()=>{throw Error('Disabled dispatch invoked');},()=>{throw Error('Disabled observer invoked');},record=>records.push(record));
 check(records.length===1&&records[0].requested===false,'Exported actual helper independently retains disabled semantics');
 process.stdout.write(JSON.stringify({checks,events:enabled.events,records:enabled.records}));
})().catch(error=>{console.error(error);process.exitCode=1;});
'''


def run_probe(source):
    header = source[:source.index('VOX_SKIP_TUTORIAL=true')]
    update = source[source.index('function HandleUpdate(et,ed)'):source.index('\nlocal originalPostUpdate=HandlePostUpdate')]
    lua = LuaRuntime(unpack_returned_tuples=True)
    compiled = lua.eval('function(text)local fn,err=load(text);return fn~=nil,err end')(source)
    assert compiled[0], compiled[1]
    lua.execute(SETUP)
    lua.execute(header + '''
local frames=0;local samples={};local sampleMode=''
local Dump=function()end
BATTLE={state=BattleTimingState,ensure=EnsureBattleTiming,set=SetBattleTiming,timed=TimedCall}
TIMING=updateTiming
''' + update)
    result = lua.execute(CHECKS)
    return {
        'checks': list(result.checks.values()),
        'initialTickCalls': result.initialTickCalls,
        'timingLabels': sorted(result.timing.keys()),
        'snapshot': dict(result.snapshot),
        'fullProbeSyntax': 'PASS',
    }


def run_runner(source):
    actual = subprocess.run(['node', '-e', RUNNER_CHECKS, str(RUNNER)], input=source, text=True,
                            encoding='utf-8', capture_output=True, check=True)
    return json.loads(actual.stdout)


def negative_controls(source, runner_source):
    rejected = []
    probe_mutations = [
        ('default-enabled', 'enabled=false,epoch=0', 'enabled=true,epoch=0'),
        ('bind-only-after-original', '    EnsureBattleTiming(timingApp)\n', ''),
        ('nested-slow-log-noise', 'local options={quiet=true,bindings=battleBindings}', 'local options={quiet=false,bindings=battleBindings}'),
        ('lost-return-slots', 'return first,second,third,fourth', 'return first,second'),
        ('nested-wrapper', 'if methods[method]==object[method] then return end', ''),
        ('clobber-external-method', 'if binding.object[binding.method]==binding.wrapped then binding.object[binding.method]=binding.original end', 'binding.object[binding.method]=binding.original'),
        ('unit-limit-expanded', 'unitLimit=5,', 'unitLimit=6,'),
        ('parts-traversal', 'seen[unit]=true;units[#units+1]=unit', 'for _ in pairs(unit.parts)do end;seen[unit]=true;units[#units+1]=unit'),
    ]
    runner_mutations = [
        ('implicit-environment-enable', "process.env.VOX_STORY_BATTLE_TIMING==='1'", "process.env.VOX_STORY_BATTLE_TIMING!=='0'"),
        ('wrong-chrome-key-code', 'windowsVirtualKeyCode:126,nativeVirtualKeyCode:126', 'windowsVirtualKeyCode:125,nativeVirtualKeyCode:125'),
        ('accept-false-acknowledgement', "assert.equal(observed.performance.battleTiming.enabled,true,'Actual probe acknowledged F15 CPU timing');", ''),
        ('mutable-acknowledgement', 'observed:structuredClone(observed.performance.battleTiming)', 'observed:observed.performance.battleTiming'),
    ]
    for kind, original, mutations, execute in [
        ('probe', source, probe_mutations, run_probe),
        ('runner', runner_source, runner_mutations, run_runner),
    ]:
        for name, before, after in mutations:
            assert before in original, 'Missing actual mutation anchor: ' + name
            try:
                execute(original.replace(before, after))
            except Exception as error:
                detail = error.stderr if isinstance(error, subprocess.CalledProcessError) else str(error)
                rejected.append({'scope': kind, 'name': name, 'failure': detail.splitlines()[0]})
            else:
                raise AssertionError('Negative control passed: ' + name)
    return rejected


def main():
    source = PROBE.read_text(encoding='utf-8')
    runner_source = RUNNER.read_text(encoding='utf-8')
    result = run_probe(source)
    runner = run_runner(runner_source)
    subprocess.run(['node', '--check', str(RUNNER)], text=True, capture_output=True, check=True)
    rejected = negative_controls(source, runner_source)
    report = {
        'result': 'PASS', 'probe': result, 'runner': runner,
        'runnerSyntax': 'PASS', 'rejectedMutations': rejected,
        'inputs': {str(file.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(file.read_bytes()).hexdigest()
                   for file in [PROBE, RUNNER, Path(__file__)]},
        'boundary': 'CPU execution of actual QA probe header and full HandleUpdate with deterministic Lua clock and method adapters, plus actual full runner import and inline F15 request with CDP/observation adapters. No browser, GPU, native timing, gameplay change, production payload change or performance acceptance. Nested durations are inclusive and cannot be summed; wrapper overhead and millisecond resolution remain material.',
    }
    out = ROOT / 'docs/migration/evidence/battle-update-timing-offline.json'
    out.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(json.dumps({'result': report['result'], 'probeChecks': len(result['checks']), 'runnerChecks': len(runner['checks']),
                      'rejectedMutations': len(rejected), 'output': str(out)}))


if __name__ == '__main__':
    main()
