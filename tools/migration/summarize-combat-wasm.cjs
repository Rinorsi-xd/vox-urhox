'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
function run(directory,wasmPath,jsPath,outName='independent-wasm-profile.json'){
 const profile=JSON.parse(fs.readFileSync(path.join(directory,'drive.cpuprofile'),'utf8'));
 const bytes=fs.readFileSync(wasmPath),js=fs.readFileSync(jsPath,'utf8');assert.equal(bytes.subarray(0,8).toString('hex'),'0061736d01000000');
 const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
 function reader(start,end){let pos=start;return {get pos(){return pos},byte(){assert(pos<end);return bytes[pos++]},u32(){let v=0;for(let s=0;s<35;s+=7){const b=this.byte();v+=(b&127)*2**s;if(!(b&128)){assert(v<=0xffffffff);return v}}throw Error('u32 overflow')},name(){const n=this.u32();assert(pos+n<=end);const v=bytes.subarray(pos,pos+n).toString('utf8');pos+=n;return v},skip(n){assert(n>=0&&pos+n<=end);pos+=n}}}
 const sections=[];for(let cursor=8;cursor<bytes.length;){const r=reader(cursor,bytes.length),id=r.byte(),len=r.u32(),start=r.pos,end=start+len;assert(end<=bytes.length);sections.push({id,start,end});cursor=end}
 const get=id=>{const s=sections.filter(s=>s.id===id);assert.equal(s.length,1);return reader(s[0].start,s[0].end)};
 const custom=sections.filter(s=>s.id===0).map(s=>{const r=reader(s.start,s.end);return {name:r.name(),bytes:s.end-s.start,contentOffset:r.pos,end:s.end}});
 const imports=get(2);let importedFunctions=0;const limits=r=>{const flags=r.u32();assert(!(flags&4));r.u32();if(flags&1)r.u32()};
 for(let n=imports.u32();n>0;n--){imports.name();imports.name();const kind=imports.byte();if(kind===0){imports.u32();importedFunctions++}else if(kind===1){imports.byte();limits(imports)}else if(kind===2)limits(imports);else if(kind===3){imports.byte();imports.byte()}else if(kind===4){imports.byte();imports.u32()}else throw Error('Unknown import')}
 const exports=[],er=get(7);for(let n=er.u32();n>0;n--)exports.push({name:er.name(),kind:er.byte(),index:er.u32()});
 const names=new Map();for(const s of custom.filter(s=>s.name==='name')){const r=reader(s.contentOffset,s.end);while(r.pos<s.end){const id=r.byte(),len=r.u32(),end=r.pos+len;if(id===1){for(let n=r.u32();n>0;n--)names.set(r.u32(),r.name());assert.equal(r.pos,end)}else r.skip(len)}}
 const bodies=[],cr=get(10);for(let i=0,n=cr.u32();i<n;i++){const size=cr.u32(),offset=cr.pos;bodies.push({index:importedFunctions+i,offset,size,end:offset+size});cr.skip(size)}
 const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map(),sums=new Map();for(const n of profile.nodes)for(const c of n.children||[])parents.set(c,n.id);
 const invalidDeltas=[];let sumUs=0;for(let i=0;i<profile.samples.length;i++){const n=nodes.get(profile.samples[i]);assert(n);const rawWeight=profile.timeDeltas[i];if(!Number.isFinite(rawWeight)||rawWeight<0)invalidDeltas.push({index:i,value:rawWeight,nodeId:n.id});const weight=Number.isFinite(rawWeight)&&rawWeight>=0?rawWeight:0;sumUs+=weight;const k=n.callFrame.functionName;
  const a=sums.get(k)||{name:k,samples:0,weightUs:0,profileByteOffsets:new Set(),nodeIds:new Set()};a.samples++;a.weightUs+=weight;a.nodeIds.add(n.id);if(n.callFrame.url?.endsWith('.wasm'))a.profileByteOffsets.add(n.callFrame.columnNumber);sums.set(k,a)}
 const top=[...sums.values()].sort((a,b)=>b.weightUs-a.weightUs).slice(0,30).map(a=>{
  const match=a.name.match(/^wasm-function\[(\d+)\]$/),index=match?Number(match[1]):null,body=index===null?null:bodies[index-importedFunctions];
  if(body)for(const offset of a.profileByteOffsets)assert(offset>=body.offset&&offset<body.end,'Profile function offset inside exact runtime body');
  const exported=index===null?[]:exports.filter(e=>e.kind===0&&e.index===index),bindings=[];
  for(const e of exported){const escaped=e.name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),pattern=new RegExp('([A-Za-z_$][\\w$]*)\\s*=\\s*(?:Module\\["([^"]+)"\\]\\s*=\\s*)?wasmExports\\["'+escaped+'"\\]','g');for(const m of js.matchAll(pattern))bindings.push({local:m[1],module:m[2]||null,exportName:e.name})}
  const stack=[...a.nodeIds].map(id=>{const s=[];for(let n=nodes.get(id);n&&s.length<30;n=nodes.get(parents.get(n.id)))s.push(n.callFrame.functionName);return s});
  return {name:a.name,samples:a.samples,sampledWeightMs:a.weightUs/1000,share:a.weightUs/sumUs,functionIndex:index,profileByteOffsets:[...a.profileByteOffsets],body,debugName:names.get(index)||null,exports:exported,bindings,stackExamples:stack.slice(0,2)};
 });
 const result={status:'SAMPLED_WASM_METADATA_ANALYZED',boundary:'Offline original CPU profile aggregation plus exact shipped WASM sections. No module compilation, instantiation, execution or inferred Lua/native names. Sample weights are statistical, not exact function CPU durations. Stripped functions remain numbered.',
  runtime:{wasmPath:path.resolve(wasmPath),wasmSha256:sha(bytes),jsSha256:sha(Buffer.from(js)),importedFunctions,definedFunctions:bodies.length,customSections:custom,debugFunctionNames:names.size},
  profile:{durationMs:(profile.endTime-profile.startTime)/1000,samples:profile.samples.length,nonnegativeDeltaSumMs:sumUs/1000,invalidDeltas,invalidDeltaBoundary:'Invalid deltas retain sample counts but contribute no weighted duration. Raw profile remains unchanged.'},top};
 assert.equal(path.basename(outName),outName);fs.writeFileSync(path.join(directory,outName),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({status:result.status,runtime:result.runtime,profile:result.profile,top:top.slice(0,10).map(({stackExamples,...r})=>r)},null,2));return result;
}
module.exports={run};if(require.main===module)run(path.resolve(process.argv[2]),process.argv[3]||'.tmp/web-engine/UrhoXRuntime.wasm',process.argv[4]||'.tmp/web-engine/UrhoXRuntime.js',process.argv[5]);
