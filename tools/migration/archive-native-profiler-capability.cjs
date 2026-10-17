'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),source=path.join(root,'.tmp/native-engine-profiler-capability-1017-c');
const output=path.join(root,'docs/migration/evidence/native-engine-profiler-capability-1017-c');
assert(!fs.existsSync(output),'Fresh archive only');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),raw={},hashes={};
for(const name of ['capability.json','identity.json','stdout.log','stderr.log']){
 raw[name]=fs.readFileSync(path.join(source,name));hashes[name]=sha(raw[name]);
}
const capability=JSON.parse(raw['capability.json']),identity=JSON.parse(raw['identity.json']);
assert.equal(capability.dumpOk,true);assert.equal(capability.dumpCalls,1);assert.equal(capability.logOverflow,false);
assert.equal(capability.frames,22);assert.equal(capability.exitReason,'frame-limit');
assert(capability.dumpMessages.some(m=>m.customLog==='lua'&&m.message.includes('VOX_ENGINE_DUMP_CAPTURE_CONTROL')),'Actual control log delivery');
const native=capability.dumpMessages.filter(m=>m.customLog===''&&m.message.includes('Profiler1.1.0'));
assert.equal(native.length,1,'One actual native profiler report');
const table=native[0].message,rows=[];
for(const line of table.split('\n')){
 const match=/^(\s*)(.*?)\s+(\d+):\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*$/.exec(line);
 if(!match)continue;
 rows.push({name:match[2],depth:+match[3],indent:match[1].length,
  lastFrame:{count:+match[4],avg:+match[5],max:+match[6],total:+match[7]},
  wholeExecution:{count:+match[8],avg:+match[9],max:+match[10],total:+match[11]}});
}
assert(rows.length>0);for(const name of ['RunFrame','Present','ApplyFrameLimit'])assert.equal(rows.filter(r=>r.name===name).length,1,'Actual named block '+name);
const summary={status:'NATIVE_NAMED_PROFILER_CAPABILITY_USABLE_LIMITED',source,rawSha256:hashes,probeSha256:identity.probeSha256,
 runtimeSha256:identity.runtimeSha256,frames:capability.frames,dumpCalls:capability.dumpCalls,logOverflow:false,
 controlDelivered:true,nativeReports:native.length,rows,
 absentInThisDump:['Engine.Update','UpdateOctree','Octree'].filter(name=>!rows.some(r=>r.name.includes(name))),
 boundary:'Independent offline reparse of actual root-run Native c files. Empty scene capability, not combat. Values retain the native table columns verbatim; raw header does not explicitly state units. Whole execution includes startup, named parents include children and cannot be added. ApplyFrameLimit is a named frame pacing block, not evidence of expensive simulation. No Web equivalence, CPU gap resolution, optimization gain, FPS result or mobile acceptance. Root separately reported owned PID49808 exit0; this parser did not launch or observe a process.'};
fs.mkdirSync(output,{recursive:true});for(const[name,bytes]of Object.entries(raw)){fs.writeFileSync(path.join(output,name),bytes,{flag:'wx'});assert.equal(sha(fs.readFileSync(path.join(output,name))),hashes[name]);}
fs.writeFileSync(path.join(output,'native-profiler-table.txt'),table,{flag:'wx'});
fs.writeFileSync(path.join(output,'independent-summary.json'),JSON.stringify(summary,null,2)+'\n',{flag:'wx'});
for(const[name,hash]of Object.entries(hashes))assert.equal(sha(fs.readFileSync(path.join(source,name))),hash,'Original unchanged');
console.log(JSON.stringify({output,status:summary.status,namedBlocks:rows.length,selected:rows.filter(r=>['RunFrame','Present','ApplyFrameLimit'].includes(r.name)),rawSha256:hashes},null,2));
