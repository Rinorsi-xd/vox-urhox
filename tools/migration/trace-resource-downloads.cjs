// Read-only request timing. File identity comes from the tested frozen manifest.
const fs=require('node:fs');
function attach(page,identity){
 const manifest=JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'));
 const files=new Map(manifest.files.map(f=>[f.uuid+'-'+f.hash+f.ext,{path:f.fs_path,source:f.source,size:f.size}]));
 const pending=new Map();let serial=0;
 const report={method:'Browser request start/body-finished events and ResourceTiming; fresh context, no forced cache or scheduling changes.',requests:[]};
 page.on('request',request=>{
  const url=request.url(),name=new URL(url).pathname.split('/').pop();
  const item={id:++serial,url,at:Date.now(),resourceType:request.resourceType(),file:files.get(name)};
  pending.set(request,item);report.requests.push(item);
 });
 page.on('requestfinished',async request=>{
  const item=pending.get(request);if(!item)return;
  item.finishedAt=Date.now();item.timing=request.timing();pending.delete(request);
  try{
   const response=await request.response();if(!response)return;
   item.status=response.status();const headers=response.headers();
   item.contentLength=headers['content-length'];item.contentEncoding=headers['content-encoding'];
   item.fromServiceWorker=response.fromServiceWorker();
  }catch(e){item.observationError=e.message;}
 });
 page.on('requestfailed',request=>{
  const item=pending.get(request);if(!item)return;
  item.failedAt=Date.now();item.failure=request.failure();pending.delete(request);
 });
 return report;
}
async function snapshot(page,report){
 report.resourceTiming=await page.evaluate(()=>performance.getEntriesByType('resource').map(e=>({
  name:e.name,startTime:e.startTime,duration:e.duration,fetchStart:e.fetchStart,
  requestStart:e.requestStart,responseStart:e.responseStart,responseEnd:e.responseEnd,
  transferSize:e.transferSize,encodedBodySize:e.encodedBodySize,decodedBodySize:e.decodedBodySize,
  workerStart:e.workerStart,nextHopProtocol:e.nextHopProtocol,
 })));
}
module.exports={attach,snapshot};
