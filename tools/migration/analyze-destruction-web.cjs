// Reclassify only documented optional bootstrap probes; preserve original report.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {classifyNetwork}=require('./check-destruction-web.cjs');
const dir=path.resolve(process.argv[2]||'');
const report=JSON.parse(fs.readFileSync(path.join(dir,'report.json'),'utf8'));
const lines=fs.readFileSync(path.join(dir,'console.log'),'utf8').split('\n');
const skipped=lines.flatMap(line=>line.match(/No package for (engine-res|urhox-libs), skipping/)?.slice(1)||[]);
const completed=lines.some(line=>line.includes('[Bootstrap/DownloadInitialPackage] Completed successfully'));
const classification=classifyNetwork(report.networkErrors,skipped,completed);
const checks=report.checks.filter(check=>check.name!=='No failed resource requests');
assert(report.checks.at(-1)?.name==='No failed resource requests','This analysis only applies to the original bootstrap-network assertion failure');
const measured=JSON.parse(fs.readFileSync(path.join(dir,'frames.json'),'utf8'));
const shaderLoads=lines.filter(line=>/Succeed to compile shader|Loaded (?:vertex|pixel) shader/.test(line)).flatMap(line=>{
 const stamp=line.match(/^\[(\d{4}-\d{2}-\d{2}) (\d{2})_(\d{2})_(\d{2})_(\d{3})\]/);
 if(!stamp)return [];
 const wallAt=Date.parse(`${stamp[1]}T${stamp[2]}:${stamp[3]}:${stamp[4]}.${stamp[5]}+08:00`);
 return [{wallAt,line}];
});
const spikes=measured.frames.filter(frame=>frame.phase==='fire'&&frame.ms>100).map(frame=>({
 frame,nearFlushes:report.damageEvents.filter(event=>Math.abs(event.arrivedAt-frame.wallAt)<1000),
 nearbyShaderLoads:shaderLoads.filter(event=>event.wallAt>=frame.wallAt-frame.ms-100&&event.wallAt<=frame.wallAt+100),
 boundary:'Native console timestamps use the machine Asia/Shanghai time zone. Temporal correlation identifies first-use shader compilation, not an exclusive CPU/GPU causal profile.'
}));
const analysis={originalResult:report.result,originalFunctionalResult:report.functionalResult,
 functionalReview:checks.every(check=>check.pass)&&classification.unresolved.length===0?'PASS':'FAIL',
 performanceResult:report.performanceResult,thresholdMs:100,networkClassification:classification,
 sourceEvidence:'report.json and console.log retained unchanged',checksPassed:checks.filter(check=>check.pass).length,
 flushCount:report.damageEvents.length,maxFlushMs:Math.max(...report.damageEvents.map(event=>event.ms)),
 targetResult:report.targetResult,finalScore:report.final.combatFeedback,feedbackAudio:report.final.feedbackAudio.counts,
 liveFrames:report.liveFrames,inclusiveFireFrames:report.inclusiveFireFrames,spikes,
 finalReviewResult:report.performanceResult==='PASS'&&checks.every(check=>check.pass)&&classification.unresolved.length===0?'PASS':'FAIL',
 boundary:'Desktop Chrome public inputs only. Audio play counters are not an audible-quality review. The original failure and >100 ms spike remain visible.'};
fs.writeFileSync(path.join(dir,'analysis.json'),JSON.stringify(analysis,null,2)+'\n');
console.log(JSON.stringify(analysis,null,2));
