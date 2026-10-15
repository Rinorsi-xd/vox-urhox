// Independent raw-log review. Writes a new analysis, never changes captured inputs.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const dir=path.resolve(process.argv[2]||'');
const inputs=['report.json','frames.json','console.log','damage-events.json'];
const digest=name=>crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,name))).digest('hex');
const before=Object.fromEntries(inputs.map(name=>[name,digest(name)]));
const r=JSON.parse(fs.readFileSync(path.join(dir,'report.json'),'utf8'));
const frames=JSON.parse(fs.readFileSync(path.join(dir,'frames.json'),'utf8')).frames;
const lines=fs.readFileSync(path.join(dir,'console.log'),'utf8').split('\n');
const compiled=lines.flatMap((line,index)=>{
 if(!line.includes('Succeed to compile shader'))return [];
 const stamp=line.match(/^\[(\d{4}-\d{2}-\d{2}) (\d{2})_(\d{2})_(\d{2})_(\d{3})\]/);
 if(!stamp)return [];
 const wallAt=Date.parse(`${stamp[1]}T${stamp[2]}:${stamp[3]}:${stamp[4]}.${stamp[5]}+08:00`);
 const frame=frames.find(frame=>wallAt>=frame.wallAt-frame.ms&&wallAt<=frame.wallAt);
 return [{line:index+1,wallAt,utc:new Date(wallAt).toISOString(),observedPhase:frame?.phase||'between recorded frames',text:line}];
});
const material='surface_pbr_FIJGacrvO5aEcLp0K6C43qPV_11eeca77_61464CF2';
const stencil=compiled.filter(event=>/\/Stencil_[^/]+\.(?:vs|fs)\]/.test(event.text));
const instancedPoint=compiled.filter(event=>event.text.includes(material+'_')&&event.text.includes('.vs]')&&
 /defines \[[^\]]*\bAO;/.test(event.text)&&/\bINSTANCED;/.test(event.text)&&/\bPERPIXEL;/.test(event.text)&&/\bPOINTLIGHT;/.test(event.text));
const firstLive=frames.find(frame=>frame.phase==='target-area');
assert(firstLive,'captured public target-area boundary required');
const afterLoad=compiled.filter(event=>event.wallAt>=firstLive.wallAt&&event.wallAt<=Date.parse(r.finishedAt));
const inFire=compiled.filter(event=>event.wallAt>=r.fireStartedAt&&event.wallAt<=r.fireFinishedAt);
const inclusive=frames.filter(frame=>frame.wallAt>=r.fireStartedAt&&frame.wallAt-frame.ms<=r.fireFinishedAt);
const max=Math.max(...inclusive.map(frame=>frame.ms));
assert(inclusive.length===r.inclusiveFireFrames.count,'inclusive fire frame count independently agrees');
assert(Math.abs(max-r.inclusiveFireFrames.maxMs)<1e-6,'inclusive maximum independently agrees');
const result={schema:1,independentReviewUtc:new Date().toISOString(),inputHashes:before,
 sourceCommit:r.identity.identity.sourceCommit,servedManifest:r.identity.servedManifest,
 warmupHash:r.identity.identity.scripts['render/CombatWarmup.lua'],
 firstLiveUtc:new Date(firstLive.wallAt).toISOString(),fireStartUtc:new Date(r.fireStartedAt).toISOString(),
 stencil,instancedPoint,compiledAfterLoading:afterLoad,compiledDuringFire:inFire,
 checks:{stencilVsAndFsCompiledDuringLoading:stencil.some(e=>e.text.includes('.vs]'))&&stencil.some(e=>e.text.includes('.fs]'))&&stencil.every(e=>e.observedPhase==='trial-load'),
  exactInstancedAoPointVertexCompiledDuringLoading:instancedPoint.length>0&&instancedPoint.every(e=>e.observedPhase==='trial-load'),
  noShaderFirstUseAfterLoading:afterLoad.length===0,noShaderFirstUseDuringFire:inFire.length===0,
  allFunctionalAssertionsPassed:r.checks.length===17&&r.checks.every(check=>check.pass),
  inclusiveFireBelow100ms:inclusive.length>0&&inclusive.every(frame=>frame.ms<=100),
  allObservedFlushesBelow100ms:r.damageEvents.length>0&&r.damageEvents.every(event=>event.ms<=100)},
 functionalAssertions:r.checks.length,flushCount:r.damageEvents.length,maxFlushMs:Math.max(...r.damageEvents.map(event=>event.ms)),
 inclusiveFireFrames:{count:inclusive.length,maxMs:max,over100ms:inclusive.filter(frame=>frame.ms>100).length},
 loadingFailuresRetained:{boot:r.frameSummary.boot,trialLoad:r.frameSummary['trial-load']},
 boundary:'Desktop Chrome public-input destruction fixture only. Shader timestamps are native log time Asia/Shanghai, aligned to requestAnimationFrame wall times. No exclusive CPU/GPU causal attribution, whole-run/boot/load PASS, audible-quality review, mobile acceptance, or ShellMaterials candidate acceptance.'};
result.reviewResult=Object.values(result.checks).every(Boolean)?'PASS':'FAIL';
assert.deepEqual(before,Object.fromEntries(inputs.map(name=>[name,digest(name)])),'raw evidence changed during review');
fs.writeFileSync(path.join(dir,'warmup-independent-analysis.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
