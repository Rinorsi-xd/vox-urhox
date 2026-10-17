const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
function inspect(jsPath,wasmPath){
 const js=fs.readFileSync(jsPath,'utf8'),bytes=fs.readFileSync(wasmPath);
 assert.equal(bytes.subarray(0,8).toString('hex'),'0061736d01000000','WASM v1 header');
 const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
 function reader(start,end){let pos=start;return {get pos(){return pos;},byte(){assert.ok(pos<end,'WASM field bounds');return bytes[pos++];},u32(){let value=0,shift=0;for(let i=0;i<5;i++){const b=this.byte();value+=(b&127)*2**shift;if(!(b&128)){assert.ok(value<=0xffffffff,'u32 overflow');return value;}shift+=7;}throw Error('Invalid u32 LEB');},name(){const n=this.u32();assert.ok(pos+n<=end,'WASM string bounds');const value=bytes.subarray(pos,pos+n).toString('utf8');pos+=n;return value;},skip(n){assert.ok(n>=0&&pos+n<=end,'WASM skip bounds');pos+=n;}};}
 const sections=[];let cursor=8;
 while(cursor<bytes.length){const r=reader(cursor,bytes.length),id=r.byte(),length=r.u32(),start=r.pos,end=start+length;assert.ok(end<=bytes.length,'WASM section bounds');sections.push({id,start,end});cursor=end;}
 const section=id=>{const found=sections.filter(s=>s.id===id);assert.equal(found.length,1,'Unique WASM section '+id);return reader(found[0].start,found[0].end);};
 const types=[],tr=section(1),typeCount=tr.u32();
 for(let i=0;i<typeCount;i++){assert.equal(tr.byte(),0x60,'Function type');const params=[],results=[];for(let n=tr.u32();n>0;n--)params.push(tr.byte());for(let n=tr.u32();n>0;n--)results.push(tr.byte());types.push({params,results});}
 const ir=section(2),importTypes=[];
 const limits=r=>{const flags=r.u32();assert.ok(!(flags&4),'memory64 is unsupported by this inspector');r.u32();if(flags&1)r.u32();};
 for(let n=ir.u32();n>0;n--){ir.name();ir.name();const kind=ir.byte();if(kind===0)importTypes.push(ir.u32());else if(kind===1){ir.byte();limits(ir);}else if(kind===2)limits(ir);else if(kind===3){ir.byte();ir.byte();}else if(kind===4){ir.byte();ir.u32();}else throw Error('Unknown import kind '+kind);}
 const functions=[],fr=section(3);for(let n=fr.u32();n>0;n--)functions.push(fr.u32());
 const exports=[],er=section(7);for(let n=er.u32();n>0;n--)exports.push({name:er.name(),kind:er.byte(),index:er.u32()});
 const exportMatch=js.match(/__heapInfo\s*=\s*Module\["__heapInfo"\]\s*=\s*wasmExports\["([^"]+)"\]/);
 assert.ok(exportMatch,'Actual heapInfo JS-to-WASM export binding');
 const exp=exports.find(e=>e.name===exportMatch[1]);assert.ok(exp&&exp.kind===0,'Heap info is function export');
 const definedIndex=exp.index-importTypes.length;assert.ok(definedIndex>=0,'Heap info is a defined function');
 const type=types[functions[definedIndex]];assert.deepEqual(type,{params:[],results:[]},'Verified void heapInfo ABI');
 const cr=section(10),bodyCount=cr.u32();assert.equal(bodyCount,functions.length,'Function and body count');let body;
 for(let i=0;i<bodyCount;i++){const length=cr.u32(),start=cr.pos;if(i===definedIndex)body={offset:start,length,tailHex:bytes.subarray(start+Math.max(0,length-80),start+length).toString('hex')};cr.skip(length);}
 const labelAt=js.indexOf('=== WASM Heap (dlmalloc) ===');assert.ok(labelAt>=0&&js.indexOf('=== WASM Heap (dlmalloc) ===',labelAt+1)<0,'Unique shipped dlmalloc label');
 const callbackContext=js.slice(Math.max(0,labelAt-150),labelAt+200);assert.ok(['In-use:','Free:','Arena:','1048576'].every(s=>callbackContext.includes(s)),'Shipped callback labels bytes converted to MiB');
 return {result:'PASS',boundary:'Read-only binary metadata; no WebAssembly compilation, instantiation, execution or live heap offsets.',js:{path:path.resolve(jsPath),sha256:hash(Buffer.from(js)),bytes:Buffer.byteLength(js)},wasm:{path:path.resolve(wasmPath),sha256:hash(bytes),bytes:bytes.length,importedFunctions:importTypes.length,definedFunctions:functions.length,typeCount},heapInfo:{exportName:exp.name,functionIndex:exp.index,type,body},callback:{labelOffset:labelAt,context:callbackContext}};
}
module.exports={inspect};
if(require.main===module)console.log(JSON.stringify(inspect(process.argv[2]||'.tmp/web-engine/UrhoXRuntime.js',process.argv[3]||'.tmp/web-engine/UrhoXRuntime.wasm'),null,2));
