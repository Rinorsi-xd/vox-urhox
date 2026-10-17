-- Fake modules exercise profiler plumbing only; they are not damage/native evidence.
local modules={}
local declarations={
 ['construction.Blueprint']={'Graph','Connectivity'},['construction.Prefab']={},
 ['drive.VehicleSpec']={'Build','BuildParts','MergeBoxes','Debris'},
 ['combat.CarUnit']={'DisposeVehicle','Build','Budget','LostCombatAbility'},
 ['drive.Vehicle']={'New','init','Dispose'},['combat.WeaponSystem']={'New','init','Refit'},
 ['combat.Debris']={'Spawn'},['physics.Space']={'Register','Unregister'},['physics.Body']={'Wrap'},
 ['drive.TrackWorld']={'NewVehicle'},['drive.TrialMetrics']={},
 ['construction.Rotors']={'Spec'},['construction.TurretRange']={'For'},
}
for name,methods in pairs(declarations)do local module={};modules[name]=module;for _,key in ipairs(methods)do module[key]=function()return nil,false,7 end end;package.loaded[name]=module end
local unit=modules['combat.CarUnit'];local spec=modules['drive.VehicleSpec'];local vehicle=modules['drive.Vehicle'];local body=modules['physics.Body']
spec.Build=function()return spec.BuildParts()end
vehicle.New=function()return vehicle.init()end
vehicle.init=function()return body.Wrap()end
unit.Build=function()local a,b,c=spec.Build();assert(a==nil and b==false and c==7);return vehicle.New()end
local M=assert(load(...))()
local original=unit.Build
local now=0;local function clock()now=now+1;return now end
local none=M.Profile(clock,false);assert(unit.Build==original);assert(none.Snapshot()==false);none.Reset();none.Restore()
local profiler=M.Profile(clock,true);profiler.Reset()
local a,b,c=unit.Build();assert(a==nil and b==false and c==7)
local rows=profiler.Snapshot();assert(#rows==23)
local counts={};local totalSelf=0
for _,row in ipairs(rows)do counts[row.name]=row.calls;assert(row.ms>=row.selfMs and row.selfMs>=0);totalSelf=totalSelf+row.selfMs end
assert(counts['CarUnit.Build']==1 and counts['VehicleSpec.Build']==1 and counts['VehicleSpec.BuildParts']==1 and counts['Vehicle.New']==1 and counts['Vehicle.init']==1 and counts['Body.Wrap']==1)
for _,row in ipairs(rows)do if row.name=='CarUnit.Build'then assert(row.ms==totalSelf)end end
profiler.Reset();for _,row in ipairs(profiler.Snapshot())do assert(row.calls==0 and row.ms==0 and row.selfMs==0)end
profiler.Restore();assert(unit.Build==original)
return {status='PASS',scopes=#rows,checks='timing installs no wrappers; profile preserves nil returns; exact nested counts/self conservation; snapshots/reset; all methods restored'}
