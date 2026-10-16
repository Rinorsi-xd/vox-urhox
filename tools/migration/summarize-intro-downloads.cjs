// Attribute observed project requests using browser timestamps, not event delivery.
const fs=require('node:fs');
const input=process.argv[2];
if(!input)throw Error('Usage: node summarize-intro-downloads.cjs report.json');
const report=JSON.parse(fs.readFileSync(input,'utf8'));
if(report.scope!=='opening-boot-only'||report.shutdown!=='CLOSED')throw Error('A completed boot-only report is required');
const first=report.samples[0],last=report.samples.at(-1);
const requests=report.network.requests.filter(q=>q.file&&q.timing&&q.timing.startTime>=first.at&&q.timing.responseEnd>=0);
if(!requests.length)throw Error('No timed project requests');
const events=requests.flatMap(q=>[[q.timing.startTime,1],[q.timing.startTime+q.timing.responseEnd,-1]])
 .sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
let active=0,maxActive=0;
const occupancy={};
for(let i=0;i<events.length;i++){
 const duration=i?events[i][0]-events[i-1][0]:0;
 occupancy[active]=(occupancy[active]||0)+duration;
 active+=events[i][1];maxActive=Math.max(maxActive,active);
}
const slow=requests.slice().sort((a,b)=>b.timing.responseEnd-a.timing.responseEnd).slice(0,10).map(q=>({
 path:q.file.path,bytes:q.file.size,startAfterBootMs:q.timing.startTime-first.at,
 responseStartMs:q.timing.responseStart,responseEndMs:q.timing.responseEnd,
 observerDeliveryAfterBodyMs:q.finishedAt-q.timing.startTime-q.timing.responseEnd,
}));
console.log(JSON.stringify({
 scope:report.scope,result:report.result,shutdown:report.shutdown,
 manifest:report.identity.servedManifest,downloadConcurrencyOverride:report.identity.downloadConcurrency,
 errors:report.errors.length,httpFailures:report.httpFailures.length,
 bootToReadyMs:last.openingLoad.wallMs-first.openingLoad.wallMs,
 projectRequests:requests.length,projectBytes:requests.reduce((sum,q)=>sum+q.file.size,0),
 observedRequestWindowMs:events.at(-1)[0]-events[0][0],maxActive,
 observedDurationByActiveProjectRequestsMs:occupancy,slow,
 loader:last.openingLoad.loader,warmup:last.openingLoad.warmup,
 boundary:'Local raw fixture, instrumented browser. Occupancy covers matched project requests starting after the first boot sample; other origins, native queues/cache/worker work and earlier requests are excluded. Zero observed requests is not proof that the process is idle. Body end uses browser timing; observer delivery may be late. This does not measure CDN/mobile or playback continuity.',
},null,2));
