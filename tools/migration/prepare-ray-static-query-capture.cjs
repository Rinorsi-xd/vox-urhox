// One actual eight-car recording fixture, normal GC, no timing comparison.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const target=path.resolve(root,process.argv[2]||'.tmp/ray-static-query-capture-4a3a-1017-a');
assert(target.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(target));
const base=path.join(root,'.tmp/gc-ray-allocation-4a3a-1017-a/baseline');
const old=JSON.parse(fs.readFileSync(path.join(base,'identity.json')));
for(const [relative,hash]of Object.entries(old.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(base,relative))),hash);
let source=fs.readFileSync(path.join(__dirname,'vehicle-allocation-probe.lua'),'utf8');
const cut=source.indexOf('    for index=1,config.warmup do api.Step(index)end');assert(cut>0);
source=source.slice(source.indexOf("local World=require"),cut)
 .replace('local output=false','local recorder=false\nlocal output=false')
 .replace('local function RestoreGuard() collectgarbage=rawGc end','local function RestoreGuard() collectgarbage=rawGc;if recorder then recorder:Restore()end end');
const config={seed:1016,fixedDt:1/60,samples:8,normalBetween:1,warmup:120,recordSteps:16};
const tail=String.raw`
    for index=1,config.warmup do api.Step(index)end
    local before={shots=world.stats.shots,hits=world.stats.hits,damage=world.stats.damage}
    recorder=require('ray-static-query-recorder').New{units=world.units}
    recorder:Install(require('combat.VehicleRay'))
    for _=1,config.recordSteps do assert(collectgarbage('isrunning'));api.Step(stepNumber+1)end
    recorder:Restore();local result=recorder:Report()
    assert(#result.records>0 and result.cold>0 and result.warm>0,'Actual cold and warm queries required')
    assert(result.vehicleCount==8,'Capture must cover eight actual vehicles')
    result.metadata=metadata;result.rosterIdentity=source.identity;result.configuration=config
    result.workload={before=before,after={shots=world.stats.shots,hits=world.stats.hits,damage=world.stats.damage},step=stepNumber}
    result.collectorRunning=collectgarbage('isrunning');result.timingValidity='INVALID_QUERY_CAPTURE_OVERHEAD'
    result.finalRng={global=math.random(),drivers={}}
    for i,entry in ipairs(entries)do result.finalRng.drivers[i]=entry.driver and entry.driver.random()or false end
    world:Dispose();world=false;scene:Dispose();scene=false;return result
end
function Start()
    local ok,result=xpcall(Run,function(value)return tostring(value)end)
    local restored,restoreError=pcall(RestoreGuard)
    if not ok or not restored then result={status='FAIL',error=tostring(result),restoreError=not restored and tostring(restoreError)or false}end
    pcall(function()if world then world:Dispose()end;if scene then scene:Dispose()end end)
    local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
`;
const entry='VEHICLE_ALLOCATION_CONFIG=cjson.decode([=['+JSON.stringify(config)+']=])\n'+source+tail;
fs.mkdirSync(target,{recursive:true});fs.cpSync(path.join(base,'scripts'),path.join(target,'scripts'),{recursive:true});
fs.cpSync(path.join(base,'.project'),path.join(target,'.project'),{recursive:true});fs.symlinkSync(old.assetRoot,path.join(target,'assets'),'junction');
fs.copyFileSync(path.join(base,'allocation-roster.json'),path.join(target,'allocation-roster.json'));
const recorder=fs.readFileSync(path.join(__dirname,'ray-static-query-recorder.lua'));
fs.writeFileSync(path.join(target,'scripts/ray-static-query-capture.lua'),entry,{flag:'wx'});
fs.writeFileSync(path.join(target,'scripts/ray-static-query-recorder.lua'),recorder,{flag:'wx'});
const identity={...old,target,entry:'ray-static-query-capture.lua',configuration:config,timingValidity:'INVALID_QUERY_CAPTURE_OVERHEAD',
 sourceHashes:{...old.sourceHashes,'scripts/ray-static-query-capture.lua':sha(entry),'scripts/ray-static-query-recorder.lua':sha(recorder)},
 queryCapture:{version:1,originalRaySha256:old.sourceHashes['scripts/combat/VehicleRay.lua'],floatEncoding:'little-endian-double-hex'}};
let runner=fs.readFileSync(path.join(__dirname,'run-vehicle-allocation-probe.ps1'),'utf8');
function replaceOnce(oldText,newText){assert.equal(runner.split(oldText).length,2,'Exact Native runner boundary');runner=runner.replace(oldText,newText)}
replaceOnce("[string]$ProbeDirectory='.tmp/vehicle-allocation-fd97-a'","[string]$ProbeDirectory='"+path.relative(root,target).replaceAll('\\','/')+"'");
replaceOnce("$timingValidity=if($NormalTiming){'NORMAL_GC_FIXED_WORKLOAD_WALL'}else{'INVALID_FOR_PERFORMANCE'}","if($NormalTiming){throw 'Query capture is not a timing run'}\n$timingValidity='INVALID_QUERY_CAPTURE_OVERHEAD'");
const resultAt=runner.indexOf('if($NormalTiming){\n if($result.status');assert(resultAt>0);
runner=runner.slice(0,resultAt)+String.raw`if($result.status -ne 'ACTUAL_RAY_QUERY_CAPTURE_PASS' -or !$result.restored -or !$result.collectorRunning -or $result.vehicleCount -ne 8 -or $result.cold -le 0 -or $result.warm -le 0){throw ('Query capture incomplete; inspect '+$output)}
@{status=$result.status;output=$output;queries=$result.records.Count;cold=$result.cold;warm=$result.warm;vehicles=$result.vehicleCount;runtimeExitCode=$exitCode;nativeErrors=$errors.Count;timingValidity=$timingValidity} | ConvertTo-Json -Compress
`;
fs.writeFileSync(path.join(target,'run-capture.ps1'),runner,{flag:'wx'});identity.queryCapture.runnerSha256=sha(runner);
fs.writeFileSync(path.join(target,'identity.json'),JSON.stringify(identity,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({status:'READY_NOT_RUN',target,entry:identity.entry,configuration:config},null,2));
