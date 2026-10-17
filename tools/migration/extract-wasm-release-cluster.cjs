'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(output,ids=[1680,5650,7185,10056]){
 const wasmPath=path.join(root,'.tmp/web-engine/UrhoXRuntime.wasm'),jsPath=path.join(root,'.tmp/web-engine/UrhoXRuntime.js'),wabtPath=path.join(root,'.tmp/g0-wasm-tools/node_modules/wabt');
 const bytes=fs.readFileSync(wasmPath),js=fs.readFileSync(jsPath),wabtSource=fs.readFileSync(path.join(wabtPath,'index.js')),version=JSON.parse(fs.readFileSync(path.join(wabtPath,'package.json'))).version;
 assert.equal(sha(bytes),'4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765');assert.equal(sha(js),'260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f');
 assert(!fs.existsSync(output),'Fresh evidence directory only');const wabt=await require(wabtPath)();const module=wabt.readWasm(bytes,{readDebugNames:false,exceptions:true,threads:true,simd:true,bulk_memory:true,reference_types:true,tail_call:true,extended_const:true});
 let wat;try{wat=module.toText({foldExprs:false,inlineExport:false});}finally{module.destroy();}
 const boundaries=[...wat.matchAll(/^  \(func \(;(\d+);\)/gm)],starts=new Map(boundaries.map((m,i)=>[+m[1],{start:m.index,end:boundaries[i+1]?.index??wat.indexOf('\n  (table ',m.index)}]));
 const imports=[...wat.matchAll(/^  \(import "([^"]+)" "([^"]+)" \(func \(;(\d+);\)([^\n]*)/gm)].map(m=>({index:+m[3],module:m[1],field:m[2],declaration:m[0]}));
 const exports=[...wat.matchAll(/^  \(export "([^"]+)" \(func (\d+)\)\)/gm)].map(m=>({index:+m[2],name:m[1]}));
 const types=new Map([...wat.matchAll(/^  \(type \(;(\d+);\)([^\n]*)/gm)].map(m=>[+m[1],m[0]]));
 const functions=ids.map(id=>{const range=starts.get(id);assert(range&&range.end>range.start);const text=wat.slice(range.start,range.end),lines=text.split('\n');
  const calls=[...text.matchAll(/^\s+(return_)?call (\d+)\s*$/gm)].map(m=>({index:+m[2],tail:!!m[1],imports:imports.filter(i=>i.index===+m[2]),exports:exports.filter(e=>e.index===+m[2])}));
  const indirect=[...text.matchAll(/^.*\b(?:return_)?call_indirect[^\n]*/gm)].map(m=>({instruction:m[0].trim(),type:types.get(+(m[0].match(/\(type (\d+)\)/)?.[1]??-1))??null}));
  return {id,declaration:lines[0],watSha256:sha(text),lines:lines.length,exports:exports.filter(e=>e.index===id),directCalls:calls,indirectCalls:indirect,text};});
 const result={status:'STATIC_EXACT_WASM_DISASSEMBLY_ONLY',runtime:{wasmPath,wasmSha256:sha(bytes),jsPath,jsSha256:sha(js)},tool:{name:'local wabt',version,indexJsSha256:sha(wabtSource)},functions:[],
  importCount:imports.length,definedFunctions:boundaries.length,
  boundary:'Local WABT parses exact shipped target bytes and formats WAT. The target module is never compiled/instantiated/executed. Direct call indices/import/export metadata are static facts; indirect targets and original source names remain unknown unless separately proven. WABT executes its own parser implementation only; no connector/export or hardware/game run.'};
 fs.mkdirSync(output,{recursive:true});for(const f of functions){fs.writeFileSync(path.join(output,'function-'+f.id+'.wat'),f.text,{flag:'wx'});delete f.text;result.functions.push(f);}
 fs.writeFileSync(path.join(output,'imports.json'),JSON.stringify(imports,null,2)+'\n',{flag:'wx'});fs.writeFileSync(path.join(output,'analysis.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 assert.equal(sha(fs.readFileSync(wasmPath)),result.runtime.wasmSha256);assert.equal(sha(fs.readFileSync(jsPath)),result.runtime.jsSha256);
 console.log(JSON.stringify({output,...result},null,2));return result;
}
module.exports={run};if(require.main===module)run(path.resolve(process.argv[2]),process.argv.slice(3).length?process.argv.slice(3).map(Number):undefined).catch(e=>{console.error(e.stack);process.exitCode=1;});
